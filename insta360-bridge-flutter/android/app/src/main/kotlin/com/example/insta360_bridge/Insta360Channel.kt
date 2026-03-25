package com.example.insta360_bridge

import android.app.Activity
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

class Insta360Channel(
    private val activity: Activity,
    private val methodChannel: MethodChannel
) : MethodCallHandler {

    companion object {
        const val TAG = "Insta360Channel"
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    val wifiHelper = WifiHelper(activity)
    private var demoMode = false
    
    var bgService: Insta360BackgroundService? = null

    fun setService(service: Insta360BackgroundService) {
        this.bgService = service
        Log.d(TAG, "Background Service bound to Flutter Channel!")
    }

    init {
        // Connect WifiHelper results to Flutter events
        wifiHelper.onScanResults = { results ->
            val networkList = results.map { 
                mapOf("ssid" to it.ssid, "level" to it.level)
            }
            invokeDartEvent("onWifiList", networkList)
        }

        wifiHelper.onConnectionStatus = { status ->
            Log.d(TAG, "Wi-Fi connection status: $status")
            invokeDartEvent("onWifiConnected", mapOf("status" to status))
            if (status == "CONNECTED") {
                onWifiConnected()
            }
        }
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "startRecording" -> startRecording(result)
            "stopRecording" -> stopRecording(result)
            "getStatus" -> result.success(bgService?.cameraControl?.getStatus() ?: "DISCONNECTED")
            "connectCamera" -> connectCamera(result)
            "scanWifi" -> scanWifi(result)
            "stopScan" -> {
                wifiHelper.stopScan()
                result.success(null)
            }
            "connectWifi" -> {
                val ssid = call.argument<String>("ssid") ?: ""
                val pwd = call.argument<String>("password") ?: ""
                connectWifi(ssid, pwd, result)
            }
            "saveRecordingMetadata" -> {
                val jsonStr = call.argument<String>("data") ?: ""
                saveRecordingMetadata(jsonStr, result)
            }
            "getRecordings" -> result.success(getRecordings())
            "setDemoMode" -> {
                val enabled = call.argument<Boolean>("enabled") ?: false
                setDemoMode(enabled, result)
            }
            "exportRecording" -> {
                val recordingId = call.argument<String>("recordingId") ?: ""
                exportRecording(recordingId, result)
            }
            "signInToDrive" -> signInToDrive(result)
            "getDriveSignInStatus" -> result.success(getDriveSignInStatus())
            "uploadToDrive" -> {
                val filePath = call.argument<String>("filePath") ?: ""
                uploadToDrive(filePath, result)
            }
            "uploadPendingFiles" -> uploadPendingFiles(result)
            "getPendingUploadCount" -> result.success(bgService?.driveUploader?.getPendingFiles()?.size ?: 0)
            "openWifiSettings" -> {
                val intent = android.content.Intent(android.provider.Settings.ACTION_WIFI_SETTINGS)
                intent.flags = android.content.Intent.FLAG_ACTIVITY_NEW_TASK
                activity.startActivity(intent)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun invokeDartEvent(method: String, arguments: Any? = null) {
        mainHandler.post {
            methodChannel.invokeMethod(method, arguments)
        }
    }

    private fun startRecording(result: Result) {
        Log.d(TAG, "Flutter called startRecording")
        if (bgService == null) {
            result.error("NO_SERVICE", "Background service not bound yet", null)
            return
        }
        mainHandler.post {
            bgService?.cameraControl?.startRecording(object : CameraControl.RecordingCallback {
                override fun onSuccess() {
                    Log.d(TAG, "Recording started")
                    invokeDartEvent("onRecordingStarted")
                    result.success(null)
                }

                override fun onFailed(reason: String) {
                    Log.e(TAG, "Recording failed: $reason")
                    invokeDartEvent("onRecordingFailed", mapOf("reason" to reason))
                    result.error("FAILED", reason, null)
                }
            })
        }
    }

    private fun stopRecording(result: Result) {
        Log.d(TAG, "Flutter called stopRecording")
        if (bgService == null) {
            result.error("NO_SERVICE", "Background service not bound yet", null)
            return
        }
        mainHandler.post {
            bgService?.cameraControl?.stopRecording(object : CameraControl.RecordingCallback {
                override fun onSuccess() {
                    Log.d(TAG, "Recording stopped")
                    invokeDartEvent("onRecordingStopped")
                    result.success(null)
                }

                override fun onFailed(reason: String) {
                    Log.e(TAG, "Stop recording failed: $reason")
                    invokeDartEvent("onRecordingStopFailed", mapOf("reason" to reason))
                    result.error("FAILED", reason, null)
                }
            })
        }
    }

    private fun connectCamera(result: Result) {
        Log.d(TAG, "Flutter called connectCamera")
        mainHandler.post {
            bgService?.cameraControl?.connect()
            result.success(null)
        }
    }

    private fun scanWifi(result: Result) {
        Log.d(TAG, "Flutter called scanWifi")
        mainHandler.post {
            // 1. Immediately return cached results if any
            val cached = wifiHelper.getCachedScanResults()
            val cachedList = cached.map { 
                mapOf("ssid" to it.ssid, "level" to it.level)
            }
            if (cachedList.isNotEmpty()) {
                invokeDartEvent("onWifiList", cachedList)
            }

            // 2. Trigger a fresh scan in background
            wifiHelper.startScan() 
            
            result.success(null) // Return null, results come via onWifiList event
        }
    }

    private fun connectWifi(ssid: String, password: String, result: Result) {
        Log.d(TAG, "Flutter called connectWifi: $ssid")
        mainHandler.post {
            wifiHelper.connectToNetwork(ssid, password)
            result.success(null)
        }
    }

    // Called from init when wifiHelper.onConnectionStatus fires
    private fun onWifiConnected() {
        Log.d(TAG, "Wi-Fi connected! Now auto-connecting camera SDK...")
        mainHandler.post {
            bgService?.cameraControl?.connect()
        }
    }

    private fun saveRecordingMetadata(jsonStr: String, result: Result) {
        try {
            val dir = File(activity.filesDir, "recordings")
            if (!dir.exists()) dir.mkdirs()

            val file = File(dir, "recordings.json")
            val existingJson = if (file.exists()) file.readText() else "[]"
            val recordings = JSONArray(existingJson)

            recordings.put(JSONObject(jsonStr))
            file.writeText(recordings.toString(2))
            
            invokeDartEvent("onMetadataSaved")
            result.success(null)
        } catch (e: Exception) {
            val safeMsg = e.message ?: "Unknown error"
            invokeDartEvent("onMetadataSaveFailed", mapOf("reason" to safeMsg))
            result.error("FAILED", safeMsg, null)
        }
    }

    private fun getRecordings(): String {
        return try {
            val file = File(activity.filesDir, "recordings/recordings.json")
            if (file.exists()) file.readText() else "[]"
        } catch (e: Exception) {
            "[]"
        }
    }

    private fun setDemoMode(enabled: Boolean, result: Result) {
        demoMode = enabled
        result.success(null)
    }

    private fun exportRecording(recordingId: String, result: Result) {
        if (bgService == null) {
            result.error("NO_SERVICE", "Background service not bound yet", null)
            return
        }
        val filePaths = bgService?.cameraControl?.lastCapturedFilePaths
        if (filePaths == null || filePaths.isEmpty()) {
            val safeMsg = "No recording files found. Make sure to record first."
            invokeDartEvent("onExportFailed", mapOf("error" to safeMsg, "resolution" to "all"))
            result.error("FAILED", safeMsg, null)
            return
        }

        mainHandler.post {
            // Fix the "Array<out String>" variance issue by creating a typed copy
            val pathsArray = filePaths.map { it }.toTypedArray()
            bgService?.videoExporter?.exportBothResolutions(
                pathsArray,
                recordingId,
                object : VideoExporter.ExportCallback {
                    override fun onProgress(progress: Float, resolution: String) {
                        val pct = (progress * 100).toInt()
                        invokeDartEvent("onExportProgress", mapOf("progress" to pct, "resolution" to resolution))
                    }

                    override fun onSuccess(outputPath: String, resolution: String) {
                        invokeDartEvent("onExportSuccess", mapOf("path" to outputPath, "resolution" to resolution))
                        if (resolution == "1080P") {
                            result.success("Export Complete")
                        }
                    }

                    override fun onFailed(error: String, resolution: String) {
                        invokeDartEvent("onExportFailed", mapOf("error" to error, "resolution" to resolution))
                        if (resolution == "1080P") {
                            result.error("EXPORT_FAILED", error, null)
                        }
                    }
                }
            )
        }
    }

    // ===== GOOGLE DRIVE =====

    private fun signInToDrive(result: Result) {
        Log.d(TAG, "Flutter called signInToDrive")
        if (activity is MainActivity) {
            (activity as MainActivity).signInToDrive()
            result.success(null)
        } else {
            result.error("NO_ACTIVITY", "MainActivity required", null)
        }
    }

    private fun getDriveSignInStatus(): String {
        return if (activity is MainActivity) {
            (activity as MainActivity).getDriveSignInStatus() ?: ""
        } else ""
    }

    fun onDriveSignInResult(email: String?, error: String?) {
        if (email != null) {
            invokeDartEvent("onDriveSignInSuccess", mapOf("email" to email))
        } else {
            invokeDartEvent("onDriveSignInFailed", mapOf("error" to (error ?: "Unknown error")))
        }
    }

    private fun uploadToDrive(filePath: String, result: Result) {
        Log.d(TAG, "Flutter called uploadToDrive: $filePath")
        val file = java.io.File(filePath)
        if (!file.exists()) {
            invokeDartEvent("onDriveUploadFailed", mapOf("error" to "File does not exist: $filePath"))
            result.error("NOT_FOUND", "File not found", null)
            return
        }

        bgService?.driveUploader?.uploadFile(file, object : DriveUploader.UploadCallback {
            override fun onProgress(progress: Int) {
                invokeDartEvent("onDriveUploadProgress", mapOf("progress" to progress))
            }
            override fun onSuccess(fileId: String) {
                invokeDartEvent("onDriveUploadSuccess", mapOf("fileId" to fileId))
            }
            override fun onError(error: String) {
                invokeDartEvent("onDriveUploadFailed", mapOf("error" to error))
            }
            override fun onQueued(filePath: String) {
                invokeDartEvent("onDriveUploadQueued", mapOf("filePath" to filePath))
            }
        })
        result.success(null)
    }

    private fun uploadPendingFiles(result: Result) {
        Log.d(TAG, "Flutter called uploadPendingFiles")
        bgService?.driveUploader?.uploadPendingFiles(object : DriveUploader.UploadCallback {
            override fun onProgress(progress: Int) {
                invokeDartEvent("onDriveUploadProgress", mapOf("progress" to progress))
            }
            override fun onSuccess(fileId: String) {
                invokeDartEvent("onDriveUploadSuccess", mapOf("fileId" to fileId))
            }
            override fun onError(error: String) {
                invokeDartEvent("onDriveUploadFailed", mapOf("error" to error))
            }
            override fun onQueued(filePath: String) {
                invokeDartEvent("onDriveUploadQueued", mapOf("filePath" to filePath))
            }
        })
        result.success(null)
    }
}
