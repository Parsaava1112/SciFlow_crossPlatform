buildscript {
    repositories {
        google()
        mavenCentral()
        // مسیر محلی پلاگین‌های Flutter
        maven {
            url = uri("${System.getenv("FLUTTER_ROOT")}/packages/flutter_tools/gradle")
        }
    }
    dependencies {
        classpath("com.android.tools.build:gradle:8.1.0")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.0")
        // بارگذاری پلاگین فلاتر از مسیر محلی
        classpath("dev.flutter:flutter-gradle-plugin:1.0.0")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}
