package io.github.aaronified.lexodle

import android.content.ActivityNotFoundException
import android.content.ContentUris
import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import androidx.core.content.FileProvider
import java.io.File
import java.security.MessageDigest

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
                            call.argument<String>("mime") ?: "application/json",
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
                    "writeLog" -> {
                        File(logsDir(), safe(call.argument<String>("name")!!))
                            .writeBytes(call.argument<ByteArray>("bytes")!!)
                        result.success(true)
                    }
                    "readLog" -> {
                        val f = File(logsDir(), safe(call.argument<String>("name")!!))
                        result.success(if (f.isFile) f.readBytes() else null)
                    }
                    "keptApk" -> result.success(keptApk(call.argument<String>("name")!!))
                    "installApk" -> result.success(installApk(call.argument<String>("name")!!))
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

    /// The update downloaded by ota_update: files/ota_update/<name>.
    private fun apkFile(name: String): File = File(File(filesDir, "ota_update"), safe(name))

    /// The size and SHA-256 of a kept update, or null when there is none, so the
    /// app can open the installer on it again instead of downloading it twice.
    private fun keptApk(name: String): Map<String, Any>? {
        val f = apkFile(name)
        if (!f.isFile || f.length() <= 0) return null
        val digest = MessageDigest.getInstance("SHA-256")
        f.inputStream().use { input ->
            val buffer = ByteArray(64 * 1024)
            while (true) {
                val n = input.read(buffer)
                if (n < 0) break
                digest.update(buffer, 0, n)
            }
        }
        return mapOf(
            "size" to f.length(),
            "sha256" to digest.digest().joinToString("") { "%02x".format(it) },
        )
    }

    /// Opens Android's installer on a kept update, through ota_update's
    /// FileProvider (declared in the manifest). True if the installer opened.
    private fun installApk(name: String): Boolean {
        val f = apkFile(name)
        if (!f.isFile) return false
        val uri: Uri = try {
            FileProvider.getUriForFile(this, "$packageName.ota_update_provider", f)
        } catch (e: IllegalArgumentException) {
            return false
        }
        val view = Intent(Intent.ACTION_VIEW)
            .setDataAndType(uri, "application/vnd.android.package-archive")
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        return try {
            startActivity(view)
            true
        } catch (e: ActivityNotFoundException) {
            false
        } catch (e: SecurityException) {
            false
        }
    }

    /// The folder of the app's own copies, inside its private storage.
    private fun backupsDir(): File = File(filesDir, "backups").also { it.mkdirs() }

    /// The app's log, kept apart from the backups (which are pruned by age).
    private fun logsDir(): File = File(filesDir, "logs").also { it.mkdirs() }

    /// A file name with no path in it.
    private fun safe(name: String): String = File(name).name

    /// Saves [bytes] as [name] in the Downloads folder, replacing an earlier copy
    /// of the same name that this app made. Returns the name it was saved as, or
    /// null before Android 10 (which would need a storage permission).
    private fun saveToDownloads(name: String, bytes: ByteArray, mime: String): String? {
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
            put(MediaStore.Downloads.MIME_TYPE, mime)
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
