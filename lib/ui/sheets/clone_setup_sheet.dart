// lib/ui/sheets/clone_setup_sheet.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/app_info.dart';
import '../../models/device_preset.dart';
import '../../providers/clone_provider.dart';
import '../widgets/clone_app_icon.dart';
import '../widgets/clone_progress_dialog.dart';

/// Clean, simplified Clone Setup Bottom Sheet.
/// Asks how many copies to clone (1-25), ensures data & profile isolation,
/// allows device identity & hardware fingerprint spoofing,
/// and allows adding directly to the phone's App Menu & Home Screen.
class CloneSetupSheet extends ConsumerStatefulWidget {
  final AppInfo? preselectedApp;

  const CloneSetupSheet({
    super.key,
    this.preselectedApp,
  });

  @override
  ConsumerState<CloneSetupSheet> createState() => _CloneSetupSheetState();
}

class _CloneSetupSheetState extends ConsumerState<CloneSetupSheet> {
  int _count = 1;
  bool _addToAppMenuAndDesktop = true;
  bool _isCreating = false;
  DevicePreset? _selectedPreset; // null means 'Auto-Randomize (Flagships)'
  late String _customAndroidId;
  late String _customImei;
  late String _customMac;
  final TextEditingController _profileLabelController = TextEditingController();

  static const List<String> _profileSuggestions = [
    'Personal', 'Work', 'Business', 'Family', 'Gaming', 'Account 2', 'Backup',
  ];

  @override
  void initState() {
    super.initState();
    _customAndroidId = DevicePreset.generateRandomAndroidId();
    _customImei = DevicePreset.generateRandomImei();
    _customMac = DevicePreset.generateRandomMac();
  }

  @override
  void dispose() {
    _profileLabelController.dispose();
    super.dispose();
  }

  void _regenerateIdentifiers() {
    setState(() {
      _customAndroidId = DevicePreset.generateRandomAndroidId();
      _customImei = DevicePreset.generateRandomImei();
      _customMac = DevicePreset.generateRandomMac();
    });
  }

  AppInfo get _effectiveApp =>
      widget.preselectedApp ??
      const AppInfo(
        appName: 'Application',
        packageName: 'com.app.clone',
        versionCode: 1,
        versionName: '1.0.0',
      );

  void _increment() {
    if (_count < 25) {
      setState(() => _count++);
    }
  }

  void _decrement() {
    if (_count > 1) {
      setState(() => _count--);
    }
  }

  void _setCount(int count) {
    if (count >= 1 && count <= 25) {
      setState(() => _count = count);
    }
  }

  Future<void> _startCloning() async {
    if (_isCreating) return;
    setState(() => _isCreating = true);

    final targetPackage = _effectiveApp.packageName;
    final targetBaseName = _effectiveApp.appName;
    final totalInstances = _count;
    final addToMenu = _addToAppMenuAndDesktop;

    final navigator = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);

    // Dismiss bottom sheet
    Navigator.of(context).pop();

    // Show Batch Progress Overlay
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => CloneProgressDialog(
        totalClones: totalInstances,
        targetPackage: targetPackage,
        baseDisplayName: targetBaseName,
        isSingleTask: false,
        silentInstall: false,
        keepDataIsolated: true,
      ),
    );

    try {
      final cloneNotifier = ref.read(cloneListProvider.notifier);

      for (int i = 1; i <= totalInstances; i++) {
        final pad = i.toString().padLeft(2, '0');
        // Use user-provided profile label or auto-generate one
        final rawLabel = _profileLabelController.text.trim();
        final profileLabel = totalInstances == 1
            ? rawLabel.isNotEmpty ? rawLabel : null
            : rawLabel.isNotEmpty ? '$rawLabel $pad' : null;
        final displayName = profileLabel != null
            ? '$targetBaseName [$profileLabel]'
            : '$targetBaseName [C-$pad]';

        final preset = _selectedPreset ?? DevicePreset.presets[(i - 1) % DevicePreset.presets.length];
        final androidId = totalInstances == 1
            ? _customAndroidId
            : DevicePreset.generateRandomAndroidId();

        await cloneNotifier.createClone(
          packageName: targetPackage,
          displayName: displayName,
          profileLabel: profileLabel,
          isSingleTask: false,
          silentInstall: false,
          keepDataIsolated: true,
          pinToDesktop: addToMenu,
          mode: 'standalone',
          devicePreset: preset.id,
          deviceModel: preset.displayName,
          androidId: androidId,
          advertisingId: DevicePreset.generateRandomGaid(),
        );
      }

      await cloneNotifier.refreshClones();

      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: const Color(0xFF10B981),
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Created $totalInstances isolated clone(s) of $targetBaseName with unique hardware fingerprints!',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: Colors.redAccent,
          content: Text('Failed creating clones: $e'),
        ),
      );
    } finally {
      try {
        navigator.pop();
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: isDark ? Colors.white12 : Colors.black12,
            ),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            left: 20,
            right: 20,
            top: 12,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.88,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag Handle
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
                  const SizedBox(height: 18),

                  // Selected App Info Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Row(
                      children: [
                        CloneAppIcon(
                          packageName: _effectiveApp.packageName,
                          cloneId: 1,
                          size: 50,
                          showBadge: false,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _effectiveApp.appName,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _effectiveApp.packageName,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontFamily: 'monospace',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Question Heading: "How many copies to clone?"
                  Text(
                    'How many copies to clone?',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Each copy will run as an independent application with its own separate profile and login session.',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Number Counter Row
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: primary.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Decrement Button
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline_rounded),
                          iconSize: 32,
                          color: _count > 1 ? primary : theme.disabledColor,
                          onPressed: _count > 1 ? _decrement : null,
                        ),

                        // Counter Display
                        Column(
                          children: [
                            Text(
                              '$_count',
                              style: TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                                color: primary,
                              ),
                            ),
                            Text(
                              _count == 1 ? 'Clone Instance' : 'Clone Instances',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),

                        // Increment Button
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline_rounded),
                          iconSize: 32,
                          color: _count < 25 ? primary : theme.disabledColor,
                          onPressed: _count < 25 ? _increment : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Quick Pick Chips (1, 2, 3, 5, 10)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [1, 2, 3, 5, 10].map((countValue) {
                      final isSelected = _count == countValue;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: ChoiceChip(
                          label: Text(
                            '$countValue',
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? Colors.white : null,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: primary,
                          onSelected: (_) => _setCount(countValue),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),

                  // ==================== PROFILE NAME CARD ====================
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: primary.withValues(alpha: 0.30),
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.badge_rounded, color: primary, size: 18),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Profile Name (Optional)',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                  ),
                                  Text(
                                    'Label each clone so you know which account is which',
                                    style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Quick suggestion chips
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _profileSuggestions.map((suggestion) {
                              final isSelected = _profileLabelController.text.trim() == suggestion;
                              return Padding(
                                padding: const EdgeInsets.only(right: 6.0),
                                child: ChoiceChip(
                                  label: Text(suggestion),
                                  selected: isSelected,
                                  selectedColor: primary,
                                  labelStyle: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected ? Colors.white : null,
                                  ),
                                  onSelected: (val) {
                                    setState(() {
                                      if (val) {
                                        _profileLabelController.text = suggestion;
                                      } else {
                                        _profileLabelController.clear();
                                      }
                                    });
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _profileLabelController,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: _count == 1
                                ? 'e.g. Work, Personal, Account 2...'
                                : 'e.g. Work  →  Work 01, Work 02...',
                            hintStyle: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                            ),
                            prefixIcon: const Icon(Icons.label_outline_rounded, size: 20),
                            suffixIcon: _profileLabelController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 18),
                                    onPressed: () => setState(() => _profileLabelController.clear()),
                                  )
                                : null,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: primary.withValues(alpha: 0.4)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: primary, width: 1.5),
                            ),
                          ),
                        ),
                        if (_profileLabelController.text.isNotEmpty && _count > 1) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.info_outline_rounded, size: 13, color: Colors.blueAccent),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  'Will create: "${_profileLabelController.text.trim()} 01", "${_profileLabelController.text.trim()} 02"...',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    color: Colors.blueAccent,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ==================== DEVICE IDENTITY SPOOFING CARD ====================
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B5CF6).withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.phonelink_setup_rounded,
                                color: Color(0xFF8B5CF6),
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Hardware Identity Virtualization',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                  Text(
                                    'Spoofs device model, manufacturer & Android ID per clone',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.3),
                                ),
                              ),
                              child: const Text(
                                'ACTIVE',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF10B981),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Preset Chips (Horizontal Scroll)
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              ChoiceChip(
                                avatar: const Icon(Icons.casino_rounded, size: 16),
                                label: const Text('Auto-Rotate (Flagships)'),
                                selected: _selectedPreset == null,
                                selectedColor: const Color(0xFF8B5CF6),
                                labelStyle: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: _selectedPreset == null ? FontWeight.bold : FontWeight.normal,
                                  color: _selectedPreset == null ? Colors.white : null,
                                ),
                                onSelected: (val) {
                                  if (val) setState(() => _selectedPreset = null);
                                },
                              ),
                              const SizedBox(width: 6),
                              ...DevicePreset.presets.map((preset) {
                                final isSel = _selectedPreset?.id == preset.id;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 6.0),
                                  child: ChoiceChip(
                                    label: Text(preset.displayName),
                                    selected: isSel,
                                    selectedColor: const Color(0xFF8B5CF6),
                                    labelStyle: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                      color: isSel ? Colors.white : null,
                                    ),
                                    onSelected: (val) {
                                      if (val) setState(() => _selectedPreset = preset);
                                    },
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Spoofed Hardware Details Sub-Card
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.memory_rounded, size: 14, color: Colors.blueAccent),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      _selectedPreset != null
                                          ? '${_selectedPreset!.brand.toUpperCase()} ${_selectedPreset!.model}'
                                          : 'Dynamic Rotation',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _selectedPreset != null ? 'Board: ${_selectedPreset!.board}' : 'Distinct / Clone',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.fingerprint_rounded, size: 14, color: Color(0xFF10B981)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'ID: ${_count == 1 ? _customAndroidId : 'Unique 16-hex / clone'}',
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (_count == 1) ...[
                                    const SizedBox(width: 8),
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        key: const ValueKey('reroll_android_id_button'),
                                        borderRadius: BorderRadius.circular(8),
                                        onTap: _regenerateIdentifiers,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
                                            ),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.refresh_rounded, size: 13, color: Color(0xFF8B5CF6)),
                                              SizedBox(width: 4),
                                              Text(
                                                'Reroll',
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF8B5CF6),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (_count == 1) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.sim_card_rounded, size: 13, color: Color(0xFF3B82F6)),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'IMEI: $_customImei',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontFamily: 'monospace',
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.wifi_rounded, size: 13, color: Color(0xFFF59E0B)),
                                    const SizedBox(width: 4),
                                    Text(
                                      'MAC: ${_customMac.length > 11 ? _customMac.substring(0, 11) : _customMac}..',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontFamily: 'monospace',
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Add to App Menu & Desktop Option
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.black12,
                      ),
                    ),
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: _addToAppMenuAndDesktop,
                      onChanged: (val) => setState(() => _addToAppMenuAndDesktop = val),
                      activeThumbColor: primary,
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.install_mobile_rounded, color: primary, size: 22),
                      ),
                      title: const Text(
                        'Add to Phone App Menu & Home Screen',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      subtitle: const Text(
                        'Enables quick access and independent launcher icons for each profile',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 100% Data Isolation Reassurance Banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF10B981).withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          color: Color(0xFF10B981),
                          size: 20,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '100% Profile Isolation: Logging out of one app will never log out the other.',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Action Buttons
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: _startCloning,
                      style: FilledButton.styleFrom(
                        backgroundColor: primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.copy_rounded),
                      label: Text(
                        _count == 1
                            ? 'Clone App (1 Instance)'
                            : 'Clone App ($_count Instances)',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
