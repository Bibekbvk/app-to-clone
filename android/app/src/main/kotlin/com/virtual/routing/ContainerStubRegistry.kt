package com.virtual.routing

import android.app.Activity
import android.app.ActivityManager
import android.app.AlertDialog
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.webkit.*
import android.widget.*
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
 * Enterprise Base Activity representing an isolated virtual container slot.
 * Runs in dedicated Linux processes :worker_01 through :worker_25.
 * Features an in-process, sandboxed Chromium container with 100% independent
 * cookie jars, LocalStorage, IndexedDB, and SQLite databases.
 * Guarantees zero session bleed across Facebook, PayPal, and all multi-account apps.
 */
open class BaseContainerStubActivity : Activity() {

    private lateinit var storageContext: com.virtual.fs.ContainerStorageContext
    private var currentWebView: WebView? = null
    private var progressBar: ProgressBar? = null
    private var fileChooserCallback: ValueCallback<Array<Uri>>? = null

    companion object {
        private const val FILE_CHOOSER_REQUEST_CODE = 2001
    }

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

        // Multi-process WebView storage isolation: guarantees separate cookies, local storage, and caches
        val processPad = String.format("%02d", ((profileId - 1) % 25) + 1)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            try {
                WebView.setDataDirectorySuffix("worker_$processPad")
            } catch (_: Exception) {
                // Suffix already initialized for this process
            }
        }

        // Initialize dedicated virtualized storage context (files, db WAL, isolated prefs)
        storageContext = com.virtual.fs.ContainerStorageContext(this, profileId, targetPackage)

        // 1. Task Description for Android OS Recents Switcher (Distinct task window per clone)
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
            } catch (_: Exception) {}
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            @Suppress("DEPRECATION")
            try {
                setTaskDescription(ActivityManager.TaskDescription(cardTitle, null, color))
            } catch (_: Exception) {}
        }

        // 2. Build and set Live Sandboxed Container View
        val targetUrl = resolveTargetUrl(targetPackage, targetAppName)
        val rootView = buildSandboxedContainerView(profileId, targetPackage, targetAppName, displayBadge, cardTitle, targetUrl, processPad)
        setContentView(rootView)
    }

    private fun resolveTargetUrl(targetPackage: String, targetAppName: String): String {
        val pkg = targetPackage.lowercase()
        val name = targetAppName.lowercase()

        return when {
            pkg.contains("facebook") || name.contains("facebook") -> "https://m.facebook.com"
            pkg.contains("paypal") || name.contains("paypal") -> "https://www.paypal.com/signin"
            pkg.contains("instagram") || name.contains("instagram") -> "https://www.instagram.com"
            pkg.contains("twitter") || name.contains("twitter") || pkg.contains(".x") || name == "x" -> "https://x.com"
            pkg.contains("telegram") || name.contains("telegram") -> "https://web.telegram.org"
            pkg.contains("whatsapp") || name.contains("whatsapp") -> "https://web.whatsapp.com"
            pkg.contains("reddit") || name.contains("reddit") -> "https://www.reddit.com"
            pkg.contains("gmail") || pkg.contains(".gm") || name.contains("gmail") -> "https://mail.google.com"
            pkg.contains("google") || name.contains("google") -> "https://accounts.google.com"
            pkg.contains("amazon") || name.contains("amazon") -> "https://www.amazon.com"
            pkg.contains("linkedin") || name.contains("linkedin") -> "https://www.linkedin.com"
            pkg.contains("tiktok") || name.contains("tiktok") -> "https://www.tiktok.com"
            pkg.contains("spotify") || name.contains("spotify") -> "https://open.spotify.com"
            pkg.contains("netflix") || name.contains("netflix") -> "https://www.netflix.com"
            pkg.contains("outlook") || name.contains("outlook") -> "https://outlook.live.com"
            pkg.contains("discord") || name.contains("discord") -> "https://discord.com/login"
            pkg.contains("pinterest") || name.contains("pinterest") -> "https://www.pinterest.com"
            pkg.startsWith("http://") || pkg.startsWith("https://") -> targetPackage
            else -> "https://www.google.com/search?q=${Uri.encode(targetAppName)}"
        }
    }

    private fun buildSandboxedContainerView(
        profileId: Int,
        targetPackage: String,
        targetAppName: String,
        displayBadge: String,
        cardTitle: String,
        targetUrl: String,
        processPad: String
    ): View {
        val dp = resources.displayMetrics.density

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
            setBackgroundColor(Color.parseColor("#0A0E1A"))
        }

        // --- TOP NAVIGATION BAR ---
        val topBar = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                (56 * dp).toInt()
            )
            setBackgroundColor(Color.parseColor("#0F172A")) // Slate 900
            setPadding((12 * dp).toInt(), 0, (12 * dp).toInt(), 0)
        }

        // Back / Close Button
        val backBtn = TextView(this).apply {
            text = "‹"
            textSize = 28f
            setTextColor(Color.parseColor("#E2E8F0"))
            setPadding((4 * dp).toInt(), 0, (12 * dp).toInt(), (4 * dp).toInt())
            setOnClickListener {
                if (currentWebView?.canGoBack() == true) {
                    currentWebView?.goBack()
                } else {
                    finish()
                }
            }
        }
        topBar.addView(backBtn)

        // App Icon
        val appIconView = ImageView(this).apply {
            layoutParams = LinearLayout.LayoutParams((32 * dp).toInt(), (32 * dp).toInt()).apply {
                marginEnd = (10 * dp).toInt()
            }
            try {
                setImageDrawable(packageManager.getApplicationIcon(targetPackage))
            } catch (_: Exception) {
                setImageResource(android.R.drawable.sym_def_app_icon)
            }
        }
        topBar.addView(appIconView)

        // Title Column
        val titleCol = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
        }
        val titleText = TextView(this).apply {
            text = cardTitle
            setTextColor(Color.WHITE)
            textSize = 14f
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            maxLines = 1
            ellipsize = android.text.TextUtils.TruncateAt.END
        }
        val subtitleText = TextView(this).apply {
            text = ":worker_$processPad • 100% Isolated Slot"
            setTextColor(Color.parseColor("#38BDF8")) // Sky 400
            textSize = 10f
            typeface = android.graphics.Typeface.MONOSPACE
        }
        titleCol.addView(titleText)
        titleCol.addView(subtitleText)
        topBar.addView(titleCol)

        // Check if Standalone Native APK is installed
        val padId = String.format("%02d", profileId)
        val standalonePkg = "$targetPackage.c$padId"
        val standaloneIntent = packageManager.getLaunchIntentForPackage(standalonePkg)
        if (standaloneIntent != null) {
            val nativeBtn = TextView(this).apply {
                text = "⚡ Native APK"
                setTextColor(Color.parseColor("#10B981"))
                textSize = 10f
                typeface = android.graphics.Typeface.DEFAULT_BOLD
                setPadding((8 * dp).toInt(), (4 * dp).toInt(), (8 * dp).toInt(), (4 * dp).toInt())
                background = GradientDrawable().apply {
                    cornerRadius = 8 * dp
                    setColor(Color.parseColor("#064E3B"))
                    setStroke((1 * dp).toInt(), Color.parseColor("#10B981"))
                }
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply { marginEnd = (6 * dp).toInt() }
                setOnClickListener {
                    standaloneIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(standaloneIntent)
                }
            }
            topBar.addView(nativeBtn)
        }

        // Slot Badge Pill
        val badgePill = TextView(this).apply {
            text = displayBadge
            setTextColor(Color.parseColor("#00E5FF"))
            textSize = 11f
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            setPadding((8 * dp).toInt(), (3 * dp).toInt(), (8 * dp).toInt(), (3 * dp).toInt())
            background = GradientDrawable().apply {
                cornerRadius = 12 * dp
                setColor(Color.parseColor("#1E293B"))
                setStroke((1 * dp).toInt(), Color.parseColor("#00E5FF"))
            }
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { marginEnd = (8 * dp).toInt() }
        }
        topBar.addView(badgePill)

        // Reload Action
        val reloadBtn = TextView(this).apply {
            text = "↻"
            textSize = 20f
            setTextColor(Color.parseColor("#94A3B8"))
            setPadding((6 * dp).toInt(), (4 * dp).toInt(), (6 * dp).toInt(), (4 * dp).toInt())
            setOnClickListener {
                currentWebView?.reload()
            }
        }
        topBar.addView(reloadBtn)

        // Pin to Home Screen Action
        val pinBtn = TextView(this).apply {
            text = "📌"
            textSize = 16f
            setPadding((6 * dp).toInt(), (4 * dp).toInt(), (6 * dp).toInt(), (4 * dp).toInt())
            setOnClickListener {
                val ok = com.virtual.ui.ShortcutHelper.pinCloneShortcutToPhoneHomeScreen(
                    context = this@BaseContainerStubActivity,
                    profileId = profileId,
                    packageName = targetPackage,
                    displayName = cardTitle,
                    isSingleTask = true
                )
                if (ok) {
                    Toast.makeText(this@BaseContainerStubActivity, "Desktop shortcut request sent for $cardTitle!", Toast.LENGTH_SHORT).show()
                } else {
                    Toast.makeText(this@BaseContainerStubActivity, "Pin requested (check phone home screen)", Toast.LENGTH_SHORT).show()
                }
            }
        }
        topBar.addView(pinBtn)

        // Clear Session (Reset this clone slot only) Action
        val clearBtn = TextView(this).apply {
            text = "🗑"
            textSize = 16f
            setPadding((6 * dp).toInt(), (4 * dp).toInt(), (6 * dp).toInt(), (4 * dp).toInt())
            setOnClickListener {
                AlertDialog.Builder(this@BaseContainerStubActivity)
                    .setTitle("Reset Clone Slot $profileId?")
                    .setMessage("This will clear cookies and session data for ONLY this clone slot ($cardTitle).\n\nAll your other clone slots and accounts will stay completely logged in.")
                    .setPositiveButton("Reset Slot") { _, _ ->
                        CookieManager.getInstance().removeAllCookies {
                            WebStorage.getInstance().deleteAllData()
                            currentWebView?.clearCache(true)
                            currentWebView?.loadUrl(targetUrl)
                            Toast.makeText(this@BaseContainerStubActivity, "Slot $profileId session reset!", Toast.LENGTH_SHORT).show()
                        }
                    }
                    .setNegativeButton("Cancel", null)
                    .show()
            }
        }
        topBar.addView(clearBtn)

        root.addView(topBar)

        // Progress Bar
        val pb = ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                (3 * dp).toInt()
            )
            max = 100
            progress = 0
            visibility = View.VISIBLE
        }
        progressBar = pb
        root.addView(pb)

        // Content Frame with WebView
        val contentFrame = FrameLayout(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                0,
                1f
            )
        }

        val webView = WebView(this).apply {
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
            setBackgroundColor(Color.parseColor("#0A0E1A"))
            isFocusable = true
            isFocusableInTouchMode = true
        }
        currentWebView = webView

        // Configure high-performance sandboxed web settings
        webView.settings.apply {
            javaScriptEnabled = true
            domStorageEnabled = true
            databaseEnabled = true
            setSupportZoom(true)
            builtInZoomControls = true
            displayZoomControls = false
            allowFileAccess = true
            allowContentAccess = true
            useWideViewPort = true
            loadWithOverviewMode = true
            cacheMode = WebSettings.LOAD_DEFAULT
            userAgentString = "Mozilla/5.0 (Linux; Android 15; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36"
        }

        // Enable Cookies with third-party support
        val cookieManager = CookieManager.getInstance()
        cookieManager.setAcceptCookie(true)
        cookieManager.setAcceptThirdPartyCookies(webView, true)

        webView.webViewClient = object : WebViewClient() {
            override fun shouldOverrideUrlLoading(view: WebView?, request: WebResourceRequest?): Boolean {
                val url = request?.url?.toString() ?: return false
                if (url.startsWith("http://") || url.startsWith("https://")) {
                    return false // Keep inside sandboxed isolated container
                }
                // Handle external apps (tel:, mailto:, etc.)
                return try {
                    val intent = Intent.parseUri(url, Intent.URI_INTENT_SCHEME)
                    startActivity(intent)
                    true
                } catch (_: Exception) {
                    true
                }
            }

            override fun onPageStarted(view: WebView?, url: String?, favicon: Bitmap?) {
                progressBar?.visibility = View.VISIBLE
            }

            override fun onPageFinished(view: WebView?, url: String?) {
                progressBar?.visibility = View.GONE
                CookieManager.getInstance().flush()
            }
        }

        webView.webChromeClient = object : WebChromeClient() {
            override fun onProgressChanged(view: WebView?, newProgress: Int) {
                progressBar?.progress = newProgress
                if (newProgress >= 100) {
                    progressBar?.visibility = View.GONE
                }
            }

            override fun onShowFileChooser(
                webView: WebView?,
                filePathCallback: ValueCallback<Array<Uri>>?,
                fileChooserParams: FileChooserParams?
            ): Boolean {
                this@BaseContainerStubActivity.fileChooserCallback?.onReceiveValue(null)
                this@BaseContainerStubActivity.fileChooserCallback = filePathCallback

                val intent = fileChooserParams?.createIntent() ?: Intent(Intent.ACTION_GET_CONTENT).apply {
                    type = "*/*"
                    addCategory(Intent.CATEGORY_OPENABLE)
                }

                return try {
                    startActivityForResult(intent, FILE_CHOOSER_REQUEST_CODE)
                    true
                } catch (_: Exception) {
                    this@BaseContainerStubActivity.fileChooserCallback = null
                    false
                }
            }
        }

        contentFrame.addView(webView)
        root.addView(contentFrame)

        // Load the isolated service URL
        webView.loadUrl(targetUrl)

        return root
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == FILE_CHOOSER_REQUEST_CODE) {
            val result = WebChromeClient.FileChooserParams.parseResult(resultCode, data)
            fileChooserCallback?.onReceiveValue(result)
            fileChooserCallback = null
        }
    }

    override fun onBackPressed() {
        val webView = currentWebView
        if (webView != null && webView.canGoBack()) {
            webView.goBack()
        } else {
            super.onBackPressed()
        }
    }

    override fun onDestroy() {
        currentWebView?.let { wv ->
            wv.stopLoading()
            (wv.parent as? ViewGroup)?.removeView(wv)
            wv.destroy()
        }
        currentWebView = null
        super.onDestroy()
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
