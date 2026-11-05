/// File Name: groups_screen.dart
/// Description: Screen for displaying and managing groups/workspaces.
/// Author: Keefe Chen
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/groups/group_provider.dart';

class GroupsScreen extends ConsumerWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(groupProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Groups'),
      ),
      body: groups.when(
        data: (groups) {
          if (groups.isEmpty) {
            return const Center(
              child: Text('No groups yet. Create one to get started!'),
            );
          }
          return ListView.builder(
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
              return ListTile(
                leading: const Icon(Icons.group),
                title: Text(group.name),
                subtitle: Text(group.description ?? ''),
                trailing: const Icon(Icons.arrow_forward_ios,
                    size: 16),
                onTap: () {
                  // TODO: Navigate to group detail screen
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Group ${group.name} selected')),
                  );
                },
              );
            },
          );
        },
        error: (error, stack) => Center(child: Text('Error: $error')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Show dialog to create new group
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Create group functionality coming soon')),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}