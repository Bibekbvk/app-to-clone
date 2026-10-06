package com.virtual.engine.signature

import android.util.Log
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.math.BigInteger
import java.security.KeyPair
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.PrivateKey
import java.security.SecureRandom
import java.security.Signature
import java.security.cert.CertificateFactory
import java.security.cert.X509Certificate
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

/**
 * Per-Clone Signing Key Generator.
 *
 * Generates a unique RSA-2048 keypair and self-signed X.509 certificate for each clone ID,
 * ensuring Android treats every standalone cloned APK as a completely independent developer identity.
 * This prevents AccountManager cross-talk, shared content provider access, and session bleed
 * between clones signed by different certificates.
 *
 * Certificates are generated using pure Java crypto APIs with manual DER/ASN.1 encoding —
 * no BouncyCastle or external dependencies required.
 */
object CloneKeyGenerator {

    private const val TAG = "CloneKeyGen"

    data class CloneSigningIdentity(
        val keyStore: KeyStore,
        val privateKey: PrivateKey,
        val certificate: X509Certificate,
        val alias: String,
        val password: CharArray
    )

    /**
     * Retrieves or generates a unique PKCS12 keystore for the given clone ID.
     * The keystore is cached at [keystoreDir]/clone_<cloneId>.p12.
     */
    fun getOrCreateSigningIdentity(keystoreDir: File, cloneId: Int): CloneSigningIdentity {
        keystoreDir.mkdirs()
        val alias = "clone_$cloneId"
        val password = generateDeterministicPassword(cloneId, keystoreDir).toCharArray()
        val keystoreFile = File(keystoreDir, "clone_${cloneId}.p12")

        // Return cached keystore if it exists
        if (keystoreFile.exists() && keystoreFile.length() > 0) {
            try {
                val ks = KeyStore.getInstance("PKCS12")
                FileInputStream(keystoreFile).use { ks.load(it, password) }
                val key = ks.getKey(alias, password) as PrivateKey
                val cert = ks.getCertificate(alias) as X509Certificate
                return CloneSigningIdentity(ks, key, cert, alias, password)
            } catch (e: Exception) {
                Log.w(TAG, "Cached keystore corrupt for clone $cloneId, regenerating: ${e.message}")
                keystoreFile.delete()
            }
        }

        // Generate fresh RSA-2048 keypair
        val kpg = KeyPairGenerator.getInstance("RSA")
        kpg.initialize(2048, SecureRandom())
        val keyPair = kpg.generateKeyPair()

        // Create self-signed X.509 certificate
        val cert = createSelfSignedCertificate(keyPair, "CN=CloneApp_$cloneId, O=VirtualEngine")

        // Store in PKCS12 keystore
        val ks = KeyStore.getInstance("PKCS12")
        ks.load(null, null)
        ks.setKeyEntry(alias, keyPair.private, password, arrayOf(cert))
        FileOutputStream(keystoreFile).use { ks.store(it, password) }

        Log.i(TAG, "Generated unique signing identity for clone $cloneId")
        return CloneSigningIdentity(ks, keyPair.private, cert, alias, password)
    }

    /**
     * Generates a deterministic but installation-unique password for the keystore.
     */
    private fun generateDeterministicPassword(cloneId: Int, dir: File): String {
        val seed = "${cloneId}_${dir.absolutePath}"
        return "ck_${seed.hashCode().toUInt().toString(36)}_${cloneId}"
    }

    // =========================================================================
    // Self-Signed X.509 Certificate Generation (Pure DER/ASN.1 Encoding)
    // =========================================================================

    /**
     * Creates a self-signed X.509 v3 certificate using manual DER encoding.
     * Valid for 25 years with SHA256withRSA signature.
     */
    private fun createSelfSignedCertificate(keyPair: KeyPair, distinguishedName: String): X509Certificate {
        val serial = BigInteger(64, SecureRandom())
        val now = System.currentTimeMillis()
        // Backdate 1 day to prevent clock skew across devices
        val notBefore = Date(now - 24L * 3600 * 1000)
        // 20 years validity keeps expiration before year 2050 (e.g. 2026 -> 2046)
        // so RFC 5280 UTCTime formatting (yyMMddHHmmss'Z') parses safely as 2046, not 1951!
        val notAfter = Date(now + 20L * 365 * 24 * 3600 * 1000)

        // Parse CN and O from the distinguished name string
        val cnValue = Regex("CN=([^,]+)").find(distinguishedName)?.groupValues?.get(1)?.trim() ?: "CloneApp"
        val oValue = Regex("O=([^,]+)").find(distinguishedName)?.groupValues?.get(1)?.trim()

        // Build TBS (To-Be-Signed) Certificate body
        val tbsContent = ByteArrayOutputStream()

        // 1. Version: [0] EXPLICIT { INTEGER 2 } → X.509 v3
        tbsContent.write(derContextTag(0, derInteger(BigInteger.valueOf(2))))

        // 2. Serial Number
        tbsContent.write(derInteger(serial))

        // 3. Signature Algorithm: SHA256withRSA (OID 1.2.840.113549.1.1.11)
        tbsContent.write(SHA256_WITH_RSA_ALGORITHM_ID)

        // 4. Issuer: Distinguished Name
        tbsContent.write(encodeDN(cnValue, oValue))

        // 5. Validity: { notBefore, notAfter }
        tbsContent.write(encodeValidity(notBefore, notAfter))

        // 6. Subject: same as Issuer (self-signed)
        tbsContent.write(encodeDN(cnValue, oValue))

        // 7. SubjectPublicKeyInfo: from the public key's standard encoding
        tbsContent.write(keyPair.public.encoded)

        val tbsCertificate = derSequence(tbsContent.toByteArray())

        // Sign the TBS Certificate
        val signer = Signature.getInstance("SHA256withRSA")
        signer.initSign(keyPair.private)
        signer.update(tbsCertificate)
        val signatureBytes = signer.sign()

        // Assemble final Certificate: SEQUENCE { TBS, AlgorithmID, Signature }
        val certContent = ByteArrayOutputStream()
        certContent.write(tbsCertificate)
        certContent.write(SHA256_WITH_RSA_ALGORITHM_ID)
        certContent.write(derBitString(signatureBytes))

        val certDer = derSequence(certContent.toByteArray())

        // Parse back through CertificateFactory to get a proper X509Certificate object
        val cf = CertificateFactory.getInstance("X.509")
        return cf.generateCertificate(ByteArrayInputStream(certDer)) as X509Certificate
    }

    // =========================================================================
    // DER / ASN.1 Encoding Primitives
    // =========================================================================

    /** SHA256withRSA AlgorithmIdentifier: SEQUENCE { OID 1.2.840.113549.1.1.11, NULL } */
    private val SHA256_WITH_RSA_ALGORITHM_ID = byteArrayOf(
        0x30, 0x0d,                                                 // SEQUENCE (13 bytes)
        0x06, 0x09,                                                 // OID (9 bytes)
        0x2a, 0x86.toByte(), 0x48, 0x86.toByte(), 0xf7.toByte(),   // 1.2.840.113549
        0x0d, 0x01, 0x01, 0x0b,                                     // .1.1.11
        0x05, 0x00                                                   // NULL
    )

    /** OID for CommonName (2.5.4.3) */
    private val OID_CN = byteArrayOf(0x55, 0x04, 0x03)

    /** OID for Organization (2.5.4.10) */
    private val OID_O = byteArrayOf(0x55, 0x04, 0x0a)

    private fun derTag(tag: Byte, content: ByteArray): ByteArray {
        val out = ByteArrayOutputStream(2 + content.size)
        out.write(tag.toInt())
        derWriteLength(out, content.size)
        out.write(content)
        return out.toByteArray()
    }

    private fun derWriteLength(out: ByteArrayOutputStream, length: Int) {
        when {
            length < 0x80 -> out.write(length)
            length < 0x100 -> {
                out.write(0x81)
                out.write(length)
            }
            length < 0x10000 -> {
                out.write(0x82)
                out.write((length shr 8) and 0xFF)
                out.write(length and 0xFF)
            }
            else -> {
                out.write(0x83)
                out.write((length shr 16) and 0xFF)
                out.write((length shr 8) and 0xFF)
                out.write(length and 0xFF)
            }
        }
    }

    private fun derSequence(content: ByteArray): ByteArray = derTag(0x30, content)

    private fun derSet(content: ByteArray): ByteArray = derTag(0x31, content)

    private fun derInteger(value: BigInteger): ByteArray = derTag(0x02, value.toByteArray())

    private fun derOid(oid: ByteArray): ByteArray = derTag(0x06, oid)

    private fun derUtf8String(value: String): ByteArray = derTag(0x0c, value.toByteArray(Charsets.UTF_8))

    private fun derBitString(content: ByteArray): ByteArray {
        val padded = ByteArray(content.size + 1)
        padded[0] = 0 // zero unused bits
        System.arraycopy(content, 0, padded, 1, content.size)
        return derTag(0x03, padded)
    }

    private fun derUtcTime(date: Date): ByteArray {
        val fmt = SimpleDateFormat("yyMMddHHmmss'Z'", Locale.US)
        fmt.timeZone = TimeZone.getTimeZone("UTC")
        return derTag(0x17, fmt.format(date).toByteArray(Charsets.US_ASCII))
    }

    private fun derContextTag(tagNumber: Int, content: ByteArray): ByteArray {
        val tag = (0xa0 or (tagNumber and 0x1f)).toByte()
        return derTag(tag, content)
    }

    /**
     * Encodes a Distinguished Name with CN and optional O attributes.
     * Structure: SEQUENCE { SET { SEQUENCE { OID, UTF8String } }, ... }
     */
    private fun encodeDN(cn: String, org: String?): ByteArray {
        val rdns = ByteArrayOutputStream()

        // RDN for CN
        val cnAtv = derSequence(derOid(OID_CN) + derUtf8String(cn))
        rdns.write(derSet(cnAtv))

        // RDN for O (if provided)
        if (!org.isNullOrBlank()) {
            val oAtv = derSequence(derOid(OID_O) + derUtf8String(org))
            rdns.write(derSet(oAtv))
        }

        return derSequence(rdns.toByteArray())
    }

    /**
     * Encodes Validity: SEQUENCE { UTCTime notBefore, UTCTime notAfter }
     */
    private fun encodeValidity(notBefore: Date, notAfter: Date): ByteArray {
        return derSequence(derUtcTime(notBefore) + derUtcTime(notAfter))
    }

    private operator fun ByteArray.plus(other: ByteArray): ByteArray {
        val result = ByteArray(this.size + other.size)
        System.arraycopy(this, 0, result, 0, this.size)
        System.arraycopy(other, 0, result, this.size, other.size)
        return result
    }
}
