package com.example.login_vault_app

import android.os.Build
import android.os.Process
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.login_vault_app/sys_info"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getSysInfo" -> {
                    val info = mapOf(
                        "uid" to Process.myUid().toString(),
                        "pid" to Process.myPid().toString(),
                        "dataDir" to if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) dataDir.absolutePath else filesDir.parentFile?.absolutePath.orEmpty(),
                        "filesDir" to filesDir.absolutePath,
                        "packageName" to packageName
                    )
                    result.success(info)
                }
                else -> result.notImplemented()
            }
        }
    }
}
