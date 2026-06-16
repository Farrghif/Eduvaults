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

subprojects {
    if (project.state.executed) {
        try {
            val androidExtension = project.extensions.getByName("android")
            androidExtension.javaClass.getMethod("compileSdkVersion", Integer.TYPE).invoke(androidExtension, 36)
        } catch (e: Exception) {
            // ignore
        }
    } else {
        project.afterEvaluate {
            try {
                val androidExtension = project.extensions.getByName("android")
                androidExtension.javaClass.getMethod("compileSdkVersion", Integer.TYPE).invoke(androidExtension, 36)
            } catch (e: Exception) {
                // ignore
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
