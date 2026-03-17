package com.example.insta360_bridge

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import android.util.Log
import com.google.android.gms.auth.api.signin.GoogleSignIn
import com.google.android.gms.auth.api.signin.GoogleSignInClient
import com.google.android.gms.auth.api.signin.GoogleSignInOptions
import com.google.android.gms.common.api.Scope
import com.google.api.services.drive.DriveScopes
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.insta360bridge/camera"
    private lateinit var googleSignInClient: GoogleSignInClient
    private var channelHandler: Insta360Channel? = null
    
    private var bgService: Insta360BackgroundService? = null
    private var isBound = false

    companion object {
        const val TAG = "MainActivity"
        const val GOOGLE_SIGN_IN_REQUEST_CODE = 9001
    }

    private val serviceConnection = object : ServiceConnection {
        override fun onServiceConnected(className: ComponentName, service: IBinder) {
            val binder = service as Insta360BackgroundService.LocalBinder
            bgService = binder.getService()
            isBound = true
            channelHandler?.setService(bgService!!)
            Log.d(TAG, "Insta360BackgroundService connected")
        }

        override fun onServiceDisconnected(arg0: ComponentName) {
            isBound = false
            bgService = null
            Log.d(TAG, "Insta360BackgroundService disconnected")
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Start and bind the background service right away
        val intent = Intent(this, Insta360BackgroundService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
        bindService(intent, serviceConnection, Context.BIND_AUTO_CREATE)
    }

    override fun onDestroy() {
        super.onDestroy()
        if (isBound) {
            unbindService(serviceConnection)
            isBound = false
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        setupGoogleSignIn()

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channelHandler = Insta360Channel(this, channel)
        // Inject service if already bound
        if (bgService != null) {
            channelHandler?.setService(bgService!!)
        }
        channel.setMethodCallHandler(channelHandler)
    }

    private fun setupGoogleSignIn() {
        val gso = GoogleSignInOptions.Builder(GoogleSignInOptions.DEFAULT_SIGN_IN)
            .requestEmail()
            .requestScopes(Scope(DriveScopes.DRIVE_FILE))
            .build()
        googleSignInClient = GoogleSignIn.getClient(this, gso)
    }

    fun signInToDrive() {
        Log.d(TAG, "Starting Google Sign-In...")
        val signInIntent = googleSignInClient.signInIntent
        startActivityForResult(signInIntent, GOOGLE_SIGN_IN_REQUEST_CODE)
    }

    fun getDriveSignInStatus(): String? {
        return GoogleSignIn.getLastSignedInAccount(this)?.email
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode == GOOGLE_SIGN_IN_REQUEST_CODE) {
            val task = GoogleSignIn.getSignedInAccountFromIntent(data)
            try {
                val account = task.getResult(com.google.android.gms.common.api.ApiException::class.java)
                Log.d(TAG, "Sign-in successful: ${account?.email}")
                channelHandler?.onDriveSignInResult(account?.email, null)
            } catch (e: Exception) {
                Log.e(TAG, "Sign-in failed: ${e.message}")
                channelHandler?.onDriveSignInResult(null, e.message)
            }
        }
    }
}
