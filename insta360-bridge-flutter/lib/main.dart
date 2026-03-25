import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import 'package:permission_handler/permission_handler.dart';
import 'insta360_service.dart';

// ===== DESIGN TOKENS (from companion app styles.css) =====
class AppColors {
  static const bg = Color(0xFF0A0E1A);
  static const bgCard = Color(0xDD161E32); // rgba(22,30,50,0.85)
  static const primary = Color(0xFF6366F1);
  static const primaryGlow = Color(0x4D6366F1);
  static const success = Color(0xFF22C55E);
  static const successGlow = Color(0x4D22C55E);
  static const danger = Color(0xFFEF4444);
  static const dangerGlow = Color(0x4DEF4444);
  static const text = Color(0xFFF1F5F9);
  static const textDim = Color(0xFF64748B);
  static const border = Color(0x14FFFFFF); // rgba(255,255,255,0.08)
  static const menuBg = Color(0xFF111827);
}

void main() {
  runApp(const Insta360App());
}

class Insta360App extends StatelessWidget {
  const Insta360App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Insta360 Bridge',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.bg,
        primaryColor: AppColors.primary,
        fontFamily: 'Inter',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
        drawerTheme: const DrawerThemeData(
          backgroundColor: AppColors.menuBg,
        ),
      ),
      home: const MainShell(),
    );
  }
}

// ===== MAIN SHELL WITH DRAWER =====
class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0; // 0=Welcome, 1=Camera, 2=Layout, 3=Gallery
  String _cameraStatus = 'DISCONNECTED';
  String _driveEmail = '';
  late StreamSubscription _eventSub;

  final _pages = const [0, 1, 2, 3];

  @override
  void initState() {
    super.initState();
    _eventSub = Insta360Service.instance.events.listen((event) {
      if (!mounted) return;
      final e = event['event'];
      if (e == 'onWifiConnected') {
        _showToast('Wi-Fi connected! Initializing camera...');
      } else if (e == 'onDriveSignInSuccess') {
        final email = event['data']?['email'] ?? '';
        setState(() => _driveEmail = email);
        _showToast('Linked to Google Drive! ✅');
      } else if (e == 'onDriveSignInFailed') {
        _showToast('Drive linking failed: ${event['data']?['error']}');
      } else if (e == 'onDriveUploadSuccess') {
        _showToast('Uploaded to Google Drive! ☁️✅');
      } else if (e == 'onDriveUploadFailed') {
        _showToast('Drive upload failed: ${event['data']?['error']}');
      } else if (e == 'onDriveUploadQueued') {
        _showToast('No internet — queued for upload ⏳');
      } else if (e == 'onExportSuccess') {
        // Auto-upload to Drive after export if linked
        if (_driveEmail.isNotEmpty) {
          final path = event['data']?['path'] ?? '';
          if (path.isNotEmpty) {
            _showToast('Uploading to Drive... ☁️');
            Insta360Service.instance.uploadToDrive(path);
          }
        }
      }
      _pollStatus();
    });
    // Start polling
    Timer.periodic(const Duration(seconds: 2), (_) => _pollStatus());
    // Check initial Drive status
    _checkDriveStatus();
  }

  void _pollStatus() async {
    try {
      final status = await Insta360Service.instance.getStatus();
      if (!mounted) return;
      final wasDisconnected = _cameraStatus == 'DISCONNECTED';
      setState(() => _cameraStatus = status);

      // Auto-navigate: if camera just connected and we're on camera page
      if (wasDisconnected && status != 'DISCONNECTED' && _currentIndex == 1) {
        _showToast('Camera connected! ✅');
        setState(() => _currentIndex = 2);
      }
    } catch (_) {}
  }

  void _checkDriveStatus() async {
    try {
      final email = await Insta360Service.instance.getDriveSignInStatus();
      if (mounted && email.isNotEmpty) {
        setState(() => _driveEmail = email);
      }
    } catch (_) {}
  }

  void _handleDriveLink() async {
    Navigator.pop(context); // close drawer
    if (_driveEmail.isNotEmpty) {
      // Already linked — check for pending uploads
      try {
        final pending = await Insta360Service.instance.getPendingUploadCount();
        if (pending > 0) {
          _showToast('Linked: $_driveEmail | $pending uploads pending. Uploading...');
          Insta360Service.instance.uploadPendingFiles();
        } else {
          _showToast('Linked to: $_driveEmail | No pending uploads');
        }
      } catch (_) {
        _showToast('Linked to: $_driveEmail');
      }
    } else {
      _showToast('Opening Google Sign-In...');
      await Insta360Service.instance.signInToDrive();
    }
  }

  void _showToast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 13)),
        backgroundColor: AppColors.bgCard,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void navigateTo(int index) {
    // If going to Layout and not connected, redirect to Camera
    if (index == 2 && _cameraStatus == 'DISCONNECTED') {
      _showToast('Please connect to camera first');
      setState(() => _currentIndex = 1);
      Navigator.pop(context); // close drawer
      return;
    }
    setState(() => _currentIndex = index);
    Navigator.pop(context); // close drawer
  }

  Widget _buildStatusDot() {
    Color color;
    if (_cameraStatus == 'DISCONNECTED') {
      color = const Color(0xFF475569);
    } else if (_cameraStatus == 'RECORDING') {
      color = AppColors.danger;
    } else {
      color = AppColors.success;
    }
    return Container(
      width: 10, height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: _cameraStatus != 'DISCONNECTED'
          ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8)]
          : [],
      ),
    );
  }

  String _statusLabel() {
    switch (_cameraStatus) {
      case 'IDLE': return 'Camera Ready';
      case 'RECORDING': return 'Recording...';
      default: return 'Disconnected';
    }
  }

  @override
  void dispose() {
    _eventSub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      drawer: _buildDrawer(),
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu, color: AppColors.text),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.6, -1.0),
            radius: 1.5,
            colors: [Color(0x1F6366F1), Colors.transparent],
          ),
        ),
        child: IndexedStack(
          index: _currentIndex,
          children: [
            WelcomePage(
              status: _cameraStatus,
              statusDot: _buildStatusDot(),
              statusLabel: _statusLabel(),
              onConnect: () => setState(() => _currentIndex = 1),
              onLayout: () {
                if (_cameraStatus == 'DISCONNECTED') {
                  _showToast('Connect camera first');
                  setState(() => _currentIndex = 1);
                } else {
                  setState(() => _currentIndex = 2);
                }
              },
            ),
            CameraPage(
              status: _cameraStatus,
              statusDot: _buildStatusDot(),
              statusLabel: _statusLabel(),
              onConnected: () {
                // Will be handled by polling
              },
            ),
            LayoutPage(
              status: _cameraStatus,
              onNotConnected: () {
                _showToast('Camera not connected! Redirecting...');
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (mounted) setState(() => _currentIndex = 1);
                });
              },
            ),
            const GalleryPage(),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(children: [
                const Text('🎥', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 10),
                const Text('Insta360 Bridge',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text)),
              ]),
            ),
            const Divider(color: AppColors.border, height: 1),
            _drawerItem(Icons.camera_alt, 'Connect to Camera', () => navigateTo(1)),
            _drawerItem(Icons.map, 'Upload Layout', () => navigateTo(2)),
            _drawerItem(Icons.video_library, 'Saved Videos', () => navigateTo(3)),
            const Divider(color: AppColors.border, height: 1),
            ListTile(
              leading: const Icon(Icons.cloud, color: AppColors.textDim, size: 22),
              title: Text(
                _driveEmail.isNotEmpty ? 'Linked: $_driveEmail' : 'Link Google Drive',
                style: TextStyle(
                  fontSize: 14,
                  color: _driveEmail.isNotEmpty ? AppColors.success : AppColors.text,
                ),
              ),
              onTap: _handleDriveLink,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
            ),
            const Divider(color: AppColors.border, height: 1),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                _buildStatusDot(),
                const SizedBox(width: 8),
                Text(_statusLabel(), style: const TextStyle(fontSize: 13, color: AppColors.textDim)),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textDim, size: 22),
      title: Text(label, style: const TextStyle(fontSize: 14, color: AppColors.text)),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
    );
  }
}

// ===================================================================
// WELCOME PAGE
// ===================================================================
class WelcomePage extends StatelessWidget {
  final String status;
  final Widget statusDot;
  final String statusLabel;
  final VoidCallback onConnect;
  final VoidCallback onLayout;

  const WelcomePage({super.key, required this.status, required this.statusDot,
    required this.statusLabel, required this.onConnect, required this.onLayout});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Glow icon
            Stack(alignment: Alignment.center, children: [
              Container(
                width: 120, height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [AppColors.primaryGlow, Colors.transparent],
                  ),
                ),
              ),
              const Text('🎥', style: TextStyle(fontSize: 56)),
            ]),
            const SizedBox(height: 20),
            // Gradient title
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFF818CF8), Color(0xFFA78BFA), Color(0xFFC084FC)],
              ).createShader(bounds),
              child: const Text('Insta360 Bridge',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
            const SizedBox(height: 6),
            const Text('360° Recording Controller',
              style: TextStyle(fontSize: 14, color: AppColors.textDim)),
            const SizedBox(height: 20),
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                statusDot,
                const SizedBox(width: 8),
                Text(statusLabel, style: const TextStyle(fontSize: 13, color: AppColors.text)),
              ]),
            ),
            const SizedBox(height: 28),
            // Buttons
            SizedBox(
              width: 280,
              child: Column(children: [
                _welcomeButton('📷', 'Connect to Camera', true, onConnect),
                const SizedBox(height: 12),
                _welcomeButton('📐', 'Upload Layout', false, onLayout),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _welcomeButton(String icon, String label, bool primary, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity, height: 56,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: primary
            ? null : Colors.white.withOpacity(0.08),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: primary ? BorderSide.none : const BorderSide(color: AppColors.border),
          ),
          elevation: primary ? 8 : 0,
          shadowColor: primary ? AppColors.primaryGlow : Colors.transparent,
        ).copyWith(
          backgroundColor: primary
            ? WidgetStateProperty.all(AppColors.primary)
            : WidgetStateProperty.all(Colors.white.withOpacity(0.08)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

// ===================================================================
// CAMERA PAGE (Wi-Fi Scan + Connect)
// ===================================================================
class CameraPage extends StatefulWidget {
  final String status;
  final Widget statusDot;
  final String statusLabel;
  final VoidCallback onConnected;

  const CameraPage({super.key, required this.status, required this.statusDot,
    required this.statusLabel, required this.onConnected});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  List<dynamic> networks = [];
  bool isScanning = false;
  bool _isIOS = false;
  bool _showFirstTimeSetup = false;
  List<String> logs = ['[System] Ready to connect...'];

  late StreamSubscription _sub;

  @override
  void initState() {
    super.initState();
    _isIOS = Platform.isIOS;
    _sub = Insta360Service.instance.events.listen((event) {
      if (!mounted) return;
      if (event['event'] == 'onWifiList') {
        final data = event['data'] as List<dynamic>;
        setState(() {
          networks = data;
          isScanning = false;
          // On iOS, if no saved cameras, show first-time setup
          if (_isIOS && data.isEmpty) {
            _showFirstTimeSetup = true;
          }
        });
        if (_isIOS) {
          _log(data.isEmpty ? 'No saved cameras. Please set up.' : 'Found ${data.length} saved camera(s).');
        } else {
          _log('Found ${data.length} networks.');
        }
      } else if (event['event'] == 'onWifiConnected') {
        final status = event['data']?['status'] ?? '';
        _log('Connection: $status');
        if (status == 'CONNECTED') {
          _log('Camera WiFi connected! ✅');
          setState(() => _showFirstTimeSetup = false);
        } else if (status == 'USER_DENIED') {
          _log('Connection was cancelled by user.');
        } else if (status == 'INVALID_PASSWORD') {
          _log('Wrong password. Please try again.');
        } else if (status.toString().startsWith('FAILED')) {
          _log('Connection failed: $status');
        }
      }
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  void _log(String msg) {
    setState(() {
      logs.insert(0, '[${TimeOfDay.now().format(context)}] $msg');
      if (logs.length > 8) logs.removeLast();
    });
  }

  void _scan() async {
    setState(() { isScanning = true; networks = []; _showFirstTimeSetup = false; });

    if (_isIOS) {
      _log('Loading saved cameras...');
      await Insta360Service.instance.scanWifi();
    } else {
      _log('Scanning for cameras...');
      var status = await Permission.locationWhenInUse.request();
      if (status.isDenied) {
        if (!mounted) return;
        setState(() => isScanning = false);
        _log('Location permission denied.');
        return;
      }
      await Insta360Service.instance.scanWifi();
    }
  }

  void _stopScan() async {
    _log('Stopping scan...');
    await Insta360Service.instance.stopScan();
    if (mounted) {
      setState(() => isScanning = false);
    }
  }

  void _connect(String ssid, {bool isSaved = false}) {
    final controller = TextEditingController(text: '88888888');
    
    if (isSaved) {
      // Saved camera on iOS — connect directly without asking password
      _log('Auto-connecting to $ssid...');
      Insta360Service.instance.connectWifi(ssid, '');
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Connect to Camera', style: TextStyle(fontSize: 16)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(ssid, style: const TextStyle(fontSize: 13, color: AppColors.textDim)),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            obscureText: true,
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: 'Enter Password',
              filled: true,
              fillColor: Colors.black.withOpacity(0.3),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textDim)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              _log('Connecting to $ssid...');
              setState(() {
                networks = [];
              });
              await Insta360Service.instance.connectWifi(ssid, controller.text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }

  void _openWifiSettings() async {
    _log('Opening WiFi Settings...');
    await Insta360Service.instance.openWifiSettings();
  }

  void _addNewCameraIOS() {
    // Show dialog explaining how to add a new camera
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Add New Camera', style: TextStyle(fontSize: 16)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Steps:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('1. Open WiFi Settings below', style: TextStyle(fontSize: 13, color: AppColors.textDim)),
          const Text('2. Connect to your camera\'s WiFi', style: TextStyle(fontSize: 13, color: AppColors.textDim)),
          const Text('   (e.g., ONE X3 XXXX.OSC)', style: TextStyle(fontSize: 12, color: AppColors.textDim)),
          const Text('3. Come back to this app', style: TextStyle(fontSize: 13, color: AppColors.textDim)),
          const Text('4. Enter the camera password', style: TextStyle(fontSize: 13, color: AppColors.textDim)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _openWifiSettings();
              },
              icon: const Icon(Icons.wifi, size: 18),
              label: const Text('Open WiFi Settings'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              // After returning from settings, prompt for SSID and password
              _promptSaveCamera();
            },
            child: const Text('I\'ve connected — Save Camera', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  void _promptSaveCamera() async {
    // Try to get current SSID
    String? currentSSID;
    try {
      currentSSID = await Insta360Service.instance.getCurrentSSID();
    } catch (_) {}

    final ssidController = TextEditingController(text: currentSSID ?? '');
    final passwordController = TextEditingController(text: '88888888');

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Save Camera', style: TextStyle(fontSize: 16)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: ssidController,
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: 'Camera WiFi Name (SSID)',
              filled: true,
              fillColor: Colors.black.withOpacity(0.3),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: passwordController,
            obscureText: true,
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: 'Camera WiFi Password',
              filled: true,
              fillColor: Colors.black.withOpacity(0.3),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
            ),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textDim)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final ssid = ssidController.text.trim();
              final password = passwordController.text.trim();
              if (ssid.isNotEmpty && password.isNotEmpty) {
                _log('Saving & connecting to $ssid...');
                await Insta360Service.instance.connectWifi(ssid, password);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Save & Connect'),
          ),
        ],
      ),
    );
  }

  void _deleteSavedCamera(String ssid) async {
    await Insta360Service.instance.removeSavedCamera(ssid);
    _log('Removed $ssid');
    _scan(); // Refresh list
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFF818CF8), Color(0xFFA78BFA)],
              ).createShader(bounds),
              child: const Text('Connect to Camera',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
            const SizedBox(height: 16),
            // Camera card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(children: [
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    widget.statusDot,
                    const SizedBox(width: 8),
                    Text(widget.statusLabel, style: const TextStyle(fontSize: 13)),
                  ]),
                ),
                const SizedBox(height: 16),
                // Scan / Load saved cameras button
                SizedBox(
                  width: double.infinity, height: 48,
                  child: OutlinedButton(
                    onPressed: isScanning ? null : _scan,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.border),
                      backgroundColor: Colors.white.withOpacity(0.05),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      isScanning
                        ? (_isIOS ? 'Loading...' : 'Scanning...')
                        : (_isIOS ? '📷 Load Saved Cameras' : '🔍 Scan for Cameras'),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text),
                    ),
                  ),
                ),
                // iOS: Add New Camera button
                if (_isIOS) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity, height: 48,
                    child: OutlinedButton(
                      onPressed: _addNewCameraIOS,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primary),
                        backgroundColor: AppColors.primary.withOpacity(0.1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        '+ Add New Camera',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                // Network / Saved Camera list
                if (networks.isNotEmpty || isScanning)
                  Container(
                    constraints: const BoxConstraints(maxHeight: 250),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: isScanning
                      ? const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: networks.length,
                          separatorBuilder: (_, __) => const Divider(color: AppColors.border, height: 1),
                          itemBuilder: (_, i) {
                            final net = networks[i];
                            final ssid = net['ssid'] ?? '';
                            final isSaved = net['saved'] == true;
                            final isLastUsed = net['isLastUsed'] == 'true';
                            
                            if (_isIOS) {
                              // iOS: show saved cameras with auto-connect and delete
                              return ListTile(
                                leading: Icon(
                                  isLastUsed ? Icons.star : Icons.wifi,
                                  color: isLastUsed ? const Color(0xFFF59E0B) : AppColors.textDim,
                                  size: 20,
                                ),
                                title: Text(ssid, style: const TextStyle(fontSize: 14)),
                                subtitle: isLastUsed
                                  ? const Text('Last used', style: TextStyle(fontSize: 11, color: Color(0xFFF59E0B)))
                                  : null,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: AppColors.textDim, size: 18),
                                      onPressed: () => _deleteSavedCamera(ssid),
                                    ),
                                    const Icon(Icons.chevron_right, color: AppColors.textDim, size: 20),
                                  ],
                                ),
                                onTap: () => _connect(ssid, isSaved: true),
                                dense: true,
                              );
                            } else {
                              // Android: show scanned WiFi networks
                              final level = net['level'] ?? 0;
                              return ListTile(
                                title: Text(ssid, style: const TextStyle(fontSize: 14)),
                                trailing: Text('${level}dBm', style: const TextStyle(fontSize: 12, color: AppColors.textDim)),
                                onTap: () => _connect(ssid),
                                dense: true,
                              );
                            }
                          },
                        ),
                  ),
                // iOS first-time setup message
                if (_isIOS && _showFirstTimeSetup)
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                    ),
                    child: Column(children: [
                      const Text('📱 First Time Setup', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      const Text(
                        'Tap "+ Add New Camera" above to connect your Insta360 camera for the first time. After the first setup, the app will auto-connect!',
                        style: TextStyle(fontSize: 12, color: AppColors.textDim),
                        textAlign: TextAlign.center,
                      ),
                    ]),
                  ),
              ]),
            ),
            const Spacer(),
            // Logs
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: logs.map((l) => Text(l,
                    style: const TextStyle(fontSize: 11, color: AppColors.textDim, fontFamily: 'monospace'),
                  )).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===================================================================
// LAYOUT & RECORDING PAGE
// ===================================================================
class LayoutPage extends StatefulWidget {
  final String status;
  final VoidCallback onNotConnected;

  const LayoutPage({super.key, required this.status, required this.onNotConnected});

  @override
  State<LayoutPage> createState() => _LayoutPageState();
}

class _LayoutPageState extends State<LayoutPage> {
  File? layoutImage;
  Offset? startPoint;
  Offset? stopPoint;
  bool isRecording = false;
  String instructionText = 'Tap on the map to set a start point';
  Timer? _timer;
  int _seconds = 0;
  List<String> logs = ['[System] Ready...'];

  late StreamSubscription _sub;

  @override
  void initState() {
    super.initState();
    _sub = Insta360Service.instance.events.listen((event) {
      if (!mounted) return;
      final e = event['event'];
      if (e == 'onRecordingStarted') {
        setState(() {
          isRecording = true;
          _seconds = 0;
          instructionText = 'Recording... Tap map to set stop point';
        });
        _timer = Timer.periodic(const Duration(seconds: 1), (_) {
          setState(() => _seconds++);
        });
        _layoutLog('Recording STARTED ✅');
      } else if (e == 'onRecordingStopped') {
        _timer?.cancel();
        _saveMetadata();
        setState(() {
          isRecording = false;
          instructionText = 'Recording saved! Tap map to set new start point';
          startPoint = null;
          stopPoint = null;
        });
        _layoutLog('Recording STOPPED ✅');
      } else if (e == 'onRecordingFailed') {
        setState(() => isRecording = false);
        final reason = event['data']?['reason'] ?? 'Unknown';
        _layoutLog('Recording FAILED: $reason');
        if (reason.toString().toLowerCase().contains('not connected')) {
          widget.onNotConnected();
        }
      }
    });
  }

  void _layoutLog(String msg) {
    setState(() {
      logs.insert(0, '[${TimeOfDay.now().format(context)}] $msg');
      if (logs.length > 8) logs.removeLast();
    });
  }

  void _saveMetadata() {
    final metadata = {
      'id': 'rec_${DateTime.now().millisecondsSinceEpoch}',
      'timestamp': DateTime.now().toIso8601String(),
      'duration': _seconds,
      'startPoint': startPoint != null ? {'x': startPoint!.dx, 'y': startPoint!.dy} : null,
      'stopPoint': stopPoint != null ? {'x': stopPoint!.dx, 'y': stopPoint!.dy} : null,
    };
    Insta360Service.instance.invokeMethod('saveRecordingMetadata', {'data': jsonEncode(metadata)});
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        layoutImage = File(image.path);
        startPoint = null;
        stopPoint = null;
      });
      _layoutLog('Layout uploaded.');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sub.cancel();
    super.dispose();
  }

  String _formatTime(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = widget.status != 'DISCONNECTED';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with connection badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFF818CF8), Color(0xFFA78BFA)],
                  ).createShader(bounds),
                  child: const Text('Layout & Recording',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isConnected ? AppColors.success : const Color(0xFF475569),
                      boxShadow: isConnected ? [BoxShadow(color: AppColors.successGlow, blurRadius: 6)] : [],
                    )),
                    const SizedBox(width: 6),
                    Text(isConnected ? 'Ready' : 'Offline',
                      style: const TextStyle(fontSize: 11, color: AppColors.textDim)),
                  ]),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Content
            Expanded(
              child: layoutImage == null
                ? _buildUploadZone()
                : _buildCanvasArea(),
            ),
            // Recording controls
            if (layoutImage != null) ...[
              const SizedBox(height: 12),
              // Recording status indicator
              if (isRecording)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.danger.withOpacity(0.2)),
                  ),
                  child: Row(children: [
                    Container(width: 10, height: 10, decoration: const BoxDecoration(
                      shape: BoxShape.circle, color: AppColors.danger,
                    )),
                    const SizedBox(width: 8),
                    const Text('REC', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.danger, letterSpacing: 0.5)),
                    const Spacer(),
                    Text(_formatTime(_seconds), style: const TextStyle(fontSize: 13, color: AppColors.textDim, fontFamily: 'monospace')),
                  ]),
                ),
              const SizedBox(height: 10),
              // Start/Stop button
              SizedBox(
                width: double.infinity, height: 56,
                child: isRecording
                  ? ElevatedButton(
                      onPressed: stopPoint == null ? null : () => Insta360Service.instance.stopRecording(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.danger,
                        disabledBackgroundColor: AppColors.danger.withOpacity(0.4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text('⏹ STOP RECORDING (${_formatTime(_seconds)})',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
                    )
                  : ElevatedButton(
                      onPressed: startPoint == null ? null : () {
                        if (!isConnected) {
                          widget.onNotConnected();
                          return;
                        }
                        Insta360Service.instance.startRecording();
                        _layoutLog('Sending start recording...');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        disabledBackgroundColor: AppColors.success.withOpacity(0.4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('⏺ START RECORDING',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
                    ),
              ),
              const SizedBox(height: 8),
              // Util buttons
              Row(children: [
                Expanded(child: _utilButton('🔄 Reset Points', () {
                  setState(() { startPoint = null; stopPoint = null;
                    instructionText = 'Tap on the map to set a start point';
                  });
                  _layoutLog('Points reset.');
                })),
                const SizedBox(width: 10),
                Expanded(child: _utilButton('📤 Change Layout', _pickImage)),
              ]),
            ],
            const SizedBox(height: 12),
            // Logs
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              constraints: const BoxConstraints(maxHeight: 100),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: logs.map((l) => Text(l,
                    style: const TextStyle(fontSize: 11, color: AppColors.textDim, fontFamily: 'monospace'),
                  )).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadZone() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 2, strokeAlign: BorderSide.strokeAlignInside),
        ),
        child: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('📤', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            const Text('Tap to Upload Layout', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text('Upload a floor plan or map image', style: TextStyle(fontSize: 12, color: AppColors.textDim)),
          ]),
        ),
      ),
    );
  }

  Widget _buildCanvasArea() {
    return Column(children: [
      // Instruction bar
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(instructionText,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: AppColors.textDim)),
      ),
      const SizedBox(height: 8),
      // Canvas
      Expanded(
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.all(12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: GestureDetector(
              onTapUp: (details) {
                if (isRecording) {
                  setState(() {
                    stopPoint = details.localPosition;
                    instructionText = 'Stop point set ✅ — Tap to move, or press STOP';
                  });
                  _layoutLog('Stop point set.');
                } else {
                  setState(() {
                    startPoint = details.localPosition;
                    stopPoint = null;
                    instructionText = 'Start point set ✅ — Tap to move, or press START';
                  });
                  _layoutLog('Start point set.');
                }
              },
              child: Stack(children: [
                Image.file(layoutImage!, fit: BoxFit.contain, width: double.infinity),
                CustomPaint(
                  painter: MapPainter(startPoint: startPoint, stopPoint: stopPoint),
                  size: Size.infinite,
                ),
              ]),
            ),
          ),
        ),
      ),
      // Legend
      if (startPoint != null || stopPoint != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(children: [
            if (startPoint != null) _legendItem(AppColors.success, 'Start'),
            if (startPoint != null && stopPoint != null) const SizedBox(width: 16),
            if (stopPoint != null) _legendItem(AppColors.danger, 'Stop'),
          ]),
        ),
    ]);
  }

  Widget _legendItem(Color color, String label) {
    return Row(children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(
        shape: BoxShape.circle, color: color,
        boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 6)],
      )),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textDim)),
    ]);
  }

  Widget _utilButton(String label, VoidCallback onTap) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: AppColors.border),
        backgroundColor: Colors.white.withOpacity(0.05),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textDim)),
    );
  }
}

// ===== MAP PAINTER =====
class MapPainter extends CustomPainter {
  final Offset? startPoint;
  final Offset? stopPoint;

  MapPainter({this.startPoint, this.stopPoint});

  @override
  void paint(Canvas canvas, Size size) {
    if (startPoint != null) _drawMarker(canvas, startPoint!, AppColors.success, 'S');
    if (stopPoint != null) _drawMarker(canvas, stopPoint!, AppColors.danger, 'E');
  }

  void _drawMarker(Canvas canvas, Offset pos, Color color, String label) {
    final paint = Paint()..color = color;
    final glow = Paint()..color = color.withOpacity(0.3);
    canvas.drawCircle(pos, 18, glow);
    canvas.drawCircle(pos, 14, paint);
    canvas.drawCircle(pos, 14, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2);
    final tp = TextPainter(
      text: TextSpan(text: label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ===================================================================
// GALLERY PAGE
// ===================================================================
class GalleryPage extends StatefulWidget {
  const GalleryPage({super.key});
  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  List<dynamic> recordings = [];

  @override
  void initState() {
    super.initState();
    _loadGallery();
  }

  void _loadGallery() async {
    final results = await Insta360Service.instance.getRecordings();
    if (mounted) setState(() => recordings = results);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFF818CF8), Color(0xFFA78BFA)],
                  ).createShader(bounds),
                  child: const Text('Saved Videos',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text('${recordings.length} recording${recordings.length != 1 ? 's' : ''}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textDim)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Content
            Expanded(
              child: recordings.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: () async => _loadGallery(),
                    child: ListView.separated(
                      itemCount: recordings.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => _buildRecordingCard(recordings[i]),
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Opacity(opacity: 0.6, child: Text('🎬', style: TextStyle(fontSize: 56))),
        const SizedBox(height: 12),
        const Text('No recordings yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        const Text('Complete a recording on the Layout page',
          style: TextStyle(fontSize: 13, color: AppColors.textDim), textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _buildRecordingCard(dynamic rec) {
    final id = rec['id'] ?? 'Unknown';
    final ts = rec['timestamp'] != null ? DateTime.tryParse(rec['timestamp']) : null;
    final dateStr = ts != null ? DateFormat('MMM d, yyyy · hh:mm a').format(ts) : '';
    final dur = rec['duration'] ?? 0;
    final durStr = '${(dur ~/ 60).toString().padLeft(2, '0')}:${(dur % 60).toString().padLeft(2, '0')}';
    final sp = rec['startPoint'];
    final ep = rec['stopPoint'];
    final startStr = sp != null ? '(${sp['x']?.toStringAsFixed(2)}, ${sp['y']?.toStringAsFixed(2)})' : 'N/A';
    final stopStr = ep != null ? '(${ep['x']?.toStringAsFixed(2)}, ${ep['y']?.toStringAsFixed(2)})' : 'N/A';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(id, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary, fontFamily: 'monospace')),
          Text(dateStr, style: const TextStyle(fontSize: 11, color: AppColors.textDim)),
        ]),
        const SizedBox(height: 10),
        // Chips
        Wrap(spacing: 8, children: [
          _chip('🎥', '8K / 30fps'),
          _chip('📁', 'MP4'),
          _chip('⚡', 'FlowState'),
        ]),
        const SizedBox(height: 10),
        // Points
        Row(children: [
          _pointBadge(AppColors.success, 'Start: $startStr'),
          const SizedBox(width: 12),
          _pointBadge(AppColors.danger, 'Stop: $stopStr'),
        ]),
        const Divider(color: AppColors.border, height: 20),
        // Footer
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            const Text('⏺ ', style: TextStyle(color: AppColors.danger, fontSize: 13)),
            Text(durStr, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'monospace')),
          ]),
          OutlinedButton(
            onPressed: () {
              Insta360Service.instance.exportRecording(id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Exporting $id...'), behavior: SnackBarBehavior.floating),
              );
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.border),
              backgroundColor: Colors.white.withOpacity(0.05),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('📤 Export', style: TextStyle(fontSize: 12, color: AppColors.textDim)),
          ),
        ]),
      ]),
    );
  }

  Widget _chip(String icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(icon, style: const TextStyle(fontSize: 12)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textDim)),
      ]),
    );
  }

  Widget _pointBadge(Color color, String label) {
    return Row(children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(
        shape: BoxShape.circle, color: color,
        boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 6)],
      )),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textDim)),
    ]);
  }
}
