package com.example.insta360_bridge

import android.app.Application
import com.arashivision.sdkcamera.InstaCameraSDK
import com.arashivision.sdkmedia.InstaMediaSDK

class Insta360App : Application() {
    override fun onCreate() {
        super.onCreate()
        // Initialize Insta360 SDKs
        InstaCameraSDK.init(this)
        InstaMediaSDK.init(this)
    }
}
