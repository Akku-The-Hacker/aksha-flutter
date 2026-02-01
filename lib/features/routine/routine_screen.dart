import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/providers/routine_provider.dart';
import '../../core/providers/category_provider.dart';
import '../../core/providers/daily_instance_provider.dart';
import '../../core/models/routine_model.dart';
import 'add_edit_routine_dialog.dart';
import 'paused_archived_screens.dart';

class RoutineScreen extends ConsumerWidget {
  const RoutineScreen({super.key});

  String _formatTime(String time) {
    if (time.isEmpty) return '';
    final parts = time.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  }

  String _formatDays(List<int> days) {
    if (days.length == 7) return 'Every day';
    if (days.isEmpty) return 'No days';
    
    final daySet = days.toSet();
    if (daySet.length == 5 && daySet.containsAll([1, 2, 3, 4, 5])) return 'Weekdays';
    if (daySet.length == 2 && daySet.containsAll([6, 7])) return 'Weekends';

    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final sortedDays = List<int>.from(days)..sort();
    return sortedDays.map((d) => dayNames[d - 1]).join(', ');
  }

  Color _parseColor(String colorStr) {
    try {
      if (colorStr.isEmpty) return Colors.grey;
      if (colorStr.startsWith('#')) {
        return Color(int.parse(colorStr.substring(1), radix: 16) + 0xFF000000);
      }
      if (colorStr.startsWith('0x')) {
        return Color(int.parse(colorStr));
      }
      return Color(int.parse(colorStr));
    } catch (e) {
      return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routinesAsync = ref.watch(activeRoutinesProvider);
    final categoriesAsync = ref.watch(activeCategoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Routines', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'paused',
                child: Row(
                  children: [
                    Icon(Icons.pause_circle_outline, color: Colors.amber),
                    SizedBox(width: 8),
                    Text('Paused Routines'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'archived',
                child: Row(
                  children: [
                    Icon(Icons.archive_outlined, color: Colors.grey),
                    SizedBox(width: 8),
                    Text('Archived Routines'),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'paused') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const PausedRoutinesScreen()));
              } else {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ArchivedRoutinesScreen()));
              }
            },
          ),
        ],
      ),
      body: routinesAsync.when(
        data: (routines) {
          if (routines.isEmpty) return _buildEmptyState(context);
          
          final categoryList = categoriesAsync.valueOrNull ?? [];
          final categoryMap = {for (var c in categoryList) c.id: c};

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: routines.length,
            itemBuilder: (context, index) {
              final routine = routines[index];
              final category = routine.categoryId != null ? categoryMap[routine.categoryId] : null;
              final categoryColor = category != null ? _parseColor(category.color) : Colors.grey[400]!;

              return _RoutineCard(
                routine: routine,
                categoryColor: categoryColor,
                categoryName: category?.name,
                onTap: () async {
                  final result = await showDialog(
                    context: context,
                    builder: (_) => AddEditRoutineDialog(routine: routine),
                  );
                  if (result == true) {
                    // Invalidate Today tab to refresh instances
                    final today = DateTime.now();
                    final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
                    ref.invalidate(dailyInstancesProvider(dateStr));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('✅ Routine updated!')),
                      );
                    }
                  }
                },
                onDelete: () async {
                  // Soft Delete (Archive)
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Archive Routine?'),
                      content: Text('Archive "${routine.name}"? You can restore it later.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Archive')),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    try {
                      await ref.read(activeRoutinesProvider.notifier).deleteRoutine(routine.id);
                      // Invalidate Today tab to refresh instances
                      final today = DateTime.now();
                      final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
                      ref.invalidate(dailyInstancesProvider(dateStr));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🗄️ Routine archived')));
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                      }
                    }
                  }
                },
                onHardDelete: () async {
                  // Hard Delete
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Delete Forever?'),
                      content: const Text(
                        'This will permanently delete the routine. This action cannot be undone.',
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Delete Forever', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    try {
                      await ref.read(activeRoutinesProvider.notifier).hardDeleteRoutine(routine.id);
                      // Invalidate Today tab to refresh instances
                      final today = DateTime.now();
                      final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
                      ref.invalidate(dailyInstancesProvider(dateStr));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🗑️ Routine deleted permanently')));
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                      }
                    }
                  }
                },
                onPause: () async {
                  try {
                    await ref.read(activeRoutinesProvider.notifier).pauseRoutine(routine.id);
                    // Invalidate Today tab to refresh instances
                    final today = DateTime.now();
                    final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
                    ref.invalidate(dailyInstancesProvider(dateStr));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⏸️ Routine paused')));
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                    }
                  }
                },
                formatTime: _formatTime,
                formatDays: _formatDays,
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await showDialog(
            context: context,
            builder: (_) => const AddEditRoutineDialog(),
          );
          if (result == true && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Routine created!')));
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Routine'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.repeat, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No routines yet',
            style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text('Create your first routine to get started', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
        ],
      ),
    );
  }
}

class _RoutineCard extends ConsumerWidget {
  final Routine routine;
  final Color categoryColor;
  final String? categoryName;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onHardDelete;
  final VoidCallback onPause;
  final String Function(String) formatTime;
  final String Function(List<int>) formatDays;

  const _RoutineCard({
    required this.routine,
    required this.categoryColor,
    this.categoryName,
    required this.onTap,
    required this.onDelete,
    required this.onHardDelete,
    required this.onPause,
    required this.formatTime,
    required this.formatDays,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Compact, colorful aesthetic
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showActionsSheet(context),
            child: Row(
              children: [
                // Left Color Strip
                Container(
                  width: 6,
                  height: 80, // Fixed height constraint for compactness
                  color: categoryColor,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                routine.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // Optional Category Badge
                            if (categoryName != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: categoryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Text(
                                    categoryName!,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: categoryColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.access_time_filled, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              '${formatTime(routine.startTime)} - ${formatTime(routine.endTime)}',
                              style: TextStyle(fontSize: 13, color: Colors.grey[800], fontWeight: FontWeight.w500),
                            ),
                            const Spacer(),
                            if (routine.notificationEnabled)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Icon(Icons.notifications_active, size: 14, color: Colors.grey[400]),
                              ),
                            if (routine.isOvernight)
                              Icon(Icons.nightlight_round, size: 14, color: Colors.indigo[300]),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                           Icon(Icons.calendar_today, size: 12, color: Colors.grey[400]),
                           const SizedBox(width: 4),
                           Text(
                              formatDays(routine.repeatDays),
                              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showActionsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Routine name header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  routine.name,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Divider(),
              // Edit
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.blue),
                title: const Text('Edit Routine'),
                onTap: () {
                  Navigator.pop(ctx);
                  onTap();
                },
              ),
              // Pause
              ListTile(
                leading: const Icon(Icons.pause_circle, color: Colors.amber),
                title: const Text('Pause Routine'),
                onTap: () {
                  Navigator.pop(ctx);
                  onPause();
                },
              ),
              // Archive
              ListTile(
                leading: const Icon(Icons.archive, color: Colors.orange),
                title: const Text('Archive Routine'),
                onTap: () {
                  Navigator.pop(ctx);
                  onDelete();
                },
              ),
              // Delete Forever
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text('Delete Forever', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  onHardDelete();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
