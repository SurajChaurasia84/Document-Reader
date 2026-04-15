package com.example.pdf_studio

import android.os.Build
import android.os.Environment
import android.os.StatFs
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val channelName = "pdf_studio/storage_info"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getStorageOverview" -> {
                        try {
                            result.success(
                                mapOf(
                                    "filesStorage" to getPrimaryStorageInfo(),
                                    "sdCardStorage" to getSdCardStorageInfo(),
                                ),
                            )
                        } catch (e: Exception) {
                            result.error("storage_error", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun getPrimaryStorageInfo(): Map<String, Any> {
        val directory = Environment.getExternalStorageDirectory()
        return buildStorageInfoMap("Files Storage", directory, directory.exists())
    }

    private fun getSdCardStorageInfo(): Map<String, Any>? {
        val externalDirs = getExternalFilesDirs(null)
        val primaryRoot = normalizeRoot(Environment.getExternalStorageDirectory())

        for (dir in externalDirs) {
            if (dir == null) continue
            val root = extractStorageRoot(dir) ?: continue
            if (!root.exists()) continue
            if (normalizeRoot(root) == primaryRoot) continue

            return buildStorageInfoMap("SD Card", root, true)
        }

        return null
    }

    private fun extractStorageRoot(file: File): File? {
        val path = file.absolutePath
        val androidIndex = path.indexOf("/Android/")
        return if (androidIndex > 0) File(path.substring(0, androidIndex)) else null
    }

    private fun normalizeRoot(file: File?): String {
        return file?.absolutePath?.trimEnd('/') ?: ""
    }

    private fun buildStorageInfoMap(
        label: String,
        directory: File,
        available: Boolean,
    ): Map<String, Any> {
        if (!available) {
            return mapOf(
                "label" to label,
                "path" to directory.absolutePath,
                "totalBytes" to 0L,
                "availableBytes" to 0L,
                "isAvailable" to false,
            )
        }

        val statFs = StatFs(directory.absolutePath)
        val totalBytes = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR2) {
            statFs.totalBytes
        } else {
            statFs.blockCountLong * statFs.blockSizeLong
        }
        val availableBytes = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR2) {
            statFs.availableBytes
        } else {
            statFs.availableBlocksLong * statFs.blockSizeLong
        }

        return mapOf(
            "label" to label,
            "path" to directory.absolutePath,
            "totalBytes" to totalBytes,
            "availableBytes" to availableBytes,
            "isAvailable" to true,
        )
    }
}
