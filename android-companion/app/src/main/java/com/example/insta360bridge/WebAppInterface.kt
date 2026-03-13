package com.example.insta360bridge

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.webkit.JavascriptInterface
import android.webkit.WebView
import android.util.Log
import org.json.JSONObject
import org.json.JSONArray
import java.io.File

class WebAppInterface(
    private val mContext: Context,
    private val cameraControl: CameraControl,
    private val webView: WebView
) {
    private val driveUploader = DriveUploader(mContext)
    private var demoMode = false

    companion object {
        const val TAG = "WebAppInterface"
    }

    private val mainHandler = Handler(Looper.getMainLooper())

    /**
     * Helper to safely call JavaScript on the WebView (must be on main thread)
     */
    private fun callJs(script: String) {
        mainHandler.post {
            webView.evaluateJavascript(script, null)
        }
    }

    /**
     * Start recording — uses callback to notify JS of REAL result.
     */
    @JavascriptInterface
    fun startRecording() {
        Log.d(TAG, "JS called startRecording")
        mainHandler.post {
            cameraControl.startRecording(object : CameraControl.RecordingCallback {
                override fun onSuccess() {
                    Log.d(TAG, "Recording started — notifying JS")
                    callJs("if(window.onRecordingStarted) window.onRecordingStarted()")
                }

                override fun onFailed(reason: String) {
                    Log.e(TAG, "Recording failed: $reason")
                    val safeReason = reason.replace("'", "\\'")
                    callJs("if(window.onRecordingFailed) window.onRecordingFailed('$safeReason')")
                }
            })
        }
    }

    /**
     * Stop recording — uses callback to notify JS of REAL result.
     */
    @JavascriptInterface
    fun stopRecording() {
        Log.d(TAG, "JS called stopRecording")
        mainHandler.post {
            cameraControl.stopRecording(object : CameraControl.RecordingCallback {
                override fun onSuccess() {
                    Log.d(TAG, "Recording stopped — notifying JS")
                    callJs("if(window.onRecordingStopped) window.onRecordingStopped()")
                }

                override fun onFailed(reason: String) {
                    Log.e(TAG, "Stop recording failed: $reason")
                    val safeReason = reason.replace("'", "\\'")
                    callJs("if(window.onRecordingStopFailed) window.onRecordingStopFailed('$safeReason')")
                }
            })
        }
    }

    /**
     * Get current camera status — synchronous, returns immediately.
     */
    @JavascriptInterface
    fun getStatus(): String {
        return cameraControl.getStatus()
    }

    /**
     * Connect to camera via SDK (after WiFi is connected).
     */
    @JavascriptInterface
    fun connectCamera() {
        Log.d(TAG, "JS called connectCamera")
        mainHandler.post {
            cameraControl.connect()
        }
    }

    /**
     * Scan for available WiFi networks.
     */
    @JavascriptInterface
    fun scanWifi() {
        Log.d(TAG, "JS called scanWifi")
        if (mContext is MainActivity) {
            mainHandler.post {
                mContext.scanWifi()
            }
        }
    }

    /**
     * Connect to a WiFi network (camera's WiFi).
     */
    @JavascriptInterface
    fun connectWifi(ssid: String, password: String) {
        Log.d(TAG, "JS called connectWifi: $ssid")
        if (mContext is MainActivity) {
            mainHandler.post {
                mContext.connectWifi(ssid, password)
            }
        }
    }

    /**
     * Save recording metadata (start/stop points, timestamps) to local storage.
     */
    @JavascriptInterface
    fun saveRecordingMetadata(jsonStr: String) {
        Log.d(TAG, "Saving recording metadata")
        try {
            val dir = File(mContext.filesDir, "recordings")
            if (!dir.exists()) dir.mkdirs()

            val file = File(dir, "recordings.json")

            // Read existing recordings
            val existingJson = if (file.exists()) file.readText() else "[]"
            val recordings = JSONArray(existingJson)

            // Add new recording
            recordings.put(JSONObject(jsonStr))

            // Save
            file.writeText(recordings.toString(2))
            Log.d(TAG, "Recording metadata saved. Total: ${recordings.length()}")

            callJs("if(window.onMetadataSaved) window.onMetadataSaved()")
        } catch (e: Exception) {
            Log.e(TAG, "Error saving metadata: ${e.message}")
            val safeMsg = (e.message ?: "Unknown error").replace("'", "\\'")
            callJs("if(window.onMetadataSaveFailed) window.onMetadataSaveFailed('$safeMsg')")
        }
    }

    /**
     * Get all saved recording metadata as JSON string.
     */
    @JavascriptInterface
    fun getRecordings(): String {
        return try {
            val file = File(mContext.filesDir, "recordings/recordings.json")
            if (file.exists()) file.readText() else "[]"
        } catch (e: Exception) {
            Log.e(TAG, "Error reading recordings: ${e.message}")
            "[]"
        }
    }

    // ===== DEMO/TEST MODE =====

    /**
     * Enable or disable demo mode for testing without camera.
     */
    @JavascriptInterface
    fun setDemoMode(enabled: Boolean) {
        demoMode = enabled
        Log.d(TAG, "Demo mode: $enabled")
    }

    @JavascriptInterface
    fun isDemoMode(): Boolean {
        return demoMode
    }

    /**
     * Simulate start recording — fires onRecordingStarted after 2s delay.
     * Use this to test the full UI flow without a real camera.
     */
    @JavascriptInterface
    fun testStartRecording() {
        Log.d(TAG, "TEST: Simulating start recording...")
        callJs("if(window.onRecordingStarted) window.onRecordingStarted()")
    }

    /**
     * Simulate stop recording — fires onRecordingStopped after 1s delay.
     */
    @JavascriptInterface
    fun testStopRecording() {
        Log.d(TAG, "TEST: Simulating stop recording...")
        mainHandler.postDelayed({
            callJs("if(window.onRecordingStopped) window.onRecordingStopped()")
        }, 1000)
    }

    // ===== VIDEO EXPORT =====

    private val videoExporter = VideoExporter(mContext)

    /**
     * Export the last recording at both 8K and 1080P resolutions.
     * Uses the file paths captured from onCaptureFinish.
     *
     * @param recordingId The recording ID for naming the output files
     */
    @JavascriptInterface
    fun exportRecording(recordingId: String) {
        Log.d(TAG, "JS called exportRecording: $recordingId")

        val filePaths = cameraControl.lastCapturedFilePaths
        if (filePaths == null || filePaths.isEmpty()) {
            Log.e(TAG, "No captured file paths available for export")
            val safeMsg = "No recording files found. Make sure to record first."
            callJs("if(window.onExportFailed) window.onExportFailed('$safeMsg', 'all')")
            return
        }

        mainHandler.post {
            videoExporter.exportBothResolutions(
                filePaths.map { it }.toTypedArray(),
                recordingId,
                object : VideoExporter.ExportCallback {
                    override fun onProgress(progress: Float, resolution: String) {
                        val pct = (progress * 100).toInt()
                        callJs("if(window.onExportProgress) window.onExportProgress($pct, '$resolution')")
                    }

                    override fun onSuccess(outputPath: String, resolution: String) {
                        val safePath = outputPath.replace("'", "\\'")
                        callJs("if(window.onExportSuccess) window.onExportSuccess('$safePath', '$resolution')")
                    }

                    override fun onFailed(error: String, resolution: String) {
                        val safeError = error.replace("'", "\\'")
                        callJs("if(window.onExportFailed) window.onExportFailed('$safeError', '$resolution')")
                    }
                }
            )
        }
    }

    /**
     * Get list of exported video files as JSON string.
     */
    @JavascriptInterface
    fun getExportedFiles(): String {
        return try {
            val files = videoExporter.getExportedFiles()
            val jsonArray = org.json.JSONArray()
            files.forEach { fileMap ->
                val jsonObj = org.json.JSONObject()
                fileMap.forEach { (key, value) ->
                    jsonObj.put(key, value)
                }
                jsonArray.put(jsonObj)
            }
            jsonArray.toString()
        } catch (e: Exception) {
            Log.e(TAG, "Error getting exported files: ${e.message}")
            "[]"
        }
    }

    // ===== GOOGLE DRIVE =====

    @JavascriptInterface
    fun signInToDrive() {
        Log.d(TAG, "JS called signInToDrive")
        if (mContext is MainActivity) {
            mainHandler.post {
                mContext.signInToDrive()
            }
        }
    }

    @JavascriptInterface
    fun getDriveSignInStatus(): String {
        Log.d(TAG, "JS called getDriveSignInStatus")
        if (mContext is MainActivity) {
            return mContext.getDriveSignInStatus() ?: ""
        }
        return ""
    }

    @JavascriptInterface
    fun uploadToDrive(filePath: String) {
        Log.d(TAG, "JS called uploadToDrive: $filePath")
        val file = File(filePath)
        if (!file.exists()) {
            callJs("if(window.onDriveUploadFailed) window.onDriveUploadFailed('File does not exist: $filePath')")
            return
        }

        driveUploader.uploadFile(file, object : DriveUploader.UploadCallback {
            override fun onProgress(progress: Int) {
                callJs("if(window.onDriveUploadProgress) window.onDriveUploadProgress($progress)")
            }

            override fun onSuccess(fileId: String) {
                callJs("if(window.onDriveUploadSuccess) window.onDriveUploadSuccess('$fileId')")
            }

            override fun onError(error: String) {
                val safeError = error.replace("'", "\\'")
                callJs("if(window.onDriveUploadFailed) window.onDriveUploadFailed('$safeError')")
            }

            override fun onQueued(filePath: String) {
                callJs("if(window.onDriveUploadQueued) window.onDriveUploadQueued('$filePath')")
            }
        })
    }

    @JavascriptInterface
    fun uploadPendingFiles() {
        Log.d(TAG, "JS called uploadPendingFiles")
        driveUploader.uploadPendingFiles(object : DriveUploader.UploadCallback {
            override fun onProgress(progress: Int) {
                callJs("if(window.onDriveUploadProgress) window.onDriveUploadProgress($progress)")
            }

            override fun onSuccess(fileId: String) {
                callJs("if(window.onDriveUploadSuccess) window.onDriveUploadSuccess('$fileId')")
            }

            override fun onError(error: String) {
                val safeError = error.replace("'", "\\\\'")
                callJs("if(window.onDriveUploadFailed) window.onDriveUploadFailed('$safeError')")
            }

            override fun onQueued(filePath: String) {
                callJs("if(window.onDriveUploadQueued) window.onDriveUploadQueued('$filePath')")
            }
        })
    }

    @JavascriptInterface
    fun getPendingUploadCount(): Int {
        return driveUploader.getPendingFiles().size
    }
}
