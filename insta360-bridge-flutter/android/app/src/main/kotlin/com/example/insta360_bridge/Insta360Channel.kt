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
    private val cameraControl = CameraControl()
    val wifiHelper = WifiHelper(activity)
    private val videoExporter = VideoExporter(activity)
    private var demoMode = false

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "startRecording" -> startRecording(result)
            "stopRecording" -> stopRecording(result)
            "getStatus" -> result.success(cameraControl.getStatus())
            "connectCamera" -> connectCamera(result)
            "scanWifi" -> scanWifi(result)
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
        mainHandler.post {
            cameraControl.startRecording(object : CameraControl.RecordingCallback {
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
        mainHandler.post {
            cameraControl.stopRecording(object : CameraControl.RecordingCallback {
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
            cameraControl.connect()
            result.success(null)
        }
    }

    private fun scanWifi(result: Result) {
        Log.d(TAG, "Flutter called scanWifi")
        mainHandler.post {
            wifiHelper.startScan() // Trigger a fresh scan in background
            val networks = wifiHelper.getCachedScanResults() // Get current list
            val networkList = networks.map { 
                mapOf("ssid" to it.ssid, "level" to it.level)
            }
            invokeDartEvent("onWifiList", networkList)
            result.success(networkList)
        }
    }

    private fun connectWifi(ssid: String, password: String, result: Result) {
        Log.d(TAG, "Flutter called connectWifi: $ssid")
        mainHandler.post {
            wifiHelper.connectToNetwork(ssid, password)
            result.success(null)
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
        val filePaths = cameraControl.lastCapturedFilePaths
        if (filePaths == null || filePaths.isEmpty()) {
            val safeMsg = "No recording files found. Make sure to record first."
            invokeDartEvent("onExportFailed", mapOf("error" to safeMsg, "resolution" to "all"))
            result.error("FAILED", safeMsg, null)
            return
        }

        mainHandler.post {
            // Fix the "Array<out String>" variance issue by creating a typed copy
            val pathsArray = filePaths.map { it }.toTypedArray()
            videoExporter.exportBothResolutions(
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
}
