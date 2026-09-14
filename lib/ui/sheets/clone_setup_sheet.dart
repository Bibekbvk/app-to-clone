// lib/ui/sheets/clone_setup_sheet.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/app_info.dart';
import '../../providers/clone_provider.dart';
import '../widgets/clone_progress_dialog.dart';

/// Batch Clone Modal Sheet for configuring clone count (1-25),
/// badge preview, isolation toggles, and executing the batch workflow.
class CloneSetupSheet extends ConsumerStatefulWidget {
  final AppInfo? preselectedApp;
  const CloneSetupSheet({super.key, this.preselectedApp});

  @override
  ConsumerState<CloneSetupSheet> createState() => _CloneSetupSheetState();
}

class _CloneSetupSheetState extends ConsumerState<CloneSetupSheet> {
  final TextEditingController _packageController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  int _count = 1;
  bool _silentInstall = false;
  bool _keepIsolated = true;
  bool _singleTask = false;
  bool _autoPin = true;
  CloneMode _selectedMode = CloneMode.standalone;

  @override
  void initState() {
    super.initState();
    _count = ref.read(cloneCountProvider);
    _silentInstall = ref.read(silentInstallProvider);
    _keepIsolated = ref.read(keepDataIsolatedProvider);
    _singleTask = ref.read(singleTaskModeProvider);
    _autoPin = ref.read(autoPinToDesktopProvider);
    _selectedMode = ref.read(cloneModeProvider);

    if (widget.preselectedApp != null) {
      _packageController.text = widget.preselectedApp!.packageName;
      _nameController.text = widget.preselectedApp!.appName;
    }
  }

  @override
  void dispose() {
    _packageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  String get _badgePreview {
    final baseName = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : (_packageController.text.trim().isNotEmpty
            ? _packageController.text.trim()
            : 'App Name');

    if (_count == 1) {
      return '$baseName [C-01]';
    }
    return '$baseName [C-01] ... $baseName [C-${_count.toString().padLeft(2, '0')}]';
  }

  bool get _isValid {
    final pkg = _packageController.text.trim();
    return pkg.isNotEmpty && pkg.contains('.') && _count >= 1 && _count <= 25;
  }

  Future<void> _startBatchCloning() async {
    if (!_isValid) return;

    final targetPackage = _packageController.text.trim();
    final targetBaseName = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : null;

    final totalInstances = _count;
    final isSingleTask = _singleTask;
    final silent = _silentInstall;
    final keepIsolated = _keepIsolated;

    final navigator = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);

    // Close bottom sheet
    Navigator.of(context).pop();

    // Open Real-Time Batch Progress Overlay
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => CloneProgressDialog(
        totalClones: totalInstances,
        targetPackage: targetPackage,
        baseDisplayName: targetBaseName,
        isSingleTask: isSingleTask,
        silentInstall: silent,
        keepDataIsolated: keepIsolated,
      ),
    );

    try {
      final cloneNotifier = ref.read(cloneListProvider.notifier);
      for (int i = 1; i <= totalInstances; i++) {
        final pad = i.toString().padLeft(2, '0');
        final displayName = targetBaseName != null ? '$targetBaseName [C-$pad]' : null;

        await cloneNotifier.createClone(
          packageName: targetPackage,
          displayName: displayName,
          isSingleTask: isSingleTask,
          silentInstall: silent,
          keepDataIsolated: keepIsolated,
          pinToDesktop: _autoPin,
          mode: _selectedMode == CloneMode.standalone ? 'standalone' : 'sandbox',
        );
      }

      await cloneNotifier.refreshClones();

      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              'Successfully deployed $totalInstances clone instance(s) of $targetPackage!',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.redAccent,
            content: Text('Error creating clones: $e'),
          ),
        );
      }
    } finally {
      navigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.95) : Colors.white.withValues(alpha: 0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08),
            ),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 12,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.content_copy_rounded,
                        color: theme.colorScheme.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Batch Clone Configuration',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Configure sandboxed instances & worker stubs',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Dual-Mode Selector: Standalone Mutated Clone vs Instant Virtual Sandbox
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.white10 : Colors.black12,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _selectedMode = CloneMode.standalone);
                            ref.read(cloneModeProvider.notifier).setMode(CloneMode.standalone);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                            decoration: BoxDecoration(
                              color: _selectedMode == CloneMode.standalone
                                  ? const Color(0xFF10B981)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.shield_rounded,
                                  size: 18,
                                  color: _selectedMode == CloneMode.standalone ? Colors.white : theme.colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Standalone (100% Isolated)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: _selectedMode == CloneMode.standalone ? Colors.white : theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _selectedMode = CloneMode.sandbox);
                            ref.read(cloneModeProvider.notifier).setMode(CloneMode.sandbox);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                            decoration: BoxDecoration(
                              color: _selectedMode == CloneMode.sandbox
                                  ? theme.colorScheme.primary
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.bolt_rounded,
                                  size: 18,
                                  color: _selectedMode == CloneMode.sandbox ? Colors.white : theme.colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Instant Sandbox',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: _selectedMode == CloneMode.sandbox ? Colors.white : theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _selectedMode == CloneMode.standalone
                        ? const Color(0xFF10B981).withValues(alpha: 0.12)
                        : theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _selectedMode == CloneMode.standalone ? Icons.verified_user_rounded : Icons.flash_on_rounded,
                        size: 16,
                        color: _selectedMode == CloneMode.standalone ? const Color(0xFF10B981) : theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _selectedMode == CloneMode.standalone
                              ? 'Separate app package. 100% Linux UID separation for WhatsApp, Social & Banking with zero session bleeding.'
                              : 'Instant launch inside :worker_XX container. Zero installation prompt required.',
                          style: TextStyle(
                            fontSize: 11,
                            color: _selectedMode == CloneMode.standalone ? const Color(0xFF10B981) : theme.colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Target Package Input
                TextField(
                  controller: _packageController,
                  decoration: InputDecoration(
                    labelText: 'Target Package Name *',
                    hintText: 'com.example.targetapp',
                    prefixIcon: const Icon(Icons.apps_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 14),

                // Display Name Customizer
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Display Name Format (Optional)',
                    hintText: 'e.g., WhatsApp Work',
                    prefixIcon: const Icon(Icons.edit_note_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),

                // Badge Format Preview Box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.preview_rounded,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Badge Preview:',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.outline,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _badgePreview,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Slider / Counter (1 to 25)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Clone Instances:',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$_count / 25',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _count.toDouble(),
                  min: 1,
                  max: 25,
                  divisions: 24,
                  label: '$_count',
                  onChanged: (val) {
                    setState(() => _count = val.toInt());
                    ref.read(cloneCountProvider.notifier).set(_count);
                  },
                ),
                const SizedBox(height: 8),

                // Toggles
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.flash_on_rounded),
                  title: const Text('Silent Install via Shizuku'),
                  subtitle: const Text('Bypasses Android system installer prompts'),
                  value: _silentInstall,
                  onChanged: (val) {
                    setState(() => _silentInstall = val);
                    ref.read(silentInstallProvider.notifier).toggle(val);
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.security_rounded),
                  title: const Text('Keep Data Isolated'),
                  subtitle: const Text('Independent isolated storage context per worker'),
                  value: _keepIsolated,
                  onChanged: (val) {
                    setState(() => _keepIsolated = val);
                    ref.read(keepDataIsolatedProvider.notifier).toggle(val);
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.tab_unselected_rounded),
                  title: const Text('Single-Task Mode'),
                  subtitle: const Text('Route to ContainerStubActivity_SingleTask_P*'),
                  value: _singleTask,
                  onChanged: (val) {
                    setState(() => _singleTask = val);
                    ref.read(singleTaskModeProvider.notifier).toggle(val);
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.add_to_home_screen_rounded, color: Color(0xFF00E5FF)),
                  title: const Text('Auto-Pin to Desktop (Home Screen)'),
                  subtitle: const Text('Creates badged launcher shortcut on phone desktop'),
                  value: _autoPin,
                  onChanged: (val) {
                    setState(() => _autoPin = val);
                    ref.read(autoPinToDesktopProvider.notifier).toggle(val);
                  },
                ),
                const SizedBox(height: 20),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.rocket_launch_rounded),
                    label: Text(
                      'Start Cloning ($_count Instance${_count > 1 ? 's' : ''})',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    onPressed: _isValid ? _startBatchCloning : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
