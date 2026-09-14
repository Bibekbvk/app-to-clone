package com.virtual.ui

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import android.net.Uri
import androidx.core.content.pm.ShortcutInfoCompat
import androidx.core.content.pm.ShortcutManagerCompat
import androidx.core.graphics.drawable.IconCompat
import com.virtual.routing.ContainerStubRegistry

/**
 * Helper object for pinning cloned instances directly to the Android OS Home screen (Desktop / App Menu),
 * generating high-contrast badged icons, and managing dynamic launcher shortcuts.
 */
object ShortcutHelper {

    /**
     * Generates a crisp launcher icon bitmap with the host app/target app logo
     * and a stylish neon cyan number badge overlay (e.g. C-01, 1, 2) on the bottom-right.
     */
    fun createBadgedIconBitmap(
        context: Context,
        packageName: String,
        appName: String,
        badgeNumber: String
    ): Bitmap {
        val size = 192 // Standard 192x192 launcher icon size
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)

        // 1. Draw base app icon
        val baseDrawable = try {
            context.packageManager.getApplicationIcon(packageName)
        } catch (e: Exception) {
            null
        }

        if (baseDrawable != null) {
            baseDrawable.setBounds(14, 14, size - 14, size - 14)
            baseDrawable.draw(canvas)
        } else {
            // Draw branded rounded tile fallback
            val brandColor = getBrandColorInt(packageName, appName)
            val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = brandColor
            }
            canvas.drawRoundRect(RectF(14f, 14f, size - 14f, size - 14f), 40f, 40f, bgPaint)

            val letterPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = 0xFFFFFFFF.toInt()
                textSize = size * 0.44f
                typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
                textAlign = Paint.Align.CENTER
            }
            val initialLetter = appName.trim().firstOrNull()?.uppercase() ?: "C"
            val fontMetrics = letterPaint.fontMetrics
            val textY = (size / 2f) - (fontMetrics.ascent + fontMetrics.descent) / 2f
            canvas.drawText(initialLetter, size / 2f, textY, letterPaint)
        }

        // 2. Draw Cyan number badge in bottom-right corner
        val badgeSize = size * 0.42f
        val badgeX = size - badgeSize - 4f
        val badgeY = size - badgeSize - 4f

        val badgePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = 0xFF00E5FF.toInt() // Neon Cyan
            style = Paint.Style.FILL
        }
        val borderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = 0xFF0A0E1A.toInt() // Dark contrast border
            style = Paint.Style.STROKE
            strokeWidth = 6f
        }
        val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = 0xFF0A0E1A.toInt()
            textSize = badgeSize * 0.50f
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
            textAlign = Paint.Align.CENTER
        }

        val cx = badgeX + badgeSize / 2f
        val cy = badgeY + badgeSize / 2f
        val r = badgeSize / 2f

        canvas.drawCircle(cx, cy, r, badgePaint)
        canvas.drawCircle(cx, cy, r, borderPaint)

        val fontMetrics = textPaint.fontMetrics
        val textY = cy - (fontMetrics.ascent + fontMetrics.descent) / 2f
        canvas.drawText(badgeNumber, cx, textY, textPaint)

        return bitmap
    }

    private fun getBrandColorInt(packageName: String, appName: String): Int {
        val hash = (packageName + appName).hashCode()
        val palette = intArrayOf(
            0xFF1E88E5.toInt(), // Blue
            0xFF43A047.toInt(), // Green
            0xFFFB8C00.toInt(), // Orange
            0xFF8E24AA.toInt(), // Purple
            0xFFE53935.toInt(), // Red
            0xFF00ACC1.toInt(), // Cyan
            0xFF00897B.toInt(), // Teal
            0xFF3949AB.toInt(), // Indigo
            0xFFD81B60.toInt(), // Pink
            0xFF5E35B1.toInt()  // Deep Purple
        )
        val index = kotlin.math.abs(hash) % palette.size
        return palette[index]
    }

    /**
     * Pins a standalone app shortcut to the Android phone's Home screen / Launcher desktop.
     * When tapped directly from the phone's launcher, it directly launches the assigned :worker_XX process.
     */
    fun pinCloneShortcutToPhoneHomeScreen(
        context: Context,
        profileId: Int,
        packageName: String,
        displayName: String?,
        isSingleTask: Boolean = true
    ): Boolean {
        if (!ShortcutManagerCompat.isRequestPinShortcutSupported(context)) {
            return false
        }

        val stubClassName = ContainerStubRegistry.getStubActivityClass(profileId, isSingleTask)
        val launchIntent = Intent().apply {
            setClassName(context.packageName, stubClassName)
            data = Uri.parse("clone://instance/$profileId")
            action = "com.virtual.action.LAUNCH_CLONE_$profileId"
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_MULTIPLE_TASK or
                    Intent.FLAG_ACTIVITY_NEW_DOCUMENT
            putExtra("com.virtual.EXTRA_PROFILE_ID", profileId)
            putExtra("com.virtual.EXTRA_TARGET_PACKAGE", packageName)
            putExtra("EXTRA_PROFILE_ID", profileId)
            val effectiveName = displayName?.takeIf { it.isNotEmpty() } ?: packageName
            putExtra("EXTRA_PROFILE_NAME", effectiveName)
            putExtra("EXTRA_TARGET_APP_NAME", effectiveName)
            putExtra("EXTRA_TARGET_PKG", packageName)
            val badgeLabel = "C-${String.format("%02d", profileId)}"
            putExtra("EXTRA_DISPLAY_BADGE", badgeLabel)
        }

        val effectiveTitle = displayName?.takeIf { it.isNotEmpty() } ?: packageName
        val badgeLabel = "C-${String.format("%02d", profileId)}"

        val badgedBitmap = createBadgedIconBitmap(
            context = context,
            packageName = packageName,
            appName = effectiveTitle,
            badgeNumber = badgeLabel
        )
        val iconCompat = IconCompat.createWithBitmap(badgedBitmap)

        val shortcutInfo = ShortcutInfoCompat.Builder(context, "clone_instance_$profileId")
            .setShortLabel(effectiveTitle)
            .setLongLabel("$effectiveTitle ($badgeLabel)")
            .setIcon(iconCompat)
            .setIntent(launchIntent)
            .setAlwaysBadged()
            .build()

        return ShortcutManagerCompat.requestPinShortcut(context, shortcutInfo, null)
    }

    /**
     * Updates Android Dynamic Launcher shortcuts so when user long-presses
     * the app icon in the phone's launcher/app drawer, recent clones are immediately available.
     */
    fun updateDynamicLauncherShortcuts(
        context: Context,
        clonesList: List<Map<String, Any?>>
    ) {
        try {
            val shortcutList = clonesList.take(4).map { record ->
                val profileId = (record["id"] as? Number)?.toInt() ?: 1
                val packageName = (record["packageName"] as? String) ?: "com.app.clone"
                val displayName = record["displayName"] as? String
                val effectiveName = displayName?.takeIf { it.isNotEmpty() } ?: packageName
                val isSingleTask = (record["isSingleTask"] as? Boolean) ?: true
                val badgeLabel = "C-${String.format("%02d", profileId)}"

                val stubClassName = ContainerStubRegistry.getStubActivityClass(profileId, isSingleTask)
                val launchIntent = Intent().apply {
                    setClassName(context.packageName, stubClassName)
                    data = Uri.parse("clone://instance/$profileId")
                    action = "com.virtual.action.LAUNCH_CLONE_$profileId"
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                            Intent.FLAG_ACTIVITY_MULTIPLE_TASK or
                            Intent.FLAG_ACTIVITY_NEW_DOCUMENT
                    putExtra("com.virtual.EXTRA_PROFILE_ID", profileId)
                    putExtra("com.virtual.EXTRA_TARGET_PACKAGE", packageName)
                    putExtra("EXTRA_PROFILE_ID", profileId)
                    putExtra("EXTRA_PROFILE_NAME", effectiveName)
                    putExtra("EXTRA_TARGET_APP_NAME", effectiveName)
                    putExtra("EXTRA_TARGET_PKG", packageName)
                    putExtra("EXTRA_DISPLAY_BADGE", badgeLabel)
                }

                val badgedBitmap = createBadgedIconBitmap(
                    context = context,
                    packageName = packageName,
                    appName = effectiveName,
                    badgeNumber = badgeLabel
                )

                ShortcutInfoCompat.Builder(context, "clone_dynamic_$profileId")
                    .setShortLabel(effectiveName)
                    .setLongLabel("$effectiveName ($badgeLabel)")
                    .setIcon(IconCompat.createWithBitmap(badgedBitmap))
                    .setIntent(launchIntent)
                    .build()
            }
            ShortcutManagerCompat.setDynamicShortcuts(context, shortcutList)
        } catch (e: Exception) {
            // Non-fatal if launcher does not support dynamic shortcuts
        }
    }
}
