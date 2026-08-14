package com.hophop.hophop

import android.app.PictureInPictureParams
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.util.Rational
import android.net.Uri
import android.os.Build
import android.os.PowerManager
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

    /// Küçük pencere (Picture-in-Picture) köprüsü. Ayrı kanal, çünkü tek yön
    /// değil: sistem kipi değiştirdiğinde Flutter'a haber vermemiz gerekiyor.
    private val pipChannelName = "hophop/pip"
    private var pipChannel: MethodChannel? = null

    /// Yalnızca görüşme sürerken küçük pencereye geçilir. Ana ekranda ev
    /// tuşuna basınca uygulama küçülmemeli.
    private var pipEligible = false

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

                    // Ahize kipinde yakınlık sensörü: telefon kulağa
                    // götürülünce ekran kapansın. Olmadığında kullanıcı yanağıyla
                    // sessize alma/kapatma düğmelerine basıyordu.
                    "proximity" -> {
                        setProximity(call.argument<Boolean>("on") == true)
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            }

        pipChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, pipChannelName)
        pipChannel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "isSupported" -> result.success(pipSupported())
                // Görüşme başlarken açılır, biterken kapanır.
                "setEligible" -> {
                    pipEligible = call.argument<Boolean>("on") == true
                    result.success(null)
                }
                // Geri tuşu ya da küçült düğmesi
                "enter" -> result.success(
                    enterPip(call.argument<Int>("w") ?: 16, call.argument<Int>("h") ?: 9))
                else -> result.notImplemented()
            }
        }
    }

    private fun pipSupported(): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)

    private fun enterPip(w: Int, h: Int): Boolean {
        if (!pipSupported()) return false
        return try {
            // Android en/boy oranını 0.42–2.39 arasında ister; dışına taşarsa
            // istisna fırlatır ve görüşme ekranı çöker.
            val ratio = Rational(w.coerceIn(10, 239), h.coerceIn(10, 239))
            val params = PictureInPictureParams.Builder().setAspectRatio(ratio).build()
            enterPictureInPictureMode(params)
        } catch (e: Exception) {
            false
        }
    }

    /// Ev tuşuna basıldı ya da uygulama arka plana alınıyor: görüşme sürüyorsa
    /// kapanmak yerine küçük pencereye geç (WhatsApp davranışı).
    override fun onUserLeaveHint() {
        if (pipEligible && pipSupported()) enterPip(16, 9)
        super.onUserLeaveHint()
    }

    /// Flutter tarafı küçük pencerede sade bir düzene geçebilsin diye haber ver.
    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration,
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        pipChannel?.invokeMethod("changed", isInPictureInPictureMode)
    }

    /// Yakınlık sensörüyle ekranı kapatan sistem kilidi. Ahize kipinde açılır,
    /// hoparlöre geçilince ya da görüşme bitince bırakılır.
    private var proximityLock: PowerManager.WakeLock? = null

    private fun setProximity(on: Boolean) {
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        if (on) {
            if (proximityLock?.isHeld == true) return
            if (!pm.isWakeLockLevelSupported(PowerManager.PROXIMITY_SCREEN_OFF_WAKE_LOCK)) return
            @Suppress("DEPRECATION")
            proximityLock = pm.newWakeLock(
                PowerManager.PROXIMITY_SCREEN_OFF_WAKE_LOCK, "hophop:proximity")
                .also { it.setReferenceCounted(false); it.acquire(60 * 60 * 1000L) }
        } else {
            proximityLock?.let { if (it.isHeld) it.release() }
            proximityLock = null
        }
    }

    override fun onDestroy() {
        setProximity(false) // görüşme yarıda kalsa bile kilit sızmasın
        super.onDestroy()
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
