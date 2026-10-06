# System Architecture & Technical Knowledge Base
**Project: App to Clone (AppMultiplicator)**  
*Enterprise Multi-Instance Virtualization & Standalone Cloned APK Framework for Android*

---

## 📖 Document Purpose for AI Models & Engineers
This document is the definitive, comprehensive architectural specification for the **App to Clone** codebase. Any AI model (Gemini, Claude, GPT, DeepSeek, etc.) or software engineer tasked with debugging, extending, or refactoring this repository must read this file first. It contains byte-level, process-level, and bridge-level details of how the entire virtualization system functions.

---

## 1. High-Level System Overview

### Core Objective
The application enables users to create and run **multiple independent, isolated instances (clones)** of installed Android applications (e.g., WhatsApp, Facebook, Telegram, PayPal, Instagram, Games, etc.) on a single device without requiring root access (`su`).

### Dual Operating Modes
The system implements **two complementary virtualization paradigms**:

```
                       ┌────────────────────────────────────────────────────────┐
                       │                   App to Clone UI                      │
                       │             (Flutter 3.22+ Material 3)                 │
                       └───────────────────────────┬────────────────────────────┘
                                                   │
                               MethodChannel & EventChannel Bridge
                                                   │
                       ┌───────────────────────────▼────────────────────────────┐
                       │         Native Android Engine (CloneAppPlugin)         │
                       └───────────────┬────────────────────────┬───────────────┘
                                       │                        │
                   Mode A: Standalone Mutated APK   Mode B: In-Process Sandbox
                                       │                        │
       ┌───────────────────────────────▼────────┐   ┌───────────▼────────────────────────┐
       │ - AXML Binary Manifest Mutation       │   │ - 25 Pre-declared Worker Stubs     │
       │ - Split APK Merging (ABIs & Drawables)│   │   (:worker_01 .. :worker_25)       │
       │ - Pure Java X.509 v3 Key Generation   │   │ - Isolated ContainerStorageContext │
       │ - Pure 16KB / 4-Byte Zip Alignment    │   │ - IsolatedSharedPreferences Disk   │
       │ - Resigned with Google apksig v1/v2/v3│   │ - Dynamic TaskDescription Badging  │
       │ - 100% Linux UID & Process Isolation  │   │ - Chromium WebView Storage Suffix  │
       └────────────────────────────────────────┘   └────────────────────────────────────┘
```

| Feature / Metric | Mode A: Standalone Mutated Clone (`standalone`) | Mode B: Instant Virtual Sandbox (`sandbox`) |
| :--- | :--- | :--- |
| **Linux UID** | **Unique UID** (Assigned by Android OS Package Manager) | Shared Host UID (Runs under host app process tree) |
| **Process Affinity** | Independent process (`targetPackage.cXX`) | Pre-allocated isolated process (`:worker_01` to `:worker_25`) |
| **Installation** | Prompted via native Android `PackageInstaller` | Instant execution (zero user confirmation needed) |
| **Session Bleed Risk** | **0% (Impossible)** — Kernel-level sandbox isolation | Controlled via `ContainerStorageContext` & `IsolatedSharedPreferences` |
| **Native C++ Code** | Runs 100% natively from merged APK splits | Loads in host process via classloader and container context |
| **App Menu / Desktop** | Appears natively in Android App Drawer & Home Screen | Pinned via `ShortcutManagerCompat` shortcut |

---

## 2. Technology Stack & Environment Requirements

- **Frontend / Framework**: Flutter `^3.22.0` (Tested on Flutter `3.41.6`, Dart `3.11.4`)
- **UI Architecture**: Material 3 Design System, Riverpod `^3.3.2` (`AsyncNotifier`, `NotifierProvider`)
- **Android Target**:
  - `compileSdk`: 34 (Android 14)
  - `targetSdk`: 33 (Android 13)
  - `minSdk`: 26 (Android 8.0 Oreo)
- **Kotlin**: 1.9.23 / 2.0.21, JVM Target 17
- **Gradle**: 8.14 (Gradle Wrapper with JVM 17)
- **Native Android Dependencies**:
  - `androidx.core:core-ktx:1.12.0`
  - `com.android.tools.build:apksig:8.2.2` (Google Official APK Signer library for v1, v2, v3 schemes)

---

## 3. Directory Layout & File Responsibility Map

```
App to Clone/
├── android/
│   ├── app/
│   │   ├── build.gradle.kts                     # Android build config, compileSdk 34, apksig dependency
│   │   └── src/main/
│   │       ├── AndroidManifest.xml              # Declares FileProvider, queries, & 25-worker stub matrix
│   │       ├── kotlin/com/virtual/
│   │       │   ├── clone_app/
│   │       │   │   └── CloneAppPlugin.kt        # Primary MethodChannel/EventChannel native bridge
│   │       │   ├── clone_app_flutter/
│   │       │   │   └── MainActivity.kt          # Host FlutterActivity entrypoint
│   │       │   ├── engine/
│   │       │   │   ├── apk/
│   │       │   │   │   └── StandaloneApkGenerator.kt # APK unpacker, AXML mutator, split merger, 16KB aligner, signer
│   │       │   │   ├── identity/
│   │       │   │   │   └── DeviceIdentityProfile.kt  # Hardware spoofing (Samsung S24, Pixel 8, Build reflection)
│   │       │   │   └── signature/
│   │       │   │       ├── CloneKeyGenerator.kt      # Pure ASN.1/DER X.509 v3 cert & RSA-2048 PKCS12 generator
│   │       │   │       └── OriginalSignatureProvider.kt # Extracts authentic developer signatures to assets/orig_cert.bin
│   │       │   ├── fs/
│   │       │   │   ├── ContainerStorageContext.kt    # ContextWrapper redirecting files, DBs, and cache
│   │       │   │   └── IsolatedSharedPreferences.kt  # Disk-based SharedPreferences bypassing ContextImpl static cache
│   │       │   ├── routing/
│   │       │   │   └── ContainerStubRegistry.kt      # Declares 25 worker activities, services, & native hub view
│   │       │   └── ui/
│   │       │       └── ShortcutHelper.kt             # Badged launcher icon generator & desktop pinning
│   │       └── res/xml/
│   │           ├── file_paths.xml               # FileProvider paths for APK staging and PackageInstaller
│   │           └── network_security_config.xml  # Cleartext policy & local development configuration
├── lib/
│   ├── clone_app.dart                           # Flutter Dart plugin bridge API for native calls
│   ├── main.dart                                # Flutter App Entrypoint, ProviderScope, ThemeMode setup
│   ├── models/
│   │   ├── app_info.dart                        # Installed app metadata (packageName, appName, icon, etc.)
│   │   ├── clone_info.dart                      # Created clone metadata model (id, packageName, mode, etc.)
│   │   └── device_preset.dart                   # Device presets (S24 Ultra, Pixel 8 Pro, random Android ID)
│   ├── providers/
│   │   └── clone_provider.dart                  # Riverpod state management for clones, installed apps, themes
│   └── ui/
│       ├── screens/
│       │   ├── animated_splash_screen.dart      # Luxury animated launch screen
│       │   ├── app_list_screen.dart             # Searchable catalog of device installed apps
│       │   ├── clone_manager_page.dart          # Glassmorphic manager page with clone cards
│       │   ├── clones_inventory_screen.dart     # Responsive grid/list view of all created clones
│       │   └── home_shell_screen.dart           # Unified home screen tabbed interface
│       ├── sheets/
│       │   └── clone_setup_sheet.dart           # Clone creation bottom sheet (1-25 count, device preset, etc.)
│       └── widgets/
│           ├── clone_app_icon.dart              # Base64 image icon rendering with fallback
│           └── clone_progress_dialog.dart       # 5-stage stepper progress dialog (Extraction -> Install)
├── test/
│   └── clone_app_test.dart                      # Automated unit tests mocking MethodChannel communication
└── pubspec.yaml                                 # Flutter dependencies and asset registrations
```

---

## 4. Deep-Dive: Standalone Mutated Clone Pipeline (`StandaloneApkGenerator.kt`)

Mode A transforms any existing installed Android app into a completely distinct, standalone Android application that can be installed directly onto the device.

```
       Installed App + Splits
                 │
       [1. Source Discovery] ── Locates base.apk + all splitSourceDirs (config.arm64_v8a, config.xxhdpi)
                 │
       [2. Signature Extraction] ── Extracts authentic developer certificates -> orig_cert.bin
                 │
       [3. DEX Class Scan] ── Catalogs all compiled class names to prevent class corruption
                 │
       [4. AXML Binary Mutation] ── Mutates StringPool in AndroidManifest.xml (package, authorities, disable splits)
                 │
       [5. Split APK Merging] ── Merges all split APK files (native .so libs, assets, drawables) into one fat APK
                 │
       [6. Custom 16KB Zip Alignment] ── Resources 4-byte aligned, .so libs 16384-byte aligned, STORED vs DEFLATED
                 │
       [7. Cryptographic Resigning] ── Pure Java RSA-2048 / X.509 v3 + apksig v1, v2, v3
                 │
       [8. Installation Dispatch] ── Android PackageInstaller prompt via FileProvider
```

### 4.1. Source APK & Split APK Discovery
Modern Android apps distributed through Google Play are delivered as **Android App Bundles (AAB)** and installed as split APKs (`base.apk`, `split_config.arm64_v8a.apk`, `split_config.xxhdpi.apk`).
- `findSourceApks()` queries `ApplicationInfo.sourceDir` for the primary base APK and `ApplicationInfo.splitSourceDirs` for all ABI and resource splits.
- If splits are ignored, the cloned app will crash with `UnsatisfiedLinkError` (missing native `.so` C++ libraries) or resource not found exceptions. The generator merges all splits.

### 4.2. DEX Class Scanning
Before rewriting the `AndroidManifest.xml`, `extractDexClassNames()` opens `base.apk` and all split APKs, reads all `.dex` files (`classes.dex`, `classes2.dex`, etc.), and uses regex patterns (`Lcom/pkg/Class;`) to build a HashSet of all compiled Java/Kotlin class names.
- **Why this is critical**: If a class named `com.target.MainActivity` is blindly string-replaced with `com.target.c01.MainActivity`, Android's `PathClassLoader` will throw `ClassNotFoundException` at launch because the compiled bytecode in the DEX file remains in the package namespace `com.target.MainActivity`.

### 4.3. Binary AndroidManifest.xml (AXML) Mutation
Android manifests are compiled into binary AXML format (`0x00080003` magic header). The mutator operates directly on the binary `RES_STRING_POOL_TYPE` (`0x001C0001`):
1. **Encoding Detection**: Checks `flags & 0x0100` to distinguish UTF-8 from UTF-16LE.
2. **String Replacement**:
   - `package`: Mutates `com.example.app` -> `com.example.app.c01`.
   - `authorities`: Mutates `com.example.app.provider` -> `com.example.app.c01.provider`. This prevents `INSTALL_FAILED_CONFLICTING_PROVIDER`, which prevents installing two apps sharing the same `ContentProvider` authority.
   - `com.android.vending.splits.required`: Mutated to `com.android.vending.splits.disabled` so the OS does not reject the merged APK expecting Google Play splits.
   - Strips `base__abi` and `base__density` split flags.
   - Preserves all compiled class names identified during the DEX scan.
3. **StringPool Rebuilding**: Recomputes all string offsets, pads the string data block to a 4-byte word boundary, calculates the chunk size delta, updates the master file size header, and preserves all downstream chunks (`RES_XML_RESOURCE_MAP_TYPE`, `RES_XML_START_NAMESPACE_TYPE`, `RES_XML_START_ELEMENT_TYPE`).

### 4.4. Split Merging & Clean Resigning
The repackaging engine:
- Strips any existing `META-INF/*.SF`, `META-INF/*.RSA`, `META-INF/*.MF`, and signature blocks.
- Merges all native libraries (`lib/arm64-v8a/*.so`, `lib/armeabi-v7a/*.so`, `lib/x86_64/*.so`) from split APKs.
- Injects `assets/orig_cert.bin` (serialized authentic developer certificate history).
- Injects `assets/clone_identity.json` (virtual hardware identity profile).

### 4.5. Custom 16KB Zip Alignment (`ApkZipWriter`)
Android 15 introduces support for 16KB memory page sizes. Apps with native libraries that are not properly aligned to 16KB boundaries will crash with memory map errors.
- `ApkZipWriter` writes zip entries with precise alignment:
  - `resources.arsc`: `ZipEntry.STORED` (uncompressed), **4-byte** word aligned.
  - `lib/**/*.so`: `ZipEntry.STORED` (uncompressed), **16384-byte (16KB)** page aligned for direct kernel `mmap()`.
  - All other files: `ZipEntry.DEFLATED` (compression level DEFAULT, raw deflate).
- Alignment is achieved by calculating the exact byte offset of the data payload and injecting padding bytes into the **Extra Field** of the Zip Local File Header (LFH):
  $$\text{Extra Padding} = (\text{alignment} - ((\text{curOffset} + 30 + \text{nameLen}) \pmod{\text{alignment}})) \pmod{\text{alignment}}$$

### 4.6. Cryptographic Resigning (`CloneKeyGenerator.kt` & `apksig`)
Every clone gets a unique signing identity:
- **RSA-2048 Keypair**: Generated using `KeyPairGenerator.getInstance("RSA")`.
- **Pure Java Self-Signed X.509 v3 Certificate**: Hand-crafted via manual DER / ASN.1 binary encoding without external dependencies (no BouncyCastle). Valid for 20 years with `SHA256withRSA` signature.
  - *Critical Bug Fix Documented*: The validity is kept at 20 years to ensure `notAfter` remains before year 2050 (e.g., 2026 -> 2046). Per RFC 5280, UTCTime format (`yyMMddHHmmss'Z'`) specifies that years `00-49` represent 2000-2049, while `50-99` represent 1950-1999. A 25-year validity (2051) parses as 1951, causing Android's certificate parser to declare the certificate expired!
- **Keystore Persistence**: Stored in a PKCS12 keystore at `filesDir/keystores/clone_<id>.p12`.
- **Signer Execution**: Google's official `com.android.apksig.ApkSigner` signs the APK with v1 (JAR signing), v2 (APK Signature Scheme v2), and v3 (APK Signature Scheme v3) simultaneously.

---

## 5. Deep-Dive: Virtual Sandbox & Stub Routing Matrix (`ContainerStubRegistry.kt`)

Mode B runs multiple instances inside the host app using pre-declared stub activities and Linux multi-processing.

### 5.1. 25-Worker Process Matrix
`AndroidManifest.xml` pre-declares 25 isolated worker processes (`:worker_01` to `:worker_25`). Each worker has:
- Standard launch activity: `com.virtual.routing.ContainerStubActivity_P01` .. `P25`
- SingleTask launch activity: `com.virtual.routing.ContainerStubActivity_SingleTask_P01` .. `P25`
- Dedicated background service: `com.virtual.routing.ContainerStubService_P01` .. `P25`
- Distinct `android:taskAffinity="com.virtual.host.slot_XX"`: Allows multiple clones to show up as separate distinct cards in the Android OS Recents App Switcher.
- `android:documentLaunchMode="always"`: Enforces new window creation.

### 5.2. Storage Isolation (`ContainerStorageContext.kt`)
A custom `ContextWrapper` redirects all app storage calls to an isolated directory:
- Sandboxed root: `/data/user/0/<host_pkg>/files/clones/<profile_id>/`
- `filesDir` -> `.../files`
- `cacheDir` -> `.../cache`
- `databasesDir` -> `.../databases` (SQLite Write-Ahead-Logging enabled)
- `sharedPrefsDir` -> `.../shared_prefs`

### 5.3. Disk-Based SharedPreferences (`IsolatedSharedPreferences.kt`)
Android's internal `ContextImpl` caches `SharedPreferences` instances in a static global map `sSharedPrefsCache`. In multi-instance or sandboxed apps, this causes session bleed where Clone #2 reads Clone #1's cached in-memory token.
- `IsolatedSharedPreferences` bypasses `ContextImpl` completely.
- Uses file-backed locking with `ReentrantReadWriteLock`.
- Saves values to atomic temporary files (`.tmp`) before renaming.
- Serializes types explicitly (`S:string`, `I:int`, `L:long`, `F:float`, `B:bool`, `T:set`).

### 5.4. Chromium WebView Isolation
In `BaseContainerStubActivity.onCreate()`:
```kotlin
if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
    WebView.setDataDirectorySuffix("clone_$profileId")
}
```
This forces Chromium/WebView to create dedicated cookie jars, LocalStorage, IndexedDB, and cache partitions per clone instance, eliminating shared logins in web-based authenticators.

---

## 6. Device Identity & Hardware Spoofing (`DeviceIdentityProfile.kt`)

Cloned applications can be fingerprinted by anti-fraud or telemetry SDKs (e.g., AppsFlyer, Adjust, SafetyNet/Play Integrity). The system virtualizes device identity:

### Supported Flagship Hardware Presets
1. **Samsung Galaxy S24 Ultra**: Model `SM-S928B`, Board `e3q`, Hardware `qcom`
2. **Google Pixel 8 Pro**: Model `Pixel 8 Pro`, Board `husky`, Hardware `zuma`
3. **Xiaomi 14 Pro**: Model `23116PN5BC`, Board `shennong`, Hardware `qcom`
4. **OnePlus 12**: Model `CPH2581`, Board `kalama`, Hardware `qcom`

### Spoofing Mechanics
- **Runtime Reflection**: `DeviceIdentityProfile.applyToRuntime()` accesses `android.os.Build` fields via reflection, strips the `Modifier.FINAL` flag using `accessFlags`, and overrides:
  - `MANUFACTURER`, `BRAND`, `MODEL`, `DEVICE`, `PRODUCT`, `BOARD`, `HARDWARE`, `FINGERPRINT`
- **Synthetic Android ID**: Generates a cryptographically random 16-hex-character ID (`DevicePreset.generateRandomAndroidId()`).
- **Synthetic Advertising ID (GAID)**: Generates a random RFC 4122 UUID v4.

---

## 7. IPC & MethodChannel Contract

Communication between Flutter and Android Native is conducted over two `MethodChannel`s and one `EventChannel`:

### Channel Identifiers
- Methods: `com.virtual.clone_app/methods`
- Installed Apps: `com.virtual.clone_app/apps`
- Progress: `com.virtual.clone_app/progress`

### Native Method Signatures

| Method | Arguments | Returns | Description |
| :--- | :--- | :--- | :--- |
| `createClone` | `packageName: String`<br>`displayName: String?`<br>`isSingleTask: Boolean`<br>`mode: String` ('standalone'/'sandbox')<br>`devicePreset: String?`<br>`androidId: String?` | `Int` (assigned clone ID, 1-25) | Generates clone profile, mutates/prepares APK or sandbox, saves to registry. |
| `launchClone` | `cloneId: Int`<br>`isSingleTask: Boolean` | `void` | Launches installed package or prompts installer or launches stub activity. |
| `listClones` | *None* | `List<Map<String, Any?>>` | Returns all registered clones and their installation status. |
| `deleteClone` | `cloneId: Int` | `void` | Deletes clone directory, removes registry record, updates shortcuts. |
| `listInstalledApps`| *None* | `List<Map<String, Any?>>` | Queries PackageManager for installed apps, icons, and flags. |
| `getAppIcon` | `packageName: String` | `String?` (Base64 PNG) | Fetches app icon asynchronously. |
| `pinToHomeScreen` | `cloneId: Int` | `Boolean` | Creates Android launcher desktop pinned shortcut with cyan badge. |
| `installStandaloneApk` | `cloneId: Int` | `Boolean` | Prompts native OS PackageInstaller to install mutated APK. |
| `exportStandaloneApk` | `cloneId: Int` | `String?` (file path) | Copies signed clone APK to public `/sdcard/Download/ClonedAPKs/`. |
| `openAppSettings` | `cloneId: Int`, `packageName: String` | `void` | Opens Android OS system settings page for the target package. |

### EventChannel Progress Stream
Streams real-time events formatted as:
`"{stageIndex}:{stageMessage}"`
- Stage 0: Extraction (`Extracting target base APK...`)
- Stage 1: Manifest Rewriting (`Mutating binary AndroidManifest...`)
- Stage 2: APK Signing (`Applying profile & signing APK...`)
- Stage 3: PackageInstaller Prompt (`Dispatching PackageInstaller prompt...`)
- Stage 4: Finished (`Standalone clone generated!`)

---

## 8. Desktop Pinning & Launcher Shortcuts (`ShortcutHelper.kt`)

Users can launch cloned apps directly from their device's home screen / desktop without opening the host app:
1. **Badged Icon Generation**: `createBadgedIconBitmap()` draws the original app icon (192x192 px) and superimposes a high-contrast Neon Cyan circular badge on the bottom right containing the clone identifier (`C-01`, `C-02`, etc.).
2. **Pinned Shortcuts**: Calls `ShortcutManagerCompat.requestPinShortcut()` with an explicit Intent targeting the assigned stub activity and data URI `clone://instance/<id>`.
3. **Dynamic Launcher Shortcuts**: Calls `ShortcutManagerCompat.setDynamicShortcuts()` so that long-pressing the host app icon in Android's launcher displays the 4 most recent clones for 1-tap launching.

---

## 9. Common Bugs, Pitfalls & Solved Gotchas

### Gotcha 1: `INSTALL_FAILED_CONFLICTING_PROVIDER`
- **Symptom**: Android `PackageInstaller` fails with "App not installed as package conflicts with an existing package."
- **Root Cause**: Two different packages on Android cannot declare the same `ContentProvider` authority (e.g. `androidx.core.content.FileProvider`).
- **Solution**: `StandaloneApkGenerator.mutateBinaryManifest` scans the StringPool for all strings beginning with `$targetPackage.` and renames them to `$newPackage.`, ensuring all authorities are uniquely namespaced.

### Gotcha 2: `INSTALL_PARSE_FAILED_UNEXPECTED_EXCEPTION` or Corrupted AXML
- **Symptom**: Android PackageInstaller aborts with parse error immediately after tapping Install.
- **Root Cause**: In AXML, UTF-8 strings have a 1-2 byte character length header AND a 1-2 byte byte-length header, followed by null termination. If string pool offsets or 4-byte padding alignments are miscalculated, the binary chunk offsets drift.
- **Solution**: The engine strictly enforces AXML specification rules:
  - String block padded with `0x00` until `size % 4 == 0`.
  - Header delta (`newChunkSize - originalChunkSize`) is added to total file size and `stylesStart`.
  - UTF-8 byte lengths are masked with `0x7F`.

### Gotcha 3: `java.lang.ClassNotFoundException` on Startup
- **Symptom**: The cloned app installs, but crashes instantly when launched.
- **Root Cause**: Manifest mutator replaced class references (`com.target.SplashActivity`) with the new package name (`com.target.c01.SplashActivity`), but DEX bytecode was not renamed.
- **Solution**: `extractDexClassNames()` catalogs compiled classes and preserves them intact during StringPool rewriting.

### Gotcha 4: Missing Native C++ Libraries (`UnsatisfiedLinkError`)
- **Symptom**: Cloned app crashes when initializing C++ libraries (e.g., Flutter engine, React Native, SQLCipher, Unreal Engine).
- **Root Cause**: Device used split APKs; `base.apk` only contains DEX and XML, while `.so` files resided in `split_config.arm64_v8a.apk`.
- **Solution**: The generator locates all split APKs via `ApplicationInfo.splitSourceDirs` and merges all files under `lib/` into the output APK.

### Gotcha 5: Unaligned Shared Libraries on Android 15 (16KB Pages)
- **Symptom**: App crashes on Android 15 or 16KB-kernel emulators with memory mapping exceptions.
- **Root Cause**: `.so` files inside the APK must be uncompressed (`STORED`) and aligned to 16384 bytes (16KB) from the start of the file.
- **Solution**: `ApkZipWriter` aligns native `.so` entries to 16KB boundaries and `resources.arsc` to 4-byte boundaries using zip local file header extra fields.

### Gotcha 6: X.509 Certificate Year 2050 UTCTime Bug
- **Symptom**: `INSTALL_PARSE_FAILED_NO_CERTIFICATES` or certificate validation errors on Android 14+.
- **Root Cause**: 25-year validity generated a certificate expiring in 2051. Per RFC 5280, UTCTime encodes 2 digits for year (`yy`). `51` is parsed as 1951, which is in the past!
- **Solution**: Validity is capped at 20 years (expiring ~2046), safe within RFC 5280 UTCTime range.

---

## 10. How to Build, Run & Test

### Run Unit Tests
```bash
flutter test test/clone_app_test.dart
```

### Run Flutter Application
```bash
flutter run
```

### Build Android Host APK
```bash
cd android
./gradlew assembleDebug
```
The output APK will be generated at:
`android/app/build/outputs/apk/debug/app-debug.apk`

### Logcat Debugging Filters
When observing virtualization operations in Android Logcat:
```bash
adb logcat -s StandaloneApkGen:V CloneAppPlugin:V DeviceIdentityProfile:V CloneKeyGen:V ShortcutHelper:V
```

---

## 11. Quick Checklist for Future AI Models Solving Specific Issues

- **If an app fails to install**:
  1. Check logcat with `adb logcat | grep -i -E "PackageManager|PackageInstaller|InstallFailed"`.
  2. Verify if `isApkAligned()` returns true.
  3. Verify provider authorities in `mutateBinaryManifest`.
- **If an app crashes immediately on launch**:
  1. Check logcat for `ClassNotFoundException` -> verify if class was excluded from package mutation.
  2. Check logcat for `UnsatisfiedLinkError` -> verify if split APK native libraries were merged.
- **If an app detects that it is cloned**:
  1. Verify hardware spoofing profile in `DeviceIdentityProfile.kt`.
  2. Check if the app reads `orig_cert.bin` via `OriginalSignatureProvider.kt`.
- **If accounts/sessions bleed across clones**:
  1. Verify mode: use `mode: 'standalone'` for 100% kernel UID separation.
  2. If using `sandbox`, verify `WebView.setDataDirectorySuffix` and `IsolatedSharedPreferences`.
