package com.example.insta360_bridge

import android.os.Handler
import android.os.Looper
import android.util.Log
import com.arashivision.sdkcamera.camera.InstaCameraManager
import com.arashivision.sdkcamera.camera.callback.ICameraChangedCallback
import com.arashivision.sdkcamera.camera.callback.ICaptureStatusListener
import com.arashivision.sdkcamera.camera.callback.IPreviewStatusListener
import com.arashivision.sdkcamera.camera.callback.ICaptureSupportConfigCallback
import com.arashivision.sdkcamera.camera.model.CaptureMode
import com.arashivision.insta360.basecamera.camera.ICameraController

class CameraControl : ICameraChangedCallback, ICaptureStatusListener, IPreviewStatusListener {

    private val cameraManager = InstaCameraManager.getInstance()
    private val mainHandler = Handler(Looper.getMainLooper())

    private var isConnected = false
    private var isRecording = false
    private var isPreviewStarted = false
    private var isWaitingForPreviewToRecord = false

    interface RecordingCallback {
        fun onSuccess()
        fun onFailed(reason: String)
    }

    private var pendingStartCallback: RecordingCallback? = null
    private var pendingStopCallback: RecordingCallback? = null
    private var startTimeoutRunnable: Runnable? = null

    var lastCapturedFilePaths: Array<out String>? = null
        private set

    companion object {
        const val TAG = "CameraControl"
        const val START_TIMEOUT_MS = 15000L  // 15 seconds timeout (more time for preview + record)
        const val PREVIEW_WAIT_MS = 2000L    // Wait for preview to initialize
        const val MODE_SWITCH_WAIT_MS = 1500L // Wait for mode switch
    }

    init {
        cameraManager.registerCameraChangedCallback(this)
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

    /**
     * Start the preview stream — required by the SDK before recording.
     */
    fun startPreview() {
        if (cameraManager.cameraConnectedType == InstaCameraManager.CONNECT_TYPE_NONE) {
            Log.w(TAG, "Cannot start preview: camera not connected")
            return
        }
        if (isPreviewStarted) {
            Log.d(TAG, "Preview already started, skipping")
            return
        }
        Log.d(TAG, "Starting preview stream...")
        cameraManager.startPreviewStream()
    }

    fun startRecording(callback: RecordingCallback?) {
        if (cameraManager.cameraConnectedType == InstaCameraManager.CONNECT_TYPE_NONE) {
            Log.e(TAG, "Cannot start recording: Camera not connected.")
            callback?.onFailed("Camera not connected")
            return
        }

        pendingStartCallback = callback

        // Robust check: use the SDK's internal state
        val isTrulyOpened = cameraManager.previewStatus == InstaCameraManager.PREVIEW_STATUS_OPENED

        if (isTrulyOpened || isPreviewStarted) {
            Log.d(TAG, "Preview is ready, starting mode switch immediately...")
            performModeSwitchAndRecord()
        } else {
            isWaitingForPreviewToRecord = true
            Log.d(TAG, "Preview not ready. Calling startPreviewStream() and waiting for onOpened() callback...")
            try {
                cameraManager.startPreviewStream()
            } catch (e: Exception) {
                Log.e(TAG, "Error starting preview stream: ${e.message}")
            }
        }
    }

    private fun performModeSwitchAndRecord() {
        try {
            // Step 3: Switch camera to Normal Video recording mode with callback
            Log.d(TAG, "Switching camera to RECORD_NORMAL mode...")
            cameraManager.setCaptureMode(
                CaptureMode.RECORD_NORMAL,
                object : ICameraController.ISetOptionsCallback {
                    override fun onSetOptionsResult(result: Int) {
                        Log.d(TAG, "setCaptureMode result: $result")
                        if (result == 0) {
                            // Step 4: Mode switch network ACK received — Wait for hardware to stabilize
                            Log.d(TAG, "Mode switch network ACK received. Waiting 1500ms for camera hardware to stabilize...")
                            mainHandler.postDelayed({
                                try {
                                    // Let's see what the camera actually supports!
                                    val supportedModes = cameraManager.supportCaptureMode
                                    Log.e(TAG, "Does camera support RECORD_NORMAL? : ${supportedModes?.contains(CaptureMode.RECORD_NORMAL)}")
                                    Log.e(TAG, "All supported modes: $supportedModes")

                                    Log.d(TAG, "Now calling startNormalRecord()...")
                                    cameraManager.startNormalRecord()
                                    Log.d(TAG, "startNormalRecord() called — waiting for onCaptureWorking callback...")

                                    // Step 5: Set a timeout
                                    startTimeoutRunnable = Runnable {
                                        if (!isRecording && pendingStartCallback != null) {
                                            Log.e(TAG, "TIMEOUT: Recording did not start within ${START_TIMEOUT_MS}ms")
                                            pendingStartCallback?.onFailed("Recording timed out — camera may not be ready")
                                            pendingStartCallback = null
                                        }
                                    }
                                    mainHandler.postDelayed(startTimeoutRunnable!!, START_TIMEOUT_MS)

                                } catch (e: Exception) {
                                    Log.e(TAG, "Error calling startNormalRecord: ${e.message}", e)
                                    pendingStartCallback?.onFailed("Error: ${e.message}")
                                    pendingStartCallback = null
                                }
                            }, MODE_SWITCH_WAIT_MS) // Re-added the crucial delay
                        } else {
                            Log.e(TAG, "Mode switch failed with result: $result")
                            pendingStartCallback?.onFailed("Mode switch failed (result=$result)")
                            pendingStartCallback = null
                        }
                    }
                }
            )

        } catch (e: Exception) {
            Log.e(TAG, "Error switching camera mode: ${e.message}", e)
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

        // Cancel the timeout since recording started successfully
        startTimeoutRunnable?.let { mainHandler.removeCallbacks(it) }
        startTimeoutRunnable = null

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

    // ===== IPreviewStatusListener =====

    override fun onOpening() {
        Log.d(TAG, "Preview stream opening...")
    }

    override fun onOpened() {
        Log.d(TAG, "Preview stream opened successfully")
        isPreviewStarted = true
        if (isWaitingForPreviewToRecord) {
            isWaitingForPreviewToRecord = false
            Log.d(TAG, "Preview is now open. Calling pending performModeSwitchAndRecord()...")
            performModeSwitchAndRecord()
        }
    }

    override fun onIdle() {
        Log.d(TAG, "Preview stream idle")
        isPreviewStarted = false
    }

    override fun onError() {
        Log.e(TAG, "Preview stream error!")
        isPreviewStarted = false
    }

    // ===== ICameraChangedCallback =====

    override fun onCameraStatusChanged(enabled: Boolean, connectType: Int) {
        Log.d(TAG, "Camera Status Changed: enabled=$enabled, connectType=$connectType")
        isConnected = enabled

        if (enabled && connectType != InstaCameraManager.CONNECT_TYPE_NONE) {
            Log.d(TAG, "Camera connected — binding SDK listeners...")
            // These MUST be set after connection, otherwise internal BaseCamera is null and they are ignored
            cameraManager.setCaptureStatusListener(this@CameraControl)
            cameraManager.setPreviewStatusChangedListener(this@CameraControl)
            
            Log.d(TAG, "Camera connected — initializing support config (REQUIRED for recording)...")
            
            // The SDK MUST initialize its internal capabilities list before it allows recording
            cameraManager.initCameraSupportConfig(object : ICaptureSupportConfigCallback {
                override fun onComplete() {
                    Log.d(TAG, "Support config initialized successfully! Allowed modes: ${cameraManager.supportCaptureMode}")
                    // Auto-start preview when camera config is ready
                    Log.d(TAG, "Camera connected — auto-starting preview stream...")
                    mainHandler.postDelayed({
                        startPreview()
                    }, 500)
                }

                override fun onFailed(error: String?) {
                    Log.e(TAG, "Failed to initialize camera support config: $error")
                }
            })
        } else {
            isPreviewStarted = false
        }
    }

    override fun onCameraConnectError(errorCode: Int) {
        Log.e(TAG, "Camera connection error: $errorCode")
        isConnected = false
        isPreviewStarted = false
    }

    override fun onCameraSDCardStateChanged(state: Boolean) {
        Log.d(TAG, "SD Card State Changed: $state")
    }

    override fun onCameraBatteryLow() {
        Log.w(TAG, "Camera battery is low!")
    }
}
