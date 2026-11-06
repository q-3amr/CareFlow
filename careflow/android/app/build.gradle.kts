plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    ndkVersion = "28.2.13676358"
    namespace = "com.example.careflow"
   compileSdk = 36
   
    compileOptions {
        // تحديث للإصدار 1.8 وتفعيل الـ Desugaring
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_1_8.toString()
    }

    defaultConfig {
        applicationId = "com.example.careflow"
        minSdk = flutter.minSdkVersion // رفعنا الـ minSdk لضمان عمل المكتبات
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        // تفعيل الـ MultiDex
        multiDexEnabled = true
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // إضافة المكتبة المسؤولة عن الـ Desugaring في نهاية الملف
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.3")
}
