package com.example.insta360_bridge

import android.content.Context
import android.os.Environment
import android.util.Log
import com.arashivision.sdkmedia.export.ExportUtils
import com.arashivision.sdkmedia.export.ExportUtils.ExportMode
import com.arashivision.sdkmedia.export.ExportVideoParamsBuilder
import com.arashivision.sdkmedia.export.IExportCallback
import com.arashivision.sdkmedia.player.config.InstaStabType
import com.arashivision.sdkmedia.work.WorkWrapper
import java.io.File

/**
 * VideoExporter — Handles post-processing and export of Insta360 recordings
 *
 * Exports raw .insv files to MP4 with:
 * - FlowState Stabilization
 * - Dynamic Stitching
 * - Chromatic Calibration (DePurple filter)
 * - Two output resolutions: 8K (7680x3840) and 1080P (1920x960)
 * - 30 FPS, 100 Mbps bitrate, H.264 encoding
 */
class VideoExporter(private val context: Context) {

    companion object {
        const val TAG = "VideoExporter"

        // Export presets
        const val WIDTH_4K = 3840
        const val HEIGHT_4K = 1920
        const val WIDTH_1080P = 1920
        const val HEIGHT_1080P = 960
        const val FPS = 30
        const val BITRATE_4K = 60_000_000    // 60 Mbps for 4K
        const val BITRATE_1080P = 20_000_000  // 20 Mbps for 1080P
    }

    /**
     * Callback interface for export progress and completion
     */
    interface ExportCallback {
        fun onProgress(progress: Float, resolution: String)
        fun onSuccess(outputPath: String, resolution: String)
        fun onFailed(error: String, resolution: String)
    }

    /**
     * Get the export output directory
     */
    private fun getExportDir(): File {
        val dir = File(
            context.getExternalFilesDir(Environment.DIRECTORY_MOVIES),
            "Insta360Bridge"
        )
        if (!dir.exists()) dir.mkdirs()
        return dir
    }

    /**
     * Export a recording at a specific resolution
     *
     * @param filePaths Array of .insv file paths from the camera
     * @param resolution "8K" or "1080P"
     * @param recordingId Unique recording ID for naming
     * @param callback Progress and result callback
     */
    fun exportVideo(
        filePaths: Array<String>,
        resolution: String,
        recordingId: String,
        callback: ExportCallback
    ) {
        try {
            // Create WorkWrapper from the insv file paths
            val workWrapper = WorkWrapper(filePaths)

            // Load extra data (gyroscope data for stabilization)
            if (!workWrapper.isExtraDataLoaded) {
                workWrapper.loadExtraData()
            }

            // Determine export parameters based on resolution
            val width: Int
            val height: Int
            val bitrate: Int

            when (resolution) {
                "4K" -> {
                    width = WIDTH_4K
                    height = HEIGHT_4K
                    bitrate = BITRATE_4K
                }
                "1080P" -> {
                    width = WIDTH_1080P
                    height = HEIGHT_1080P
                    bitrate = BITRATE_1080P
                }
                else -> {
                    callback.onFailed("Unknown resolution: $resolution", resolution)
                    return
                }
            }

            // Build export parameters
            val videoBuilder = ExportVideoParamsBuilder()

            // Output path
            val outputFileName = "${recordingId}_${resolution}_${System.currentTimeMillis()}.mp4"
            val outputFile = File(getExportDir(), outputFileName)
            videoBuilder.targetPath = outputFile.absolutePath

            // Resolution and framerate
            videoBuilder.width = width
            videoBuilder.height = height
            videoBuilder.fps = FPS
            videoBuilder.bitrate = bitrate

            // Stabilization — FlowState with direction lock
            videoBuilder.stabType = InstaStabType.STAB_TYPE_AUTO

            // Stitching — Panoramic mode for 360° content
            videoBuilder.exportMode = ExportMode.PANORAMA
            videoBuilder.setScreenRatio(2, 1)

            // Dynamic Stitching — enabled
            videoBuilder.isDynamicStitch = true

            // Chromatic Calibration (DePurple filter) — enabled
            videoBuilder.isDePurpleFilterOn = true

            // Image Fusion (lens stitching enhancement) — enabled
            videoBuilder.isImageFusion = true

            // Color enhancement
            videoBuilder.isColorPlusEnable = false

            // Denoise
            videoBuilder.isDenoise = false

            Log.d(TAG, "Starting export: $resolution (${width}x${height}) @ ${FPS}fps, ${bitrate/1_000_000}Mbps")
            Log.d(TAG, "Output: ${outputFile.absolutePath}")

            // Execute export
            ExportUtils.exportVideo(workWrapper, videoBuilder, object : IExportCallback {
                override fun onStart(id: Int) {
                    Log.d(TAG, "Export started [$resolution] id=$id")
                }

                override fun onProgress(progress: Float) {
                    Log.d(TAG, "Export progress [$resolution]: ${(progress * 100).toInt()}%")
                    callback.onProgress(progress, resolution)
                }

                override fun onSuccess() {
                    Log.d(TAG, "Export SUCCESS [$resolution]: ${outputFile.absolutePath}")
                    callback.onSuccess(outputFile.absolutePath, resolution)
                }

                override fun onFail(code: Int, msg: String?) {
                    Log.e(TAG, "Export FAILED [$resolution]: code=$code, msg=$msg")
                    callback.onFailed("Export failed (code=$code): ${msg ?: "Unknown error"}", resolution)
                }

                override fun onCancel() {
                    Log.d(TAG, "Export cancelled [$resolution]")
                    callback.onFailed("Export cancelled", resolution)
                }
            })

        } catch (e: Exception) {
            Log.e(TAG, "Export error [$resolution]: ${e.message}", e)
            callback.onFailed("Export error: ${e.message}", resolution)
        }
    }

    /**
     * Export a recording at both 4K and 1080P resolutions
     * Exports 4K first, then 1080P sequentially
     *
     * @param filePaths Array of .insv file paths from the camera
     * @param recordingId Unique recording ID for naming
     * @param callback Progress and result callback (called for each resolution)
     */
    fun exportBothResolutions(
        filePaths: Array<String>,
        recordingId: String,
        callback: ExportCallback
    ) {
        // Export 4K first
        exportVideo(filePaths, "4K", recordingId, object : ExportCallback {
            override fun onProgress(progress: Float, resolution: String) {
                callback.onProgress(progress, resolution)
            }

            override fun onSuccess(outputPath: String, resolution: String) {
                callback.onSuccess(outputPath, resolution)

                // After 4K is done, export 1080P
                Log.d(TAG, "4K export complete, starting 1080P export...")
                exportVideo(filePaths, "1080P", recordingId, callback)
            }

            override fun onFailed(error: String, resolution: String) {
                callback.onFailed(error, resolution)
                // Still try 1080P even if 4K fails
                Log.d(TAG, "4K export failed, still trying 1080P...")
                exportVideo(filePaths, "1080P", recordingId, callback)
            }
        })
    }

    /**
     * Get list of exported video files
     */
    fun getExportedFiles(): List<Map<String, Any>> {
        val exportDir = getExportDir()
        val files = mutableListOf<Map<String, Any>>()

        if (exportDir.exists()) {
            exportDir.listFiles()?.filter { it.extension == "mp4" }?.forEach { file ->
                val resolution = when {
                    file.name.contains("_4K_") -> "4K (3840×1920)"
                    file.name.contains("_1080P_") -> "1080P (1920×960)"
                    else -> "Unknown"
                }
                files.add(mapOf(
                    "name" to file.name,
                    "path" to file.absolutePath,
                    "size" to file.length(),
                    "sizeFormatted" to formatFileSize(file.length()),
                    "resolution" to resolution,
                    "lastModified" to file.lastModified()
                ))
            }
        }

        // Sort newest first
        return files.sortedByDescending { it["lastModified"] as Long }
    }

    private fun formatFileSize(bytes: Long): String {
        return when {
            bytes >= 1_073_741_824 -> String.format("%.1f GB", bytes / 1_073_741_824.0)
            bytes >= 1_048_576 -> String.format("%.1f MB", bytes / 1_048_576.0)
            bytes >= 1024 -> String.format("%.1f KB", bytes / 1024.0)
            else -> "$bytes B"
        }
    }
}
