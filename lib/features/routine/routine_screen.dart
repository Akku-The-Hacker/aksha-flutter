import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/routine_provider.dart';
import '../../core/providers/category_provider.dart';
import '../../core/models/routine_model.dart';
import '../../core/models/category_model.dart';
import 'add_edit_routine_dialog.dart';

class RoutineScreen extends ConsumerWidget {
  const RoutineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeRoutinesAsync = ref.watch(activeRoutinesProvider);
    final categoriesAsync = ref.watch(activeCategoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Routines'),
        elevation: 0,
      ),
      body: activeRoutinesAsync.when(
        data: (routines) {
          if (routines.isEmpty) {
            return _buildEmptyState(context);
          }
          return _buildRoutineList(context, routines, categoriesAsync.value ?? []);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddEditRoutineDialog()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.list_alt, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No routines yet',
            style: TextStyle(fontSize: 20, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddEditRoutineDialog()),
              );
            },
            child: const Text('Create First Routine'),
          ),
        ],
      ),
    );
  }

  Widget _buildRoutineList(
    BuildContext context,
    List<Routine> routines,
    List<Category> categories,
  ) {
    // Group routines by category for better organization
    // Or just a simple list. Let's do a simple list first.
    
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80), // Fab space
      itemCount: routines.length,
      itemBuilder: (context, index) {
        final routine = routines[index];
        final category = categories.firstWhere(
          (c) => c.id == routine.categoryId,
          orElse: () => Category(
            id: -1,
            name: 'Unknown',
            color: Colors.grey,
            iconName: 'help',
            isSystem: false,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: category.color.withOpacity(0.2),
              child: Icon(Icons.schedule, color: category.color),
            ),
            title: Text(
              routine.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_formatTime(routine.startTime)} • ${routine.durationMinutes} min',
                ),
                const SizedBox(height: 4),
                _buildRepeatDays(routine.repeatDays),
              ],
            ),
            isThreeLine: true,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddEditRoutineDialog(routine: routine),
                ),
              );
            },
            trailing: PopupMenuButton(
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 20),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'edit') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddEditRoutineDialog(routine: routine),
                    ),
                  );
                } else if (value == 'delete') {
                  // Show confirmation?
                  // For now, assume ref is available on a real implementation to call delete
                }
              },
            ),
          ),
        );
      },
    );
  }

  String _formatTime(DateTime time) {
    // Simple formatter, in real app use DateFormat
    final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  Widget _buildRepeatDays(List<bool> days) {
    if (days.every((d) => d)) return const Text('Every day');
    if (days.every((d) => !d)) return const Text('Never');
    
    // 0=Mon, 6=Sun
    final labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final activeDays = <String>[];
    for (int i = 0; i < 7; i++) {
        if (days[i]) activeDays.add(labels[i]);
    }
    
    // Handling "Weekdays" and "Weekends" logic could be added here
    
    return Text(
      activeDays.join(', '),
      style: const TextStyle(fontSize: 12, color: Colors.grey),
    );
  }
}
