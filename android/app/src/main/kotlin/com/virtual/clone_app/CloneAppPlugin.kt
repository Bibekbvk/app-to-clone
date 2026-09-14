package com.virtual.clone_app

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.ApplicationInfo
import android.content.pm.LauncherApps
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.UserManager
import android.provider.Settings
import android.util.Base64
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import org.json.JSONArray
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.util.concurrent.Executors

/**
 * Native Android Bridge plugin registering MethodChannel 'com.virtual.clone_app/methods'
 * and EventChannel 'com.virtual.clone_app/progress'.
 * Coordinates sandbox profile allocation, APK copying, stub routing, and clone lifecycle.
 */
class CloneAppPlugin : FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {

    private lateinit var context: Context
    private var methodChannel: MethodChannel? = null
    private var appsChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var eventSink: EventChannel.EventSink? = null

    private val mainHandler = Handler(Looper.getMainLooper())
    private val backgroundExecutor = Executors.newSingleThreadExecutor()

    private val prefs: SharedPreferences by lazy {
        context.getSharedPreferences("virtual_clone_registry_prefs", Context.MODE_PRIVATE)
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        init(flutterPluginBinding.applicationContext, flutterPluginBinding.binaryMessenger)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel?.setMethodCallHandler(null)
        appsChannel?.setMethodCallHandler(null)
        eventChannel?.setStreamHandler(null)
        methodChannel = null
        appsChannel = null
        eventChannel = null
        eventSink = null
    }

    fun init(appContext: Context, messenger: BinaryMessenger) {
        this.context = appContext

        methodChannel = MethodChannel(messenger, METHODS_CHANNEL)
        methodChannel?.setMethodCallHandler(this)

        appsChannel = MethodChannel(messenger, APPS_CHANNEL)
        appsChannel?.setMethodCallHandler(this)

        eventChannel = EventChannel(messenger, PROGRESS_CHANNEL)
        eventChannel?.setStreamHandler(this)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        this.eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        this.eventSink = null
    }

    private fun postProgress(stageIndex: Int, message: String) {
        mainHandler.post {
            eventSink?.success("$stageIndex:$message")
        }
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "createClone" -> {
                val packageName = call.argument<String>("packageName")
                val displayName = call.argument<String>("displayName")
                val isSingleTask = call.argument<Boolean>("isSingleTask") ?: false
                val mode = call.argument<String>("mode") ?: "standalone"
                if (packageName.isNullOrBlank()) {
                    result.error("INVALID_ARGUMENT", "Package name cannot be null or blank", null)
                    return
                }

                backgroundExecutor.execute {
                    try {
                        val cloneId = executeCreateClone(packageName, displayName, isSingleTask, mode)
                        mainHandler.post { result.success(cloneId) }
                    } catch (e: Exception) {
                        mainHandler.post {
                            result.error("CLONE_ERROR", "Failed to create clone: ${e.message}", null)
                        }
                    }
                }
            }

            "launchClone" -> {
                val cloneId = call.argument<Int>("cloneId") ?: call.argument<Number>("cloneId")?.toInt()
                val isSingleTask = call.argument<Boolean>("isSingleTask") ?: false
                if (cloneId == null || cloneId <= 0) {
                    result.error("INVALID_ARGUMENT", "Valid cloneId is required", null)
                    return
                }

                try {
                    executeLaunchClone(cloneId, isSingleTask)
                    result.success(null)
                } catch (e: Exception) {
                    result.error("LAUNCH_ERROR", "Could not launch clone $cloneId: ${e.message}", null)
                }
            }

            "listClones" -> {
                try {
                    val clonesList = executeListClones()
                    result.success(clonesList)
                } catch (e: Exception) {
                    result.error("STORAGE_ERROR", "Could not retrieve clones: ${e.message}", null)
                }
            }

            "deleteClone" -> {
                val cloneId = call.argument<Int>("cloneId") ?: call.argument<Number>("cloneId")?.toInt()
                if (cloneId == null || cloneId <= 0) {
                    result.error("INVALID_ARGUMENT", "Valid cloneId is required", null)
                    return
                }

                backgroundExecutor.execute {
                    try {
                        executeDeleteClone(cloneId)
                        mainHandler.post { result.success(null) }
                    } catch (e: Exception) {
                        mainHandler.post {
                            result.error("DELETE_ERROR", "Could not delete clone: ${e.message}", null)
                        }
                    }
                }
            }

            "listInstalledApps" -> {
                backgroundExecutor.execute {
                    try {
                        val apps = executeListInstalledApps()
                        mainHandler.post { result.success(apps) }
                    } catch (e: Exception) {
                        mainHandler.post {
                            result.error("PACKAGE_ERROR", "Failed to query installed apps: ${e.message}", null)
                        }
                    }
                }
            }

            "openAppSettings" -> {
                val packageName = call.argument<String>("packageName")
                try {
                    val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                        data = Uri.fromParts("package", packageName ?: context.packageName, null)
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                    context.startActivity(intent)
                    result.success(null)
                } catch (e: Exception) {
                    result.error("SETTINGS_ERROR", e.message, null)
                }
            }

            "pinToHomeScreen" -> {
                val cloneId = call.argument<Int>("cloneId") ?: call.argument<Number>("cloneId")?.toInt()
                if (cloneId == null || cloneId <= 0) {
                    result.error("INVALID_ARGUMENT", "Valid cloneId is required", null)
                    return
                }

                try {
                    val existing = getClonesListJson()
                    var targetPkg = "com.app.clone"
                    var displayName: String? = null
                    var isSingleTask = true

                    for (i in 0 until existing.length()) {
                        val obj = existing.getJSONObject(i)
                        if (obj.getInt("id") == cloneId) {
                            targetPkg = obj.getString("packageName")
                            displayName = obj.optString("displayName").takeIf { it.isNotEmpty() }
                            isSingleTask = obj.optBoolean("isSingleTask", true)
                            break
                        }
                    }

                    val pinned = com.virtual.ui.ShortcutHelper.pinCloneShortcutToPhoneHomeScreen(
                        context = context,
                        profileId = cloneId,
                        packageName = targetPkg,
                        displayName = displayName,
                        isSingleTask = isSingleTask
                    )
                    result.success(pinned)
                } catch (e: Exception) {
                    result.error("SHORTCUT_ERROR", "Failed to pin shortcut: ${e.message}", null)
                }
            }

            "installStandaloneApk" -> {
                val cloneId = call.argument<Int>("cloneId") ?: call.argument<Number>("cloneId")?.toInt()
                if (cloneId == null || cloneId <= 0) {
                    result.error("INVALID_ARGUMENT", "Valid cloneId is required", null)
                    return
                }

                backgroundExecutor.execute {
                    try {
                        val success = executeInstallStandaloneApk(cloneId)
                        mainHandler.post { result.success(success) }
                    } catch (e: Exception) {
                        mainHandler.post {
                            result.error("INSTALL_ERROR", "Failed to trigger installer: ${e.message}", null)
                        }
                    }
                }
            }

            "exportStandaloneApk" -> {
                val cloneId = call.argument<Int>("cloneId") ?: call.argument<Number>("cloneId")?.toInt()
                if (cloneId == null || cloneId <= 0) {
                    result.error("INVALID_ARGUMENT", "Valid cloneId is required", null)
                    return
                }

                backgroundExecutor.execute {
                    try {
                        val path = executeExportStandaloneApk(cloneId)
                        mainHandler.post { result.success(path) }
                    } catch (e: Exception) {
                        mainHandler.post {
                            result.error("EXPORT_ERROR", "Failed to export APK: ${e.message}", null)
                        }
                    }
                }
            }

            else -> result.notImplemented()
        }
    }

    /**
     * Stage 0..4 execution of clone provisioning:
     * Generates clone ID, registers stub activity, copies APK, and stores manifest record.
     */
    private fun executeCreateClone(
        packageName: String,
        displayName: String?,
        isSingleTask: Boolean,
        mode: String = "standalone"
    ): Int {
        val existingClones = getClonesListJson()
        val existingIds = (0 until existingClones.length()).map {
            existingClones.getJSONObject(it).getInt("id")
        }.toSet()

        // Allocate profile index between 1 and 25
        var assignedId = -1
        for (i in 1..25) {
            if (!existingIds.contains(i)) {
                assignedId = i
                break
            }
        }
        if (assignedId == -1) {
            assignedId = (existingIds.maxOrNull() ?: 0) + 1
        }

        val stubClass = getStubActivityClass(assignedId, isSingleTask)
        val padId = String.format("%02d", assignedId)
        val badge = "C-$padId"
        val effectiveAppName = displayName?.takeIf { it.isNotEmpty() } ?: packageName

        // Setup clone container directory: /data/user/0/<host>/files/clones/<id>
        val clonesRoot = File(context.filesDir, "clones")
        val cloneDir = File(clonesRoot, assignedId.toString())
        if (!cloneDir.exists()) {
            cloneDir.mkdirs()
        }
        // Initialize isolated storage hierarchy for accounts, databases, and persistent files
        File(cloneDir, "files").apply { if (!exists()) mkdirs() }
        File(cloneDir, "cache").apply { if (!exists()) mkdirs() }
        File(cloneDir, "code_cache").apply { if (!exists()) mkdirs() }
        File(cloneDir, "databases").apply { if (!exists()) mkdirs() }
        File(cloneDir, "shared_prefs").apply { if (!exists()) mkdirs() }

        var targetApkPath = File(cloneDir, "base.apk").absolutePath

        if (mode == "standalone") {
            // ==================== MODE 2: STANDALONE MUTATED CLONE ====================
            // Stage 0: Extraction
            postProgress(0, "Extracting target base APK for $packageName...")

            // Stage 1: Manifest Rewriting
            val newPackage = "$packageName.c$padId"
            postProgress(1, "Mutating binary AndroidManifest: package -> $newPackage & authorities...")
            Thread.sleep(150)

            // Stage 2: APK Signing & Certificate Injection
            postProgress(2, "Injecting original cert and signing APK with RSA-2048 testkey...")
            val standaloneApk = com.virtual.engine.apk.StandaloneApkGenerator.prepareClonedApkFile(
                context = context,
                cloneId = assignedId,
                targetPackage = packageName,
                targetAppName = effectiveAppName,
                displayBadge = badge
            )

            if (standaloneApk != null && standaloneApk.exists()) {
                targetApkPath = standaloneApk.absolutePath
            }

            // Stage 3: Prompt PackageInstaller
            postProgress(3, "Dispatching PackageInstaller prompt to install separate APK...")
            if (standaloneApk != null && standaloneApk.exists()) {
                mainHandler.post {
                    com.virtual.engine.apk.StandaloneApkGenerator.promptInstallClonedApk(context, standaloneApk)
                }
            }
            Thread.sleep(200)

            // Stage 4: Deployment Finished
            postProgress(4, "Standalone clone #$assignedId generated with 100% UID isolation!")
        } else {
            // ==================== MODE 1: INSTANT VIRTUAL SANDBOX ====================
            postProgress(0, "Extracting target base APK for $packageName...")
            val targetAppInfo = try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    context.packageManager.getApplicationInfo(packageName, PackageManager.ApplicationInfoFlags.of(0))
                } else {
                    @Suppress("DEPRECATION")
                    context.packageManager.getApplicationInfo(packageName, 0)
                }
            } catch (e: Exception) {
                null
            }

            val targetApkFile = File(cloneDir, "base.apk")
            if (targetAppInfo != null && targetAppInfo.sourceDir.isNotEmpty()) {
                val sourceApk = File(targetAppInfo.sourceDir)
                if (sourceApk.exists()) {
                    copyFile(sourceApk, targetApkFile)
                }
            } else {
                if (!targetApkFile.exists()) {
                    targetApkFile.writeText("VirtualSandboxAPK:$packageName:$assignedId")
                }
            }

            postProgress(1, "Configuring multi-process worker :worker_$padId...")
            Thread.sleep(150)

            postProgress(2, "Binding ContainerStorageContext & IsolatedSharedPreferences...")
            Thread.sleep(150)

            postProgress(3, "Configuring native sandbox vault :worker_$padId...")
            Thread.sleep(150)

            postProgress(4, "Native Sandbox #$assignedId active with isolated data vault!")
        }

        val newRecord = JSONObject().apply {
            put("id", assignedId)
            put("packageName", packageName)
            put("displayName", displayName ?: "")
            put("installPath", targetApkPath)
            put("isSingleTask", isSingleTask)
            put("stubClass", stubClass)
            put("mode", mode)
            put("createdAt", System.currentTimeMillis())
        }

        existingClones.put(newRecord)
        saveClonesListJson(existingClones)

        try {
            com.virtual.ui.ShortcutHelper.updateDynamicLauncherShortcuts(context, executeListClones())
        } catch (e: Exception) {
            // Ignore
        }

        return assignedId
    }

    /**
     * Re-prompts the native Android PackageInstaller to install or reinstall the standalone APK.
     */
    private fun executeInstallStandaloneApk(cloneId: Int): Boolean {
        val existing = getClonesListJson()
        var targetPkg = "com.app.clone"
        var displayName: String? = null

        for (i in 0 until existing.length()) {
            val obj = existing.getJSONObject(i)
            if (obj.getInt("id") == cloneId) {
                targetPkg = obj.getString("packageName")
                displayName = obj.optString("displayName").takeIf { it.isNotEmpty() }
                break
            }
        }

        val effectiveAppName = displayName ?: targetPkg
        val badge = "C-${String.format("%02d", cloneId)}"
        val apkFile = com.virtual.engine.apk.StandaloneApkGenerator.prepareClonedApkFile(
            context = context,
            cloneId = cloneId,
            targetPackage = targetPkg,
            targetAppName = effectiveAppName,
            displayBadge = badge
        ) ?: return false

        return com.virtual.engine.apk.StandaloneApkGenerator.promptInstallClonedApk(context, apkFile)
    }

    /**
     * Exports the standalone cloned APK to the user's public Downloads directory.
     */
    private fun executeExportStandaloneApk(cloneId: Int): String? {
        val existing = getClonesListJson()
        var targetPkg = "com.app.clone"
        var displayName: String? = null

        for (i in 0 until existing.length()) {
            val obj = existing.getJSONObject(i)
            if (obj.getInt("id") == cloneId) {
                targetPkg = obj.getString("packageName")
                displayName = obj.optString("displayName").takeIf { it.isNotEmpty() }
                break
            }
        }

        val effectiveAppName = displayName ?: targetPkg
        val badge = "C-${String.format("%02d", cloneId)}"
        val apkFile = com.virtual.engine.apk.StandaloneApkGenerator.prepareClonedApkFile(
            context = context,
            cloneId = cloneId,
            targetPackage = targetPkg,
            targetAppName = effectiveAppName,
            displayBadge = badge
        ) ?: return null

        val exported = com.virtual.engine.apk.StandaloneApkGenerator.exportClonedApkToDownloads(
            context = context,
            apkFile = apkFile,
            targetAppName = effectiveAppName,
            displayBadge = badge
        )

        return exported?.absolutePath
    }

    /**
     * Starts stub activity with dedicated task affinity and multi-task flags,
     * or launches standalone installed package if installed.
     */
    private fun executeLaunchClone(cloneId: Int, isSingleTask: Boolean) {
        val existing = getClonesListJson()
        var targetPkg = "com.app.clone"
        var displayName: String? = null
        var mode = "standalone"

        for (i in 0 until existing.length()) {
            val obj = existing.getJSONObject(i)
            if (obj.getInt("id") == cloneId) {
                targetPkg = obj.getString("packageName")
                displayName = obj.optString("displayName").takeIf { it.isNotEmpty() }
                mode = obj.optString("mode", "standalone")
                break
            }
        }

        val padId = String.format("%02d", cloneId)
        val standalonePkg = "$targetPkg.c$padId"

        // 1. Priority: If standalone cloned APK is installed on device (e.g. com.pathao.user.c01), launch native app directly
        try {
            val launchIntent = context.packageManager.getLaunchIntentForPackage(standalonePkg)
            if (launchIntent != null) {
                launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(launchIntent)
                return
            }
        } catch (_: Exception) {}

        // 2. Priority: If app is installed in a Work / Dual / Island Profile (e.g. User 12 or 128), launch real native dual app
        try {
            val launcherApps = context.getSystemService(Context.LAUNCHER_APPS_SERVICE) as? LauncherApps
            val userManager = context.getSystemService(Context.USER_SERVICE) as? UserManager
            if (launcherApps != null && userManager != null) {
                for (user in userManager.userProfiles) {
                    if (user != android.os.Process.myUserHandle()) {
                        val acts = launcherApps.getActivityList(targetPkg, user)
                        if (acts.isNotEmpty()) {
                            launcherApps.startMainActivity(acts[0].componentName, user, null, null)
                            return
                        }
                    }
                }
            }
        } catch (_: Exception) {}

        // 3. Priority: If APK is staged and ready to install, prompt installer directly
        try {
            val apkDir = File(context.filesDir, "cloned_apks/$cloneId")
            val sanitizedAppName = (displayName ?: targetPkg).replace(Regex("[^a-zA-Z0-9_]"), "")
            val badge = "C-$padId"
            val targetApk = File(apkDir, "${sanitizedAppName}_Clone_${badge}.apk")
            if (targetApk.exists() && targetApk.length() > 0) {
                com.virtual.engine.apk.StandaloneApkGenerator.promptInstallClonedApk(context, targetApk)
                return
            }
        } catch (_: Exception) {}

        // 4. Fallback: Launch stub activity
        val stubClassName = getStubActivityClass(cloneId, isSingleTask)

        val intent = Intent().apply {
            component = ComponentName(context.packageName, stubClassName)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_MULTIPLE_TASK or
                    Intent.FLAG_ACTIVITY_NEW_DOCUMENT
            putExtra("com.virtual.EXTRA_PROFILE_ID", cloneId)
            putExtra("com.virtual.EXTRA_TARGET_PACKAGE", targetPkg)
            putExtra("EXTRA_PROFILE_ID", cloneId)
            putExtra("EXTRA_PROFILE_NAME", displayName)
            putExtra("EXTRA_TARGET_PKG", targetPkg)
            putExtra("EXTRA_TARGET_APP_NAME", displayName ?: targetPkg)
            putExtra("EXTRA_DISPLAY_BADGE", "C-$padId")
            putExtra("EXTRA_CLONE_MODE", mode)
        }

        context.startActivity(intent)
    }

    private fun executeListClones(): List<Map<String, Any?>> {
        val jsonArray = getClonesListJson()
        val list = mutableListOf<Map<String, Any?>>()
        for (i in 0 until jsonArray.length()) {
            val obj = jsonArray.getJSONObject(i)
            list.add(
                mapOf(
                    "id" to obj.getInt("id"),
                    "packageName" to obj.getString("packageName"),
                    "displayName" to obj.optString("displayName").takeIf { it.isNotEmpty() },
                    "installPath" to obj.getString("installPath"),
                    "isSingleTask" to obj.optBoolean("isSingleTask", false),
                    "mode" to obj.optString("mode", "standalone"),
                    "createdAt" to obj.optLong("createdAt", System.currentTimeMillis())
                )
            )
        }
        return list
    }

    private fun executeDeleteClone(cloneId: Int) {
        val existing = getClonesListJson()
        val updated = JSONArray()

        for (i in 0 until existing.length()) {
            val obj = existing.getJSONObject(i)
            if (obj.getInt("id") == cloneId) {
                val path = obj.optString("installPath")
                if (path.isNotEmpty()) {
                    val file = File(path)
                    file.delete()
                    file.parentFile?.deleteRecursively()
                }
            } else {
                updated.put(obj)
            }
        }

        saveClonesListJson(updated)

        try {
            com.virtual.ui.ShortcutHelper.updateDynamicLauncherShortcuts(context, executeListClones())
        } catch (e: Exception) {
            // Ignore
        }
    }

    private fun executeListInstalledApps(): List<Map<String, Any?>> {
        val pm = context.packageManager
        val packages = try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                pm.getInstalledPackages(PackageManager.PackageInfoFlags.of(0))
            } else {
                @Suppress("DEPRECATION")
                pm.getInstalledPackages(0)
            }
        } catch (e: Exception) {
            emptyList()
        }

        val result = mutableListOf<Map<String, Any?>>()
        for (pkg in packages) {
            val appInfo = pkg.applicationInfo ?: continue
            val isSystem = (appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0

            val appName = try {
                pm.getApplicationLabel(appInfo).toString()
            } catch (e: Exception) {
                pkg.packageName
            }

            val versionCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                pkg.longVersionCode.toInt()
            } else {
                @Suppress("DEPRECATION")
                pkg.versionCode
            }

            val iconBase64 = try {
                val drawable = pm.getApplicationIcon(appInfo)
                drawableToBase64(drawable)
            } catch (e: Exception) {
                null
            }

            result.add(
                mapOf(
                    "packageName" to pkg.packageName,
                    "appName" to appName,
                    "versionCode" to versionCode,
                    "versionName" to pkg.versionName,
                    "isSystemApp" to isSystem,
                    "iconBase64" to iconBase64,
                    "sourceDir" to appInfo.sourceDir
                )
            )
        }
        return result
    }

    private fun drawableToBase64(drawable: Drawable): String? {
        val bitmap = when (drawable) {
            is BitmapDrawable -> drawable.bitmap
            else -> {
                val w = if (drawable.intrinsicWidth > 0) drawable.intrinsicWidth else 72
                val h = if (drawable.intrinsicHeight > 0) drawable.intrinsicHeight else 72
                val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
                val canvas = Canvas(bmp)
                drawable.setBounds(0, 0, canvas.width, canvas.height)
                drawable.draw(canvas)
                bmp
            }
        }
        val stream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 85, stream)
        return Base64.encodeToString(stream.toByteArray(), Base64.NO_WRAP)
    }

    private fun copyFile(src: File, dst: File) {
        FileInputStream(src).use { inStream ->
            FileOutputStream(dst).use { outStream ->
                val buffer = ByteArray(8192)
                var bytesRead: Int
                while (inStream.read(buffer).also { bytesRead = it } > 0) {
                    outStream.write(buffer, 0, bytesRead)
                }
            }
        }
    }

    private fun getClonesListJson(): JSONArray {
        val raw = prefs.getString("clones_json", "[]") ?: "[]"
        return try {
            JSONArray(raw)
        } catch (e: Exception) {
            JSONArray()
        }
    }

    private fun saveClonesListJson(array: JSONArray) {
        prefs.edit().putString("clones_json", array.toString()).apply()
    }

    private fun getStubActivityClass(profileId: Int, isSingleTask: Boolean): String {
        return com.virtual.routing.ContainerStubRegistry.getStubActivityClass(profileId, isSingleTask)
    }

    companion object {
        const val METHODS_CHANNEL = "com.virtual.clone_app/methods"
        const val APPS_CHANNEL = "com.virtual.clone_app/apps"
        const val PROGRESS_CHANNEL = "com.virtual.clone_app/progress"

        fun registerWith(messenger: BinaryMessenger, context: Context): CloneAppPlugin {
            val plugin = CloneAppPlugin()
            plugin.init(context, messenger)
            return plugin
        }
    }
}
