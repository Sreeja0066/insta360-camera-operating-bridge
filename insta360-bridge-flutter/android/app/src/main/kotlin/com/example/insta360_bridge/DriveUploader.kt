package com.example.insta360_bridge

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.util.Log
import com.google.android.gms.auth.api.signin.GoogleSignIn
import com.google.api.client.googleapis.extensions.android.gms.auth.GoogleAccountCredential
import com.google.api.client.http.FileContent
import com.google.api.client.http.javanet.NetHttpTransport
import com.google.api.client.json.gson.GsonFactory
import com.google.api.services.drive.Drive
import com.google.api.services.drive.DriveScopes
import com.google.api.services.drive.model.File
import java.io.IOException
import java.util.Collections

class DriveUploader(private val context: Context) {

    companion object {
        const val TAG = "DriveUploader"
        const val FOLDER_NAME = "Insta360Bridge"
        const val PREFS_NAME = "drive_pending_uploads"
        const val KEY_PENDING = "pending_files"
    }

    interface UploadCallback {
        fun onProgress(progress: Int)
        fun onSuccess(fileId: String)
        fun onError(error: String)
        fun onQueued(filePath: String)
    }

    fun hasInternet(): Boolean {
        val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val network = cm.activeNetwork ?: return false
        val capabilities = cm.getNetworkCapabilities(network) ?: return false
        return capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                && capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
    }

    fun addToPending(filePath: String) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val existing = prefs.getStringSet(KEY_PENDING, mutableSetOf()) ?: mutableSetOf()
        val updated = existing.toMutableSet()
        updated.add(filePath)
        prefs.edit().putStringSet(KEY_PENDING, updated).apply()
        Log.d(TAG, "Queued for later upload: $filePath (${updated.size} pending)")
    }

    fun getPendingFiles(): Set<String> {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.getStringSet(KEY_PENDING, emptySet()) ?: emptySet()
    }

    private fun removeFromPending(filePath: String) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val existing = prefs.getStringSet(KEY_PENDING, mutableSetOf()) ?: mutableSetOf()
        val updated = existing.toMutableSet()
        updated.remove(filePath)
        prefs.edit().putStringSet(KEY_PENDING, updated).apply()
    }

    private fun getDriveService(): Drive? {
        val account = GoogleSignIn.getLastSignedInAccount(context) ?: return null
        val credential = GoogleAccountCredential.usingOAuth2(
            context, Collections.singleton(DriveScopes.DRIVE_FILE)
        )
        credential.selectedAccount = account.account
        
        return Drive.Builder(
            NetHttpTransport(),
            GsonFactory.getDefaultInstance(),
            credential
        ).setApplicationName("Insta360 Bridge")
            .build()
    }

    private fun getOrCreateFolder(service: Drive): String? {
        try {
            val query = "name = '$FOLDER_NAME' and mimeType = 'application/vnd.google-apps.folder' and trashed = false"
            val result = service.files().list()
                .setQ(query)
                .setSpaces("drive")
                .setFields("files(id)")
                .execute()

            if (result.files.isNotEmpty()) {
                return result.files[0].id
            }

            val folderMetadata = File()
            folderMetadata.name = FOLDER_NAME
            folderMetadata.mimeType = "application/vnd.google-apps.folder"

            val folder = service.files().create(folderMetadata)
                .setFields("id")
                .execute()
            
            return folder.id
        } catch (e: Exception) {
            Log.e(TAG, "Error getting/creating folder: ${e.message}")
            return null
        }
    }

    fun uploadFile(filePath: java.io.File, callback: UploadCallback) {
        if (!hasInternet()) {
            addToPending(filePath.absolutePath)
            callback.onQueued(filePath.absolutePath)
            return
        }

        val service = getDriveService()
        if (service == null) {
            callback.onError("Not signed in to Google Drive")
            return
        }

        Thread {
            try {
                val folderId = getOrCreateFolder(service)
                
                val fileMetadata = File()
                fileMetadata.name = filePath.name
                if (folderId != null) {
                    fileMetadata.parents = listOf(folderId)
                }

                val mediaContent = FileContent("video/mp4", filePath)
                
                val driveFile = service.files().create(fileMetadata, mediaContent)
                    .setFields("id")
                    .execute()

                Log.d(TAG, "Upload successful, file ID: ${driveFile.id}")
                removeFromPending(filePath.absolutePath)
                callback.onSuccess(driveFile.id)
            } catch (e: IOException) {
                Log.e(TAG, "Upload failed: ${e.message}")
                addToPending(filePath.absolutePath)
                callback.onError(e.message ?: "Unknown upload error")
            } catch (e: Exception) {
                Log.e(TAG, "Unexpected error during upload: ${e.message}")
                callback.onError(e.message ?: "Unknown error")
            }
        }.start()
    }

    fun uploadPendingFiles(callback: UploadCallback) {
        val pending = getPendingFiles()
        if (pending.isEmpty()) {
            Log.d(TAG, "No pending uploads")
            return
        }

        Log.d(TAG, "Uploading ${pending.size} pending files...")
        for (path in pending) {
            val file = java.io.File(path)
            if (file.exists()) {
                uploadFile(file, callback)
            } else {
                Log.w(TAG, "Pending file no longer exists: $path")
                removeFromPending(path)
            }
        }
    }
}
