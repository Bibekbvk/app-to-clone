// lib/ui/screens/home_shell_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/app_info.dart';
import '../../models/clone_info.dart';
import '../../providers/clone_provider.dart';
import '../sheets/clone_setup_sheet.dart';
import '../widgets/clone_app_icon.dart';

/// Streamlined, unified Home Screen.
/// Combines the full list of installed apps (for quick 1-tap cloning)
/// with the manager for all created isolated clones.
class HomeShellScreen extends ConsumerStatefulWidget {
  const HomeShellScreen({super.key});

  @override
  ConsumerState<HomeShellScreen> createState() => _HomeShellScreenState();
}

class _HomeShellScreenState extends ConsumerState<HomeShellScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _openClonePrompt(AppInfo app) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CloneSetupSheet(preselectedApp: app),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    final appsAsync = ref.watch(installedAppsProvider);
    final clonesAsync = ref.watch(cloneListProvider);
    final clonesCount = clonesAsync.value?.length ?? 0;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 2,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.copy_all_rounded, color: primary, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Multi App Cloner',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
                ),
              ],
            ),
            Text(
              '100% Isolated Profiles & Separate Accounts',
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh Apps & Clones',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.invalidate(installedAppsProvider);
              ref.read(cloneListProvider.notifier).refreshClones();
            },
          ),
          IconButton(
            tooltip: 'Toggle Theme',
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            ),
            onPressed: () => ref.read(themeModeProvider.notifier).toggleTheme(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(54),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            height: 42,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(24),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: primary,
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: [
                const Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.apps_rounded, size: 18),
                      SizedBox(width: 6),
                      Text('Installed Apps'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.layers_rounded, size: 18),
                      const SizedBox(width: 6),
                      Text('My Clones ($clonesCount)'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Installed Apps List (Target Apps for Cloning)
          _buildInstalledAppsTab(appsAsync, clonesAsync.value ?? []),

          // Tab 2: My Cloned Apps (Active Multi-Profiles)
          _buildClonesTab(clonesAsync),
        ],
      ),
    );
  }

  Widget _buildInstalledAppsTab(
    AsyncValue<List<AppInfo>> appsAsync,
    List<CloneInfo> currentClones,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    return Column(
      children: [
        // Quick Search Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: SearchBar(
            controller: _searchController,
            elevation: WidgetStateProperty.all(0),
            backgroundColor: WidgetStateProperty.all(
              isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            ),
            hintText: 'Search applications to clone...',
            leading: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10.0),
              child: Icon(Icons.search_rounded),
            ),
            trailing: [
              if (_searchQuery.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear_rounded),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                ),
            ],
            onChanged: (val) => setState(() => _searchQuery = val.trim()),
          ),
        ),

        // Apps List
        Expanded(
          child: appsAsync.when(
            loading: () => const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 14),
                  Text('Scanning installed applications on device...'),
                ],
              ),
            ),
            error: (err, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
                    const SizedBox(height: 12),
                    Text('Failed to load apps: $err', textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref.refresh(installedAppsProvider),
                      child: const Text('Retry Scan'),
                    ),
                  ],
                ),
              ),
            ),
            data: (apps) {
              final query = _searchQuery.toLowerCase();
              final filtered = apps.where((app) {
                return app.appName.toLowerCase().contains(query) ||
                    app.packageName.toLowerCase().contains(query);
              }).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search_off_rounded, size: 48, color: theme.disabledColor),
                      const SizedBox(height: 12),
                      Text('No matching apps found for "$_searchQuery"'),
                    ],
                  ),
                );
              }

              return ListView.builder(
                itemCount: filtered.length,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemBuilder: (context, index) {
                  final app = filtered[index];
                  final existingForApp = currentClones
                      .where((c) => c.packageName == app.packageName)
                      .length;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      leading: CloneAppIcon(
                        packageName: app.packageName,
                        cloneId: 1,
                        size: 46,
                        showBadge: false,
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              app.appName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (existingForApp > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$existingForApp Active',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: primary,
                                ),
                              ),
                            ),
                        ],
                      ),
                      subtitle: Text(
                        app.packageName,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                          fontFamily: 'monospace',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () => _openClonePrompt(app),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_rounded, size: 18),
                            SizedBox(width: 4),
                            Text('Clone', style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      onTap: () => _openClonePrompt(app),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildClonesTab(AsyncValue<List<CloneInfo>> clonesAsync) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    return clonesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error loading clones: $err')),
      data: (clones) {
        if (clones.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.layers_clear_rounded, size: 48, color: primary),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'No Cloned Apps Yet',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap any app in the "Installed Apps" tab to clone it with an isolated profile and separate login session.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () => _tabController.animateTo(0),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Browse Apps to Clone'),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          itemCount: clones.length,
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            final clone = clones[index];
            final displayName = clone.displayName?.isNotEmpty == true
                ? clone.displayName!
                : clone.packageName;
            final padId = clone.id.toString().padLeft(2, '0');

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Info Row
                    Row(
                      children: [
                        CloneAppIcon(
                          packageName: clone.packageName,
                          cloneId: clone.id,
                          size: 50,
                          showBadge: true,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Profile #$padId (Isolated)',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF10B981),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      clone.packageName,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: theme.colorScheme.onSurfaceVariant,
                                        fontFamily: 'monospace',
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
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
                        // Delete Button
                        IconButton(
                          tooltip: 'Delete Clone & Clear Data',
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                          onPressed: () => _confirmDelete(clone),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(height: 1),
                    const SizedBox(height: 10),

                    // Actions Row
                    Row(
                      children: [
                        // Pin to Home Screen / App Menu Button
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(Icons.install_mobile_rounded, size: 18),
                            label: const Text(
                              'Add to Menu',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            onPressed: () => _addToMenuOrDesktop(clone),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Launch Clone Button
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: primary,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: Icon(
                              clone.isInstalled ? Icons.rocket_launch_rounded : Icons.install_mobile_rounded,
                              size: 18,
                            ),
                            label: Text(
                              clone.isInstalled ? 'Open App' : 'Install App',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            onPressed: () => _launchClone(clone),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _launchClone(CloneInfo clone) async {
    try {
      await ref.read(cloneListProvider.notifier).launchClone(clone.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to launch clone: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _addToMenuOrDesktop(CloneInfo clone) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final pinned = await ref.read(cloneListProvider.notifier).pinToHomeScreen(clone.id);
      await ref.read(cloneListProvider.notifier).installStandaloneApk(clone.id);

      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: const Color(0xFF10B981),
          content: Text(
            pinned
                ? 'Added "${clone.displayName ?? clone.packageName}" to Home Screen & App Menu!'
                : 'Installer prompt dispatched for App Menu installation!',
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: Colors.redAccent,
          content: Text('Could not add to menu: $e'),
        ),
      );
    }
  }

  Future<void> _confirmDelete(CloneInfo clone) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Cloned App?'),
        content: Text(
          'Are you sure you want to delete ${clone.displayName ?? clone.packageName}?\n\n'
          'All isolated account sessions and saved data for Profile #${clone.id} will be permanently removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(cloneListProvider.notifier).deleteClone(clone.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Clone deleted successfully.'),
          ),
        );
      }
    }
  }
}
