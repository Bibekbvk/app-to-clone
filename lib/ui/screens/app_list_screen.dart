// lib/ui/screens/app_list_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/app_info.dart';
import '../../providers/clone_provider.dart';
import '../sheets/clone_setup_sheet.dart';

/// App Selection Screen displaying searchable list of installed apps,
/// extracted icons, app names, package IDs, version codes, and filter chips.
class AppListScreen extends ConsumerStatefulWidget {
  const AppListScreen({super.key});

  @override
  ConsumerState<AppListScreen> createState() => _AppListScreenState();
}

class _AppListScreenState extends ConsumerState<AppListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'All Apps';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openCloneSetup(AppInfo app) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CloneSetupSheet(preselectedApp: app),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appsAsync = ref.watch(installedAppsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Target Applications'),
        actions: [
          IconButton(
            tooltip: 'Refresh Apps',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.refresh(installedAppsProvider),
          ),
          IconButton(
            tooltip: 'Toggle Theme',
            icon: Icon(
              theme.brightness == Brightness.dark
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
            ),
            onPressed: () => ref.read(themeModeProvider.notifier).toggleTheme(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Field
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SearchBar(
              controller: _searchController,
              hintText: 'Search applications or package ID...',
              leading: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0),
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
              onChanged: (value) => setState(() => _searchQuery = value.trim()),
            ),
          ),
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: ['All Apps', 'Social & Messaging', 'Custom Cloned'].map((chipLabel) {
                final isSelected = _selectedFilter == chipLabel;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text(chipLabel),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() => _selectedFilter = chipLabel);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          // App List
          Expanded(
            child: appsAsync.when(
              loading: () => const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Scanning installed packages...'),
                  ],
                ),
              ),
              error: (err, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline_rounded, size: 48, color: theme.colorScheme.error),
                    const SizedBox(height: 12),
                    Text('Error querying packages: $err'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => ref.refresh(installedAppsProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (apps) {
                final filtered = apps.where((app) {
                  final matchesQuery = _searchQuery.isEmpty ||
                      app.appName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                      app.packageName.toLowerCase().contains(_searchQuery.toLowerCase());

                  if (!matchesQuery) return false;

                  if (_selectedFilter == 'Social & Messaging') {
                    return _isSocialApp(app.packageName);
                  } else if (_selectedFilter == 'Custom Cloned') {
                    return app.packageName.contains('.clone') || app.appName.contains('Clone');
                  }
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text('No applications match your criteria.'),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) => const Divider(height: 1, indent: 72),
                  itemBuilder: (context, index) {
                    final app = filtered[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      leading: _buildAppIcon(app, theme),
                      title: Text(
                        app.appName,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 2),
                          Text(
                            app.packageName,
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Version: ${app.versionName ?? 'v${app.versionCode}'} (${app.versionCode})',
                            style: TextStyle(fontSize: 11, color: theme.colorScheme.outline),
                          ),
                        ],
                      ),
                      trailing: FilledButton.tonalIcon(
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const Text('Clone'),
                        onPressed: () => _openCloneSetup(app),
                      ),
                      onTap: () => _openCloneSetup(app),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.tune_rounded),
        label: const Text('Clone Setup'),
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => const CloneSetupSheet(),
          );
        },
      ),
    );
  }

  Widget _buildAppIcon(AppInfo app, ThemeData theme) {
    if (app.iconBytes != null && app.iconBytes!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(
          app.iconBytes!,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _fallbackIcon(theme),
        ),
      );
    }
    return _fallbackIcon(theme);
  }

  Widget _fallbackIcon(ThemeData theme) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        Icons.android_rounded,
        color: theme.colorScheme.onSecondaryContainer,
        size: 28,
      ),
    );
  }

  bool _isSocialApp(String pkg) {
    final lower = pkg.toLowerCase();
    return lower.contains('paypal') ||
        lower.contains('whatsapp') ||
        lower.contains('telegram') ||
        lower.contains('facebook') ||
        lower.contains('instagram') ||
        lower.contains('twitter') ||
        lower.contains('messenger') ||
        lower.contains('signal') ||
        lower.contains('tiktok') ||
        lower.contains('snapchat') ||
        lower.contains('viber') ||
        lower.contains('discord');
  }
}
