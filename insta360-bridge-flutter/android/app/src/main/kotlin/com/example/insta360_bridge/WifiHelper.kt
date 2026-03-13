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
    
    // Callback for scan results
    var onScanResults: ((List<ScanResultSimple>) -> Unit)? = null
    
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
        val intentFilter = IntentFilter()
        intentFilter.addAction(WifiManager.SCAN_RESULTS_AVAILABLE_ACTION)
        
        if (Build.VERSION.SDK_INT >= 34) { // Android 14+
            context.registerReceiver(scanReceiver, intentFilter, Context.RECEIVER_EXPORTED)
        } else {
            context.registerReceiver(scanReceiver, intentFilter)
        }
        
        @Suppress("DEPRECATION")
        val success = wifiManager.startScan()
        if (!success) {
            Log.e("WifiHelper", "Scan start failed (throttled?)")
            // Try to send old results if available
            val results = wifiManager.scanResults.map { ScanResultSimple(it.SSID, it.level) }
            onScanResults?.invoke(results)
        }
        
        // Unregister after 10 seconds to avoid leaks if no result
        Handler(Looper.getMainLooper()).postDelayed({
            try {
                context.unregisterReceiver(scanReceiver)
            } catch (e: Exception) {}
        }, 10000)
    }

    fun connectToNetwork(ssid: String, password: String) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            Log.d("WifiHelper", "Requesting connection to $ssid")
            
            val specifier = WifiNetworkSpecifier.Builder()
                .setSsid(ssid)
                .setWpa2Passphrase(password) // Insta360 uses WPA2 usually
                .build()

            val request = NetworkRequest.Builder()
                .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
                .setNetworkSpecifier(specifier)
                .build()

            connectivityManager.requestNetwork(request, object : ConnectivityManager.NetworkCallback() {
                override fun onAvailable(network: Network) {
                    Log.d("WifiHelper", "Network available: $ssid")
                    connectivityManager.bindProcessToNetwork(network)
                }

                override fun onUnavailable() {
                    Log.d("WifiHelper", "Network unavailable")
                }
            })
        } else {
            // Legacy way (Android 9 and below) - optional, likely not needed for Vivo V40
            Log.w("WifiHelper", "Legacy Wi-Fi connection logic skipped")
        }
    }
}
