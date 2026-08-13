package com.hophop.hophop

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/// Uygulama içi güncelleme için küçük bir köprü.
///
/// Neden eklenti değil de elle yazıldı: indirme (http) ve dosya yolu
/// (path_provider) zaten projede var; geriye yalnızca "kendi sürümümü öğren" ve
/// "APK'yı sistem yükleyicisine ver" kalıyor. Bu ikisi için yeni bir bağımlılık
/// taşımaya değmez.
class MainActivity : FlutterActivity() {
    private val channel = "hophop/updater"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Kurulu sürüm: pubspec'teki "1.0.0+N" → name=1.0.0, code=N
                    "versionInfo" -> result.success(
                        mapOf(
                            "code" to currentVersionCode(),
                            "name" to (packageManager
                                .getPackageInfo(packageName, 0).versionName ?: "?"),
                        ))

                    // Android 8+: "bilinmeyen kaynaklardan kurulum" izni verilmiş mi?
                    "canInstall" -> result.success(canInstallPackages())

                    // Kullanıcıyı o iznin ayar ekranına götürür
                    "openInstallSettings" -> {
                        openInstallSettings()
                        result.success(null)
                    }

                    // İndirilmiş APK'yı sistem yükleyicisine devreder
                    "install" -> {
                        val path = call.argument<String>("path")
                        if (path == null) {
                            result.error("no_path", "APK yolu verilmedi", null)
                        } else {
                            try {
                                installApk(path)
                                result.success(true)
                            } catch (e: Exception) {
                                result.error("install_failed", e.message, null)
                            }
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun currentVersionCode(): Long {
        val info = packageManager.getPackageInfo(packageName, 0)
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.longVersionCode
        } else {
            @Suppress("DEPRECATION")
            info.versionCode.toLong()
        }
    }

    private fun canInstallPackages(): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            packageManager.canRequestPackageInstalls()
        } else {
            true
        }

    private fun openInstallSettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startActivity(
                Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES)
                    .setData(Uri.parse("package:$packageName"))
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        }
    }

    private fun installApk(path: String) {
        val file = File(path)
        require(file.exists()) { "APK bulunamadı: $path" }
        // Android 7+ dosya yolunu doğrudan paylaşmaya izin vermez (FileUriExposedException),
        // bu yüzden FileProvider üzerinden content:// URI verilir.
        val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
        startActivity(
            Intent(Intent.ACTION_VIEW)
                .setDataAndType(uri, "application/vnd.android.package-archive")
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }
}
