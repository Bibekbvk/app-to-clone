package com.virtual.engine.hook

import android.location.Location
import android.net.wifi.WifiInfo
import android.os.IBinder
import android.os.IInterface
import android.util.Log
import com.virtual.engine.identity.DeviceIdentityProfile
import java.lang.reflect.Field
import java.lang.reflect.InvocationHandler
import java.lang.reflect.Method
import java.lang.reflect.Proxy

/**
 * Dynamic ServiceManager System Service Interception Hook.
 * Implements the core virtualization architecture used by Parallel Space, VirtualApp,
 * and Clone App (SZPY / BOOSTIFLY).
 *
 * Intercepts Android's [android.os.ServiceManager.sCache] binder cache to spoof:
 * 1. Telephony ("phone", "iphonesubinfo"): Fake IMEI, MEID, IMSI, SIM Serial, Phone Number, Carrier.
 * 2. Wi-Fi ("wifi"): Fake MAC Address, BSSID, SSID.
 * 3. Location ("location"): Fake GPS Latitude / Longitude coordinates.
 */
object VirtualServiceManagerHook {
    private const val TAG = "VirtualServiceHook"
    private val hookedServices = mutableSetOf<String>()

    /**
     * Installs all system service virtualization hooks into the active process.
     */
    fun install(profile: DeviceIdentityProfile) {
        try {
            // First ensure Android 9-14 hidden API restrictions are bypassed
            HiddenApiBypass.unseal()

            val serviceManagerClass = Class.forName("android.os.ServiceManager")
            val sCacheField = serviceManagerClass.getDeclaredField("sCache").apply { isAccessible = true }

            @Suppress("UNCHECKED_CAST")
            val sCache = sCacheField.get(null) as? MutableMap<String, IBinder>
            if (sCache == null) {
                Log.w(TAG, "ServiceManager.sCache is null, cannot hook services.")
                return
            }

            synchronized(sCache) {
                // 1. Hook Telephony Manager ("phone" and "iphonesubinfo")
                hookService(serviceManagerClass, sCache, "phone") { rawService ->
                    createTelephonyProxy(rawService, profile)
                }
                hookService(serviceManagerClass, sCache, "iphonesubinfo") { rawService ->
                    createTelephonyProxy(rawService, profile)
                }

                // 2. Hook Wifi Manager ("wifi")
                hookService(serviceManagerClass, sCache, "wifi") { rawService ->
                    createWifiProxy(rawService, profile)
                }

                // 3. Hook Location Manager ("location")
                if (profile.fakeLatitude != null && profile.fakeLongitude != null) {
                    hookService(serviceManagerClass, sCache, "location") { rawService ->
                        createLocationProxy(rawService, profile)
                    }
                }
            }

            Log.i(TAG, "Successfully installed ServiceManager hooks for clone (IMEI: ${profile.imei}, MAC: ${profile.macAddress})")
        } catch (e: Throwable) {
            Log.w(TAG, "Notice during VirtualServiceManagerHook installation: ${e.message}")
        }
    }

    private fun hookService(
        serviceManagerClass: Class<*>,
        sCache: MutableMap<String, IBinder>,
        serviceName: String,
        proxyFactory: (rawService: Any?) -> InvocationHandler
    ) {
        try {
            // Obtain raw IBinder from getService static method or cache
            val getServiceMethod = serviceManagerClass.getDeclaredMethod("getService", String::class.java)
            val rawBinder = getServiceMethod.invoke(null, serviceName) as? IBinder ?: sCache[serviceName]
            if (rawBinder == null) {
                Log.d(TAG, "Service $serviceName not found in system, skipping hook.")
                return
            }

            // Wrap rawBinder with a dynamic IBinder proxy
            val binderProxy = Proxy.newProxyInstance(
                rawBinder.javaClass.classLoader,
                arrayOf(IBinder::class.java),
                BinderHookHandler(rawBinder, proxyFactory)
            ) as IBinder

            sCache[serviceName] = binderProxy
            hookedServices.add(serviceName)
            Log.d(TAG, "Hooked ServiceManager service: $serviceName")
        } catch (e: Throwable) {
            Log.w(TAG, "Failed to hook service $serviceName: ${e.message}")
        }
    }

    /**
     * Intercepts IBinder.queryLocalInterface() to return a hooked service interface.
     */
    private class BinderHookHandler(
        private val rawBinder: IBinder,
        private val proxyFactory: (rawService: Any?) -> InvocationHandler
    ) : InvocationHandler {

        override fun invoke(proxy: Any, method: Method, args: Array<out Any>?): Any? {
            val safeArgs = args ?: emptyArray()

            if (method.name == "queryLocalInterface") {
                val descriptor = safeArgs.getOrNull(0) as? String ?: ""
                val targetInterfaceClass = try {
                    Class.forName(descriptor)
                } catch (_: Throwable) {
                    null
                }

                val interfaces = if (targetInterfaceClass != null) {
                    arrayOf(IInterface::class.java, targetInterfaceClass)
                } else {
                    arrayOf(IInterface::class.java)
                }

                val rawService = try {
                    method.invoke(rawBinder, *safeArgs)
                } catch (_: Throwable) {
                    null
                }

                return Proxy.newProxyInstance(
                    rawBinder.javaClass.classLoader,
                    interfaces,
                    proxyFactory(rawService)
                )
            }

            return try {
                method.invoke(rawBinder, *safeArgs)
            } catch (e: Throwable) {
                null
            }
        }
    }

    /**
     * Dynamic proxy for ITelephony and IPhoneSubInfo interfaces.
     */
    private fun createTelephonyProxy(rawService: Any?, profile: DeviceIdentityProfile): InvocationHandler {
        return InvocationHandler { _, method, args ->
            val name = method.name
            val safeArgs = args ?: emptyArray()

            when {
                name.startsWith("getDeviceId") || name.startsWith("getImei") -> {
                    Log.d(TAG, "Intercepted Telephony.$name -> returning spoofed IMEI: ${profile.imei}")
                    profile.imei
                }
                name.startsWith("getMeid") -> {
                    profile.imei.take(14)
                }
                name.startsWith("getSubscriberId") -> {
                    Log.d(TAG, "Intercepted Telephony.$name -> returning spoofed IMSI: ${profile.imsi}")
                    profile.imsi
                }
                name.startsWith("getSimSerialNumber") || name.startsWith("getIccSerialNumber") -> {
                    profile.simSerial
                }
                name.startsWith("getLine1Number") -> {
                    profile.phoneNumber
                }
                name.startsWith("getNetworkOperatorName") || name.startsWith("getSimOperatorName") -> {
                    profile.networkOperator
                }
                name.startsWith("getNetworkCountryIso") || name.startsWith("getSimCountryIso") -> {
                    "us"
                }
                name == "getPhoneType" -> {
                    // PhoneConstants.PHONE_TYPE_GSM = 1
                    1
                }
                rawService != null -> {
                    try {
                        method.invoke(rawService, *safeArgs)
                    } catch (t: Throwable) {
                        getDefaultReturnValue(method.returnType)
                    }
                }
                else -> getDefaultReturnValue(method.returnType)
            }
        }
    }

    /**
     * Dynamic proxy for IWifiManager.
     */
    private fun createWifiProxy(rawService: Any?, profile: DeviceIdentityProfile): InvocationHandler {
        return InvocationHandler { _, method, args ->
            val name = method.name
            val safeArgs = args ?: emptyArray()

            when (name) {
                "getConnectionInfo" -> {
                    var wifiInfo = rawService?.let {
                        try {
                            method.invoke(it, *safeArgs) as? WifiInfo
                        } catch (_: Throwable) {
                            null
                        }
                    }

                    if (wifiInfo == null) {
                        try {
                            val constructor = WifiInfo::class.java.getDeclaredConstructor().apply { isAccessible = true }
                            wifiInfo = constructor.newInstance()
                        } catch (_: Throwable) {}
                    }

                    if (wifiInfo != null) {
                        spoofWifiInfoFields(wifiInfo, profile.macAddress)
                    }
                    wifiInfo
                }
                else -> {
                    if (rawService != null) {
                        try {
                            method.invoke(rawService, *safeArgs)
                        } catch (_: Throwable) {
                            getDefaultReturnValue(method.returnType)
                        }
                    } else {
                        getDefaultReturnValue(method.returnType)
                    }
                }
            }
        }
    }

    private fun spoofWifiInfoFields(wifiInfo: WifiInfo, macAddress: String) {
        val fieldsToSpoof = mapOf(
            "mMacAddress" to macAddress,
            "mBSSID" to macAddress,
            "mSSID" to "\"Virtual-WiFi\""
        )

        for ((fieldName, value) in fieldsToSpoof) {
            try {
                val field: Field = WifiInfo::class.java.getDeclaredField(fieldName).apply { isAccessible = true }
                field.set(wifiInfo, value)
            } catch (_: Throwable) {}
        }
    }

    /**
     * Dynamic proxy for ILocationManager (Fake GPS).
     */
    private fun createLocationProxy(rawService: Any?, profile: DeviceIdentityProfile): InvocationHandler {
        val lat = profile.fakeLatitude ?: 37.7749
        val lng = profile.fakeLongitude ?: -122.4194

        return InvocationHandler { _, method, args ->
            val name = method.name
            val safeArgs = args ?: emptyArray()

            when {
                name == "getLastLocation" || name == "getLastKnownLocation" -> {
                    val fakeLocation = Location("gps").apply {
                        latitude = lat
                        longitude = lng
                        altitude = 15.0
                        accuracy = 3.0f
                        time = System.currentTimeMillis()
                    }
                    Log.d(TAG, "Intercepted Location.$name -> returning Fake GPS ($lat, $lng)")
                    fakeLocation
                }
                rawService != null -> {
                    try {
                        method.invoke(rawService, *safeArgs)
                    } catch (_: Throwable) {
                        getDefaultReturnValue(method.returnType)
                    }
                }
                else -> getDefaultReturnValue(method.returnType)
            }
        }
    }

    private fun getDefaultReturnValue(returnType: Class<*>): Any? {
        return when (returnType) {
            Boolean::class.javaPrimitiveType -> false
            Int::class.javaPrimitiveType -> 0
            Long::class.javaPrimitiveType -> 0L
            Float::class.javaPrimitiveType -> 0.0f
            Double::class.javaPrimitiveType -> 0.0
            Byte::class.javaPrimitiveType -> 0.toByte()
            Short::class.javaPrimitiveType -> 0.toShort()
            Char::class.javaPrimitiveType -> ' '
            Void.TYPE -> null
            java.lang.String::class.java -> ""
            java.util.List::class.java -> emptyList<Any>()
            java.util.Map::class.java -> emptyMap<Any, Any>()
            else -> null
        }
    }
}
