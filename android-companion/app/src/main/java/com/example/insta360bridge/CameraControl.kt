package com.example.insta360bridge

import android.util.Log
import com.arashivision.sdkcamera.camera.InstaCameraManager
import com.arashivision.sdkcamera.camera.callback.ICameraChangedCallback
import com.arashivision.sdkcamera.camera.callback.ICaptureStatusListener

class CameraControl : ICameraChangedCallback, ICaptureStatusListener {

    private val cameraManager = InstaCameraManager.getInstance()

    private var isConnected = false
    private var isRecording = false

    interface RecordingCallback {
        fun onSuccess()
        fun onFailed(reason: String)
    }

    private var pendingStartCallback: RecordingCallback? = null
    private var pendingStopCallback: RecordingCallback? = null

    var lastCapturedFilePaths: Array<out String>? = null
        private set

    companion object {
        const val TAG = "CameraControl"
    }

    init {
        cameraManager.registerCameraChangedCallback(this)
        cameraManager.setCaptureStatusListener(this)
    }

    fun connect(): Boolean {
        Log.d(TAG, "Opening camera via WiFi...")
        cameraManager.openCamera(InstaCameraManager.CONNECT_TYPE_WIFI)
        return true
    }

    fun isCameraConnected(): Boolean {
        return cameraManager.cameraConnectedType != InstaCameraManager.CONNECT_TYPE_NONE
    }

    fun isCameraRecording(): Boolean {
        return isRecording
    }

    fun startRecording(callback: RecordingCallback?) {
        if (cameraManager.cameraConnectedType == InstaCameraManager.CONNECT_TYPE_NONE) {
            Log.e(TAG, "Cannot start recording: Camera not connected.")
            callback?.onFailed("Camera not connected")
            return
        }

        pendingStartCallback = callback

        try {
            // Start normal recording directly
            // The SDK internally handles capture mode when calling startNormalRecord()
            Log.d(TAG, "Starting normal recording...")
            cameraManager.startNormalRecord()
        } catch (e: Exception) {
            Log.e(TAG, "Error starting recording: ${e.message}", e)
            pendingStartCallback?.onFailed("Error: ${e.message}")
            pendingStartCallback = null
        }
    }

    fun stopRecording(callback: RecordingCallback?) {
        if (!isRecording) {
            Log.e(TAG, "Stop called but camera is not recording")
            callback?.onFailed("Camera is not recording")
            return
        }

        pendingStopCallback = callback
        cameraManager.stopNormalRecord()
    }

    fun getStatus(): String {
        val type = cameraManager.cameraConnectedType
        val currentlyConnected = type != InstaCameraManager.CONNECT_TYPE_NONE

        return when {
            !currentlyConnected -> "DISCONNECTED"
            isRecording -> "RECORDING"
            else -> "IDLE"
        }
    }

    // ===== ICaptureStatusListener =====

    override fun onCaptureStarting() {
        Log.d(TAG, "onCaptureStarting")
    }

    override fun onCaptureWorking() {
        Log.d(TAG, "onCaptureWorking — recording is now active")
        isRecording = true
        pendingStartCallback?.onSuccess()
        pendingStartCallback = null
    }

    override fun onCaptureStopping() {
        Log.d(TAG, "onCaptureStopping")
    }

    override fun onCaptureFinish(filePaths: Array<out String>?) {
        Log.d(TAG, "onCaptureFinish — paths=${filePaths?.joinToString()}")
        isRecording = false
        lastCapturedFilePaths = filePaths
        pendingStopCallback?.onSuccess()
        pendingStopCallback = null
    }

    override fun onCaptureCountChanged(count: Int) {
        Log.d(TAG, "onCaptureCountChanged: $count")
    }

    override fun onCaptureTimeChanged(captureTime: Long) {}

    override fun onCaptureError(errorCode: Int) {
        Log.e(TAG, "onCaptureError: $errorCode")
        isRecording = false
        pendingStartCallback?.onFailed("Capture error (code=$errorCode)")
        pendingStartCallback = null
        pendingStopCallback?.onFailed("Capture error (code=$errorCode)")
        pendingStopCallback = null
    }

    // ===== ICameraChangedCallback =====

    override fun onCameraStatusChanged(enabled: Boolean, connectType: Int) {
        Log.d(TAG, "Camera Status Changed: enabled=$enabled, connectType=$connectType")
        isConnected = enabled
    }

    override fun onCameraConnectError(errorCode: Int) {
        Log.e(TAG, "Camera connection error: $errorCode")
        isConnected = false
    }

    override fun onCameraSDCardStateChanged(state: Boolean) {
        Log.d(TAG, "SD Card State Changed: $state")
    }

    override fun onCameraBatteryLow() {
        Log.w(TAG, "Camera battery is low!")
    }
}
