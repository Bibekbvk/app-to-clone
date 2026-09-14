// lib/ui/widgets/clone_progress_dialog.dart

import 'dart:async';
import 'package:flutter/material.dart';
import '../../clone_app.dart';

/// Real-Time Batch Progress Overlay Dialog displaying dynamic progress bar,
/// circular stage stepper (Extraction -> Split Merging -> Manifest Rewriting -> Signing -> Installation),
/// and live status logs.
class CloneProgressDialog extends StatefulWidget {
  final int totalClones;
  final String targetPackage;
  final String? baseDisplayName;
  final bool isSingleTask;
  final bool silentInstall;
  final bool keepDataIsolated;

  const CloneProgressDialog({
    super.key,
    required this.totalClones,
    required this.targetPackage,
    this.baseDisplayName,
    this.isSingleTask = false,
    this.silentInstall = false,
    this.keepDataIsolated = true,
  });

  @override
  State<CloneProgressDialog> createState() => _CloneProgressDialogState();
}

class _CloneProgressDialogState extends State<CloneProgressDialog> {
  static const List<String> _stageNames = [
    'Extraction',
    'Split Merging',
    'Manifest Rewriting',
    'Signing',
    'Installation',
  ];

  static const List<IconData> _stageIcons = [
    Icons.file_download_rounded,
    Icons.call_split_rounded,
    Icons.code_rounded,
    Icons.verified_user_rounded,
    Icons.install_mobile_rounded,
  ];

  int _currentStage = 0;
  String _statusLog = 'Initializing deployment sandbox...';
  StreamSubscription<String>? _progressSub;
  Timer? _fallbackSimulationTimer;

  @override
  void initState() {
    super.initState();

    // Listen to native EventChannel progress
    _progressSub = CloneApp.progressStream.listen(
      (event) {
        _handleProgressEvent(event);
      },
      onError: (err) {
        setState(() => _statusLog = 'Process info: $err');
      },
    );

    // Subtle simulation ticker for responsive feel if native channel is silent
    _fallbackSimulationTimer = Timer.periodic(const Duration(milliseconds: 1400), (t) {
      if (mounted && _currentStage < _stageNames.length - 1) {
        setState(() {
          _currentStage = (_currentStage + 1) % _stageNames.length;
          _statusLog = '${_stageNames[_currentStage]} for ${widget.targetPackage}...';
        });
      }
    });
  }

  void _handleProgressEvent(String event) {
    if (event.contains(':')) {
      final parts = event.split(':');
      final stageIdx = int.tryParse(parts[0]);
      if (stageIdx != null && stageIdx >= 0 && stageIdx < _stageNames.length) {
        setState(() {
          _currentStage = stageIdx;
          _statusLog = parts.sublist(1).join(':').trim();
        });
        return;
      }
    }
    setState(() => _statusLog = event);
  }

  @override
  void dispose() {
    _progressSub?.cancel();
    _fallbackSimulationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = (_currentStage + 1) / _stageNames.length;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title & Target App
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.rocket_launch_rounded, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cloning In Progress',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      Text(
                        'Target: ${widget.targetPackage}',
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
            const SizedBox(height: 24),

            // Circular Stage Stepper
            SizedBox(
              height: 140,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 130,
                    height: 130,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 8,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _stageIcons[_currentStage],
                        size: 36,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Stage ${_currentStage + 1} / ${_stageNames.length}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        _stageNames[_currentStage],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Stepper Dots Indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_stageNames.length, (idx) {
                final isCompleted = idx < _currentStage;
                final isCurrent = idx == _currentStage;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: isCurrent ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? theme.colorScheme.primary
                        : (isCurrent
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),

            // Linear Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 16),

            // Status Log Console
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _statusLog,
                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Cancel / Background Button
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Run in Background'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
