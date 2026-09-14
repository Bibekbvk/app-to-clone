package com.virtual.routing

import android.app.Activity
import android.app.ActivityManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
import java.io.File

/**
 * 25-Stub Component definitions for standard and singleTask launchModes
 * across isolated processes :worker_01 through :worker_25.
 */
object ContainerStubRegistry {
    const val MAX_INSTANCES = 25

    fun getStubActivityClass(profileId: Int, isSingleTask: Boolean = false): String {
        val index = ((profileId - 1).coerceAtLeast(0) % MAX_INSTANCES) + 1
        val pad = String.format("%02d", index)
        return if (isSingleTask) {
            "com.virtual.routing.ContainerStubActivity_SingleTask_P$pad"
        } else {
            "com.virtual.routing.ContainerStubActivity_P$pad"
        }
    }

    fun getStubServiceClass(profileId: Int): String {
        val index = ((profileId - 1).coerceAtLeast(0) % MAX_INSTANCES) + 1
        val pad = String.format("%02d", index)
        return "com.virtual.routing.ContainerStubService_P$pad"
    }

    fun getProcessName(profileId: Int): String {
        val index = ((profileId - 1).coerceAtLeast(0) % MAX_INSTANCES) + 1
        return ":worker_${String.format("%02d", index)}"
    }
}

/**
 * Base Activity representing an isolated virtual container slot.
 * Renders an isolated workspace UI with dedicated TaskDescription in the Android Recents switcher.
 */
open class BaseContainerStubActivity : Activity() {

    private lateinit var storageContext: com.virtual.fs.ContainerStorageContext

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val profileId = intent.getIntExtra("com.virtual.EXTRA_PROFILE_ID", 
            intent.getIntExtra("EXTRA_PROFILE_ID", 1))
        val targetPackage = intent.getStringExtra("com.virtual.EXTRA_TARGET_PACKAGE")
            ?: intent.getStringExtra("EXTRA_TARGET_PKG") ?: "com.app.clone"
        val profileName = intent.getStringExtra("EXTRA_PROFILE_NAME")
        val targetAppName = intent.getStringExtra("EXTRA_TARGET_APP_NAME") ?: targetPackage
        val displayBadge = intent.getStringExtra("EXTRA_DISPLAY_BADGE") ?: "C-${String.format("%02d", profileId)}"
        val cardTitle = profileName?.takeIf { it.isNotEmpty() } ?: "$targetAppName ($displayBadge)"

        // Multi-process WebView storage isolation: ensures separate cookies, local storage, and caches
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val processPad = String.format("%02d", ((profileId - 1) % 25) + 1)
            try {
                android.webkit.WebView.setDataDirectorySuffix("worker_$processPad")
            } catch (e: Exception) {
                // Ignore if already set in this process
            }
        }

        // Initialize dedicated virtualized storage context (files, db WAL, isolated prefs)
        storageContext = com.virtual.fs.ContainerStorageContext(this, profileId, targetPackage)

        // 1. Task Description for Android OS Recents Switcher (Distinct task card per clone)
        val color = when (profileId % 6) {
            0 -> Color.parseColor("#1E88E5")
            1 -> Color.parseColor("#43A047")
            2 -> Color.parseColor("#FB8C00")
            3 -> Color.parseColor("#8E24AA")
            4 -> Color.parseColor("#E53935")
            else -> Color.parseColor("#00ACC1")
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            try {
                val td = ActivityManager.TaskDescription.Builder()
                    .setLabel(cardTitle)
                    .setPrimaryColor(color)
                    .build()
                setTaskDescription(td)
            } catch (e: Exception) {
                // Ignore fallback
            }
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            @Suppress("DEPRECATION")
            try {
                setTaskDescription(ActivityManager.TaskDescription(cardTitle, null, color))
            } catch (e: Exception) {
                // Ignore fallback
            }
        }

        // 2. Build Isolated Sandbox UI
        val rootView = buildContainerUi(profileId, targetPackage, targetAppName, displayBadge, cardTitle)
        setContentView(rootView)
    }

    private fun buildContainerUi(
        profileId: Int,
        targetPackage: String,
        targetAppName: String,
        displayBadge: String,
        cardTitle: String
    ): View {
        val dp = resources.displayMetrics.density

        val scrollView = ScrollView(this).apply {
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
            setBackgroundColor(Color.parseColor("#0F172A")) // Slate 900
            isFillViewport = true
        }

        val container = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
            setPadding((24 * dp).toInt(), (40 * dp).toInt(), (24 * dp).toInt(), (32 * dp).toInt())
            gravity = Gravity.CENTER_HORIZONTAL
        }

        // Top Status Badge
        val topBadge = TextView(this).apply {
            text = "VIRTUAL SANDBOX CONTAINER [SLOT $profileId]"
            setTextColor(Color.parseColor("#38BDF8")) // Sky 400
            textSize = 12f
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            setPadding((12 * dp).toInt(), (6 * dp).toInt(), (12 * dp).toInt(), (6 * dp).toInt())
            background = GradientDrawable().apply {
                cornerRadius = 16 * dp
                setColor(Color.parseColor("#1E293B"))
                setStroke((1 * dp).toInt(), Color.parseColor("#0284C7"))
            }
        }
        container.addView(topBadge)

        // App Icon
        val iconView = ImageView(this).apply {
            layoutParams = LinearLayout.LayoutParams((84 * dp).toInt(), (84 * dp).toInt()).apply {
                topMargin = (24 * dp).toInt()
                bottomMargin = (16 * dp).toInt()
            }
            try {
                val appIcon = packageManager.getApplicationIcon(targetPackage)
                setImageDrawable(appIcon)
            } catch (e: Exception) {
                setImageResource(android.R.drawable.sym_def_app_icon)
            }
        }
        container.addView(iconView)

        // App Title
        val titleView = TextView(this).apply {
            text = cardTitle
            setTextColor(Color.WHITE)
            textSize = 22f
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
        }
        container.addView(titleView)

        // Package Name
        val packageView = TextView(this).apply {
            text = targetPackage
            setTextColor(Color.parseColor("#94A3B8"))
            textSize = 13f
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                topMargin = (4 * dp).toInt()
                bottomMargin = (24 * dp).toInt()
            }
        }
        container.addView(packageView)

        // Info Card
        val infoCard = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomMargin = (28 * dp).toInt()
            }
            setPadding((16 * dp).toInt(), (16 * dp).toInt(), (16 * dp).toInt(), (16 * dp).toInt())
            background = GradientDrawable().apply {
                cornerRadius = 12 * dp
                setColor(Color.parseColor("#1E293B")) // Slate 800
                setStroke((1 * dp).toInt(), Color.parseColor("#334155"))
            }
        }

        val workerPad = String.format("%02d", ((profileId - 1) % 25) + 1)
        val storageKb = try {
            val bytes = storageContext.getStorageFootprintBytes()
            (bytes / 1024L).coerceAtLeast(4L)
        } catch (e: Exception) { 4L }

        addInfoRow(infoCard, "Process Slot", ":worker_$workerPad", "#38BDF8", dp)
        addInfoRow(infoCard, "Multi-Task Affinity", "com.virtual.host.slot_$workerPad", "#E2E8F0", dp)
        addInfoRow(infoCard, "Clone Badge", displayBadge, "#F59E0B", dp)
        addInfoRow(infoCard, "Storage Directory", storageContext.profileRootDir.absolutePath, "#A855F7", dp)
        addInfoRow(infoCard, "Storage Footprint", "$storageKb KB (Isolated)", "#34D399", dp)
        addInfoRow(infoCard, "Data Isolation", "WAL SQLite + Direct XML Prefs", "#38BDF8", dp)
        addInfoRow(infoCard, "Sandbox Status", "ACTIVE & ISOLATED", "#10B981", dp)

        container.addView(infoCard)

        // Pin to Phone Desktop Button
        val pinBtn = Button(this).apply {
            text = "Pin to Phone Desktop (Home Screen)"
            setTextColor(Color.parseColor("#0A0E1A"))
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                (48 * dp).toInt()
            ).apply {
                bottomMargin = (12 * dp).toInt()
            }
            background = GradientDrawable().apply {
                cornerRadius = 10 * dp
                setColor(Color.parseColor("#00E5FF")) // Neon Cyan
            }
            setOnClickListener {
                val ok = com.virtual.ui.ShortcutHelper.pinCloneShortcutToPhoneHomeScreen(
                    context = this@BaseContainerStubActivity,
                    profileId = profileId,
                    packageName = targetPackage,
                    displayName = cardTitle,
                    isSingleTask = true
                )
                if (ok) {
                    Toast.makeText(this@BaseContainerStubActivity, "Desktop shortcut request sent!", Toast.LENGTH_SHORT).show()
                } else {
                    Toast.makeText(this@BaseContainerStubActivity, "Home screen shortcut pinned or not supported by launcher", Toast.LENGTH_SHORT).show()
                }
            }
        }
        container.addView(pinBtn)

        // Launch Guest App Button
        val launchBtn = Button(this).apply {
            text = "Launch Guest Application"
            setTextColor(Color.WHITE)
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                (50 * dp).toInt()
            ).apply {
                bottomMargin = (12 * dp).toInt()
            }
            background = GradientDrawable().apply {
                cornerRadius = 10 * dp
                setColor(Color.parseColor("#6366F1")) // Indigo 500
            }
            setOnClickListener {
                try {
                    val launchIntent = packageManager.getLaunchIntentForPackage(targetPackage)
                    if (launchIntent != null) {
                        launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(launchIntent)
                    } else {
                        Toast.makeText(
                            this@BaseContainerStubActivity,
                            "Guest application '$targetPackage' not installed on device.",
                            Toast.LENGTH_LONG
                        ).show()
                    }
                } catch (e: Exception) {
                    Toast.makeText(
                        this@BaseContainerStubActivity,
                        "Launch error: ${e.message}",
                        Toast.LENGTH_SHORT
                    ).show()
                }
            }
        }
        container.addView(launchBtn)

        // Close / Back Button
        val closeBtn = Button(this).apply {
            text = "Back to Clone Manager"
            setTextColor(Color.parseColor("#94A3B8"))
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                (46 * dp).toInt()
            )
            background = GradientDrawable().apply {
                cornerRadius = 10 * dp
                setColor(Color.parseColor("#1E293B"))
                setStroke((1 * dp).toInt(), Color.parseColor("#334155"))
            }
            setOnClickListener {
                finish()
            }
        }
        container.addView(closeBtn)

        scrollView.addView(container)
        return scrollView
    }

    private fun addInfoRow(parent: LinearLayout, label: String, value: String, valueColor: String, dp: Float) {
        val row = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                topMargin = (4 * dp).toInt()
                bottomMargin = (4 * dp).toInt()
            }
        }
        val labelView = TextView(this).apply {
            text = label
            setTextColor(Color.parseColor("#64748B")) // Slate 500
            textSize = 12f
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
        }
        val valueView = TextView(this).apply {
            text = value
            setTextColor(Color.parseColor(valueColor))
            textSize = 12f
            gravity = Gravity.END
            typeface = android.graphics.Typeface.MONOSPACE
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1.8f)
        }
        row.addView(labelView)
        row.addView(valueView)
        parent.addView(row)
    }
}

// ----------------- Standard LaunchMode Stub Activities (P01 to P25) -----------------
class ContainerStubActivity_P01 : BaseContainerStubActivity()
class ContainerStubActivity_P02 : BaseContainerStubActivity()
class ContainerStubActivity_P03 : BaseContainerStubActivity()
class ContainerStubActivity_P04 : BaseContainerStubActivity()
class ContainerStubActivity_P05 : BaseContainerStubActivity()
class ContainerStubActivity_P06 : BaseContainerStubActivity()
class ContainerStubActivity_P07 : BaseContainerStubActivity()
class ContainerStubActivity_P08 : BaseContainerStubActivity()
class ContainerStubActivity_P09 : BaseContainerStubActivity()
class ContainerStubActivity_P10 : BaseContainerStubActivity()
class ContainerStubActivity_P11 : BaseContainerStubActivity()
class ContainerStubActivity_P12 : BaseContainerStubActivity()
class ContainerStubActivity_P13 : BaseContainerStubActivity()
class ContainerStubActivity_P14 : BaseContainerStubActivity()
class ContainerStubActivity_P15 : BaseContainerStubActivity()
class ContainerStubActivity_P16 : BaseContainerStubActivity()
class ContainerStubActivity_P17 : BaseContainerStubActivity()
class ContainerStubActivity_P18 : BaseContainerStubActivity()
class ContainerStubActivity_P19 : BaseContainerStubActivity()
class ContainerStubActivity_P20 : BaseContainerStubActivity()
class ContainerStubActivity_P21 : BaseContainerStubActivity()
class ContainerStubActivity_P22 : BaseContainerStubActivity()
class ContainerStubActivity_P23 : BaseContainerStubActivity()
class ContainerStubActivity_P24 : BaseContainerStubActivity()
class ContainerStubActivity_P25 : BaseContainerStubActivity()

// ----------------- SingleTask LaunchMode Stub Activities (P01 to P25) -----------------
class ContainerStubActivity_SingleTask_P01 : BaseContainerStubActivity()
class ContainerStubActivity_SingleTask_P02 : BaseContainerStubActivity()
class ContainerStubActivity_SingleTask_P03 : BaseContainerStubActivity()
class ContainerStubActivity_SingleTask_P04 : BaseContainerStubActivity()
class ContainerStubActivity_SingleTask_P05 : BaseContainerStubActivity()
class ContainerStubActivity_SingleTask_P06 : BaseContainerStubActivity()
class ContainerStubActivity_SingleTask_P07 : BaseContainerStubActivity()
class ContainerStubActivity_SingleTask_P08 : BaseContainerStubActivity()
class ContainerStubActivity_SingleTask_P09 : BaseContainerStubActivity()
class ContainerStubActivity_SingleTask_P10 : BaseContainerStubActivity()
class ContainerStubActivity_SingleTask_P11 : BaseContainerStubActivity()
class ContainerStubActivity_SingleTask_P12 : BaseContainerStubActivity()
class ContainerStubActivity_SingleTask_P13 : BaseContainerStubActivity()
class ContainerStubActivity_SingleTask_P14 : BaseContainerStubActivity()
class ContainerStubActivity_SingleTask_P15 : BaseContainerStubActivity()
class ContainerStubActivity_SingleTask_P16 : BaseContainerStubActivity()
class ContainerStubActivity_SingleTask_P17 : BaseContainerStubActivity()
class ContainerStubActivity_SingleTask_P18 : BaseContainerStubActivity()
class ContainerStubActivity_SingleTask_P19 : BaseContainerStubActivity()
class ContainerStubActivity_SingleTask_P20 : BaseContainerStubActivity()
class ContainerStubActivity_SingleTask_P21 : BaseContainerStubActivity()
class ContainerStubActivity_SingleTask_P22 : BaseContainerStubActivity()
class ContainerStubActivity_SingleTask_P23 : BaseContainerStubActivity()
class ContainerStubActivity_SingleTask_P24 : BaseContainerStubActivity()
class ContainerStubActivity_SingleTask_P25 : BaseContainerStubActivity()

// ----------------- Stub Services (P01 to P25) -----------------
open class BaseContainerStubService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null
}
class ContainerStubService_P01 : BaseContainerStubService()
class ContainerStubService_P02 : BaseContainerStubService()
class ContainerStubService_P03 : BaseContainerStubService()
class ContainerStubService_P04 : BaseContainerStubService()
class ContainerStubService_P05 : BaseContainerStubService()
class ContainerStubService_P06 : BaseContainerStubService()
class ContainerStubService_P07 : BaseContainerStubService()
class ContainerStubService_P08 : BaseContainerStubService()
class ContainerStubService_P09 : BaseContainerStubService()
class ContainerStubService_P10 : BaseContainerStubService()
class ContainerStubService_P11 : BaseContainerStubService()
class ContainerStubService_P12 : BaseContainerStubService()
class ContainerStubService_P13 : BaseContainerStubService()
class ContainerStubService_P14 : BaseContainerStubService()
class ContainerStubService_P15 : BaseContainerStubService()
class ContainerStubService_P16 : BaseContainerStubService()
class ContainerStubService_P17 : BaseContainerStubService()
class ContainerStubService_P18 : BaseContainerStubService()
class ContainerStubService_P19 : BaseContainerStubService()
class ContainerStubService_P20 : BaseContainerStubService()
class ContainerStubService_P21 : BaseContainerStubService()
class ContainerStubService_P22 : BaseContainerStubService()
class ContainerStubService_P23 : BaseContainerStubService()
class ContainerStubService_P24 : BaseContainerStubService()
class ContainerStubService_P25 : BaseContainerStubService()
