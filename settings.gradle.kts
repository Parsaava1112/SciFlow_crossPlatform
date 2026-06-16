pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
        // مسیر محلی پلاگین فلاتر
        maven {
            url = uri("${providers.gradleProperty("flutter.sdk").get()}/packages/flutter_tools/gradle")
        }
    }
}

plugins {
    id("dev.flutter.flutter-gradle-plugin") version "1.0.0" apply false
}

include(":app")
