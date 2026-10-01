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
    
    plugins.withId("org.jetbrains.kotlin.android") {
        project.tasks.withType(org.jetbrains.kotlin.gradle.tasks.KotlinCompile::class.java).configureEach {
            compilerOptions {
                freeCompilerArgs.addAll(listOf("-Xskip-metadata-version-check"))
            }
        }
    }

    pluginManager.withPlugin("com.android.library") {
        val androidExtension = extensions.findByName("android")
        if (androidExtension != null) {
            try {
                val setCompileSdk = androidExtension.javaClass.getMethod("setCompileSdk", Int::class.java)
                setCompileSdk.invoke(androidExtension, 36)
            } catch (_: Exception) {}
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
