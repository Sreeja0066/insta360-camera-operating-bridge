import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';

class Insta360Service {
  static const MethodChannel _channel = MethodChannel('com.example.insta360bridge/camera');
  
  // Singleton
  static final Insta360Service instance = Insta360Service._internal();
  Insta360Service._internal() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  final _eventsController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get events => _eventsController.stream;
  
  bool isConnected = false;

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onWifiConnected') {
      isConnected = true;
    }
    _eventsController.add({
      'event': call.method,
      'data': call.arguments,
    });
    return null;
  }

  Future<void> connectCamera() async {
    await _channel.invokeMethod('connectCamera');
  }

  Future<String> getStatus() async {
    return await _channel.invokeMethod('getStatus');
  }

  Future<void> startRecording() async {
    await _channel.invokeMethod('startRecording');
  }

  Future<void> stopRecording() async {
    await _channel.invokeMethod('stopRecording');
  }

  Future<void> scanWifi() async {
    await _channel.invokeMethod('scanWifi');
  }

  Future<void> connectWifi(String ssid, String password) async {
    await _channel.invokeMethod('connectWifi', {'ssid': ssid, 'password': password});
  }

  Future<void> exportRecording(String recordingId) async {
    await _channel.invokeMethod('exportRecording', {'recordingId': recordingId});
  }

  Future<void> setDemoMode(bool enabled) async {
    await _channel.invokeMethod('setDemoMode', {'enabled': enabled});
  }

  Future<T?> invokeMethod<T>(String method, [dynamic arguments]) async {
    return await _channel.invokeMethod<T>(method, arguments);
  }

  Future<List<dynamic>> getRecordings() async {
    final String? result = await _channel.invokeMethod<String>('getRecordings');
    if (result == null) return [];
    return jsonDecode(result);
  }

  // ===== GOOGLE DRIVE =====

  Future<void> signInToDrive() async {
    await _channel.invokeMethod('signInToDrive');
  }

  Future<String> getDriveSignInStatus() async {
    final result = await _channel.invokeMethod<String>('getDriveSignInStatus');
    return result ?? '';
  }

  Future<void> uploadToDrive(String filePath) async {
    await _channel.invokeMethod('uploadToDrive', {'filePath': filePath});
  }

  Future<void> uploadPendingFiles() async {
    await _channel.invokeMethod('uploadPendingFiles');
  }

  Future<int> getPendingUploadCount() async {
    final result = await _channel.invokeMethod<int>('getPendingUploadCount');
    return result ?? 0;
  }
}
