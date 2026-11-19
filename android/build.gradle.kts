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

// Every AAR this app links is built against API 37 (audio_service,
// audio_session, jni, media_kit, permission_handler, flutter_js …), while
// Flutter 3.47's default compileSdk is 36, so AGP 9 stops at
// `checkDebugAarMetadata`. Raising only the :app module is not enough: a
// plugin that itself consumes one of those AARs (`shared_preferences_android`
// -> `jni`) has to compile against 37 as well. Registered before the
// `evaluationDependsOn` below, which evaluates every subproject immediately.
subprojects {
    afterEvaluate {
        val android =
            project.extensions.findByType(com.android.build.gradle.BaseExtension::class.java)
        if (android != null) android.compileSdkVersion(37)
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

// flutter_js ships its Kotlin at jvmTarget 1.8 (its own build.gradle still
// targets AGP 7.3), while AGP compiles its Java sources at 11 — AGP 9 refuses
// that mismatch outright. Align the Kotlin target of that one plugin instead
// of forking the package: it has no Java sources whose target would move.
subprojects {
    if (name == "flutter_js") {
        tasks.withType(org.jetbrains.kotlin.gradle.tasks.KotlinCompile::class.java).configureEach {
            compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11)
        }
    }
}
