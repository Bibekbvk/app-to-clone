package com.virtual.engine.apk

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.util.Base64
import android.util.Log
import androidx.core.content.FileProvider
import com.virtual.engine.signature.OriginalSignatureProvider
import java.io.*
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.security.*
import java.security.cert.CertificateFactory
import java.security.cert.X509Certificate
import java.util.zip.ZipEntry
import java.util.zip.ZipInputStream
import java.util.zip.ZipOutputStream

/**
 * Enterprise Standalone Cloned APK Generation and Mutation Engine.
 *
 * 1. Extracts source base APK from installed application package.
 * 2. Parses and mutates binary AndroidManifest.xml (AXML) StringPool:
 *    - Rewrites `package` (e.g., com.target -> com.target.c01)
 *    - Rewrites all `<provider android:authorities="...">` to prevent INSTALL_FAILED_CONFLICTING_PROVIDER
 * 3. Extracts authentic developer signatures and embeds `assets/orig_cert.bin`.
 * 4. Signs the mutated APK with standard v1 signature so Android PackageInstaller accepts it.
 * 5. Dispatches prompt to native Android PackageInstaller or exports to public Downloads.
 */
object StandaloneApkGenerator {

    private const val TAG = "StandaloneApkGen"

    /**
     * Prepares and stages a standalone signed APK file for the given clone profile.
     * Saved at filesDir/cloned_apks/<cloneId>/<AppName>_Clone_<Badge>.apk
     */
    fun prepareClonedApkFile(
        context: Context,
        cloneId: Int,
        targetPackage: String,
        targetAppName: String,
        displayBadge: String
    ): File? {
        val sanitizedAppName = targetAppName.replace(Regex("[^a-zA-Z0-9_]"), "")
        val apkDir = File(context.filesDir, "cloned_apks/$cloneId").apply { mkdirs() }
        val targetApk = File(apkDir, "${sanitizedAppName}_Clone_${displayBadge}.apk")

        if (targetApk.exists() && targetApk.length() > 0L) {
            return targetApk
        }

        try {
            // 1. Locate source APK and splits
            val bundle = findSourceApks(context, targetPackage)
            val sourceApk = bundle.baseApk ?: run {
                Log.e(TAG, "Source APK not found for package $targetPackage")
                return null
            }

            val newPackage = "${targetPackage}.c${String.format("%02d", cloneId)}"

            // 2. Extract original signatures
            val certFile = File(apkDir, "orig_cert.bin")
            val sigs = OriginalSignatureProvider.extractFromInstalledPackage(context, targetPackage)
                ?: OriginalSignatureProvider.extractFromApkFile(context, sourceApk)
            if (sigs != null && sigs.isNotEmpty()) {
                OriginalSignatureProvider.saveOriginalSignatures(targetPackage, sigs, certFile)
            }

            // 3. Mutate Manifest and Repack APK with all splits merged
            val tempUnsignedApk = File(apkDir, "temp_unsigned.apk")
            repackAndMutateApk(
                srcApk = sourceApk,
                splitApks = bundle.splitApks,
                destApk = tempUnsignedApk,
                targetPackage = targetPackage,
                newPackage = newPackage,
                origCertBytes = if (certFile.exists()) certFile.readBytes() else null
            )

            // 4. Sign APK with official Android ApkSigner (v1 + v2 + v3)
            signApk(context, tempUnsignedApk, targetApk)
            tempUnsignedApk.delete()

            return targetApk
        } catch (e: Exception) {
            Log.e(TAG, "Failed generating standalone APK: ${e.message}", e)
            return null
        }
    }

    data class SourceApkBundle(val baseApk: File?, val splitApks: List<File>)

    private fun findSourceApks(context: Context, packageName: String): SourceApkBundle {
        // Method A: Check device installed application and all split directories
        try {
            val appInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                context.packageManager.getApplicationInfo(packageName, PackageManager.ApplicationInfoFlags.of(0))
            } else {
                @Suppress("DEPRECATION")
                context.packageManager.getApplicationInfo(packageName, 0)
            }
            val src = File(appInfo.sourceDir)
            val splits = mutableListOf<File>()
            appInfo.splitSourceDirs?.forEach { path ->
                val splitFile = File(path)
                if (splitFile.exists() && splitFile.length() > 0) {
                    splits.add(splitFile)
                }
            }
            if (src.exists() && src.length() > 0) {
                return SourceApkBundle(src, splits)
            }
        } catch (_: Exception) {}

        // Method B: Check app files/clones/<id>/base.apk
        val clonesRoot = File(context.filesDir, "clones")
        clonesRoot.listFiles()?.forEach { dir ->
            val apk = File(dir, "base.apk")
            if (apk.exists() && apk.length() > 1000) return SourceApkBundle(apk, emptyList())
        }

        return SourceApkBundle(null, emptyList())
    }

    /**
     * Reads source APK zip, mutates AndroidManifest.xml, merges all split APKs (native C++ libs, drawables),
     * embeds orig_cert.bin, strips existing META-INF signatures, and produces a complete self-contained APK.
     */
    private fun repackAndMutateApk(
        srcApk: File,
        splitApks: List<File>,
        destApk: File,
        targetPackage: String,
        newPackage: String,
        origCertBytes: ByteArray?
    ) {
        val addedEntries = HashSet<String>()

        ZipInputStream(BufferedInputStream(FileInputStream(srcApk))).use { zis ->
            ZipOutputStream(BufferedOutputStream(FileOutputStream(destApk))).use { zos ->
                var entry: ZipEntry? = zis.nextEntry
                while (entry != null) {
                    val name = entry.name

                    // Skip existing signature blocks to prepare for clean resign
                    if (name.startsWith("META-INF/") &&
                        (name.endsWith(".SF") || name.endsWith(".RSA") || name.endsWith(".DSA") ||
                         name.endsWith(".EC") || name.endsWith(".MF") || name.contains("SIG"))
                    ) {
                        entry = zis.nextEntry
                        continue
                    }

                    if (name == "AndroidManifest.xml") {
                        val rawManifest = zis.readBytes()
                        val mutatedManifest = mutateBinaryManifest(rawManifest, targetPackage, newPackage)
                        val newEntry = ZipEntry(name)
                        zos.putNextEntry(newEntry)
                        zos.write(mutatedManifest)
                        zos.closeEntry()
                        addedEntries.add(name)
                    } else {
                        if (!addedEntries.contains(name)) {
                            val newEntry = ZipEntry(name)
                            zos.putNextEntry(newEntry)
                            zis.copyTo(zos)
                            zos.closeEntry()
                            addedEntries.add(name)
                        }
                    }

                    entry = zis.nextEntry
                }

                // Merge all split APK entries (native .so files from split_config.arm64_v8a, resources from split_config.xxhdpi, etc.)
                for (split in splitApks) {
                    try {
                        ZipInputStream(BufferedInputStream(FileInputStream(split))).use { splitZis ->
                            var splitEntry = splitZis.nextEntry
                            while (splitEntry != null) {
                                val sName = splitEntry.name
                                if (!sName.startsWith("META-INF/") && 
                                    sName != "AndroidManifest.xml" && 
                                    !addedEntries.contains(sName)
                                ) {
                                    val newEntry = ZipEntry(sName)
                                    zos.putNextEntry(newEntry)
                                    splitZis.copyTo(zos)
                                    zos.closeEntry()
                                    addedEntries.add(sName)
                                }
                                splitEntry = splitZis.nextEntry
                            }
                        }
                    } catch (e: Exception) {
                        Log.w(TAG, "Error merging split ${split.name}: ${e.message}")
                    }
                }

                // Inject assets/orig_cert.bin if present
                if (origCertBytes != null && origCertBytes.isNotEmpty()) {
                    val certEntry = ZipEntry("assets/orig_cert.bin")
                    zos.putNextEntry(certEntry)
                    zos.write(origCertBytes)
                    zos.closeEntry()
                    addedEntries.add("assets/orig_cert.bin")
                }
            }
        }
    }

    /**
     * Binary AndroidManifest.xml (AXML) StringPool Mutator.
     * Rewrites package name and authority references across UTF-8 or UTF-16LE string pools.
     */
    fun mutateBinaryManifest(
        manifestBytes: ByteArray,
        targetPackage: String,
        newPackage: String
    ): ByteArray {
        if (manifestBytes.size < 32) return manifestBytes

        val buffer = ByteBuffer.wrap(manifestBytes).order(ByteOrder.LITTLE_ENDIAN)
        val magic = buffer.int
        if (magic != 0x00080003) {
            return manifestBytes // Not standard AXML
        }

        val originalSize = buffer.int
        val chunkType = buffer.int
        if (chunkType != 0x001C0001) { // RES_STRING_POOL_TYPE
            return manifestBytes
        }

        val chunkSize = buffer.int
        val stringCount = buffer.int
        val styleCount = buffer.int
        val flags = buffer.int
        val stringsStart = buffer.int
        val stylesStart = buffer.int

        val isUtf8 = (flags and 0x0100) != 0

        // Read string offsets
        val offsets = IntArray(stringCount)
        for (i in 0 until stringCount) {
            offsets[i] = buffer.int
        }

        val stringsAbsoluteStart = 8 + stringsStart
        val stringBytesLen = if (stylesStart > 0) (8 + stylesStart) - stringsAbsoluteStart else (8 + chunkSize) - stringsAbsoluteStart

        // Read all strings and perform replacements
        val strings = mutableListOf<String>()
        for (i in 0 until stringCount) {
            val offset = stringsAbsoluteStart + offsets[i]
            if (offset >= manifestBytes.size) {
                strings.add("")
                continue
            }

            if (isUtf8) {
                // UTF-8 string: 1-2 bytes char count, 1-2 bytes byte count, chars, 0x00
                var pos = offset
                var charLen = manifestBytes[pos].toInt() and 0xFF
                pos++
                if ((charLen and 0x80) != 0) pos++
                var byteLen = manifestBytes[pos].toInt() and 0xFF
                pos++
                if ((byteLen and 0x80) != 0) pos++
                val str = String(manifestBytes, pos, byteLen.coerceAtMost(manifestBytes.size - pos), Charsets.UTF_8)
                strings.add(str)
            } else {
                // UTF-16LE string: 2 bytes char count, 2*charLen bytes, 0x0000
                val charLen = (manifestBytes[offset].toInt() and 0xFF) or ((manifestBytes[offset + 1].toInt() and 0xFF) shl 8)
                val byteLen = charLen * 2
                val start = offset + 2
                val str = if (start + byteLen <= manifestBytes.size) {
                    String(manifestBytes, start, byteLen, Charsets.UTF_16LE)
                } else ""
                strings.add(str)
            }
        }

        // Apply mutation to target package and provider authorities
        var replacedAny = false
        val mutatedStrings = strings.map { str ->
            when {
                str == targetPackage -> {
                    replacedAny = true
                    newPackage
                }
                str.startsWith("$targetPackage.") -> {
                    replacedAny = true
                    str.replaceFirst(targetPackage, newPackage)
                }
                else -> str
            }
        }

        if (!replacedAny) {
            return manifestBytes
        }

        // Rebuild StringPool
        val stringDataOut = ByteArrayOutputStream()
        val newOffsets = IntArray(stringCount)

        for (i in 0 until stringCount) {
            val s = mutatedStrings[i]
            newOffsets[i] = stringDataOut.size()

            if (isUtf8) {
                val utf8Bytes = s.toByteArray(Charsets.UTF_8)
                val len = s.length
                stringDataOut.write(len and 0x7F)
                stringDataOut.write(utf8Bytes.size and 0x7F)
                stringDataOut.write(utf8Bytes)
                stringDataOut.write(0)
            } else {
                val utf16Bytes = s.toByteArray(Charsets.UTF_16LE)
                val charLen = s.length
                stringDataOut.write(charLen and 0xFF)
                stringDataOut.write((charLen shr 8) and 0xFF)
                stringDataOut.write(utf16Bytes)
                stringDataOut.write(0)
                stringDataOut.write(0)
            }
        }

        // Pad strings data to 4-byte boundary
        while (stringDataOut.size() % 4 != 0) {
            stringDataOut.write(0)
        }

        val newStringsBytes = stringDataOut.toByteArray()
        val newStringsStart = 28 + (stringCount * 4) + (styleCount * 4)
        val newChunkSize = newStringsStart + newStringsBytes.size + (if (stylesStart > 0) chunkSize - stylesStart else 0)

        val outBuffer = ByteArrayOutputStream()
        val dataOut = DataOutputStream(outBuffer)

        // Write Magic and new total file size
        val delta = newChunkSize - chunkSize
        val newTotalSize = originalSize + delta
        dataOut.writeInt(Integer.reverseBytes(0x00080003))
        dataOut.writeInt(Integer.reverseBytes(newTotalSize))

        // Write StringPool Header
        dataOut.writeInt(Integer.reverseBytes(0x001C0001))
        dataOut.writeInt(Integer.reverseBytes(newChunkSize))
        dataOut.writeInt(Integer.reverseBytes(stringCount))
        dataOut.writeInt(Integer.reverseBytes(styleCount))
        dataOut.writeInt(Integer.reverseBytes(flags))
        dataOut.writeInt(Integer.reverseBytes(newStringsStart))
        dataOut.writeInt(Integer.reverseBytes(if (stylesStart > 0) stylesStart + delta else 0))

        // Write Offsets
        for (offset in newOffsets) {
            dataOut.writeInt(Integer.reverseBytes(offset))
        }

        // Write String Data
        dataOut.write(newStringsBytes)

        // Write remaining AXML chunks (ResMap, Namespace, Elements)
        val remainingStart = 8 + chunkSize
        if (remainingStart < manifestBytes.size) {
            dataOut.write(manifestBytes, remainingStart, manifestBytes.size - remainingStart)
        }

        return outBuffer.toByteArray()
    }

    /**
     * Signs the generated APK using official Android ApkSigner with v1, v2, and v3 schemes.
     */
    private fun signApk(context: Context, unsignedApk: File, signedApk: File) {
        val ks = KeyStore.getInstance("PKCS12")
        context.assets.open("clone_signer.p12").use { input ->
            ks.load(input, "cloneapp".toCharArray())
        }
        val privateKey = ks.getKey("clonekey", "cloneapp".toCharArray()) as PrivateKey
        val cert = ks.getCertificate("clonekey") as X509Certificate

        val signerConfig = com.android.apksig.ApkSigner.SignerConfig.Builder(
            "clonekey",
            privateKey,
            listOf(cert)
        ).build()

        val signer = com.android.apksig.ApkSigner.Builder(listOf(signerConfig))
            .setInputApk(unsignedApk)
            .setOutputApk(signedApk)
            .setV1SigningEnabled(true)
            .setV2SigningEnabled(true)
            .setV3SigningEnabled(true)
            .build()

        signer.sign()
    }

    /**
     * Prompts the Android OS Native PackageInstaller via FileProvider
     * to install the cloned APK as a separate application on the device.
     */
    fun promptInstallClonedApk(context: Context, apkFile: File): Boolean {
        return try {
            if (!apkFile.exists() || apkFile.length() == 0L) {
                return false
            }

            val apkUri: Uri = FileProvider.getUriForFile(
                context,
                "${context.packageName}.fileprovider",
                apkFile
            )

            val installIntent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(apkUri, "application/vnd.android.package-archive")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION
                putExtra(Intent.EXTRA_NOT_UNKNOWN_SOURCE, true)
            }

            context.startActivity(installIntent)
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed launching PackageInstaller: ${e.message}", e)
            false
        }
    }

    /**
     * Exports the standalone cloned APK file to the phone's public Downloads directory.
     * Saved at /sdcard/Download/ClonedAPKs/<AppName>_Clone_<Badge>.apk
     */
    fun exportClonedApkToDownloads(
        context: Context,
        apkFile: File,
        targetAppName: String,
        displayBadge: String
    ): File? {
        val sanitizedAppName = targetAppName.replace(Regex("[^a-zA-Z0-9_]"), "")
        val fileName = "${sanitizedAppName}_Clone_${displayBadge}.apk"

        return try {
            if (!apkFile.exists() || apkFile.length() == 0L) return null

            // Method 1: Try public Downloads folder
            val downloadsDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
            val exportFolder = File(downloadsDir, "ClonedAPKs").apply { mkdirs() }
            val exportedFile = File(exportFolder, fileName)

            apkFile.copyTo(exportedFile, overwrite = true)

            // Broadcast media scanner
            try {
                val mediaScanIntent = Intent(Intent.ACTION_MEDIA_SCANNER_SCAN_FILE).apply {
                    data = Uri.fromFile(exportedFile)
                }
                context.sendBroadcast(mediaScanIntent)
            } catch (_: Exception) {}

            exportedFile
        } catch (e: Exception) {
            null
        }
    }
}
