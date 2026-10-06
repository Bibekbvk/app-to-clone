# AppMultiplicator: Flutter/Dart Virtual App Cloner & Sandbox Framework

[![Flutter](https://img.shields.io/badge/Flutter-3.41+-blue.svg)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.11+-teal.svg)](https://dart.dev)
[![Android](https://img.shields.io/badge/Android-SDK%2033+-green.svg)](https://developer.android.com)
[![Kotlin](https://img.shields.io/badge/Kotlin-1.9+-purple.svg)](https://kotlinlang.org)
[![Material 3](https://img.shields.io/badge/Design-Material%203-indigo.svg)](https://m3.material.io)

An enterprise-grade Android application virtualization and multi-instance sandbox framework. Built with a high-performance **Flutter Material 3 UI**, **Riverpod State Engine**, and a native **Kotlin Virtual Runtime Engine** connected via bidirectional Method and Event Channels.

> 📘 **AI Models & Engineers**: For a complete technical breakdown and architecture reference, see [AI_SYSTEM_ARCHITECTURE.md](file:///c:/Users/Asus/Desktop/vibe/App%20to%20Clone/AI_SYSTEM_ARCHITECTURE.md). For current progress and the implementation checklist, see [PROGRESS.md](file:///c:/Users/Asus/Desktop/vibe/App%20to%20Clone/PROGRESS.md).

---

## 🚀 Key Features

- **Multi-Instance Virtualization Engine**:
  - Pre-allocated 25-worker isolated stub matrix (`:worker_01` to `:worker_25`).
  - Standard multi-task and single-task launch mode support (`ContainerStubActivity_P*` and `ContainerStubActivity_SingleTask_P*`).
  - Dynamic `TaskDescription` badging, isolated WebView storage suffixes, and individual process affinity.
  - Software-isolated BKS Keystore vault and signature bypass hooks.
- **Modern Material 3 Interface**:
  - **Clone Manager Page**: Animated entry cards, gradient app bar, glassmorphism cards, dark mode toggle, and one-tap clone creation dialog.
  - **App Catalog**: Live searchable list of installed packages, app icon extraction (Base64 PNG), and category filter chips (*All Apps*, *Social & Messaging*, *Custom Cloned*).
  - **Batch Clone Setup Modal**: Interactive slider (1 to 25 instances), live badge format preview (`App [C-01]`), Shizuku silent installer toggle, and storage isolation switches.
  - **Real-Time Progress Overlay**: Circular stage stepper listening to the native `EventChannel` across 5 stages (*Extraction* → *Split Merging* → *Manifest Rewriting* → *Signing* → *Installation*).
  - **Instance Inventory**: Responsive grid view of all deployed clones with quick actions (*Open App*, *App Info / Storage*, *Uninstall*).
- **Persistent State**:
  - Fast offline cache with `SharedPreferences` persisting clone registries and theme preferences across app restarts.
  - Full unit test coverage mocking binary messenger channels.

---

## 🏗️ Architecture Overview

```
 ┌────────────────────────────────────────────────────────┐
 │            Flutter Frontend (Material 3)               │
 │  CloneManagerPage  │ AppListScreen │ InventoryScreen   │
 │  BatchSetupSheet   │ ProgressDialog│ Riverpod Providers│
 └───────────────────────────┬────────────────────────────┘
                             │
            MethodChannel & EventChannel
    - com.virtual.clone_app/methods
    - com.virtual.clone_app/apps
    - com.virtual.clone_app/progress
                             │
 ┌───────────────────────────▼────────────────────────────┐
 │         CloneAppPlugin (Android Native Bridge)         │
 │  createClone() │ launchClone() │ listClones() │ delete │
 └───────────────────────────┬────────────────────────────┘
                             │
 ┌───────────────────────────▼────────────────────────────┐
 │       VirtualRuntimeEngine & ContainerStubRegistry     │
 │  25 Pre-Declared Worker Stubs (:worker_01..:worker_25)  │
 │  Isolated Storage (/data/user/0/<host>/files/clones)   │
 └────────────────────────────────────────────────────────┘
```

---

## 🛠️ Project Structure

```
├── lib/
│   ├── clone_app.dart                    # Core Flutter plugin bridge
│   ├── main.dart                         # Material 3 entrypoint with ProviderScope & themes
│   ├── models/
│   │   ├── app_info.dart                 # Installed app metadata & icon model
│   │   └── clone_info.dart               # Cloned instance data model
│   ├── providers/
│   │   └── clone_provider.dart           # Riverpod AsyncNotifier, theme, and stream providers
│   └── ui/
│       ├── navigation/
│       │   └── home_shell_screen.dart    # Bottom NavigationBar shell
│       ├── screens/
│       │   ├── app_list_screen.dart      # Installed apps with search & FilterChips
│       │   ├── clone_manager_page.dart   # Glassmorphism manager with animated cards
│       │   └── clones_inventory_screen.dart # Grid view of all created clones
│       ├── sheets/
│       │   └── clone_setup_sheet.dart    # 1-25 instance counter slider & preview
│       └── widgets/
│           └── clone_progress_dialog.dart# 5-stage circular stepper progress dialog
├── android/
│   └── src/main/kotlin/com/virtual/clone_app/
│       └── CloneAppPlugin.kt             # Native Kotlin MethodChannel/EventChannel bridge
├── example/
│   └── main.dart                         # Sample standalone Dart implementation
├── test/
│   └── clone_app_test.dart               # Unit tests verifying channel methods
└── pubspec.yaml                          # Flutter module configuration
```

---

## ⚙️ Setup & Requirements

### 1. Prerequisites
- **Flutter SDK**: `3.22.0+` (Tested on Flutter 3.41.6, Dart 3.11.4)
- **Android SDK**: `API Level 34` (Compile SDK: 34, Min SDK: 26, Target SDK: 33)
- **Kotlin**: `1.8.0+` (Configured with Kotlin 1.9.23 / 2.0.21)
- **Gradle**: `8.0+` (Gradle 8.14)

### 2. Dependency Installation
Inside the Flutter project directory:
```bash
flutter pub get
```

### 3. Gradle Host Integration
In the host Android project's `settings.gradle.kts`:
```kotlin
// Apply Flutter Module
apply(from = File(settingsDir, "../clone_app_flutter/.android/include_flutter.groovy"))
include(":clone_app_flutter")
project(":clone_app_flutter").projectDir = File(settingsDir, "../clone_app_flutter/.android/Flutter")
```

In `app/build.gradle.kts`:
```kotlin
dependencies {
    implementation(project(":clone_app_flutter"))
}
```

In `app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />

<application
    android:hasCode="true"
    ... >
    <provider
        android:name="androidx.core.content.FileProvider"
        android:authorities="${applicationId}.fileprovider"
        android:exported="false"
        android:grantUriPermissions="true">
        <meta-data
            android:name="android.support.FILE_PROVIDER_PATHS"
            android:resource="@xml/file_paths" />
    </provider>
</application>
```

---

## 🏃 Running the Application

### Option A: Run Flutter UI directly
To launch the Flutter interface on an connected Android device, emulator, or desktop:
```bash
flutter run
```

### Option B: Build Android Host App with Embedded Module
Inside the Android project (`clone app/`):
```bash
./gradlew clean assembleDebug
```

---

## 🧪 Testing

### Automated Unit Tests
To run unit tests verifying channel communication:
```bash
flutter test test/clone_app_test.dart
```

### Manual Verification Checklist
1. **Create Clone**:
   - Open **Clone Manager** or tap **Clone** on an app in **App Catalog**.
   - Set instance count to `2` and display name to `Work Space`.
   - Tap **Start Cloning**.
   - Verify the circular stage dialog steps through *Extraction* → *Installation*.
   - Verify clone base APK is saved to `/data/user/0/com.virtual.host/files/clones/1/base.apk`.
2. **Launch Clone**:
   - Tap **Launch** on Clone card `C-01`.
   - Ensure the app opens in a separate task in the Android Recents switcher with a badged title (`Work Space (C-01)`).
3. **Delete Clone**:
   - Tap the **Delete** icon on a card and confirm.
   - Verify the card disappears, sandbox files under `/files/clones/<id>` are deleted, and SharedPreferences is updated.

---

## ❓ Frequently Asked Questions (FAQ)

### Q: Why do I see `"Unable to find explicit activity class"` error?
**Cause**:
Android throws `android.content.ActivityNotFoundException: Unable to find explicit activity class {com.virtual.host/com.virtual.routing.ContainerStubActivity_P01}` when:
1. The activity class is not registered in the host `AndroidManifest.xml`.
2. The package name passed in `ComponentName(context.packageName, className)` differs from the build applicationId.
3. Obfuscation/R8 renamed the stub classes.

**Solution**:
- Ensure all 25 stubs (`ContainerStubActivity_P01` to `ContainerStubActivity_P25` and their `_SingleTask_` variants) are declared in `app/src/main/AndroidManifest.xml`.
- Keep them preserved in `proguard-rules.pro`:
  ```proguard
  -keep class com.virtual.routing.ContainerStubActivity_* { *; }
  -keep class com.virtual.routing.BaseContainerStubActivity { *; }
  ```
- Always resolve stub class names via `ContainerStubRegistry.getStubActivityClass(profileId, isSingleTask)`.

---

## 🔒 Identity Isolation & Zero Session Bleed

The framework guarantees 100% session independence across all cloned instances:

1. **Independent Linux UIDs & Sandboxes (Standalone Mode)**:
   - Each clone installs with a unique Linux UID (e.g. `u0_a150`, `u0_a151`) and its own private internal storage directory (`/data/user/0/<pkg>.cXX/`).
   - SQLite databases, caches, and SharedPreferences are completely physically separated at the Linux kernel level.

2. **Per-Clone ANDROID_ID & Hardware Fingerprints**:
   - **Android 8.0+ Scoped Android ID**: Since Android 8.0 (API 26), `Settings.Secure.ANDROID_ID` is scoped per application signing key. Because each clone is cryptographically signed with its own unique RSA-2048 keypair generated by `CloneKeyGenerator.kt`, the Android OS kernel naturally assigns a distinct `ANDROID_ID` to each clone!
   - **In-Process `sNameValueCache` Injection**: For sandboxed clones, `DeviceIdentityProfile.spoofSettingsSecure()` injects per-clone unique Android IDs directly into `Settings.Secure`, `Settings.System`, and `Settings.Global` in-memory caches, guaranteeing that server fingerprinting sees unique devices.
   - **Hardware Spoofing via Reflection**: Static properties in `android.os.Build` (`MANUFACTURER`, `BRAND`, `MODEL`, `DEVICE`, `PRODUCT`, `BOARD`, `HARDWARE`, `FINGERPRINT`, `SERIAL`, `DISPLAY`, `ID`, `USER`) are spoofed per flagship preset (Samsung S24 Ultra, Pixel 8 Pro, Xiaomi 14 Pro, OnePlus 12).

3. **ContentProvider & Permission Authority Conflict Prevention**:
   - In AXML binary manifests, all provider authorities (`androidx.core.content.FileProvider`, `FirebaseInitProvider`, custom authorities) and custom permission definitions are namespaced to the new package, preventing `INSTALL_FAILED_CONFLICTING_PROVIDER` and `INSTALL_FAILED_DUPLICATE_PERMISSION`.
   - Manifest StringPool length encoding properly handles 2-byte UTF-8 lengths (> 127 bytes) and 4-byte UTF-16 lengths to prevent corrupt installs.

4. **Independent Login Sessions**:
   - **Zero Profile Bleed**: Logging into Clone #1 does not reveal profiles in Clone #2.
   - **Independent Logout**: Logging out from one clone sends revocation only for that clone's unique token and device identity, leaving other clones active.

---

## 📄 License
MIT License. Developed for sandbox virtualization research and app cloning workflows.
