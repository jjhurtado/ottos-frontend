package com.remesadeotto.ottos

import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import androidx.core.content.pm.PackageInfoCompat
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
                        val file = File(call.arguments as String)
                        if (!isNewerBuildOfThisApp(file)) {
                            // SEC-1: the Dart side deletes the file, so a retry downloads it again.
                            result.error("rejected", "Not a newer build of this app signed with its key", null)
                        } else {
                            // A file outside cache/updates makes getUriForFile throw.
                            val uri = FileProvider.getUriForFile(this, "$packageName.updates", file)
                            startActivity(
                                Intent(Intent.ACTION_VIEW)
                                    .setDataAndType(uri, "application/vnd.android.package-archive")
                                    .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            )
                            result.success(null)
                        }
                    }
                    else -> result.notImplemented()
                }
            } catch (error: Exception) {
                result.error("update", error.javaClass.simpleName, null)
            }
        }
    }

    /**
     * SEC-1: the installer is opened only for this app's package, signed with the
     * installed app's key, with a higher versionCode. Android's same-key rule covers
     * only an APK with this package name; another one would be offered as a new app.
     */
    private fun isNewerBuildOfThisApp(file: File): Boolean {
        val installed = packageManager.getPackageInfo(packageName, 0)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val archive = packageManager.getPackageArchiveInfo(file.path, PackageManager.GET_SIGNING_CERTIFICATES)
                ?: return false
            val signers = archive.signingInfo?.apkContentsSigners ?: return false
            return archive.packageName == packageName &&
                PackageInfoCompat.getLongVersionCode(archive) > PackageInfoCompat.getLongVersionCode(installed) &&
                signers.isNotEmpty() &&
                signers.all {
                    packageManager.hasSigningCertificate(packageName, it.toByteArray(), PackageManager.CERT_INPUT_RAW_X509)
                }
        }
        @Suppress("DEPRECATION")
        val archive = packageManager.getPackageArchiveInfo(file.path, PackageManager.GET_SIGNATURES) ?: return false
        @Suppress("DEPRECATION")
        val ours = packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNATURES).signatures?.toSet()
        @Suppress("DEPRECATION")
        val theirs = archive.signatures?.toSet()
        return archive.packageName == packageName &&
            PackageInfoCompat.getLongVersionCode(archive) > PackageInfoCompat.getLongVersionCode(installed) &&
            !theirs.isNullOrEmpty() && theirs == ours
    }
}
