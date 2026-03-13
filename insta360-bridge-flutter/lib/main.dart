import 'package:flutter/material.dart';
import 'dart:async';
import 'insta360_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Insta360 Bridge',
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.deepPurple,
        scaffoldBackgroundColor: const Color(0xFF1E1E2E), // Modern dark theme
      ),
      home: const WelcomeScreen(),
    );
  }
}

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  String status = "DISCONNECTED";
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    Insta360Service.instance.events.listen((event) {
      if (event['event'] == 'onStatusUpdate') {
         // handle if native streams it
      }
    });
    
    _statusTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
       try {
         final s = await Insta360Service.instance.getStatus();
         setState(() {
           status = s;
         });
       } catch (e) {
         // Ignore
       }
    }); // Poll status like app.js did
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Insta360 Bridge'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Text(
                status,
                style: TextStyle(
                  color: status == "RECORDING" ? Colors.red : Colors.greenAccent
                ),
              ),
            ),
          )
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
               onPressed: () {
                 Navigator.push(context, MaterialPageRoute(builder: (_) => const WifiScreen()));
               },
               style: ElevatedButton.styleFrom(minimumSize: const Size(200, 50)),
               child: const Text('Connect Camera'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
               onPressed: () {
                 if (status == "IDLE" || true) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const LayoutScreen()));
                 } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                       const SnackBar(content: Text('Camera not ready. Test mode enabled?'))
                    );
                 }
               },
               style: ElevatedButton.styleFrom(minimumSize: const Size(200, 50)),
               child: const Text('Layout & Record'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
               onPressed: () {
                 Navigator.push(context, MaterialPageRoute(builder: (_) => const GalleryScreen()));
               },
               style: ElevatedButton.styleFrom(minimumSize: const Size(200, 50)),
               child: const Text('Gallery'),
            )
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// WIFI SCREEN (Camera Connect)
// -------------------------------------------------------------
class WifiScreen extends StatefulWidget {
  const WifiScreen({super.key});

  @override
  State<WifiScreen> createState() => _WifiScreenState();
}

class _WifiScreenState extends State<WifiScreen> {
  List<dynamic> networks = [];
  bool isScanning = false;

  @override
  void initState() {
    super.initState();
    Insta360Service.instance.events.listen((event) {
      if (event['event'] == 'onWifiList') {
        setState(() {
          networks = event['data'];
          isScanning = false;
        });
      }
    });
  }

  void scan() async {
    setState(() { isScanning = true; networks = []; });
    await Insta360Service.instance.scanWifi();
  }

  void connect(String ssid) {
    showDialog(context: context, builder: (context) {
      String pwd = '';
      return AlertDialog(
        title: Text('Connect to $ssid'),
        content: TextField(
          obscureText: true,
          decoration: const InputDecoration(hintText: 'Password (usually 88888888)'),
          onChanged: (v) => pwd = v,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await Insta360Service.instance.connectWifi(ssid, pwd);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connecting... check main screen status.')));
            }, 
            child: const Text('Connect')
          )
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connect to Camera')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: isScanning ? null : scan, 
              icon: isScanning ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2,) : const Icon(Icons.wifi_find), 
              label: const Text('Scan WiFi Networks')
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: networks.length,
              itemBuilder: (context, index) {
                final net = networks[index];
                return ListTile(
                  leading: const Icon(Icons.wifi),
                  title: Text(net['ssid'] ?? 'Unknown'),
                  subtitle: Text(net['capabilities'] ?? ''),
                  onTap: () => connect(net['ssid'] ?? ''),
                );
              }
            )
          )
        ],
      )
    );
  }
}

// -------------------------------------------------------------
// LAYOUT & RECORD SCREEN
// -------------------------------------------------------------
class LayoutScreen extends StatefulWidget {
  const LayoutScreen({super.key});

  @override
  State<LayoutScreen> createState() => _LayoutScreenState();
}

class _LayoutScreenState extends State<LayoutScreen> {
  bool isRecording = false;

  @override
  void initState() {
    super.initState();
    Insta360Service.instance.events.listen((event) {
      if (event['event'] == 'onRecordingStarted') {
        setState(() => isRecording = true);
      } else if (event['event'] == 'onRecordingStopped') {
        setState(() => isRecording = false);
        // Trigger export logically next!
        final id = DateTime.now().millisecondsSinceEpoch.toString();
        Insta360Service.instance.exportRecording(id);
      } else if (event['event'] == 'onExportProgress') {
         // handle progress visually
      } else if (event['event'] == 'onExportSuccess') {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export matched!')));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Layout & Record')),
      body: Center(
        child: isRecording
            ? ElevatedButton.icon(
                onPressed: () async => await Insta360Service.instance.stopRecording(),
                icon: const Icon(Icons.stop),
                label: const Text('Stop Recording'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, minimumSize: const Size(200, 80)),
              )
            : ElevatedButton.icon(
                onPressed: () async => await Insta360Service.instance.startRecording(),
                icon: const Icon(Icons.circle, color: Colors.red),
                label: const Text('Start Recording'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white12, minimumSize: const Size(200, 80)),
              ),
      )
    );
  }
}

// -------------------------------------------------------------
// GALLERY SCREEN
// -------------------------------------------------------------
class GalleryScreen extends StatelessWidget {
  const GalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gallery (Exports)')),
      body: const Center(child: Text('Gallery goes here'))
    );
  }
}
