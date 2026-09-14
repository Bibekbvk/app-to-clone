// example/main.dart

import 'package:flutter/material.dart';
import 'package:clone_app_flutter/clone_app.dart';

/// Sample Dart usage code demonstrating clone creation, launch, listing, and deletion.
void main() {
  runApp(const MaterialApp(
    home: CloneAppExampleScreen(),
    debugShowCheckedModeBanner: false,
  ));
}

class CloneAppExampleScreen extends StatefulWidget {
  const CloneAppExampleScreen({super.key});

  @override
  State<CloneAppExampleScreen> createState() => _CloneAppExampleScreenState();
}

class _CloneAppExampleScreenState extends State<CloneAppExampleScreen> {
  final List<CloneInfo> _clones = [];
  bool _isLoading = false;
  String _status = 'Ready';

  @override
  void initState() {
    super.initState();
    _refreshClones();
  }

  Future<void> _refreshClones() async {
    setState(() => _isLoading = true);
    try {
      final list = await CloneApp.listClones();
      setState(() {
        _clones.clear();
        _clones.addAll(list);
        _status = 'Loaded ${_clones.length} clones.';
      });
    } catch (e) {
      setState(() => _status = 'Error loading clones: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleCreateClone() async {
    setState(() => _status = 'Creating clone for com.whatsapp...');
    try {
      final id = await CloneApp.createClone(
        packageName: 'com.whatsapp',
        displayName: 'Work WhatsApp',
        isSingleTask: false,
      );
      setState(() => _status = 'Created clone with ID: $id');
      await _refreshClones();
    } catch (e) {
      setState(() => _status = 'Creation error: $e');
    }
  }

  Future<void> _handleLaunchClone(int cloneId) async {
    setState(() => _status = 'Launching clone #$cloneId...');
    try {
      await CloneApp.launchClone(cloneId);
      setState(() => _status = 'Clone #$cloneId launched in separate task.');
    } catch (e) {
      setState(() => _status = 'Launch error: $e');
    }
  }

  Future<void> _handleDeleteClone(int cloneId) async {
    setState(() => _status = 'Deleting clone #$cloneId...');
    try {
      await CloneApp.deleteClone(cloneId);
      setState(() => _status = 'Deleted clone #$cloneId.');
      await _refreshClones();
    } catch (e) {
      setState(() => _status = 'Delete error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CloneApp Plugin Example'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshClones,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Colors.grey.shade200,
            child: Text(
              'Status: $_status',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _clones.isEmpty
                    ? const Center(child: Text('No clones yet. Tap Create Clone below.'))
                    : ListView.builder(
                        itemCount: _clones.length,
                        itemBuilder: (context, idx) {
                          final c = _clones[idx];
                          return ListTile(
                            leading: CircleAvatar(child: Text('${c.id}')),
                            title: Text(c.effectiveName),
                            subtitle: Text('${c.packageName}\n${c.installPath}'),
                            isThreeLine: true,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.play_arrow, color: Colors.green),
                                  onPressed: () => _handleLaunchClone(c.id),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _handleDeleteClone(c.id),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Create Sample Clone'),
        onPressed: _handleCreateClone,
      ),
    );
  }
}
