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

    // Namespace fix must be registered BEFORE evaluationDependsOn forces evaluation
    afterEvaluate {
        if (project.hasProperty("android")) {
            val androidExt = project.extensions.findByName("android")
            if (androidExt != null) {
                try {
                    val getNamespace = androidExt.javaClass.getMethod("getNamespace")
                    if (getNamespace.invoke(androidExt) == null) {
                        val setNamespace = androidExt.javaClass.getMethod("setNamespace", String::class.java)
                        val ns = if (project.name == "blue_thermal_printer") "id.kakzaki.blue_thermal_printer" 
                                 else if (project.group.toString().isNotEmpty()) project.group.toString() 
                                 else "com.plugin.\${project.name}"
                        setNamespace.invoke(androidExt, ns)
                    }
                } catch (e: Exception) {}
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

