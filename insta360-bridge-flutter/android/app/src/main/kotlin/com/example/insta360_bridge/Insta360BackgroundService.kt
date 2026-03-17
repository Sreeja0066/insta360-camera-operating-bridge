package com.example.insta360_bridge

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Binder
import android.os.Build
import android.os.IBinder
import android.util.Log
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import androidx.core.app.NotificationCompat
import androidx.work.Constraints
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager

class Insta360BackgroundService : Service() {

    companion object {
        const val TAG = "Insta360BgService"
        const val NOTIFICATION_ID = 360
        const val CHANNEL_ID = "Insta360ServiceChannel"
    }

    // Binder given to clients (like MainActivity/Insta360Channel)
    inner class LocalBinder : Binder() {
        fun getService(): Insta360BackgroundService = this@Insta360BackgroundService
    }
    private val binder = LocalBinder()

    lateinit var cameraControl: CameraControl
    lateinit var videoExporter: VideoExporter
    val driveUploader by lazy { DriveUploader(this) }
    
    private lateinit var connectivityManager: ConnectivityManager
    private var networkCallback: ConnectivityManager.NetworkCallback? = null

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "Service onCreate")
        cameraControl = CameraControl()
        videoExporter = VideoExporter(this)
        createNotificationChannel()
        registerNetworkListener()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "Service onStartCommand")
        startForeground(NOTIFICATION_ID, createNotification("Running in background..."))
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent): IBinder {
        Log.d(TAG, "Service onBind")
        return binder
    }

    override fun onDestroy() {
        Log.d(TAG, "Service onDestroy")
        // Clean up connection or stop recording if needed
        networkCallback?.let { connectivityManager.unregisterNetworkCallback(it) }
        super.onDestroy()
    }

    // --- Service Operations ---
    
    private fun registerNetworkListener() {
        connectivityManager = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        
        val request = NetworkRequest.Builder()
            .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .build()
            
        networkCallback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                super.onAvailable(network)
                val caps = connectivityManager.getNetworkCapabilities(network)
                if (caps?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true || 
                    caps?.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) == true) {
                    
                    // We gained real internet (not camera Wi-Fi without internet).
                    // Trigger the Drive upload queue!
                    Log.d(TAG, "Internet connection restored. Triggering auto-upload check...")
                    scheduleDriveUploadWorker()
                }
            }
        }
        
        connectivityManager.registerNetworkCallback(request, networkCallback!!)
    }

    fun scheduleDriveUploadWorker() {
        Log.d(TAG, "Scheduling WorkManager for pending Drive uploads...")
        val constraints = Constraints.Builder()
            .setRequiredNetworkType(NetworkType.CONNECTED)
            .build()
            
        val uploadWork = OneTimeWorkRequestBuilder<DriveUploadWorker>()
            .setConstraints(constraints)
            .build()
            
        WorkManager.getInstance(this).enqueueUniqueWork(
            "DriveUploadWork",
            ExistingWorkPolicy.REPLACE, // Restart if already queued
            uploadWork
        )
    }

    // --- Notifications ---

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val serviceChannel = NotificationChannel(
                CHANNEL_ID,
                "Insta360 Background Service",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(serviceChannel)
        }
    }

    fun updateNotificationContext(message: String) {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(NOTIFICATION_ID, createNotification(message))
    }

    private fun createNotification(contentText: String): Notification {
        val notificationIntent = Intent(this, MainActivity::class.java)
        
        // Prevent creating multiple back stacks
        notificationIntent.flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        
        val pendingIntentFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            notificationIntent,
            pendingIntentFlags
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Insta360 Bridge")
            .setContentText(contentText)
            .setSmallIcon(android.R.drawable.stat_notify_sync) // Safe fallback icon
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }
}
