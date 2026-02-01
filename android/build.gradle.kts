allprojects {
    repositories {
    google()
    mavenCentral()
    maven(url = "https://storage.googleapis.com/download.flutter.io")
    maven {
        url = uri("https://nexusmobile.fawrystaging.com:2597/repository/maven-public/")
        isAllowInsecureProtocol = false
        metadataSources {
            mavenPom()
            artifact()
            // Skip gradleModule() to avoid hanging on metadata checks
        }
        // Removed content filter to allow all dependencies from this repository
    }
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
