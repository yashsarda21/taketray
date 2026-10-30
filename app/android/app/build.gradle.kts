plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "app.taketray"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "app.taketray"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 30 // Android 11 is the minimum supported version
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Launcher name for release and profile; the debug build type overrides it.
        // (Set here, not on release: Flutter's profile type does not inherit it.)
        manifestPlaceholders["appLabel"] = "TakeTray"
        // Patrol on-device tests (docs/dev-setup.md).
        testInstrumentationRunner = "pl.leancode.patrol.PatrolJUnitRunner"
        testInstrumentationRunnerArguments["clearPackageData"] = "true"
    }

    testOptions {
        execution = "ANDROIDX_TEST_ORCHESTRATOR"
        // Robolectric unit tests (tool/test_android, D-67) read the merged
        // manifest and resources.
        unitTests.isIncludeAndroidResources = true
    }

    buildTypes {
        debug {
            // Debug builds (flutter run, Patrol) are a second app, so Patrol's
            // clearPackageData can never wipe the real app.taketray data (D-52).
            applicationIdSuffix = ".dev"
            manifestPlaceholders["appLabel"] = "TakeTray Dev"
        }
        release {
            // Note: signed with the debug keys for now, so `flutter run --release`
            // and tool/check_release_permissions work. Real release signing is
            // phase 11 (keystore and key.properties are never committed).
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

// `tool/test_android -ProbolectricSdks=35` runs the Robolectric tests on one
// SDK level only, for quick iterations (robolectric.properties lists all four).
tasks.withType<Test>().configureEach {
    providers.gradleProperty("robolectricSdks").orNull?.let { systemProperty("robolectric.enabledSdks", it) }
}

// With unitTests.isIncludeAndroidResources, the unit-test package reads the
// merged assets folder, which Flutter's copyFlutterAssets<Variant> task also
// writes without declaring it; Gradle 9 refuses that, so order the two.
tasks.configureEach {
    val variant = Regex("package(\\w+)UnitTestForUnitTest").matchEntire(name)?.groupValues?.get(1)
    if (variant != null) dependsOn("copyFlutterAssets$variant")
}

dependencies {
    // The Pigeon code launches its async handlers on Dispatchers.Main, which
    // lives in this artifact. It already arrives through the Flutter embedding;
    // declared so the bridge never depends on that by accident.
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.10.2")

    androidTestUtil("androidx.test:orchestrator:1.5.1")

    // Android unit tests on the JVM (tool/test_android, D-67). The SDK levels
    // they run on are in src/test/resources/robolectric.properties.
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.robolectric:robolectric:4.17")
    testImplementation("androidx.test:core:1.7.0")
}
