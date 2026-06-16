pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
        // مسیر محلی پلاگین‌های Flutter با استفاده از متغیر محیطی FLUTTER_ROOT
        maven {
            url = uri("${System.getenv("FLUTTER_ROOT")}/packages/flutter_tools/gradle")
        }
    }
}

plugins {
    id("dev.flutter.flutter-gradle-plugin") version "1.0.0" apply false
}

include(":app")
