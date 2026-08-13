#!/usr/bin/env python3
"""HopHop Android proje kurulumu.

`flutter create` ile eksik Android iskeletini üretir, sonra gerekli yamaları uygular:
  - AndroidManifest izinleri
  - minSdk 23 + core library desugaring (flutter_local_notifications gereği)
  - google-services Gradle eklentisi
  - zil sesi → res/raw/ringtone.wav

Çalıştır (app/ dizininde): python3 setup_android.py
İdempotenttir; tekrar çalıştırmak güvenlidir.
"""
import re
import shutil
import subprocess
import sys
from pathlib import Path

APP = Path(__file__).resolve().parent

PERMISSIONS = [
    'android.permission.INTERNET',
    'android.permission.CAMERA',
    'android.permission.RECORD_AUDIO',
    'android.permission.POST_NOTIFICATIONS',
    'android.permission.USE_FULL_SCREEN_INTENT',
    'android.permission.VIBRATE',
    'android.permission.WAKE_LOCK',
    'android.permission.ACCESS_NETWORK_STATE',
    'android.permission.CHANGE_NETWORK_STATE',
    'android.permission.MODIFY_AUDIO_SETTINGS',
    'android.permission.BLUETOOTH_CONNECT',
    'android.permission.FOREGROUND_SERVICE',
    'android.permission.FOREGROUND_SERVICE_SPECIAL_USE',
    'android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS',
]


def run_flutter_create():
    if (APP / 'android').exists():
        print('✓ android/ zaten var — flutter create atlandı')
        return
    # flutter create mevcut lib/ ve pubspec'i korur ama garanti olsun diye yedekle
    backup = APP / '.pubspec.backup.yaml'
    shutil.copy(APP / 'pubspec.yaml', backup)
    subprocess.run(
        ['flutter', 'create', '.', '--org', 'com.hophop', '--project-name',
         'hophop', '--platforms', 'android'],
        cwd=APP, check=True)
    shutil.copy(backup, APP / 'pubspec.yaml')
    backup.unlink()
    print('✓ flutter create tamam')


def patch_manifest():
    manifest = APP / 'android/app/src/main/AndroidManifest.xml'
    text = manifest.read_text()
    add = ''.join(
        f'    <uses-permission android:name="{p}" />\n'
        for p in PERMISSIONS
        if p not in text)
    if add:
        text = text.replace('<application', f'{add}    <application', 1)
    # flutter_foreground_task servis tipi
    if 'specialUse' not in text and '</application>' in text:
        service = (
            '        <service\n'
            '            android:name="com.pravera.flutter_foreground_task.service.ForegroundService"\n'
            '            android:foregroundServiceType="specialUse"\n'
            '            android:exported="false">\n'
            '            <property android:name="android.app.PROPERTY_SPECIAL_USE_FGS_SUBTYPE"\n'
            '                android:value="family video call readiness" />\n'
            '        </service>\n')
        text = text.replace('</application>', f'{service}    </application>')
    manifest.write_text(text)
    print('✓ AndroidManifest izinleri ve servis eklendi')


def patch_app_gradle():
    kts = APP / 'android/app/build.gradle.kts'
    groovy = APP / 'android/app/build.gradle'
    path = kts if kts.exists() else groovy
    text = path.read_text()
    is_kts = path.suffix == '.kts'

    if 'com.google.gms.google-services' not in text:
        if is_kts:
            text = re.sub(r'(plugins\s*\{)', r'\1\n    id("com.google.gms.google-services")', text, count=1)
        else:
            text = re.sub(r"(plugins\s*\{)", r"\1\n    id 'com.google.gms.google-services'", text, count=1)

    if 'coreLibraryDesugaringEnabled' not in text and 'isCoreLibraryDesugaringEnabled' not in text:
        if is_kts:
            text = re.sub(
                r'(compileOptions\s*\{)',
                r'\1\n        isCoreLibraryDesugaringEnabled = true', text, count=1)
        else:
            text = re.sub(
                r'(compileOptions\s*\{)',
                r'\1\n        coreLibraryDesugaringEnabled true', text, count=1)

    text = re.sub(r'minSdk\s*=\s*flutter\.minSdkVersion', 'minSdk = 23', text)
    text = re.sub(r'minSdkVersion\s+flutter\.minSdkVersion', 'minSdkVersion 23', text)

    if 'desugar_jdk_libs' not in text:
        dep = ('coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")'
               if is_kts else
               "coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'")
        if re.search(r'^dependencies\s*\{', text, flags=re.M):
            text = re.sub(r'(^dependencies\s*\{)', rf'\1\n    {dep}', text, count=1, flags=re.M)
        else:
            text += f'\n\ndependencies {{\n    {dep}\n}}\n'

    path.write_text(text)
    print(f'✓ {path.name} yamalandı (google-services, desugaring, minSdk 23)')


def patch_signing():
    """release derlemesini android/key.properties varsa gerçek anahtarla imzalat.

    Dosya yoksa debug anahtarına düşülür (uyarı basar). Ayrıntı: SETUP.md §5.1.
    """
    path = APP / 'android/app/build.gradle.kts'
    if not path.exists():
        print('⚠ build.gradle.kts yok — imzalama yaması atlandı')
        return
    text = path.read_text()
    if 'key.properties' in text:
        print('✓ imzalama yapılandırması zaten var')
        return

    header = (
        'import java.io.FileInputStream\n'
        'import java.util.Properties\n\n')
    block = (
        '\n// Yayın imzası: android/key.properties (gitignore\'da) varsa oradan okunur.\n'
        'val keystorePropertiesFile = rootProject.file("key.properties")\n'
        'val keystoreProperties = Properties().apply {\n'
        '    if (keystorePropertiesFile.exists()) {\n'
        '        FileInputStream(keystorePropertiesFile).use { load(it) }\n'
        '    }\n'
        '}\n'
        'val hasReleaseKey = keystorePropertiesFile.exists()\n')
    signing = (
        '    signingConfigs {\n'
        '        if (hasReleaseKey) {\n'
        '            create("release") {\n'
        '                storeFile = file(keystoreProperties.getProperty("storeFile"))\n'
        '                storePassword = keystoreProperties.getProperty("storePassword")\n'
        '                keyAlias = keystoreProperties.getProperty("keyAlias")\n'
        '                keyPassword = keystoreProperties.getProperty("keyPassword")\n'
        '            }\n'
        '        }\n'
        '    }\n\n'
        '    buildTypes {\n'
        '        release {\n'
        '            signingConfig = if (hasReleaseKey) {\n'
        '                signingConfigs.getByName("release")\n'
        '            } else {\n'
        '                logger.warn("\\n⚠ android/key.properties yok → release APK DEBUG '
        'anahtarıyla imzalanıyor. Dağıtmadan önce app/make-release-key.sh çalıştır.\\n")\n'
        '                signingConfigs.getByName("debug")\n'
        '            }\n'
        '        }\n'
        '    }\n')

    # DİKKAT: replacement'lar fonksiyon olarak verilir — düz metin verilirse
    # re.sub içindeki "\n" gibi kaçışlar çözülür ve Kotlin string'i satır ortasında kırılır.
    text = header + text
    text = re.sub(r'(^plugins\s*\{[^}]*\}\n)', lambda m: m.group(1) + block,
                  text, count=1, flags=re.M | re.S)
    # flutter create'in ürettiği varsayılan buildTypes bloğunu tamamen değiştir
    new_text = re.sub(
        r'^    buildTypes \{.*?^    \}\n', lambda m: signing, text, count=1,
        flags=re.M | re.S)
    if new_text == text:  # buildTypes bulunamadıysa android{} sonuna ekle
        print('⚠ buildTypes bloğu bulunamadı — imzalama bloğunu elle ekle')
        return
    path.write_text(new_text)
    print('✓ build.gradle.kts imzalama yapılandırması eklendi')


def patch_settings_gradle():
    kts = APP / 'android/settings.gradle.kts'
    groovy = APP / 'android/settings.gradle'
    path = kts if kts.exists() else groovy
    text = path.read_text()
    if 'com.google.gms.google-services' in text:
        print('✓ settings.gradle google-services zaten var')
        return
    line = ('    id("com.google.gms.google-services") version "4.4.2" apply false'
            if path.suffix == '.kts' else
            '    id "com.google.gms.google-services" version "4.4.2" apply false')
    # plugins bloğunun sonuna ekle (flutter-plugin-loader satırından sonra)
    m = list(re.finditer(r'^\s*id[ (]"dev\.flutter\.flutter-gradle-plugin".*$', text, flags=re.M))
    if not m:
        m = list(re.finditer(r'^plugins\s*\{\s*$', text, flags=re.M))
    if m:
        pos = m[-1].end()
        text = text[:pos] + '\n' + line + text[pos:]
        path.write_text(text)
        print(f'✓ {path.name} yamalandı (google-services eklentisi)')
    else:
        print(f'⚠ {path.name} içinde plugins bloğu bulunamadı — google-services satırını elle ekle:')
        print(f'   {line}')


def copy_ringtone():
    src = APP / 'android-extras/ringtone.wav'
    dst = APP / 'android/app/src/main/res/raw/ringtone.wav'
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy(src, dst)
    print('✓ ringtone.wav → res/raw/ kopyalandı')


def main():
    run_flutter_create()
    patch_manifest()
    patch_app_gradle()
    patch_signing()
    patch_settings_gradle()
    copy_ringtone()
    gsj = APP / 'android/app/google-services.json'
    print()
    if not gsj.exists():
        print('❗ Eksik: android/app/google-services.json')
        print('   Firebase Console → Project Settings → Android app → google-services.json indir.')
    print('Sonraki adım: flutter pub get && flutter build apk --release \\')
    print('              --dart-define=HOPHOP_API=https://<vercel-projen>.vercel.app')


if __name__ == '__main__':
    try:
        main()
    except subprocess.CalledProcessError as e:
        sys.exit(f'Komut başarısız: {e}')
