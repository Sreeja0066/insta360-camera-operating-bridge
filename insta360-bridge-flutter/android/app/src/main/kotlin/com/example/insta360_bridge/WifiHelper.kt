package com.example.insta360_bridge

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.wifi.WifiNetworkSpecifier
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.app.ActivityCompat

class WifiHelper(private val context: Context) {

    private val wifiManager = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
    private val connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    
    // Track active connection callback to prevent overlaps
    private var activeNetworkCallback: ConnectivityManager.NetworkCallback? = null
    
    // Callback for scan results
    var onScanResults: ((List<ScanResultSimple>) -> Unit)? = null
    
    // Callback for connection status
    var onConnectionStatus: ((String) -> Unit)? = null
    
    // Simple data class for JS
    data class ScanResultSimple(val ssid: String, val level: Int)

    private val scanReceiver = object : BroadcastReceiver() {
        override fun onReceive(c: Context, intent: Intent) {
            if (intent.action == WifiManager.SCAN_RESULTS_AVAILABLE_ACTION) {
                if (ActivityCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
                    return
                }
                
                val results = wifiManager.scanResults
                val filtered = results
                    .filter { it.SSID.isNotEmpty() } // Filter empty
                    .map { ScanResultSimple(it.SSID, it.level) }
                    .distinctBy { it.ssid } // Remove duplicates
                
                Log.d("WifiHelper", "Scan found ${filtered.size} networks")
                onScanResults?.invoke(filtered)
            }
        }
    }

    fun getCachedScanResults(): List<ScanResultSimple> {
        if (ActivityCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            return emptyList()
        }
        return wifiManager.scanResults
            .filter { it.SSID.isNotEmpty() }
            .map { ScanResultSimple(it.SSID, it.level) }
            .distinctBy { it.ssid }
    }

    fun startScan() {
        Log.d("WifiHelper", "Starting Wi-Fi Scan...")
        val intentFilter = IntentFilter(WifiManager.SCAN_RESULTS_AVAILABLE_ACTION)
        
        try {
            if (Build.VERSION.SDK_INT >= 34) {
                context.registerReceiver(scanReceiver, intentFilter, Context.RECEIVER_EXPORTED)
            } else {
                context.registerReceiver(scanReceiver, intentFilter)
            }
        } catch (e: Exception) {
            Log.e("WifiHelper", "Receiver registration error: ${e.message}")
        }
        
        @Suppress("DEPRECATION")
        val success = wifiManager.startScan()
        if (!success) {
            Log.e("WifiHelper", "Scan start failed (throttled?)")
            onScanResults?.invoke(getCachedScanResults())
        }
        
        // Auto-stop after 10s to be safe
        Handler(Looper.getMainLooper()).postDelayed({ stopScan() }, 10000)
    }

    fun stopScan() {
        try {
            context.unregisterReceiver(scanReceiver)
        } catch (e: Exception) {
            // Unregistered
        }
    }

    fun connectToNetwork(ssid: String, password: String) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // 1. Clear any existing active request
            activeNetworkCallback?.let { 
                try { connectivityManager.unregisterNetworkCallback(it) } catch (e: Exception) {}
            }

            val specifier = WifiNetworkSpecifier.Builder()
                .setSsid(ssid)
                .setWpa2Passphrase(password)
                .build()

            val request = NetworkRequest.Builder()
                .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
                .setNetworkSpecifier(specifier)
                .build()

            val callback = object : ConnectivityManager.NetworkCallback() {
                override fun onAvailable(network: Network) {
                    Log.d("WifiHelper", "Network available: $ssid")
                    connectivityManager.bindProcessToNetwork(network)
                    onConnectionStatus?.invoke("CONNECTED")
                }

                override fun onUnavailable() {
                    Log.d("WifiHelper", "Network unavailable")
                    onConnectionStatus?.invoke("FAILED")
                    activeNetworkCallback = null
                }
            }
            
            activeNetworkCallback = callback
            
            // 2. Request network with a 5-second timeout to prevent hanging the UI
            connectivityManager.requestNetwork(request, callback, 5000)
        } else {
            // Legacy way (Android 9 and below) - optional, likely not needed for Vivo V40
            Log.w("WifiHelper", "Legacy Wi-Fi connection logic skipped")
        }
    }

    fun getCurrentSSID(): String? {
        val info = wifiManager.connectionInfo
        if (info != null && info.networkId != -1) {
            var ssid = info.ssid
            if (ssid.startsWith("\"") && ssid.endsWith("\"")) {
                ssid = ssid.substring(1, ssid.length - 1)
            }
            if (ssid == "<unknown ssid>") {
                return null
            }
            return ssid
        }
        return null
    }
}
