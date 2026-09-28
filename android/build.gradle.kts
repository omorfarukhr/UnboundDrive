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
    val configureCompileSdk = {
        val android = extensions.findByName("android")
        if (android != null) {
            try {
                val setCompileSdk = android.javaClass.getMethod("setCompileSdk", java.lang.Integer::class.java)
                setCompileSdk.invoke(android, 36)
                println("SET compileSdk 36 for $name")
            } catch (e: Throwable) {
                try {
                    val compileSdkVersion = android.javaClass.getMethod("compileSdkVersion", Int::class.javaPrimitiveType)
                    compileSdkVersion.invoke(android, 36)
                    println("SET compileSdkVersion 36 for $name")
                } catch (e2: Throwable) {}
            }
        }
    }

    if (state.executed) {
        configureCompileSdk()
    } else {
        afterEvaluate {
            configureCompileSdk()
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
