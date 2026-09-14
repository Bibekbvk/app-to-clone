package com.virtual.fs

import android.content.Context
import android.content.ContextWrapper
import android.content.SharedPreferences
import android.content.pm.ApplicationInfo
import android.database.sqlite.SQLiteDatabase
import java.io.File
import java.util.concurrent.ConcurrentHashMap

/**
 * Isolated ContextWrapper that virtualizes all file, database, shared preferences,
 * and storage operations for a given profile ID and target package.
 *
 * Dedicated sandbox path:
 * /data/user/0/<host_pkg>/files/clones/<profile_id>/
 */
class ContainerStorageContext(
    base: Context,
    val profileId: Int,
    val targetPackage: String
) : ContextWrapper(base) {

    val profileRootDir: File by lazy {
        File(base.filesDir, "clones/$profileId").apply {
            if (!exists()) mkdirs()
        }
    }

    private val sharedPrefsMap = ConcurrentHashMap<String, SharedPreferences>()

    override fun getPackageName(): String = targetPackage

    override fun getDataDir(): File = profileRootDir

    override fun getFilesDir(): File {
        return File(profileRootDir, "files").apply { if (!exists()) mkdirs() }
    }

    override fun getCacheDir(): File {
        return File(profileRootDir, "cache").apply { if (!exists()) mkdirs() }
    }

    override fun getCodeCacheDir(): File {
        return File(profileRootDir, "code_cache").apply { if (!exists()) mkdirs() }
    }

    override fun getDatabasePath(name: String): File {
        val databasesDir = File(profileRootDir, "databases").apply { if (!exists()) mkdirs() }
        val dbFile = if (name.endsWith(".db")) File(databasesDir, name) else File(databasesDir, "$name.db")
        return dbFile
    }

    override fun openOrCreateDatabase(
        name: String,
        mode: Int,
        factory: SQLiteDatabase.CursorFactory?
    ): SQLiteDatabase {
        val dbFile = getDatabasePath(name)
        val db = SQLiteDatabase.openOrCreateDatabase(dbFile, factory)
        // Enable Write-Ahead Logging (WAL) for high throughput and crash resilience
        db.enableWriteAheadLogging()
        return db
    }

    override fun getSharedPreferences(name: String, mode: Int): SharedPreferences {
        return sharedPrefsMap.getOrPut(name) {
            val prefsDir = File(profileRootDir, "shared_prefs").apply { if (!exists()) mkdirs() }
            val prefsFile = File(prefsDir, "$name.xml")
            IsolatedSharedPreferences(prefsFile)
        }
    }

    override fun getExternalFilesDir(type: String?): File? {
        val hostExternalDir = super.getExternalFilesDir(null) ?: return null
        val isolatedExternal = File(hostExternalDir, "clones/$profileId/${type ?: ""}")
        if (!isolatedExternal.exists()) {
            isolatedExternal.mkdirs()
        }
        return isolatedExternal
    }

    override fun getApplicationInfo(): ApplicationInfo {
        val info = ApplicationInfo(super.getApplicationInfo())
        info.packageName = targetPackage
        info.dataDir = profileRootDir.absolutePath
        info.sourceDir = File(profileRootDir, "base.apk").absolutePath
        return info
    }

    /**
     * Computes the total storage footprint (in bytes) of this clone's isolated sandbox.
     */
    fun getStorageFootprintBytes(): Long {
        return try {
            calculateDirectorySize(profileRootDir)
        } catch (e: Exception) {
            0L
        }
    }

    private fun calculateDirectorySize(dir: File): Long {
        if (!dir.exists()) return 0L
        if (dir.isFile) return dir.length()
        var size = 0L
        dir.listFiles()?.forEach { file ->
            size += if (file.isDirectory) calculateDirectorySize(file) else file.length()
        }
        return size
    }
}
