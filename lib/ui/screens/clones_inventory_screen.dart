// lib/ui/screens/clones_inventory_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/clone_info.dart';
import '../../providers/clone_provider.dart';
import '../widgets/clone_app_icon.dart';

/// Instance Inventory Screen displaying a responsive, overflow-free view of all
/// generated clones with quick actions: Launch, Install Standalone APK, Pin to Desktop,
/// App Info, and Delete.
class ClonesInventoryScreen extends ConsumerStatefulWidget {
  const ClonesInventoryScreen({super.key});

  @override
  ConsumerState<ClonesInventoryScreen> createState() => _ClonesInventoryScreenState();
}

class _ClonesInventoryScreenState extends ConsumerState<ClonesInventoryScreen> {
  bool _isGridView = true;

  @override
  Widget build(BuildContext context) {
    final clonesAsync = ref.watch(cloneListProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Instance Inventory',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: _isGridView ? 'Switch to List View' : 'Switch to Grid View',
            icon: Icon(_isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded),
            onPressed: () => setState(() => _isGridView = !_isGridView),
          ),
          IconButton(
            tooltip: 'Refresh Clones',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.read(cloneListProvider.notifier).refreshClones(),
          ),
        ],
      ),
      body: clonesAsync.when(
        data: (clones) => clones.isEmpty
            ? _buildEmptyState(context)
            : _isGridView
                ? _buildGrid(context, clones)
                : _buildList(context, clones),
        loading: () => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 14),
              Text(
                'Fetching clone vault inventory...',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline_rounded, size: 52, color: theme.colorScheme.error),
                const SizedBox(height: 14),
                Text(
                  'Failed to query inventory',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.colorScheme.error),
                ),
                const SizedBox(height: 6),
                Text('$e', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => ref.read(cloneListProvider.notifier).refreshClones(),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.grid_view_rounded,
                size: 56,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Clones in Inventory',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Select any app in the App Catalog to deploy isolated clone workers.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Grid View (Compact, perfectly proportioned, ZERO overflow)
  // ---------------------------------------------------------------------------
  Widget _buildGrid(BuildContext context, List<CloneInfo> clones) {
    return RefreshIndicator(
      onRefresh: () => ref.read(cloneListProvider.notifier).refreshClones(),
      child: GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.65, // Ample vertical room to prevent any overflow
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
        ),
        itemCount: clones.length,
        itemBuilder: (context, index) {
          final clone = clones[index];
          return _buildCloneGridCard(context, clone);
        },
      ),
    );
  }

  Widget _buildCloneGridCard(BuildContext context, CloneInfo clone) {
    final theme = Theme.of(context);
    final padId = clone.id.toString().padLeft(2, '0');

    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withOpacity(0.4),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Worker Tag & More Menu
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    ':worker_$padId',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  iconSize: 18,
                  constraints: const BoxConstraints(minWidth: 140),
                  icon: Icon(Icons.more_vert_rounded, size: 18, color: theme.colorScheme.onSurfaceVariant),
                  onSelected: (val) async {
                    if (val == 'settings') {
                      ref.read(cloneListProvider.notifier).openSettings(clone.id, clone.packageName);
                    } else if (val == 'export') {
                      final path = await ref.read(cloneListProvider.notifier).exportStandaloneApk(clone.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            behavior: SnackBarBehavior.floating,
                            content: Text(path != null ? 'Exported APK to: $path' : 'Export failed'),
                          ),
                        );
                      }
                    } else if (val == 'delete') {
                      ref.read(cloneListProvider.notifier).deleteClone(clone.id);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'settings',
                      child: Row(
                        children: [
                          Icon(Icons.storage_rounded, size: 16),
                          SizedBox(width: 8),
                          Text('App Info', style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'export',
                      child: Row(
                        children: [
                          Icon(Icons.file_download_rounded, size: 16),
                          SizedBox(width: 8),
                          Text('Export APK', style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, size: 16, color: theme.colorScheme.error),
                          const SizedBox(width: 8),
                          Text('Delete Clone', style: TextStyle(fontSize: 13, color: theme.colorScheme.error)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Icon Avatar
            Center(
              child: CloneAppIcon(
                packageName: clone.packageName,
                cloneId: clone.id,
                size: 48,
                borderRadius: 13,
              ),
            ),
            const SizedBox(height: 8),

            // Text Info (Flexible to prevent any overflow)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    clone.effectiveName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  // Profile badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.30),
                        width: 0.7,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.badge_rounded, size: 9, color: theme.colorScheme.primary),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            clone.effectiveProfileLabel,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    clone.packageName,
                    style: TextStyle(
                      fontSize: 9.5,
                      color: theme.colorScheme.onSurfaceVariant,
                      fontFamily: 'monospace',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            const Divider(height: 10),

            // Quick Action Buttons Row (Fitted perfectly with zero wrapping / zero overflow)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // 1. Launch
                _buildCompactActionButton(
                  icon: clone.isInstalled ? Icons.play_arrow_rounded : Icons.install_mobile_rounded,
                  color: clone.isInstalled ? const Color(0xFF673AB7) : const Color(0xFF00C853),
                  tooltip: clone.isInstalled ? 'Launch Instance' : 'Install Standalone APK',
                  onTap: () {
                    ref.read(cloneListProvider.notifier).launchClone(clone.id, isSingleTask: clone.isSingleTask);
                  },
                ),
                // 2. Install Standalone APK
                _buildCompactActionButton(
                  icon: Icons.install_mobile_rounded,
                  color: const Color(0xFF00C853),
                  tooltip: 'Install Standalone APK',
                  onTap: () async {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        behavior: SnackBarBehavior.floating,
                        content: Text('Preparing standalone installer for ${clone.effectiveName}...'),
                      ),
                    );
                    await ref.read(cloneListProvider.notifier).installStandaloneApk(clone.id);
                  },
                ),
                // 3. Pin to Phone Desktop
                _buildCompactActionButton(
                  icon: Icons.add_to_home_screen_rounded,
                  color: const Color(0xFF00B0FF),
                  tooltip: 'Pin to Phone Desktop',
                  onTap: () async {
                    final ok = await ref.read(cloneListProvider.notifier).pinToHomeScreen(clone.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          behavior: SnackBarBehavior.floating,
                          content: Text(
                            ok
                                ? 'Desktop shortcut for ${clone.effectiveName} added!'
                                : 'Shortcut requested. Check your phone home screen!',
                          ),
                        ),
                      );
                    }
                  },
                ),
                // 4. Delete Clone
                _buildCompactActionButton(
                  icon: Icons.delete_outline_rounded,
                  color: const Color(0xFFFF5252),
                  tooltip: 'Delete Clone',
                  onTap: () {
                    ref.read(cloneListProvider.notifier).deleteClone(clone.id);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // List View (Full-width detailed cards with explicit action buttons)
  // ---------------------------------------------------------------------------
  Widget _buildList(BuildContext context, List<CloneInfo> clones) {
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: () => ref.read(cloneListProvider.notifier).refreshClones(),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        itemCount: clones.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final clone = clones[index];
          final padId = clone.id.toString().padLeft(2, '0');

          return Card(
            elevation: 2,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: theme.colorScheme.outlineVariant.withOpacity(0.4),
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: [
                      CloneAppIcon(
                        packageName: clone.packageName,
                        cloneId: clone.id,
                        size: 46,
                        borderRadius: 12,
                      ),
                      const SizedBox(width: 12),
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
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    ':worker_$padId',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            // Profile badge
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: theme.colorScheme.primary.withValues(alpha: 0.30),
                                      width: 0.7,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.badge_rounded, size: 10, color: theme.colorScheme.primary),
                                      const SizedBox(width: 3),
                                      Text(
                                        clone.effectiveProfileLabel,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              clone.packageName,
                              style: TextStyle(
                                fontSize: 11,
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
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Launch Button
                      FilledButton.tonalIcon(
                        onPressed: () {
                          ref.read(cloneListProvider.notifier).launchClone(clone.id, isSingleTask: clone.isSingleTask);
                        },
                        icon: const Icon(Icons.play_arrow_rounded, size: 16),
                        label: const Text('Open', style: TextStyle(fontSize: 12)),
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Install Standalone APK
                      OutlinedButton.icon(
                        onPressed: () async {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              behavior: SnackBarBehavior.floating,
                              content: Text('Preparing installer for ${clone.effectiveName}...'),
                            ),
                          );
                          await ref.read(cloneListProvider.notifier).installStandaloneApk(clone.id);
                        },
                        icon: const Icon(Icons.install_mobile_rounded, size: 16, color: Color(0xFF00C853)),
                        label: const Text('Install', style: TextStyle(fontSize: 12, color: Color(0xFF00C853))),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Pin Shortcut
                      IconButton(
                        tooltip: 'Pin to Phone Desktop',
                        icon: const Icon(Icons.add_to_home_screen_rounded, size: 20, color: Color(0xFF00B0FF)),
                        onPressed: () async {
                          final ok = await ref.read(cloneListProvider.notifier).pinToHomeScreen(clone.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                behavior: SnackBarBehavior.floating,
                                content: Text(
                                  ok
                                      ? 'Desktop shortcut added!'
                                      : 'Shortcut requested. Check your phone home screen!',
                                ),
                              ),
                            );
                          }
                        },
                      ),
                      // Delete
                      IconButton(
                        tooltip: 'Delete Clone',
                        icon: Icon(Icons.delete_outline_rounded, size: 20, color: theme.colorScheme.error),
                        onPressed: () {
                          ref.read(cloneListProvider.notifier).deleteClone(clone.id);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Reusable Compact Action Button
  // ---------------------------------------------------------------------------
  Widget _buildCompactActionButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: color.withOpacity(0.3),
                width: 0.8,
              ),
            ),
            child: Icon(
              icon,
              size: 16,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}
