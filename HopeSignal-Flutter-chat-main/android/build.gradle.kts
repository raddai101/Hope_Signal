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
    
    // On utilise afterEvaluate pour être sûr de passer APRÈS la config de la lib Bluetooth
    afterEvaluate {
        project.plugins.withType<com.android.build.gradle.api.AndroidBasePlugin> {
            project.extensions.configure<com.android.build.gradle.BaseExtension> {
                compileSdkVersion(34) // Forcer 34 pour régler lStar
                buildToolsVersion("34.0.0")

                if (namespace == null) {
                    namespace = project.group.toString()
                }
                buildFeatures.buildConfig = true
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}