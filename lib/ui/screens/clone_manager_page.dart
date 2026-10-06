// lib/ui/screens/clone_manager_page.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/clone_info.dart';
import '../../providers/clone_provider.dart';
import '../sheets/clone_setup_sheet.dart';
import '../widgets/clone_app_icon.dart';

/// Main screen showcasing CloneManagerPage with Material 3 design,
/// dynamic gradient app bar, glassmorphism card styling, animated entries,
/// actions (Launch, Delete, Settings), and Create Clone FAB dialog.
class CloneManagerPage extends ConsumerStatefulWidget {
  const CloneManagerPage({super.key});

  @override
  ConsumerState<CloneManagerPage> createState() => _CloneManagerPageState();
}

class _CloneManagerPageState extends ConsumerState<CloneManagerPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _showCreateCloneDialog(BuildContext context) {
    final packageController = TextEditingController();
    final nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSingleTask = false;
    bool pinToDesktop = true;
    String selectedMode = 'standalone';

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isStandalone = selectedMode == 'standalone';

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.copy_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                const Text('Create App Clone'),
              ],
            ),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: packageController,
                      decoration: InputDecoration(
                        labelText: 'Package Name *',
                        hintText: 'e.g. com.whatsapp',
                        prefixIcon: const Icon(Icons.apps_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Package name is required';
                        }
                        if (!value.contains('.')) {
                          return 'Enter a valid package (e.g. com.example.app)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Display Name (Optional)',
                        hintText: 'e.g. Work WhatsApp',
                        prefixIcon: const Icon(Icons.badge_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Clone Engine Mode',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'standalone',
                          icon: Icon(Icons.security_rounded, size: 16),
                          label: Text('Standalone'),
                        ),
                        ButtonSegment(
                          value: 'sandbox',
                          icon: Icon(Icons.flash_on_rounded, size: 16),
                          label: Text('Sandbox'),
                        ),
                      ],
                      selected: {selectedMode},
                      onSelectionChanged: (val) {
                        setDialogState(() => selectedMode = val.first);
                      },
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isStandalone
                            ? const Color(0xFF10B981).withValues(alpha: 0.12)
                            : const Color(0xFF00E5FF).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isStandalone
                              ? const Color(0xFF10B981).withValues(alpha: 0.3)
                              : const Color(0xFF00E5FF).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isStandalone ? Icons.verified_user_rounded : Icons.bolt_rounded,
                            size: 18,
                            color: isStandalone ? const Color(0xFF10B981) : const Color(0xFF00E5FF),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isStandalone
                                  ? '100% Kernel-level UID isolation. Prevents session bleeding across WhatsApp, Facebook, etc.'
                                  : 'Instant launch inside container worker. No APK installation required.',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Single-Task Isolation', style: TextStyle(fontSize: 14)),
                      subtitle: const Text('Dedicates isolated singleTask stub window', style: TextStyle(fontSize: 12)),
                      value: isSingleTask,
                      onChanged: (val) => setDialogState(() => isSingleTask = val),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Pin to Phone Desktop', style: TextStyle(fontSize: 14)),
                      subtitle: const Text('Adds direct launcher shortcut to phone screen', style: TextStyle(fontSize: 12)),
                      value: pinToDesktop,
                      onChanged: (val) => setDialogState(() => pinToDesktop = val),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.add_task_rounded),
                label: const Text('Create'),
                onPressed: () async {
                  if (formKey.currentState?.validate() == true) {
                    final pkg = packageController.text.trim();
                    final name = nameController.text.trim().isNotEmpty
                        ? nameController.text.trim()
                        : null;

                    Navigator.of(dialogCtx).pop();

                    final scaffoldMessenger = ScaffoldMessenger.of(context);
                    final newId = await ref.read(cloneListProvider.notifier).createClone(
                          packageName: pkg,
                          displayName: name,
                          isSingleTask: isSingleTask,
                          pinToDesktop: pinToDesktop,
                          mode: selectedMode,
                        );

                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        behavior: SnackBarBehavior.floating,
                        content: Text(
                          newId > 0
                              ? 'Successfully created clone ID #$newId for $pkg'
                              : 'Clone registered for $pkg',
                        ),
                        action: SnackBarAction(
                          label: isStandalone ? 'Install' : 'Launch',
                          onPressed: () {
                            if (isStandalone) {
                              ref.read(cloneListProvider.notifier).installStandaloneApk(newId);
                            } else {
                              ref.read(cloneListProvider.notifier).launchClone(newId, isSingleTask: isSingleTask);
                            }
                          },
                        ),
                      ),
                    );
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final clonesAsync = ref.watch(cloneListProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [
                          const Color(0xFF1E1B4B).withValues(alpha: 0.85),
                          const Color(0xFF311042).withValues(alpha: 0.85),
                        ]
                      : [
                          const Color(0xFF4F46E5).withValues(alpha: 0.90),
                          const Color(0xFF7C3AED).withValues(alpha: 0.90),
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border(
                  bottom: BorderSide(
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                  ),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      Hero(
                        tag: 'app_logo_hero',
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset(
                              'assets/images/app_logo.png',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  Icons.layers_rounded,
                                  color: Colors.white,
                                  size: 26,
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'App to Clone',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                              ),
                            ),
                            Text(
                              'Multi-Instance Virtualization',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Toggle Theme',
                        icon: Icon(
                          isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                          color: Colors.white,
                        ),
                        onPressed: () => ref.read(themeModeProvider.notifier).toggleTheme(),
                      ),
                      IconButton(
                        tooltip: 'Batch Cloning Sheet',
                        icon: const Icon(Icons.tune_rounded, color: Colors.white),
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => const CloneSetupSheet(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF0F172A), const Color(0xFF020617)]
                : [const Color(0xFFF8FAFC), const Color(0xFFEEF2F6)],
          ),
        ),
        child: SafeArea(
          child: clonesAsync.when(
            loading: () => const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading virtual instances...'),
                ],
              ),
            ),
            error: (err, stack) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline_rounded, size: 48, color: theme.colorScheme.error),
                    const SizedBox(height: 12),
                    Text('Failed to load clones: $err'),
                    const SizedBox(height: 16),
                    FilledButton.tonal(
                      onPressed: () => ref.read(cloneListProvider.notifier).refreshClones(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
            data: (clones) {
              if (clones.isEmpty) {
                return _buildEmptyState(context);
              }
              return RefreshIndicator(
                onRefresh: () => ref.read(cloneListProvider.notifier).refreshClones(),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 96),
                  itemCount: clones.length,
                  itemBuilder: (context, index) {
                    final clone = clones[index];
                    return _buildAnimatedCard(context, clone, index, clones.length);
                  },
                ),
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add_rounded),
        label: const Text('Create Clone'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        elevation: 6,
        onPressed: () => _showCreateCloneDialog(context),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.layers_clear_rounded,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No Clone Instances Yet',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap "+ Create Clone" or pick an app from the catalog to launch isolated sandbox profiles.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create Your First Clone'),
              onPressed: () => _showCreateCloneDialog(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedCard(BuildContext context, CloneInfo clone, int index, int total) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Sequential slide-up fade animation
    final startInterval = (index / (total + 1)).clamp(0.0, 0.6);
    final endInterval = (startInterval + 0.4).clamp(0.0, 1.0);

    final animation = CurvedAnimation(
      parent: _animController,
      curve: Interval(startInterval, endInterval, curve: Curves.easeOutCubic),
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1.0 - animation.value)),
          child: Opacity(
            opacity: animation.value,
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: _buildGlassCard(context, clone, isDark),
      ),
    );
  }

  Widget _buildGlassCard(BuildContext context, CloneInfo clone, bool isDark) {
    final theme = Theme.of(context);
    final padId = clone.id.toString().padLeft(2, '0');

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1E293B).withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.06),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.3)
                    : const Color(0xFF64748B).withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CloneAppIcon(
                    packageName: clone.packageName,
                    cloneId: clone.id,
                    size: 52,
                    borderRadius: 14,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                clone.effectiveName,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: clone.isStandalone
                                    ? const Color(0xFF10B981).withValues(alpha: 0.2)
                                    : const Color(0xFF00E5FF).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: clone.isStandalone
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFF00E5FF),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    clone.isStandalone ? Icons.shield_rounded : Icons.flash_on_rounded,
                                    size: 11,
                                    color: clone.isStandalone ? const Color(0xFF10B981) : const Color(0xFF00E5FF),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    clone.isStandalone ? 'STANDALONE' : 'SANDBOX',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: clone.isStandalone ? const Color(0xFF10B981) : const Color(0xFF00E5FF),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (clone.isSingleTask) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.tertiaryContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'SingleTask',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onTertiaryContainer,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 5),
                        // Profile label badge — the key differentiator for each clone
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    theme.colorScheme.primary.withValues(alpha: 0.18),
                                    theme.colorScheme.primary.withValues(alpha: 0.08),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.35),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.badge_rounded,
                                    size: 11,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    clone.effectiveProfileLabel,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          clone.isStandalone
                              ? '${clone.packageName}.c$padId'
                              : clone.packageName,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                            fontFamily: 'monospace',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          clone.isStandalone
                              ? 'Native Linux UID • Zero Session Bleed • /data/data/${clone.packageName}.c$padId'
                              : 'Worker: :worker_$padId • Isolated WAL SQLite • /files/clones/${clone.id}',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: theme.colorScheme.outline,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (clone.deviceModel != null && clone.deviceModel!.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.phonelink_setup_rounded, size: 10.5, color: Color(0xFF8B5CF6)),
                                    const SizedBox(width: 4),
                                    Text(
                                      clone.deviceModel!,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF8B5CF6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (clone.androidId != null && clone.androidId!.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'ID: ${clone.androidId}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontFamily: 'monospace',
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              // Action Buttons: Install (if standalone), Export (if standalone), Pin, Settings, Delete, Launch
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (clone.isStandalone) ...[
                      IconButton.filledTonal(
                        tooltip: 'Install Standalone APK',
                        style: IconButton.styleFrom(
                          foregroundColor: const Color(0xFF10B981),
                          backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.15),
                        ),
                        icon: const Icon(Icons.install_mobile_rounded, size: 20),
                        onPressed: () async {
                          final ok = await ref.read(cloneListProvider.notifier).installStandaloneApk(clone.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                behavior: SnackBarBehavior.floating,
                                content: Text(
                                  ok ? 'Opening Android Package Installer...' : 'Installing standalone APK...',
                                ),
                              ),
                            );
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        tooltip: 'Export APK to Downloads',
                        style: IconButton.styleFrom(
                          foregroundColor: const Color(0xFF8B5CF6),
                          backgroundColor: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                        ),
                        icon: const Icon(Icons.file_download_outlined, size: 20),
                        onPressed: () async {
                          final exportedPath = await ref.read(cloneListProvider.notifier).exportStandaloneApk(clone.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                behavior: SnackBarBehavior.floating,
                                content: Text(
                                  exportedPath != null
                                      ? 'APK saved to Downloads:\n$exportedPath'
                                      : 'Failed to export APK',
                                ),
                              ),
                            );
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                    ],
                    IconButton.filledTonal(
                      tooltip: 'Pin to Phone Desktop',
                      style: IconButton.styleFrom(
                        foregroundColor: const Color(0xFF00E5FF),
                        backgroundColor: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                      ),
                      icon: const Icon(Icons.add_to_home_screen_rounded, size: 20),
                      onPressed: () async {
                        final ok = await ref.read(cloneListProvider.notifier).pinToHomeScreen(clone.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              behavior: SnackBarBehavior.floating,
                              content: Text(
                                ok
                                    ? 'Desktop shortcut for ${clone.effectiveName} added to phone screen!'
                                    : 'Shortcut requested. Please check your phone home screen!',
                              ),
                            ),
                          );
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.settings_suggest_rounded, size: 18),
                      label: const Text('Settings'),
                      onPressed: () {
                        ref.read(cloneListProvider.notifier).openSettings(clone.id, clone.packageName);
                      },
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: 'Delete Clone',
                      style: IconButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                        backgroundColor: theme.colorScheme.errorContainer.withValues(alpha: 0.6),
                      ),
                      icon: const Icon(Icons.delete_outline_rounded, size: 20),
                      onPressed: () => _confirmDelete(context, clone),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded, size: 20),
                      label: const Text('Launch'),
                      onPressed: () {
                        ref.read(cloneListProvider.notifier).launchClone(clone.id, isSingleTask: clone.isSingleTask);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, CloneInfo clone) {
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Clone Instance?'),
        content: Text(
          'Are you sure you want to remove ${clone.effectiveName} (ID: ${clone.id})? '
          'This will wipe all container sandboxed data and remove isolated stub bindings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dCtx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () {
              Navigator.of(dCtx).pop();
              ref.read(cloneListProvider.notifier).deleteClone(clone.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
