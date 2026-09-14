package com.virtual.engine.signature

import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.content.pm.Signature
import android.os.Build
import android.util.Log
import java.io.DataInputStream
import java.io.DataOutputStream
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream

/**
 * Signature Extraction and Serialization Utility.
 * Extracts authentic developer signatures from source packages and saves them into
 * an encrypted or serialized binary asset (`orig_cert.bin`) to preserve app integrity checks.
 */
object OriginalSignatureProvider {

    private const val TAG = "OriginalSigProvider"
    private const val BINARY_MAGIC = 0x56534947 // "VSIG"
    private const val BINARY_VERSION = 1

    /**
     * Extracts signatures from an installed application package on the system.
     */
    @SuppressLint("PackageManagerGetSignatures")
    fun extractFromInstalledPackage(context: Context, packageName: String): Array<Signature>? {
        return try {
            val pm = context.packageManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                val pkgInfo = pm.getPackageInfo(packageName, PackageManager.GET_SIGNING_CERTIFICATES)
                val signingInfo = pkgInfo.signingInfo
                if (signingInfo != null) {
                    if (signingInfo.hasMultipleSigners()) {
                        signingInfo.apkContentsSigners
                    } else {
                        signingInfo.signingCertificateHistory
                    }
                } else {
                    @Suppress("DEPRECATION")
                    pm.getPackageInfo(packageName, PackageManager.GET_SIGNATURES).signatures
                }
            } else {
                @Suppress("DEPRECATION")
                val pkgInfo = pm.getPackageInfo(packageName, PackageManager.GET_SIGNATURES)
                pkgInfo.signatures
            }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to extract signatures for $packageName: ${e.message}")
            null
        }
    }

    /**
     * Extracts signatures directly from an APK file on disk.
     */
    @SuppressLint("PackageManagerGetSignatures")
    fun extractFromApkFile(context: Context, apkFile: File): Array<Signature>? {
        if (!apkFile.exists() || apkFile.length() == 0L) return null
        return try {
            val pm = context.packageManager
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                PackageManager.GET_SIGNING_CERTIFICATES
            } else {
                @Suppress("DEPRECATION")
                PackageManager.GET_SIGNATURES
            }
            val pkgInfo = pm.getPackageArchiveInfo(apkFile.absolutePath, flags)
            if (pkgInfo != null) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    val sInfo = pkgInfo.signingInfo
                    if (sInfo != null) {
                        if (sInfo.hasMultipleSigners()) sInfo.apkContentsSigners else sInfo.signingCertificateHistory
                    } else {
                        @Suppress("DEPRECATION")
                        pkgInfo.signatures
                    }
                } else {
                    @Suppress("DEPRECATION")
                    pkgInfo.signatures
                }
            } else {
                null
            }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to extract signatures from ${apkFile.name}: ${e.message}")
            null
        }
    }

    /**
     * Persists signatures to binary file.
     */
    fun saveOriginalSignatures(packageName: String, signatures: Array<Signature>, destFile: File): Boolean {
        return try {
            destFile.parentFile?.mkdirs()
            DataOutputStream(FileOutputStream(destFile)).use { dos ->
                dos.writeInt(BINARY_MAGIC)
                dos.writeInt(BINARY_VERSION)
                dos.writeUTF(packageName)
                dos.writeInt(signatures.size)
                for (sig in signatures) {
                    val bytes = sig.toByteArray()
                    dos.writeInt(bytes.size)
                    dos.write(bytes)
                }
                dos.flush()
            }
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to save signatures: ${e.message}")
            false
        }
    }
}
