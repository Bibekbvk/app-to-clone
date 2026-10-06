package com.virtual.engine.identity

import android.content.Context
import android.os.Build
import android.provider.Settings
import android.util.Log
import org.json.JSONObject
import java.lang.reflect.Field
import java.lang.reflect.Modifier
import java.security.SecureRandom

/**
 * Hardware Identity & Device Profile Virtualization.
 * Provides presets for major Android flagships (Galaxy S24, Pixel 8, Xiaomi 14, OnePlus 12),
 * mutates android.os.Build static properties via Java reflection, and intercepts
 * Settings.Secure.ANDROID_ID via private sNameValueCache injection.
 */
data class DeviceIdentityProfile(
    val presetId: String,
    val displayName: String,
    val brand: String,
    val manufacturer: String,
    val model: String,
    val device: String,
    val product: String,
    val board: String,
    val hardware: String,
    val fingerprint: String,
    val androidId: String,
    val advertisingId: String,
    val serial: String = "R58M" + androidId.takeLast(7).uppercase(),
    val display: String = "UP1A.231005.007." + model.replace(" ", ""),
    val buildId: String = "UP1A.231005.007"
) {
    fun toJson(): JSONObject {
        return JSONObject().apply {
            put("presetId", presetId)
            put("displayName", displayName)
            put("brand", brand)
            put("manufacturer", manufacturer)
            put("model", model)
            put("device", device)
            put("product", product)
            put("board", board)
            put("hardware", hardware)
            put("fingerprint", fingerprint)
            put("androidId", androidId)
            put("advertisingId", advertisingId)
            put("serial", serial)
            put("display", display)
            put("buildId", buildId)
        }
    }

    companion object {
        private const val TAG = "DeviceIdentityProfile"

        val PRESET_SAMSUNG_S24 = DeviceIdentityProfile(
            presetId = "samsung_s24_ultra",
            displayName = "Samsung Galaxy S24 Ultra",
            brand = "samsung",
            manufacturer = "samsung",
            model = "SM-S928B",
            device = "e3q",
            product = "e3qxxx",
            board = "e3q",
            hardware = "qcom",
            fingerprint = "samsung/e3qxxx/e3q:14/UP1A.231005.007/S928BXXU1AXB5:user/release-keys",
            androidId = "7a8b9c0d1e2f3456",
            advertisingId = "3fa85f64-5717-4562-b3fc-2c963f66afa6",
            serial = "R58M80ABCDE",
            display = "UP1A.231005.007.S928BXXU1AXB5",
            buildId = "UP1A.231005.007"
        )

        val PRESET_PIXEL_8 = DeviceIdentityProfile(
            presetId = "pixel_8_pro",
            displayName = "Google Pixel 8 Pro",
            brand = "google",
            manufacturer = "Google",
            model = "Pixel 8 Pro",
            device = "husky",
            product = "husky",
            board = "husky",
            hardware = "zuma",
            fingerprint = "google/husky/husky:14/UD1A.230803.041/10808477:user/release-keys",
            androidId = "8b9c0d1e2f34567a",
            advertisingId = "6ba7b810-9dad-11d1-80b4-00c04fd430c8",
            serial = "37251FDH2000XW",
            display = "UD1A.230803.041",
            buildId = "UD1A.230803.041"
        )

        val PRESET_XIAOMI_14 = DeviceIdentityProfile(
            presetId = "xiaomi_14_pro",
            displayName = "Xiaomi 14 Pro",
            brand = "Xiaomi",
            manufacturer = "Xiaomi",
            model = "23116PN5BC",
            device = "shennong",
            product = "shennong",
            board = "shennong",
            hardware = "qcom",
            fingerprint = "Xiaomi/shennong/shennong:14/UKQ1.230804.001/V816.0.4.0.UNBCNXM:user/release-keys",
            androidId = "9c0d1e2f34567a8b",
            advertisingId = "f47ac10b-58cc-4372-a567-0e02b2c3d479",
            serial = "23116P00192847",
            display = "UKQ1.230804.001",
            buildId = "UKQ1.230804.001"
        )

        val PRESET_ONEPLUS_12 = DeviceIdentityProfile(
            presetId = "oneplus_12",
            displayName = "OnePlus 12",
            brand = "OnePlus",
            manufacturer = "OnePlus",
            model = "CPH2581",
            device = "OP595DL1",
            product = "CPH2581",
            board = "kalama",
            hardware = "qcom",
            fingerprint = "OnePlus/CPH2581/OP595DL1:14/UKQ1.230924.001/U.18d6e3c-1-2:user/release-keys",
            androidId = "0d1e2f34567a8b9c",
            advertisingId = "c81d4e2e-bcf2-11e6-869b-7df92533d2db",
            serial = "CPH2581908273",
            display = "CPH2581_14.0.0.404(EX01)",
            buildId = "UKQ1.230924.001"
        )

        fun fromJson(json: JSONObject): DeviceIdentityProfile {
            val presetId = json.optString("presetId", "custom")
            val base = when (presetId) {
                "samsung_s24_ultra" -> PRESET_SAMSUNG_S24
                "pixel_8_pro" -> PRESET_PIXEL_8
                "xiaomi_14_pro" -> PRESET_XIAOMI_14
                "oneplus_12" -> PRESET_ONEPLUS_12
                else -> PRESET_SAMSUNG_S24
            }

            return base.copy(
                presetId = presetId,
                displayName = json.optString("displayName", base.displayName),
                brand = json.optString("brand", base.brand),
                manufacturer = json.optString("manufacturer", base.manufacturer),
                model = json.optString("model", base.model),
                device = json.optString("device", base.device),
                product = json.optString("product", base.product),
                board = json.optString("board", base.board),
                hardware = json.optString("hardware", base.hardware),
                fingerprint = json.optString("fingerprint", base.fingerprint),
                androidId = json.optString("androidId", base.androidId),
                advertisingId = json.optString("advertisingId", base.advertisingId),
                serial = json.optString("serial", base.serial),
                display = json.optString("display", base.display),
                buildId = json.optString("buildId", base.buildId)
            )
        }

        /**
         * Resolves or dynamically generates a unique identity profile for a clone instance.
         */
        fun getProfileForClone(cloneId: Int, preferredPreset: String? = null, customAndroidId: String? = null): DeviceIdentityProfile {
            val base = when (preferredPreset?.lowercase()) {
                "samsung_s24_ultra", "samsung", "galaxy" -> PRESET_SAMSUNG_S24
                "pixel_8_pro", "pixel", "google" -> PRESET_PIXEL_8
                "xiaomi_14_pro", "xiaomi" -> PRESET_XIAOMI_14
                "oneplus_12", "oneplus" -> PRESET_ONEPLUS_12
                else -> {
                    // Rotate through flagship profiles based on clone ID
                    when (cloneId % 4) {
                        1 -> PRESET_SAMSUNG_S24
                        2 -> PRESET_PIXEL_8
                        3 -> PRESET_XIAOMI_14
                        else -> PRESET_ONEPLUS_12
                    }
                }
            }

            val randomAndroidId = customAndroidId?.takeIf { it.isNotBlank() } ?: run {
                // Always generate a fresh cryptographically unique Android ID even for same cloneId
                val rnd = SecureRandom()
                val bytes = ByteArray(8)
                rnd.nextBytes(bytes)
                bytes.joinToString("") { String.format("%02x", it) }
            }
            val randomGaid = generateRandomUuid(cloneId)
            val randomSerial = "CL" + generateRandomHex(10, cloneId + 50).uppercase()

            return base.copy(
                androidId = randomAndroidId,
                advertisingId = randomGaid,
                serial = randomSerial
            )
        }

        private fun generateRandomHex(length: Int, seed: Int): String {
            val chars = "0123456789abcdef"
            // Use true cryptographic entropy + seed as additional XOR salt for reproducibility per-clone
            val rnd = SecureRandom()
            val saltedSeed = seed.toLong() xor System.nanoTime()
            rnd.setSeed(saltedSeed)
            val sb = StringBuilder(length)
            for (i in 0 until length) {
                sb.append(chars[rnd.nextInt(chars.length)])
            }
            return sb.toString()
        }

        private fun generateRandomUuid(seed: Int): String {
            val hex = generateRandomHex(32, seed + 100)
            return "${hex.substring(0, 8)}-${hex.substring(8, 12)}-4${hex.substring(13, 16)}-a${hex.substring(17, 20)}-${hex.substring(20, 32)}"
        }

        fun generateSpoofedMac(seed: String): String {
            val hash = seed.hashCode()
            val rnd = SecureRandom(byteArrayOf(
                (hash and 0xFF).toByte(),
                ((hash shr 8) and 0xFF).toByte(),
                0x02,
                0x44
            ))
            val mac = ByteArray(6)
            rnd.nextBytes(mac)
            mac[0] = (mac[0].toInt() and 0xFE or 0x02).toByte() // Locally administered, unicast
            return mac.joinToString(":") { String.format("%02x", it) }
        }

        /**
         * Applies the spoofed identity properties to android.os.Build static fields via Java reflection.
         */
        fun applyToRuntime(profile: DeviceIdentityProfile) {
            try {
                setField(Build::class.java, "MANUFACTURER", profile.manufacturer)
                setField(Build::class.java, "BRAND", profile.brand)
                setField(Build::class.java, "MODEL", profile.model)
                setField(Build::class.java, "DEVICE", profile.device)
                setField(Build::class.java, "PRODUCT", profile.product)
                setField(Build::class.java, "BOARD", profile.board)
                setField(Build::class.java, "HARDWARE", profile.hardware)
                setField(Build::class.java, "FINGERPRINT", profile.fingerprint)
                setField(Build::class.java, "SERIAL", profile.serial)
                setField(Build::class.java, "DISPLAY", profile.display)
                setField(Build::class.java, "ID", profile.buildId)
                setField(Build::class.java, "HOST", "buildhost-" + profile.presetId.take(8))
                setField(Build::class.java, "USER", "android-build")
                setField(Build::class.java, "BOOTLOADER", profile.board + "-boot")
                Log.i(TAG, "Applied hardware spoof: ${profile.displayName} (${profile.model}), Serial: ${profile.serial}")
            } catch (e: Throwable) {
                Log.w(TAG, "Error applying hardware spoof: ${e.message}")
            }
        }

        /**
         * Injects the spoofed Android ID into android.provider.Settings$Secure, System, and Global
         * internal in-memory cache (sNameValueCache.mValues).
         *
         * This intercepts all calls to Settings.Secure.getString(resolver, Settings.Secure.ANDROID_ID)
         * without modifying final methods on ContentResolver.
         */
        fun spoofSettingsSecure(androidId: String, advertisingId: String? = null) {
            val classesToHook = listOf(
                "android.provider.Settings\$Secure",
                "android.provider.Settings\$System",
                "android.provider.Settings\$Global"
            )

            for (className in classesToHook) {
                try {
                    val settingsClazz = Class.forName(className)
                    val cacheField = settingsClazz.getDeclaredField("sNameValueCache").apply { isAccessible = true }
                    val cacheObj = cacheField.get(null) ?: continue

                    // In AOSP NameValueCache: private final ArrayMap<String, String> mValues
                    var valuesMap: MutableMap<String, String>? = null
                    try {
                        val mValuesField = cacheObj.javaClass.getDeclaredField("mValues").apply { isAccessible = true }
                        @Suppress("UNCHECKED_CAST")
                        valuesMap = mValuesField.get(cacheObj) as? MutableMap<String, String>
                    } catch (_: Throwable) {}

                    if (valuesMap != null) {
                        synchronized(cacheObj) {
                            valuesMap[Settings.Secure.ANDROID_ID] = androidId
                            valuesMap["android_id"] = androidId
                            if (advertisingId != null) {
                                valuesMap["advertising_id"] = advertisingId
                                valuesMap["google_ad_id"] = advertisingId
                            }
                            valuesMap["bluetooth_address"] = generateSpoofedMac(androidId)
                        }
                        Log.i(TAG, "Successfully injected spoofed identifiers into $className.sNameValueCache")
                    }
                } catch (e: Throwable) {
                    Log.d(TAG, "Could not hook $className: ${e.message}")
                }
            }
        }

        /**
         * Comprehensive identity isolation entry point:
         * Spoofs both hardware Build properties and system settings identifiers.
         */
        fun applyFullIdentity(profile: DeviceIdentityProfile) {
            applyToRuntime(profile)
            spoofSettingsSecure(profile.androidId, profile.advertisingId)
        }

        private fun setField(clazz: Class<*>, fieldName: String, value: Any) {
            try {
                val field: Field = clazz.getDeclaredField(fieldName)
                field.isAccessible = true

                // Strip final modifier if accessible
                try {
                    val modifiersField = Field::class.java.getDeclaredField("accessFlags")
                    modifiersField.isAccessible = true
                    modifiersField.setInt(field, field.modifiers and Modifier.FINAL.inv())
                } catch (_: Throwable) {}

                field.set(null, value)
            } catch (e: Throwable) {
                Log.d(TAG, "Could not set field $fieldName: ${e.message}")
            }
        }
    }
}
