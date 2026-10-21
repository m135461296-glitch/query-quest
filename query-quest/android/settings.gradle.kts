pluginManagement {
    val localProperties = java.util.Properties()
    val localPropertiesFile = file("local.properties")
    require(localPropertiesFile.exists()) { "local.properties not found; run Flutter once to generate it." }
    localPropertiesFile.inputStream().use { localProperties.load(it) }
    val flutterSdkPath = localProperties.getProperty("flutter.sdk")
        ?: error("flutter.sdk is missing from local.properties")
    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")
    repositories { google(); mavenCentral(); gradlePluginPortal() }
}
plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}
include(":app")


