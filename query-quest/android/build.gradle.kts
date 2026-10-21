plugins {
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}

allprojects { repositories { google(); mavenCentral() } }
val newBuildDir = rootProject.layout.projectDirectory.dir("../build")
rootProject.layout.buildDirectory.value(newBuildDir)
subprojects { project.layout.buildDirectory.value(newBuildDir.dir(project.name)) }
tasks.register<Delete>("clean") { delete(rootProject.layout.buildDirectory) }



