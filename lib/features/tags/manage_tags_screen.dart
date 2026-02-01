import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/models/tag_model.dart';
import '../../core/providers/tag_provider.dart';

class ManageTagsScreen extends ConsumerWidget {
  const ManageTagsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tags = ref.watch(tagProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('🏷️ Manage Tags'),
        elevation: 0,
      ),
      body: tags.isEmpty
          ? _buildEmptyState(context, ref)
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: tags.length,
              itemBuilder: (context, index) {
                return _buildTagCard(context, ref, tags[index]);
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddTagDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add Tag'),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.label_off, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No tags yet',
            style: TextStyle(fontSize: 20, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Create tags to organize your routines',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showAddTagDialog(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Create First Tag'),
          ),
        ],
      ),
    );
  }

  Widget _buildTagCard(BuildContext context, WidgetRef ref, Tag tag) {
    final color = Color(int.parse('0xFF${tag.color}'));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(Icons.label, color: color),
        ),
        title: Text(
          tag.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: FutureBuilder<int>(
          future: ref.read(tagProvider.notifier).getUsageCount(tag.id),
          builder: (context, snapshot) {
            final count = snapshot.data ?? 0;
            return Text('Used in $count routine${count != 1 ? 's' : ''}');
          },
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _showEditTagDialog(context, ref, tag),
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              color: Colors.red,
              onPressed: () => _confirmDelete(context, ref, tag),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddTagDialog(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    Color selectedColor = Colors.blue;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create Tag'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Tag Name',
                  hintText: 'e.g., Important, Work, Personal',
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              const Text('Color:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _predefinedColors.map((color) {
                  final isSelected = color == selectedColor;
                  return GestureDetector(
                    onTap: () => setState(() => selectedColor = color),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Colors.black, width: 3)
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a tag name')),
                  );
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );

    if (result == true && context.mounted) {
      final tag = Tag(
        id: const Uuid().v4(),
        name: nameController.text.trim(),
        color: selectedColor.value.toRadixString(16).substring(2).toUpperCase(),
        createdAt: DateTime.now(),
      );

      final success = await ref.read(tagProvider.notifier).addTag(tag);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? '✅ Tag created successfully'
                : '❌ Tag name already exists'),
          ),
        );
      }
    }
  }

  Future<void> _showEditTagDialog(BuildContext context, WidgetRef ref, Tag tag) async {
    final nameController = TextEditingController(text: tag.name);
    Color selectedColor = Color(int.parse('0xFF${tag.color}'));

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Tag'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Tag Name'),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              const Text('Color:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _predefinedColors.map((color) {
                  final isSelected = color == selectedColor;
                  return GestureDetector(
                    onTap: () => setState(() => selectedColor = color),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Colors.black, width: 3)
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result == true && context.mounted) {
      final updatedTag = tag.copyWith(
        name: nameController.text.trim(),
        color: selectedColor.value.toRadixString(16).substring(2).toUpperCase(),
      );

      final success = await ref.read(tagProvider.notifier).updateTag(updatedTag);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? '✅ Tag updated successfully'
                : '❌ Tag name already exists'),
          ),
        );
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Tag tag) async {
    final usageCount = await ref.read(tagProvider.notifier).getUsageCount(tag.id);

    if (!context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Tag?'),
        content: Text(
          usageCount > 0
              ? 'This tag is used in $usageCount routine${usageCount != 1 ? 's' : ''}. Deleting it will remove it from all routines.'
              : 'Are you sure you want to delete this tag?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(tagProvider.notifier).deleteTag(tag.id);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Tag deleted')),
        );
      }
    }
  }

  static final List<Color> _predefinedColors = [
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.lightBlue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lightGreen,
    Colors.lime,
    Colors.yellow,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
  ];
}
