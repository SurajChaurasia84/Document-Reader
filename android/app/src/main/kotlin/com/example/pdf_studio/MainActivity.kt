package com.example.pdf_studio

import android.os.Build
import android.os.Environment
import android.os.StatFs
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import android.os.Handler
import android.os.Looper
import java.util.concurrent.Executors

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
                    "fetchMediaStoreFiles" -> {
                        Executors.newSingleThreadExecutor().execute {
                            try {
                                val files = fetchMediaStoreFiles()
                                Handler(Looper.getMainLooper()).post {
                                    result.success(files)
                                }
                            } catch (e: Exception) {
                                Handler(Looper.getMainLooper()).post {
                                    result.error("mediastore_error", e.message, null)
                                }
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun fetchMediaStoreFiles(): List<Map<String, Any>> {
        val files = mutableListOf<Map<String, Any>>()
        val contentResolver = contentResolver
        val uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            android.provider.MediaStore.Files.getContentUri(android.provider.MediaStore.VOLUME_EXTERNAL)
        } else {
            android.provider.MediaStore.Files.getContentUri("external")
        }

        val projection = arrayOf(
            android.provider.MediaStore.Files.FileColumns.DATA,
            android.provider.MediaStore.Files.FileColumns.DISPLAY_NAME,
            android.provider.MediaStore.Files.FileColumns.SIZE,
            android.provider.MediaStore.Files.FileColumns.DATE_MODIFIED,
            android.provider.MediaStore.Files.FileColumns.MIME_TYPE
        )

        // Filter for documents
        val selection = (android.provider.MediaStore.Files.FileColumns.MIME_TYPE + " LIKE ? OR " +
                android.provider.MediaStore.Files.FileColumns.DISPLAY_NAME + " LIKE ? OR " +
                android.provider.MediaStore.Files.FileColumns.DISPLAY_NAME + " LIKE ? OR " +
                android.provider.MediaStore.Files.FileColumns.DISPLAY_NAME + " LIKE ? OR " +
                android.provider.MediaStore.Files.FileColumns.DISPLAY_NAME + " LIKE ? OR " +
                android.provider.MediaStore.Files.FileColumns.DISPLAY_NAME + " LIKE ? OR " +
                android.provider.MediaStore.Files.FileColumns.DISPLAY_NAME + " LIKE ? OR " +
                android.provider.MediaStore.Files.FileColumns.DISPLAY_NAME + " LIKE ? OR " +
                android.provider.MediaStore.Files.FileColumns.DISPLAY_NAME + " LIKE ?")

        val selectionArgs = arrayOf(
            "application/%",
            "%.pdf", "%.doc", "%.docx", "%.xls", "%.xlsx", "%.ppt", "%.pptx", "%.txt"
        )

        contentResolver.query(uri, projection, selection, selectionArgs, null)?.use { cursor ->
            val dataIndex = cursor.getColumnIndexOrThrow(android.provider.MediaStore.Files.FileColumns.DATA)
            val nameIndex = cursor.getColumnIndexOrThrow(android.provider.MediaStore.Files.FileColumns.DISPLAY_NAME)
            val sizeIndex = cursor.getColumnIndexOrThrow(android.provider.MediaStore.Files.FileColumns.SIZE)
            val dateIndex = cursor.getColumnIndexOrThrow(android.provider.MediaStore.Files.FileColumns.DATE_MODIFIED)

            while (cursor.moveToNext()) {
                val path = cursor.getString(dataIndex) ?: continue
                val name = cursor.getString(nameIndex) ?: File(path).name
                
                // Skip hidden files and trash/recycle folders
                if (name.startsWith(".") || isTrashPath(path)) continue

                val file = File(path)
                if (!file.exists() || !file.isFile) continue

                val extension = path.substringAfterLast('.', "").lowercase()
                val supported = arrayOf("pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "csv", "rtf")
                if (!supported.contains(extension)) continue

                files.add(
                    mapOf(
                        "path" to path,
                        "name" to name,
                        "size" to cursor.getLong(sizeIndex),
                        "modified_at" to cursor.getLong(dateIndex) * 1000, // Convert to ms
                        "extension" to extension
                    )
                )
            }
        }
        return files
    }

    private fun isTrashPath(path: String): Boolean {
        val lowerPath = path.lowercase()
        val trashKeywords = arrayOf("/.trash/", "/trash/", "/recycle/", "/.recycle/", "/deleted/", "/.deleted/")
        return trashKeywords.any { lowerPath.contains(it) }
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
