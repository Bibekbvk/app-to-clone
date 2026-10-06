package com.virtual.engine.hook

import android.os.Build
import android.util.Log
import java.lang.reflect.Method

/**
 * Rootless Hidden API Enforcement Bypass (FreeReflection / Unseal pattern).
 * Used by virtual containers (Parallel Space, VirtualApp, Clone App by SZPY/Boostifly)
 * to access internal system services (ServiceManager, ITelephony, IWifiManager)
 * across Android 9 through Android 14+.
 */
object HiddenApiBypass {
    private const val TAG = "HiddenApiBypass"
    private var isUnsealed = false

    fun unseal(): Boolean {
        if (isUnsealed) return true
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) {
            isUnsealed = true
            return true
        }

        return try {
            val stringArrayClass = arrayOf<String>().javaClass
            val classArrayClass = arrayOf<Class<*>>().javaClass

            val forNameMethod = Class::class.java.getDeclaredMethod("forName", String::class.java)
            val getDeclaredMethod = Class::class.java.getDeclaredMethod(
                "getDeclaredMethod",
                String::class.java,
                classArrayClass
            )
            val vmRuntimeClass = forNameMethod.invoke(null, "dalvik.system.VMRuntime") as Class<*>
            val getRuntimeMethod = getDeclaredMethod.invoke(
                vmRuntimeClass,
                "getRuntime",
                null
            ) as Method
            val setExemptionsMethod = getDeclaredMethod.invoke(
                vmRuntimeClass,
                "setHiddenApiExemptions",
                arrayOf(stringArrayClass)
            ) as Method
            val vmRuntime = getRuntimeMethod.invoke(null)
            setExemptionsMethod.invoke(vmRuntime, arrayOf("L"))
            isUnsealed = true
            Log.i(TAG, "Successfully unsealed Android Hidden API restrictions.")
            true
        } catch (e: Throwable) {
            Log.w(TAG, "Notice: Hidden API unseal threw: ${e.message}")
            false
        }
    }
}
