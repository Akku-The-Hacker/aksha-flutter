import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/data/routine_templates.dart';
import '../../core/providers/routine_provider.dart';
import '../../core/repositories/category_repository.dart';

class TemplateLibraryScreen extends ConsumerStatefulWidget {
  const TemplateLibraryScreen({super.key});

  @override
  ConsumerState<TemplateLibraryScreen> createState() => _TemplateLibraryScreenState();
}

class _TemplateLibraryScreenState extends ConsumerState<TemplateLibraryScreen> {
  String? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    final categories = RoutineTemplateLibrary.getCategories();
    final templates = _selectedCategory == null
        ? RoutineTemplateLibrary.templates
        : RoutineTemplateLibrary.getByCategory(_selectedCategory!);

    return Scaffold(
      appBar: AppBar(
        title: const Text('📋 Routine Templates'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Category filter
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                _buildCategoryChip('All', null),
                const SizedBox(width: 8),
                ...categories.map((cat) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _buildCategoryChip(cat, cat),
                    )),
              ],
            ),
          ),
          const Divider(height: 1),
          // Templates list
          Expanded(
            child: templates.isEmpty
                ? const Center(child: Text('No templates found'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: templates.length,
                    itemBuilder: (context, index) {
                      return _buildTemplateCard(templates[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String label, String? value) {
    final isSelected = _selectedCategory == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedCategory = selected ? value : null;
        });
      },
      selectedColor: Theme.of(context).colorScheme.primaryContainer,
    );
  }

  Widget _buildTemplateCard(RoutineTemplate template) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(template.emoji, style: const TextStyle(fontSize: 24)),
            ),
            title: Text(
              template.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            subtitle: Text(template.description),
            trailing: Chip(
              label: Text(template.category),
              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.list_alt, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${template.routines.length} routines included',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...template.routines.take(3).map((routine) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.schedule, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            '${routine.startTime} - ${routine.endTime}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              routine.name,
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    )),
                if (template.routines.length > 3)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '+${template.routines.length - 3} more',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _importTemplate(template),
                    icon: const Icon(Icons.download),
                    label: const Text('Import Template'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _importTemplate(RoutineTemplate template) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Import ${template.name}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This will add ${template.routines.length} routines to your schedule:'),
            const SizedBox(height: 12),
            ...template.routines.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(child: Text(r.name, style: const TextStyle(fontSize: 14))),
                    ],
                  ),
                )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Import'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Get or create category
      final categoryRepo = CategoryRepository();
      final categories = await categoryRepo.getAll();
      final category = categories.firstWhere(
        (c) => c.name == template.category,
        orElse: () => categories.first, // Default to first category
      );

      // Import all routines
      final routineNotifier = ref.read(routineProvider.notifier);
      int successCount = 0;

      for (final routineData in template.routines) {
        final routine = RoutineTemplateLibrary.templateToRoutine(
          routineData,
          categoryId: category.id,
        );
        
        final success = await routineNotifier.addRoutine(routine);
        if (success) successCount++;
      }

      if (mounted) {
        Navigator.pop(context); // Close loading
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Imported $successCount/${template.routines.length} routines'),
            duration: const Duration(seconds: 3),
          ),
        );

        // Go back to previous screen
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Import failed: $e')),
        );
      }
    }
  }
}
