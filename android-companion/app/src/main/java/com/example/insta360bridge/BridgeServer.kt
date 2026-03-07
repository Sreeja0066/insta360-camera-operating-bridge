package com.example.insta360bridge

import fi.iki.elonen.NanoHTTPD
import android.util.Log
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

class BridgeServer(private val port: Int, private val cameraControl: CameraControl) : NanoHTTPD(port) {

    companion object {
        const val TAG = "BridgeServer"
    }

    override fun serve(session: IHTTPSession): Response {
        val uri = session.uri
        val method = session.method

        Log.d(TAG, "Request: $method $uri")

        // CORS Headers
        val headers = HashMap<String, String>()
        headers["Access-Control-Allow-Origin"] = "*"
        headers["Access-Control-Allow-Methods"] = "POST, GET, OPTIONS"
        headers["Access-Control-Allow-Headers"] = "Content-Type"

        if (Method.OPTIONS == method) {
            val response = newFixedLengthResponse(Response.Status.OK, MIME_PLAINTEXT, "")
            addHeaders(response, headers)
            return response
        }

        val jsonResponse = when (uri) {
            "/connect" -> {
                if (method == Method.POST) {
                    val success = cameraControl.connect()
                    if (success) """{"status": "connected"}""" else """{"status": "failed"}"""
                } else """{"error": "Method not allowed"}"""
            }
            "/startRecording" -> {
                if (method == Method.POST) {
                    // FIXED: Wait for actual SDK result using CountDownLatch
                    val latch = CountDownLatch(1)
                    var result = """{"status": "failed", "reason": "timeout"}"""

                    cameraControl.startRecording(object : CameraControl.RecordingCallback {
                        override fun onSuccess() {
                            result = """{"status": "started"}"""
                            latch.countDown()
                        }
                        override fun onFailed(reason: String) {
                            result = """{"status": "failed", "reason": "$reason"}"""
                            latch.countDown()
                        }
                    })

                    // Wait up to 15 seconds for SDK callback
                    latch.await(15, TimeUnit.SECONDS)
                    result
                } else """{"error": "Method not allowed"}"""
            }
            "/stopRecording" -> {
                if (method == Method.POST) {
                    val latch = CountDownLatch(1)
                    var result = """{"status": "failed", "reason": "timeout"}"""

                    cameraControl.stopRecording(object : CameraControl.RecordingCallback {
                        override fun onSuccess() {
                            result = """{"status": "stopped"}"""
                            latch.countDown()
                        }
                        override fun onFailed(reason: String) {
                            result = """{"status": "failed", "reason": "$reason"}"""
                            latch.countDown()
                        }
                    })

                    latch.await(15, TimeUnit.SECONDS)
                    result
                } else """{"error": "Method not allowed"}"""
            }
            "/status" -> {
                val status = cameraControl.getStatus()
                """{"status": "$status"}"""
            }
            else -> """{"error": "Not Found"}"""
        }

        val response = newFixedLengthResponse(Response.Status.OK, "application/json", jsonResponse)
        addHeaders(response, headers)
        return response
    }

    private fun addHeaders(response: Response, headers: Map<String, String>) {
        for ((key, value) in headers) {
            response.addHeader(key, value)
        }
    }
}
