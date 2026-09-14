// lib/ui/screens/clones_inventory_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/clone_info.dart';
import '../../providers/clone_provider.dart';

/// Instance Inventory Screen displaying a responsive grid view of all generated clones
/// with quick actions: "Open App", "App Info / Storage", and "Uninstall".
class ClonesInventoryScreen extends ConsumerWidget {
  const ClonesInventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clonesAsync = ref.watch(cloneListProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Instance Inventory'),
        actions: [
          IconButton(
            tooltip: 'Refresh Clones',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.read(cloneListProvider.notifier).refreshClones(),
          ),
        ],
      ),
      body: clonesAsync.when(
        data: (clones) => _buildGrid(context, clones, ref),
        loading: () => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Fetching clone vault inventory...'),
            ],
          ),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 48, color: theme.colorScheme.error),
              const SizedBox(height: 12),
              Text('Failed to query inventory: $e'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.read(cloneListProvider.notifier).refreshClones(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGrid(BuildContext context, List<CloneInfo> clones, WidgetRef ref) {
    if (clones.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.grid_view_rounded,
                size: 64,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 16),
              const Text(
                'No clones deployed yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Use the Clone Setup Sheet or Clone Manager to spawn virtual worker profiles.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(cloneListProvider.notifier).refreshClones(),
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.72,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
        ),
        itemCount: clones.length,
        itemBuilder: (context, index) {
          final clone = clones[index];
          return _buildCloneGridCard(context, clone, ref);
        },
      ),
    );
  }

  Widget _buildCloneGridCard(BuildContext context, CloneInfo clone, WidgetRef ref) {
    final theme = Theme.of(context);
    final padId = clone.id.toString().padLeft(2, '0');

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Badge & Worker Indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
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
                if (clone.isSingleTask)
                  Icon(
                    Icons.filter_1_rounded,
                    size: 16,
                    color: theme.colorScheme.tertiary,
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Icon & Name
            Center(
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.secondary,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    'C$padId',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Text Info
            Text(
              clone.effectiveName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
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

            const Spacer(),
            const Divider(height: 1),

            // Quick Actions: "Open App", "Pin to Desktop", "Storage", "Uninstall"
            OverflowBar(
              alignment: MainAxisAlignment.spaceEvenly,
              spacing: 0,
              children: [
                IconButton(
                  tooltip: 'Open App',
                  icon: const Icon(Icons.open_in_new_rounded, size: 19),
                  color: theme.colorScheme.primary,
                  onPressed: () {
                    ref.read(cloneListProvider.notifier).launchClone(clone.id, isSingleTask: clone.isSingleTask);
                  },
                ),
                IconButton(
                  tooltip: 'Pin to Phone Desktop',
                  icon: const Icon(Icons.add_to_home_screen_rounded, size: 19),
                  color: const Color(0xFF00E5FF),
                  onPressed: () async {
                    final ok = await ref.read(cloneListProvider.notifier).pinToHomeScreen(clone.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          behavior: SnackBarBehavior.floating,
                          content: Text(
                            ok
                                ? 'Desktop shortcut for ${clone.effectiveName} added to phone screen!'
                                : 'Shortcut requested. Check your phone home screen!',
                          ),
                        ),
                      );
                    }
                  },
                ),
                IconButton(
                  tooltip: 'App Info / Storage',
                  icon: const Icon(Icons.storage_rounded, size: 19),
                  color: theme.colorScheme.secondary,
                  onPressed: () {
                    ref.read(cloneListProvider.notifier).openSettings(clone.id, clone.packageName);
                  },
                ),
                IconButton(
                  tooltip: 'Uninstall',
                  icon: const Icon(Icons.delete_outline_rounded, size: 19),
                  color: theme.colorScheme.error,
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
  }
}
