buildscript {
    repositories {
        google()
        mavenCentral()
<<<<<<< HEAD
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/public") }
    }
    dependencies {
        classpath("com.android.tools.build:gradle:8.1.0")
=======
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
>>>>>>> 56d96f388ae5ade75ad80dc67b7a7d4913b38790
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/public") }
    }
<<<<<<< HEAD
}
=======
}
>>>>>>> 56d96f388ae5ade75ad80dc67b7a7d4913b38790
