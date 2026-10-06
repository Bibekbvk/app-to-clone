// lib/ui/widgets/clone_app_icon.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/clone_provider.dart';

/// Reusable widget that displays the authentic app icon for a cloned package
/// with a neat corner badge (e.g. C01, C02) or gracefully falls back to a sleek
/// gradient placeholder with clone number.
class CloneAppIcon extends ConsumerWidget {
  final String packageName;
  final int cloneId;
  final double size;
  final double borderRadius;
  final bool showBadge;

  const CloneAppIcon({
    super.key,
    required this.packageName,
    required this.cloneId,
    this.size = 48,
    this.borderRadius = 14,
    this.showBadge = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final padId = cloneId.toString().padLeft(2, '0');
    final iconAsync = ref.watch(appIconBytesProvider(packageName));

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // The App Icon or Gradient Placeholder
          iconAsync.when(
            data: (bytes) {
              if (bytes != null && bytes.isNotEmpty) {
                return Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(borderRadius),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(borderRadius),
                    child: Image.memory(
                      bytes,
                      width: size,
                      height: size,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _buildFallback(theme, padId),
                    ),
                  ),
                );
              }
              return _buildFallback(theme, padId);
            },
            loading: () => _buildFallback(theme, padId),
            error: (_, _) => _buildFallback(theme, padId),
          ),

          // Optional Sleek Bottom-Right Badge (e.g. C01, C02)
          if (showBadge)
            Positioned(
              right: -3,
              bottom: -3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: theme.colorScheme.surface,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Text(
                  'C$padId',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFallback(ThemeData theme, String padId) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.secondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Text(
          'C$padId',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: size * 0.32,
          ),
        ),
      ),
    );
  }
}
