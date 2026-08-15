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

// Gradle 9 no longer promotes camera-core's runtime-scoped concurrent-futures
// onto the compile classpath; camera_android_camerax needs it at compile time.
// Remove once camera_android_camerax ships an explicit concurrent-futures dep.
subprojects {
    val subproject = this
    pluginManager.withPlugin("com.android.library") {
        if (subproject.name == "camera_android_camerax") {
            subproject.dependencies.add(
                "implementation",
                "androidx.concurrent:concurrent-futures:1.2.0",
            )
        }
    }
}

// Plugins pin older compileSdk values; bump them to Flutter's current floor.
subprojects {
    fun Project.bumpCompileSdk() {
        extensions.findByType<com.android.build.gradle.BaseExtension>()?.compileSdkVersion(36)
    }
    if (state.executed) {
        bumpCompileSdk()
    } else {
        afterEvaluate { bumpCompileSdk() }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
