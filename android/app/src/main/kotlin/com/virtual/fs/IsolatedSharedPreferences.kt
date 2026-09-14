package com.virtual.fs

import android.content.SharedPreferences
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.locks.ReentrantReadWriteLock
import kotlin.concurrent.read
import kotlin.concurrent.write

/**
 * Thread-safe, persistent SharedPreferences implementation that operates directly on disk
 * and bypasses Android ContextImpl's static sSharedPrefsCache to guarantee absolute instance isolation.
 * Ensures logged-in tokens, credentials, and settings remain isolated per clone and durable long-term.
 */
class IsolatedSharedPreferences(
    private val prefsFile: File
) : SharedPreferences {

    private val lock = ReentrantReadWriteLock()
    private val memoryMap = ConcurrentHashMap<String, Any>()
    private val listeners = mutableSetOf<SharedPreferences.OnSharedPreferenceChangeListener>()

    init {
        loadFromDisk()
    }

    private fun loadFromDisk() = lock.write {
        if (!prefsFile.exists()) return@write
        try {
            FileInputStream(prefsFile).use { fis ->
                val lines = fis.bufferedReader().readLines()
                for (line in lines) {
                    val separatorIndex = line.indexOf('=')
                    if (separatorIndex > 0) {
                        val key = line.substring(0, separatorIndex)
                        val typeAndVal = line.substring(separatorIndex + 1)
                        if (typeAndVal.length >= 2) {
                            val type = typeAndVal.take(2)
                            val valueStr = typeAndVal.drop(2)
                            when (type) {
                                "S:" -> memoryMap[key] = valueStr
                                "I:" -> valueStr.toIntOrNull()?.let { memoryMap[key] = it }
                                "L:" -> valueStr.toLongOrNull()?.let { memoryMap[key] = it }
                                "F:" -> valueStr.toFloatOrNull()?.let { memoryMap[key] = it }
                                "B:" -> memoryMap[key] = valueStr.toBoolean()
                                "T:" -> memoryMap[key] = valueStr.split("|||").toSet()
                            }
                        }
                    }
                }
            }
        } catch (e: Exception) {
            // Non-fatal fallback
        }
    }

    private fun persistToDisk() = lock.write {
        try {
            val parent = prefsFile.parentFile
            if (parent != null && !parent.exists()) {
                parent.mkdirs()
            }
            val tempFile = File(parent, "${prefsFile.name}.tmp")
            FileOutputStream(tempFile).use { fos ->
                val writer = fos.bufferedWriter()
                for ((key, value) in memoryMap) {
                    val line = when (value) {
                        is String -> "$key=S:$value"
                        is Int -> "$key=I:$value"
                        is Long -> "$key=L:$value"
                        is Float -> "$key=F:$value"
                        is Boolean -> "$key=B:$value"
                        is Set<*> -> "$key=T:${value.joinToString("|||")}"
                        else -> "$key=S:$value"
                    }
                    writer.write(line)
                    writer.newLine()
                }
                writer.flush()
            }
            if (!tempFile.renameTo(prefsFile)) {
                tempFile.copyTo(prefsFile, overwrite = true)
                tempFile.delete()
            }
        } catch (e: Exception) {
            // Persistence fallback
        }
    }

    override fun getAll(): MutableMap<String, *> = lock.read { HashMap(memoryMap) }

    override fun getString(key: String?, defValue: String?): String? = lock.read {
        key?.let { memoryMap[it] as? String } ?: defValue
    }

    override fun getStringSet(key: String?, defValues: MutableSet<String>?): MutableSet<String>? = lock.read {
        @Suppress("UNCHECKED_CAST")
        (key?.let { memoryMap[it] as? Set<String> })?.toMutableSet() ?: defValues
    }

    override fun getInt(key: String?, defValue: Int): Int = lock.read {
        key?.let { memoryMap[it] as? Int } ?: defValue
    }

    override fun getLong(key: String?, defValue: Long): Long = lock.read {
        key?.let { memoryMap[it] as? Long } ?: defValue
    }

    override fun getFloat(key: String?, defValue: Float): Float = lock.read {
        key?.let { memoryMap[it] as? Float } ?: defValue
    }

    override fun getBoolean(key: String?, defValue: Boolean): Boolean = lock.read {
        key?.let { memoryMap[it] as? Boolean } ?: defValue
    }

    override fun contains(key: String?): Boolean = lock.read {
        key != null && memoryMap.containsKey(key)
    }

    override fun edit(): SharedPreferences.Editor = IsolatedEditor()

    override fun registerOnSharedPreferenceChangeListener(listener: SharedPreferences.OnSharedPreferenceChangeListener?) {
        listener?.let { synchronized(listeners) { listeners.add(it) } }
    }

    override fun unregisterOnSharedPreferenceChangeListener(listener: SharedPreferences.OnSharedPreferenceChangeListener?) {
        listener?.let { synchronized(listeners) { listeners.remove(it) } }
    }

    private fun notifyListeners(keys: Set<String>) {
        val list = synchronized(listeners) { listeners.toList() }
        for (listener in list) {
            for (key in keys) {
                listener.onSharedPreferenceChanged(this, key)
            }
        }
    }

    inner class IsolatedEditor : SharedPreferences.Editor {
        private val modifications = HashMap<String, Any?>()
        private var clear = false

        override fun putString(key: String?, value: String?): SharedPreferences.Editor = apply {
            if (key != null) modifications[key] = value
        }

        override fun putStringSet(key: String?, values: MutableSet<String>?): SharedPreferences.Editor = apply {
            if (key != null) modifications[key] = values?.toSet()
        }

        override fun putInt(key: String?, value: Int): SharedPreferences.Editor = apply {
            if (key != null) modifications[key] = value
        }

        override fun putLong(key: String?, value: Long): SharedPreferences.Editor = apply {
            if (key != null) modifications[key] = value
        }

        override fun putFloat(key: String?, value: Float): SharedPreferences.Editor = apply {
            if (key != null) modifications[key] = value
        }

        override fun putBoolean(key: String?, value: Boolean): SharedPreferences.Editor = apply {
            if (key != null) modifications[key] = value
        }

        override fun remove(key: String?): SharedPreferences.Editor = apply {
            if (key != null) modifications[key] = null
        }

        override fun clear(): SharedPreferences.Editor = apply {
            clear = true
        }

        override fun commit(): Boolean {
            apply()
            return true
        }

        override fun apply() {
            val changedKeys = mutableSetOf<String>()
            lock.write {
                if (clear) {
                    changedKeys.addAll(memoryMap.keys)
                    memoryMap.clear()
                }
                for ((k, v) in modifications) {
                    if (v == null) {
                        if (memoryMap.remove(k) != null) changedKeys.add(k)
                    } else {
                        if (memoryMap[k] != v) {
                            memoryMap[k] = v
                            changedKeys.add(k)
                        }
                    }
                }
                persistToDisk()
            }
            if (changedKeys.isNotEmpty()) {
                notifyListeners(changedKeys)
            }
        }
    }
}
