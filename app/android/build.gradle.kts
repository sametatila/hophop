allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Eski compileSdk bildiren Flutter eklentileri (ör. flutter_webrtc) androidx
// bağımlılıklarıyla çakışmasın diye tüm kütüphane modüllerine asgari 37 zorlanır.
subprojects {
    plugins.withId("com.android.library") {
        extensions.configure(com.android.build.gradle.LibraryExtension::class.java) {
            if (compileSdk == null || compileSdk!! < 37) compileSdk = 37
        }
    }
    // Eklentilerin "source value 8 is obsolete" javac uyarılarını sustur —
    // eklenti yazarlarının Java sürümü tercihi; bizim düzeltebileceğimiz bir şey değil.
    tasks.withType<JavaCompile>().configureEach {
        options.compilerArgs.addAll(listOf("-Xlint:-options", "-nowarn"))
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
