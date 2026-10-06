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
import com.virtual.engine.signature.CloneKeyGenerator
import java.io.*
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.security.*
import java.security.cert.CertificateFactory
import java.security.cert.X509Certificate
import java.util.zip.ZipEntry
import java.util.zip.ZipFile
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
        displayBadge: String,
        forceRegenerate: Boolean = false,
        identityProfile: com.virtual.engine.identity.DeviceIdentityProfile? = null
    ): File? {
        val sanitizedAppName = targetAppName.replace(Regex("[^a-zA-Z0-9_]"), "")
        val apkDir = File(context.filesDir, "cloned_apks/$cloneId").apply { mkdirs() }
        val targetApk = File(apkDir, "${sanitizedAppName}_Clone_${displayBadge}.apk")

        if (!forceRegenerate && targetApk.exists() && targetApk.length() > 0L) {
            if (isApkAligned(targetApk)) {
                return targetApk
            } else {
                Log.w(TAG, "Cached APK $targetApk is unaligned or corrupted. Regenerating...")
                targetApk.delete()
            }
        }

        // Clean any leftover temp files
        File(apkDir, "temp_unsigned.apk").delete()
        File(apkDir, "temp_signed.apk").delete()

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

            // 3. Mutate Manifest and Repack APK with pure 4-byte/16KB zipalign & split merging
            val tempUnsignedApk = File(apkDir, "temp_unsigned.apk")
            if (tempUnsignedApk.exists()) tempUnsignedApk.delete()
            repackAndMutateApk(
                srcApk = sourceApk,
                splitApks = bundle.splitApks,
                destApk = tempUnsignedApk,
                targetPackage = targetPackage,
                newPackage = newPackage,
                origCertBytes = if (certFile.exists()) certFile.readBytes() else null,
                identityProfile = identityProfile ?: com.virtual.engine.identity.DeviceIdentityProfile.getProfileForClone(cloneId)
            )

            // 4. Sign APK with official Android ApkSigner (v1 + v2 + v3) using unique identity atomically
            val tempSignedApk = File(apkDir, "temp_signed.apk")
            if (tempSignedApk.exists()) tempSignedApk.delete()
            signApk(context, tempUnsignedApk, tempSignedApk, cloneId)
            tempUnsignedApk.delete()

            if (targetApk.exists()) targetApk.delete()
            tempSignedApk.renameTo(targetApk)

            return targetApk
        } catch (e: Exception) {
            Log.e(TAG, "Failed generating standalone APK: ${e.message}", e)
            return null
        }
    }

    /**
     * Checks if the APK has its native libraries and resources.arsc properly STORED (uncompressed)
     * and not corrupted by standard ZipOutputStream deflater.
     */
    fun isApkAligned(apk: File): Boolean {
        return try {
            ZipFile(apk).use { zf ->
                val entries = zf.entries()
                var hasLibs = false
                while (entries.hasMoreElements()) {
                    val entry = entries.nextElement()
                    if (entry.name.endsWith(".so")) {
                        hasLibs = true
                        if (entry.method != ZipEntry.STORED) return false
                    }
                    if (entry.name == "resources.arsc") {
                        if (entry.method != ZipEntry.STORED) return false
                    }
                }
                true
            }
        } catch (_: Exception) {
            false
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
     * Scans DEX files in source APK and split APKs to catalog all compiled class names.
     * Preserves class names during manifest mutation so Android's ClassLoader can load them.
     */
    private fun extractDexClassNames(srcApk: File, splitApks: List<File>, targetPackage: String): Set<String> {
        val dexClasses = HashSet<String>()
        val pkgSlash = targetPackage.replace('.', '/')
        val classPattern = Regex("L${Regex.escape(pkgSlash)}/([a-zA-Z0-9_/$]+);")

        fun scanApk(apk: File) {
            try {
                java.util.zip.ZipFile(apk).use { zf ->
                    val entries = zf.entries()
                    while (entries.hasMoreElements()) {
                        val entry = entries.nextElement()
                        if (entry.name.endsWith(".dex")) {
                            zf.getInputStream(entry).use { input ->
                                val dexBytes = input.readBytes()
                                val dexText = String(dexBytes, Charsets.ISO_8859_1)
                                for (match in classPattern.findAll(dexText)) {
                                    val rel = match.groupValues[1].replace('/', '.')
                                    dexClasses.add("$targetPackage.$rel")
                                }
                            }
                        }
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "Error scanning DEX in ${apk.name}: ${e.message}")
            }
        }

        scanApk(srcApk)
        for (split in splitApks) {
            if (split.exists() && split.length() > 0) {
                scanApk(split)
            }
        }

        Log.d(TAG, "Cataloged ${dexClasses.size} compiled classes for $targetPackage")
        return dexClasses
    }

    /**
     * Dedicated APK Zip Writer implementing Android-compliant alignment:
     * - resources.arsc: STORED (uncompressed) and 4-byte word aligned
     * - lib native .so: STORED (uncompressed) and 4096-byte page aligned for mmap
     * - classes.dex, assets, drawables: DEFLATED
     */
    private class ApkZipWriter(private val out: OutputStream) : Closeable {
        private var curOffset = 0L
        private val cdRecords = mutableListOf<CdRecord>()

        data class CdRecord(
            val filename: String,
            val nameBytes: ByteArray,
            val method: Int,
            val crc: Long,
            val compSize: Long,
            val uncompSize: Long,
            val lfhOffset: Long
        )

        fun writeEntry(name: String, uncompressedData: ByteArray) {
            val nameBytes = name.toByteArray(Charsets.UTF_8)

            val isResourceArsc = (name == "resources.arsc")
            val isNativeLib = (name.startsWith("lib/") && name.endsWith(".so"))

            val method: Int
            val alignment: Int
            val payload: ByteArray

            if (uncompressedData.isEmpty()) {
                method = 0
                alignment = 0
                payload = ByteArray(0)
            } else if (isResourceArsc) {
                method = 0 // STORED
                alignment = 4
                payload = uncompressedData
            } else if (isNativeLib) {
                method = 0 // STORED
                alignment = 16384 // 16KB page alignment for Android 15 & universal backwards compatibility
                payload = uncompressedData
            } else {
                method = 8 // DEFLATED
                alignment = 0
                val deflater = java.util.zip.Deflater(java.util.zip.Deflater.DEFAULT_COMPRESSION, true)
                deflater.setInput(uncompressedData)
                deflater.finish()
                val deflatedOut = ByteArrayOutputStream(uncompressedData.size)
                val buf = ByteArray(8192)
                while (!deflater.finished()) {
                    val count = deflater.deflate(buf)
                    deflatedOut.write(buf, 0, count)
                }
                deflater.end()
                payload = deflatedOut.toByteArray()
            }

            val crc32 = java.util.zip.CRC32()
            crc32.update(uncompressedData)
            val crc = crc32.value
            val uncompSize = uncompressedData.size.toLong()
            val compSize = payload.size.toLong()

            // Calculate alignment padding in extra field
            // Fixed LFH header = 30 bytes
            val lfhBaseLen = 30 + nameBytes.size
            val extraLen = if (alignment > 0) {
                val dataOffset = curOffset + lfhBaseLen
                val rem = (dataOffset % alignment).toInt()
                if (rem != 0) alignment - rem else 0
            } else {
                0
            }
            val extra = ByteArray(extraLen)

            // Write LFH
            val lfhBuf = ByteBuffer.allocate(30).order(ByteOrder.LITTLE_ENDIAN)
            lfhBuf.putInt(0x04034b50)
            lfhBuf.putShort(20.toShort()) // version needed (2.0)
            lfhBuf.putShort(0.toShort()) // flags
            lfhBuf.putShort(method.toShort())
            lfhBuf.putShort(0.toShort()) // mod time
            lfhBuf.putShort(0.toShort()) // mod date
            lfhBuf.putInt(crc.toInt())
            lfhBuf.putInt(compSize.toInt())
            lfhBuf.putInt(uncompSize.toInt())
            lfhBuf.putShort(nameBytes.size.toShort())
            lfhBuf.putShort(extra.size.toShort())

            out.write(lfhBuf.array())
            out.write(nameBytes)
            if (extra.isNotEmpty()) {
                out.write(extra)
            }
            out.write(payload)

            cdRecords.add(CdRecord(name, nameBytes, method, crc, compSize, uncompSize, curOffset))
            curOffset += 30 + nameBytes.size + extra.size + payload.size
        }

        override fun close() {
            val cdStart = curOffset
            for (rec in cdRecords) {
                val cdBuf = ByteBuffer.allocate(46).order(ByteOrder.LITTLE_ENDIAN)
                cdBuf.putInt(0x02014b50)
                cdBuf.putShort(20.toShort()) // version made by
                cdBuf.putShort(20.toShort()) // version needed
                cdBuf.putShort(0.toShort()) // flags
                cdBuf.putShort(rec.method.toShort())
                cdBuf.putShort(0.toShort()) // mod time
                cdBuf.putShort(0.toShort()) // mod date
                cdBuf.putInt(rec.crc.toInt())
                cdBuf.putInt(rec.compSize.toInt())
                cdBuf.putInt(rec.uncompSize.toInt())
                cdBuf.putShort(rec.nameBytes.size.toShort())
                cdBuf.putShort(0.toShort()) // extra length
                cdBuf.putShort(0.toShort()) // comment length
                cdBuf.putShort(0.toShort()) // disk number start
                cdBuf.putShort(0.toShort()) // internal file attributes
                cdBuf.putInt(0) // external file attributes
                cdBuf.putInt(rec.lfhOffset.toInt())

                out.write(cdBuf.array())
                out.write(rec.nameBytes)
                curOffset += 46 + rec.nameBytes.size
            }

            val cdSize = curOffset - cdStart
            val eocdBuf = ByteBuffer.allocate(22).order(ByteOrder.LITTLE_ENDIAN)
            eocdBuf.putInt(0x06054b50)
            eocdBuf.putShort(0.toShort()) // disk number
            eocdBuf.putShort(0.toShort()) // disk where CD starts
            eocdBuf.putShort(cdRecords.size.toShort())
            eocdBuf.putShort(cdRecords.size.toShort())
            eocdBuf.putInt(cdSize.toInt())
            eocdBuf.putInt(cdStart.toInt())
            eocdBuf.putShort(0.toShort()) // comment length

            out.write(eocdBuf.array())
            out.flush()
            out.close()
        }
    }

    /**
     * Reads source APK zip, mutates AndroidManifest.xml, merges all split APKs (native C++ libs, drawables),
     * embeds orig_cert.bin, strips existing META-INF signatures, and produces a complete self-contained APK
     * with 4-byte and 4096-byte alignment.
     */
    private fun repackAndMutateApk(
        srcApk: File,
        splitApks: List<File>,
        destApk: File,
        targetPackage: String,
        newPackage: String,
        origCertBytes: ByteArray?,
        identityProfile: com.virtual.engine.identity.DeviceIdentityProfile? = null
    ) {
        val dexClasses = extractDexClassNames(srcApk, splitApks, targetPackage)
        val addedEntries = HashSet<String>()

        ApkZipWriter(BufferedOutputStream(FileOutputStream(destApk))).use { apkWriter ->
            ZipFile(srcApk).use { zf ->
                val entries = zf.entries()
                while (entries.hasMoreElements()) {
                    val entry = entries.nextElement()
                    val name = entry.name

                    if (entry.isDirectory || name.endsWith("/")) continue

                    // Skip existing signature blocks to prepare for clean resign
                    if (name.startsWith("META-INF/") &&
                        (name.endsWith(".SF") || name.endsWith(".RSA") || name.endsWith(".DSA") ||
                         name.endsWith(".EC") || name.endsWith(".MF") || name.contains("SIG"))
                    ) {
                        continue
                    }

                    if (name == "AndroidManifest.xml") {
                        val rawManifest = zf.getInputStream(entry).use { it.readBytes() }
                        val mutatedManifest = mutateBinaryManifest(rawManifest, targetPackage, newPackage, dexClasses)
                        apkWriter.writeEntry(name, mutatedManifest)
                        addedEntries.add(name)
                    } else {
                        if (!addedEntries.contains(name)) {
                            val data = zf.getInputStream(entry).use { it.readBytes() }
                            apkWriter.writeEntry(name, data)
                            addedEntries.add(name)
                        }
                    }
                }
            }

            // Merge all split APK entries (native .so files from split_config.arm64_v8a, resources from split_config.xxhdpi, etc.)
            for (split in splitApks) {
                try {
                    ZipFile(split).use { splitZf ->
                        val splitEntries = splitZf.entries()
                        while (splitEntries.hasMoreElements()) {
                            val splitEntry = splitEntries.nextElement()
                            val sName = splitEntry.name
                            if (splitEntry.isDirectory || sName.endsWith("/")) continue
                            if (!sName.startsWith("META-INF/") && 
                                sName != "AndroidManifest.xml" && 
                                !addedEntries.contains(sName)
                            ) {
                                val data = splitZf.getInputStream(splitEntry).use { it.readBytes() }
                                apkWriter.writeEntry(sName, data)
                                addedEntries.add(sName)
                            }
                        }
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "Error merging split ${split.name}: ${e.message}")
                }
            }

            // Inject assets/orig_cert.bin if present
            if (origCertBytes != null && origCertBytes.isNotEmpty()) {
                apkWriter.writeEntry("assets/orig_cert.bin", origCertBytes)
                addedEntries.add("assets/orig_cert.bin")
            }

            // Inject assets/clone_identity.json with virtual hardware profile
            val identityJson = identityProfile?.toJson()?.toString(2)
            if (identityJson != null) {
                apkWriter.writeEntry("assets/clone_identity.json", identityJson.toByteArray(Charsets.UTF_8))
                addedEntries.add("assets/clone_identity.json")
            }
        }
    }

    /**
     * Binary AndroidManifest.xml (AXML) StringPool Mutator.
     * Rewrites package name and authority references across UTF-8 or UTF-16LE string pools,
     * neutralizes App Bundle split requirements, and preserves compiled DEX class names.
     */
    fun mutateBinaryManifest(
        manifestBytes: ByteArray,
        targetPackage: String,
        newPackage: String,
        dexClasses: Set<String> = emptySet()
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
                if ((charLen and 0x80) != 0) {
                    charLen = ((charLen and 0x7F) shl 8) or (manifestBytes[pos].toInt() and 0xFF)
                    pos++
                }
                var byteLen = manifestBytes[pos].toInt() and 0xFF
                pos++
                if ((byteLen and 0x80) != 0) {
                    byteLen = ((byteLen and 0x7F) shl 8) or (manifestBytes[pos].toInt() and 0xFF)
                    pos++
                }
                val str = String(manifestBytes, pos, byteLen.coerceAtMost(manifestBytes.size - pos), Charsets.UTF_8)
                strings.add(str)
            } else {
                // UTF-16LE string: 2-4 bytes char count, 2*charLen bytes, 0x0000
                var pos = offset
                var charLen = (manifestBytes[pos].toInt() and 0xFF) or ((manifestBytes[pos + 1].toInt() and 0xFF) shl 8)
                pos += 2
                if ((charLen and 0x8000) != 0) {
                    val high = charLen and 0x7FFF
                    val low = (manifestBytes[pos].toInt() and 0xFF) or ((manifestBytes[pos + 1].toInt() and 0xFF) shl 8)
                    pos += 2
                    charLen = (high shl 16) or low
                }
                val byteLen = charLen * 2
                val str = if (pos + byteLen <= manifestBytes.size) {
                    String(manifestBytes, pos, byteLen, Charsets.UTF_16LE)
                } else ""
                strings.add(str)
            }
        }

        // Apply mutation to target package, provider authorities, and neutralize App Bundle splits
        var replacedAny = false
        val mutatedStrings = strings.map { str ->
            when {
                str == targetPackage -> {
                    replacedAny = true
                    newPackage
                }
                str == "com.android.vending.splits.required" -> {
                    replacedAny = true
                    "com.android.vending.splits.disabled"
                }
                str.contains("base__abi") || str == "base__abi,base__density" -> {
                    replacedAny = true
                    ""
                }
                str.contains(targetPackage) -> {
                    val isClass = if (dexClasses.isNotEmpty()) {
                        dexClasses.contains(str)
                    } else {
                        str.endsWith("Activity") || str.endsWith("Application") ||
                        str.endsWith("Service") || str.endsWith("Receiver")
                    }

                    if (isClass) {
                        str // Keep original compiled Java/Kotlin class name!
                    } else {
                        replacedAny = true
                        str.replace(targetPackage, newPackage)
                    }
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
                val charLen = s.length
                val byteLen = utf8Bytes.size

                // Write charLen (1 or 2 bytes per AXML spec)
                if (charLen > 0x7F) {
                    stringDataOut.write(((charLen shr 8) and 0x7F) or 0x80)
                    stringDataOut.write(charLen and 0xFF)
                } else {
                    stringDataOut.write(charLen)
                }

                // Write byteLen (1 or 2 bytes per AXML spec)
                if (byteLen > 0x7F) {
                    stringDataOut.write(((byteLen shr 8) and 0x7F) or 0x80)
                    stringDataOut.write(byteLen and 0xFF)
                } else {
                    stringDataOut.write(byteLen)
                }

                stringDataOut.write(utf8Bytes)
                stringDataOut.write(0)
            } else {
                val utf16Bytes = s.toByteArray(Charsets.UTF_16LE)
                val charLen = s.length
                if (charLen > 0x7FFF) {
                    val high = ((charLen shr 16) and 0x7FFF) or 0x8000
                    val low = charLen and 0xFFFF
                    stringDataOut.write(high and 0xFF)
                    stringDataOut.write((high shr 8) and 0xFF)
                    stringDataOut.write(low and 0xFF)
                    stringDataOut.write((low shr 8) and 0xFF)
                } else {
                    stringDataOut.write(charLen and 0xFF)
                    stringDataOut.write((charLen shr 8) and 0xFF)
                }
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
     * Signs the generated APK using official Android ApkSigner with v1, v2, and v3 schemes
     * and a unique signing key for this specific clone ID.
     */
    private fun signApk(context: Context, unsignedApk: File, signedApk: File, cloneId: Int) {
        val keystoreDir = File(context.filesDir, "keystores")
        val identity = CloneKeyGenerator.getOrCreateSigningIdentity(keystoreDir, cloneId)
        val privateKey = identity.privateKey
        val cert = identity.certificate

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
