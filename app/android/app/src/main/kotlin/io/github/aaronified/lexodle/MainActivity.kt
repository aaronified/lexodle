package io.github.aaronified.lexodle

import android.content.ContentUris
import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/// The app's automatic backups are written here: a copy in the app's own
/// storage (it survives an update) and a copy in the Downloads folder (it
/// survives anything, even uninstalling). No plugin and no permission: the
/// Downloads copy goes through MediaStore, which needs none from Android 10 on.
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "io.github.aaronified.lexodle/files",
        ).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "saveToDownloads" -> result.success(
                        saveToDownloads(
                            call.argument<String>("name")!!,
                            call.argument<ByteArray>("bytes")!!,
                        ),
                    )
                    "writeInternal" -> {
                        val dir = backupsDir()
                        File(dir, safe(call.argument<String>("name")!!))
                            .writeBytes(call.argument<ByteArray>("bytes")!!)
                        result.success(true)
                    }
                    "listInternal" -> result.success(
                        backupsDir().listFiles()
                            ?.filter { it.isFile }
                            ?.sortedByDescending { it.lastModified() }
                            ?.map { it.name } ?: emptyList<String>(),
                    )
                    "readInternal" -> {
                        val f = File(backupsDir(), safe(call.argument<String>("name")!!))
                        result.success(if (f.isFile) f.readBytes() else null)
                    }
                    "deleteInternal" -> {
                        File(backupsDir(), safe(call.argument<String>("name")!!)).delete()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("files", e.message, null)
            }
        }
    }

    /// The folder of the app's own copies, inside its private storage.
    private fun backupsDir(): File = File(filesDir, "backups").also { it.mkdirs() }

    /// A file name with no path in it.
    private fun safe(name: String): String = File(name).name

    /// Saves [bytes] as [name] in the Downloads folder, replacing an earlier copy
    /// of the same name that this app made. Returns the name it was saved as, or
    /// null before Android 10 (which would need a storage permission).
    private fun saveToDownloads(name: String, bytes: ByteArray): String? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return null
        val resolver = contentResolver
        val collection = MediaStore.Downloads.EXTERNAL_CONTENT_URI
        resolver.query(
            collection,
            arrayOf(MediaStore.Downloads._ID),
            "${MediaStore.Downloads.DISPLAY_NAME} = ?",
            arrayOf(name),
            null,
        )?.use { cursor ->
            while (cursor.moveToNext()) {
                try {
                    resolver.delete(
                        ContentUris.withAppendedId(collection, cursor.getLong(0)),
                        null,
                        null,
                    )
                } catch (_: Exception) {
                    // a file of another install: it is left, and ours is renamed
                }
            }
        }
        val values = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, name)
            put(MediaStore.Downloads.MIME_TYPE, "application/json")
            put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
            put(MediaStore.Downloads.IS_PENDING, 1)
        }
        val uri = resolver.insert(collection, values) ?: return null
        resolver.openOutputStream(uri)?.use { it.write(bytes) } ?: return null
        values.clear()
        values.put(MediaStore.Downloads.IS_PENDING, 0)
        resolver.update(uri, values, null, null)
        return name
    }
}
