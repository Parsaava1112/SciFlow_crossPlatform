<<<<<<< HEAD
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
        // آینه‌های Aliyun برای دریافت پلاگین‌ها
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/public") }
        maven { url = uri("https://maven.aliyun.com/repository/gradle-plugin") }
    }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS)
    repositories {
        google()
        mavenCentral()
        // آینه‌های Aliyun برای دریافت وابستگی‌ها
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/public") }
        maven { url = uri("https://maven.aliyun.com/repository/gradle-plugin") }
    }
}

rootProject.name = "first"
include(":app")
=======
include(":app")
>>>>>>> 56d96f388ae5ade75ad80dc67b7a7d4913b38790
