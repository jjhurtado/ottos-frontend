package com.remesadeotto.ottos

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // REQ-023: the app updates itself. The Dart side downloads the APK into
        // cache/updates, the only folder the FileProvider shares.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ottos/update").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "folder" -> result.success(File(cacheDir, "updates").apply { mkdirs() }.path)
                    "canInstall" -> result.success(
                        Build.VERSION.SDK_INT < Build.VERSION_CODES.O || packageManager.canRequestPackageInstalls()
                    )
                    "openSettings" -> {
                        startActivity(
                            Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:$packageName"))
                        )
                        result.success(null)
                    }
                    "install" -> {
                        // A file outside cache/updates makes getUriForFile throw.
                        val uri = FileProvider.getUriForFile(this, "$packageName.updates", File(call.arguments as String))
                        startActivity(
                            Intent(Intent.ACTION_VIEW)
                                .setDataAndType(uri, "application/vnd.android.package-archive")
                                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        )
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (error: Exception) {
                result.error("update", error.javaClass.simpleName, null)
            }
        }
    }
}
