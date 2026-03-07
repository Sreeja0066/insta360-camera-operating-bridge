package com.example.insta360bridge

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.webkit.ValueCallback
import android.webkit.WebChromeClient
import android.webkit.WebView
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat

class MainActivity : AppCompatActivity() {

    private lateinit var cameraControl: CameraControl
    private lateinit var webView: WebView
    private lateinit var wifiHelper: WifiHelper
    private var bridgeServer: BridgeServer? = null

    // File chooser for WebView
    private var fileUploadCallback: ValueCallback<Array<Uri>>? = null
    private val FILE_CHOOSER_REQUEST_CODE = 2001

    private val PERMISSION_REQUEST_CODE = 1001
    private var previousStatus = "DISCONNECTED"

    companion object {
        const val TAG = "MainActivity"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        webView = findViewById(R.id.webview)
        cameraControl = CameraControl()
        wifiHelper = WifiHelper(this)

        setupWebView()
        checkPermissions()

        // WiFi scan results → send to WebView JS
        wifiHelper.onScanResults = { results ->
            val json = StringBuilder("[")
            results.forEachIndexed { index, res ->
                json.append("""{"ssid":"${res.ssid}", "level":${res.level}}""")
                if (index < results.size - 1) json.append(",")
            }
            json.append("]")

            runOnUiThread {
                webView.evaluateJavascript("if(window.onWifiList) onWifiList($json)", null)
            }
        }

        // Start BridgeServer for external HTTP control
        try {
            bridgeServer = BridgeServer(8080, cameraControl)
            bridgeServer?.start()
            Log.d(TAG, "BridgeServer started on port 8080")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start BridgeServer: ${e.message}")
        }

        // Status polling — checks camera state every second and notifies JS
        webView.post(object : Runnable {
            override fun run() {
                val status = cameraControl.getStatus()
                webView.evaluateJavascript("if(window.updateStatus) updateStatus('$status')", null)

                // Detect connection state changes for auto-navigation
                if (previousStatus == "DISCONNECTED" && status != "DISCONNECTED") {
                    Log.d(TAG, "Camera connected! Notifying JS.")
                    webView.evaluateJavascript(
                        "if(window.onCameraConnected) onCameraConnected()", null
                    )
                }
                if (previousStatus != "DISCONNECTED" && status == "DISCONNECTED") {
                    Log.d(TAG, "Camera disconnected! Notifying JS.")
                    webView.evaluateJavascript(
                        "if(window.onCameraDisconnected) onCameraDisconnected()", null
                    )
                }
                previousStatus = status

                webView.postDelayed(this, 1000)
            }
        })
    }

    private fun setupWebView() {
        webView.settings.javaScriptEnabled = true
        webView.settings.domStorageEnabled = true
        webView.settings.allowFileAccess = true
        webView.settings.allowContentAccess = true

        // Pass webView reference so WebAppInterface can call evaluateJavascript
        webView.addJavascriptInterface(
            WebAppInterface(this, cameraControl, webView), "AndroidBridge"
        )

        // WebChromeClient with file chooser support for <input type="file">
        webView.webChromeClient = object : WebChromeClient() {
            override fun onShowFileChooser(
                webView: WebView?,
                filePathCallback: ValueCallback<Array<Uri>>?,
                fileChooserParams: FileChooserParams?
            ): Boolean {
                // Cancel any existing callback
                fileUploadCallback?.onReceiveValue(null)
                fileUploadCallback = filePathCallback

                val intent = fileChooserParams?.createIntent()
                    ?: Intent(Intent.ACTION_GET_CONTENT).apply {
                        type = "image/*"
                        addCategory(Intent.CATEGORY_OPENABLE)
                    }

                try {
                    startActivityForResult(intent, FILE_CHOOSER_REQUEST_CODE)
                } catch (e: Exception) {
                    Log.e(TAG, "File chooser failed: ${e.message}")
                    fileUploadCallback?.onReceiveValue(null)
                    fileUploadCallback = null
                    return false
                }
                return true
            }
        }

        webView.loadUrl("file:///android_asset/www/index.html")
    }

    // Handle file chooser result
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode == FILE_CHOOSER_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                val result = WebChromeClient.FileChooserParams.parseResult(resultCode, data)
                fileUploadCallback?.onReceiveValue(result)
            } else {
                fileUploadCallback?.onReceiveValue(null)
            }
            fileUploadCallback = null
        }
    }

    /**
     * Scan for WiFi networks — called by WebAppInterface.scanWifi()
     */
    fun scanWifi() {
        Log.d(TAG, "Scanning for WiFi networks...")
        wifiHelper.startScan()
    }

    /**
     * Connect to a WiFi network — called by WebAppInterface.connectWifi()
     */
    fun connectWifi(ssid: String, password: String) {
        Log.d(TAG, "Connecting to WiFi: $ssid")
        wifiHelper.connectToNetwork(ssid, password)

        // After WiFi connects, attempt camera SDK connection
        webView.postDelayed({
            Log.d(TAG, "Attempting camera connection after WiFi connect...")
            cameraControl.connect()
        }, 3000)
    }

    private fun checkPermissions() {
        val permissions = mutableListOf<String>()

        permissions.add(Manifest.permission.ACCESS_FINE_LOCATION)
        permissions.add(Manifest.permission.CHANGE_WIFI_STATE)
        permissions.add(Manifest.permission.CHANGE_NETWORK_STATE)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            permissions.add(Manifest.permission.BLUETOOTH_SCAN)
            permissions.add(Manifest.permission.BLUETOOTH_CONNECT)
        }

        val missing = permissions.filter {
            ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED
        }

        if (missing.isNotEmpty()) {
            ActivityCompat.requestPermissions(this, missing.toTypedArray(), PERMISSION_REQUEST_CODE)
        } else {
            Log.d(TAG, "All permissions already granted")
            attemptCameraConnect()
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        if (requestCode == PERMISSION_REQUEST_CODE) {
            if (grantResults.all { it == PackageManager.PERMISSION_GRANTED }) {
                Log.d(TAG, "Permissions granted by user")
                attemptCameraConnect()
            } else {
                Log.e(TAG, "Permissions denied – discovery will not work")
            }
        }
    }

    private fun attemptCameraConnect() {
        Log.d(TAG, "Attempting camera discovery and connection...")
        val result = cameraControl.connect()
        if (!result) {
            Log.e(TAG, "Camera discovery returned no devices.")
        } else {
            Log.d(TAG, "Camera connection attempt sent to SDK.")
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            bridgeServer?.stop()
            Log.d(TAG, "BridgeServer stopped")
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping BridgeServer: ${e.message}")
        }
    }
}
