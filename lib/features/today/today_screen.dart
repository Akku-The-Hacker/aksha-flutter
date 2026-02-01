import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/providers/daily_instance_provider.dart';
import '../../core/models/daily_instance_model.dart';
import '../../core/services/quote_service.dart';
import 'instance_detail_dialog.dart';

class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  String _dailyQuote = 'Ready to track your routines?';

  @override
  void initState() {
    super.initState();
    _loadDailyQuote();
  }

  Future<void> _loadDailyQuote() async {
    final quote = await QuoteService.getDailyQuote();
    if (mounted) {
      setState(() {
        _dailyQuote = quote;
      });
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return '🌅 Good Morning';
    if (hour < 17) return '☀️ Good Afternoon';
    if (hour < 21) return '🌆 Good Evening';
    return '🌙 Good Night';
  }

  void _previousDay() {
    final current = ref.read(selectedDateProvider);
    ref.read(selectedDateProvider.notifier).state =
        current.subtract(const Duration(days: 1));
  }

  void _nextDay() {
    final current = ref.read(selectedDateProvider);
    ref.read(selectedDateProvider.notifier).state =
        current.add(const Duration(days: 1));
  }

  void _jumpToDate() async {
    final current = ref.read(selectedDateProvider);
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      ref.read(selectedDateProvider.notifier).state = picked;
    }
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  String _formatTime(String time) {
    final parts = time.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  }

  Color _getStatusColor(InstanceStatus status) {
    switch (status) {
      case InstanceStatus.done:
        return const Color(0xFF10B981); // Green
      case InstanceStatus.partial:
        return const Color(0xFFF59E0B); // Amber
      case InstanceStatus.skipped:
        return Colors.grey;
      case InstanceStatus.missed:
        return const Color(0xFFEF4444); // Red
      case InstanceStatus.pending:
        return Colors.blue;
    }
  }

  String _getStatusEmoji(InstanceStatus status) {
    switch (status) {
      case InstanceStatus.done:
        return '✅';
      case InstanceStatus.partial:
        return '⚡';
      case InstanceStatus.skipped:
        return '⏭️';
      case InstanceStatus.missed:
        return '❌';
      case InstanceStatus.pending:
        return '⏳';
    }
  }

  // Check if instance is currently active (overlaps current time)
  bool _isCurrentRoutine(DailyInstance instance) {
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final selectedDate = ref.read(selectedDateProvider);
    final selectedDateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
    
    // Only highlight if viewing today
    if (todayStr != selectedDateStr) return false;
    
    final nowMinutes = now.hour * 60 + now.minute;
    final startParts = instance.plannedStart.split(':');
    final endParts = instance.plannedEnd.split(':');
    final startMinutes = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
    final endMinutes = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
    
    // Handle overnight routines
    if (endMinutes < startMinutes) {
      return nowMinutes >= startMinutes || nowMinutes <= endMinutes;
    }
    return nowMinutes >= startMinutes && nowMinutes <= endMinutes;
  }

  // Sort instances: Current > Upcoming > Past
  List<DailyInstance> _sortInstancesByTimeRelevance(List<DailyInstance> instances, DateTime date) {
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final nowMinutes = now.hour * 60 + now.minute;
    
    // If not viewing today, just sort by start time
    if (todayStr != dateStr) {
      final sorted = List<DailyInstance>.from(instances);
      sorted.sort((a, b) {
        final aStart = _parseTimeToMinutes(a.plannedStart);
        final bStart = _parseTimeToMinutes(b.plannedStart);
        return aStart.compareTo(bStart);
      });
      return sorted;
    }
    
    // For today: Current first, then upcoming, then past
    final current = <DailyInstance>[];
    final upcoming = <DailyInstance>[];
    final past = <DailyInstance>[];
    
    for (final instance in instances) {
      final startMinutes = _parseTimeToMinutes(instance.plannedStart);
      final endMinutes = _parseTimeToMinutes(instance.plannedEnd);
      
      // Handle overnight routines
      final isOvernight = endMinutes < startMinutes;
      bool isCurrent;
      bool isPast;
      
      if (isOvernight) {
        isCurrent = nowMinutes >= startMinutes || nowMinutes <= endMinutes;
        isPast = nowMinutes > endMinutes && nowMinutes < startMinutes;
      } else {
        isCurrent = nowMinutes >= startMinutes && nowMinutes <= endMinutes;
        isPast = nowMinutes > endMinutes;
      }
      
      if (isCurrent) {
        current.add(instance);
      } else if (isPast) {
        past.add(instance);
      } else {
        upcoming.add(instance);
      }
    }
    
    // Sort each group by start time
    current.sort((a, b) => _parseTimeToMinutes(a.plannedStart).compareTo(_parseTimeToMinutes(b.plannedStart)));
    upcoming.sort((a, b) => _parseTimeToMinutes(a.plannedStart).compareTo(_parseTimeToMinutes(b.plannedStart)));
    past.sort((a, b) => _parseTimeToMinutes(a.plannedStart).compareTo(_parseTimeToMinutes(b.plannedStart)));
    
    return [...current, ...upcoming, ...past];
  }

  int _parseTimeToMinutes(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = ref.watch(selectedDateProvider);
    final dateFormat = DateFormat('EEE, MMM d');
    final instancesAsync = ref.watch(selectedDateInstancesProvider);
    final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: _previousDay,
            ),
            TextButton(
              onPressed: _jumpToDate,
              child: Text(
                _isToday(selectedDate) ? 'Today' : dateFormat.format(selectedDate),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: _nextDay,
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Greeting banner (only show for today)
          if (_isToday(selectedDate))
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF6750A4).withOpacity(0.1),
                    const Color(0xFF6750A4).withOpacity(0.05),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getGreeting(),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _dailyQuote,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

          // Main content
          Expanded(
            child: instancesAsync.when(
              data: (instances) {
                if (instances.isEmpty) {
                  return _buildEmptyState();
                }

                // Sort instances by time relevance (current > upcoming > past)
                final sortedInstances = _sortInstancesByTimeRelevance(instances, selectedDate);

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(dailyInstancesProvider(dateStr));
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: sortedInstances.length + 1, // +1 for summary
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _buildSummary(sortedInstances);
                      }
                      
                      final instance = sortedInstances[index - 1];
                      final isCurrent = _isCurrentRoutine(instance);
                      return _InstanceCard(
                        instance: instance,
                        dateStr: dateStr,
                        formatTime: _formatTime,
                        getStatusColor: _getStatusColor,
                        getStatusEmoji: _getStatusEmoji,
                        isCurrent: isCurrent,
                        onTap: () async {
                          await showDialog(
                            context: context,
                            builder: (_) => InstanceDetailDialog(
                              instance: instance,
                              dateStr: dateStr,
                            ),
                          );
                        },
                        onStatusChange: (status) async {
                          await ref
                              .read(dailyInstancesProvider(dateStr).notifier)
                              .updateStatus(instance.id, status);
                        },
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error: $error'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(dailyInstancesProvider(dateStr)),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_today,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'No routines scheduled',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Go to Routine tab to create one',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(List<DailyInstance> instances) {
    final doneCount = instances.where((i) => i.status == InstanceStatus.done).length;
    final totalCount = instances.length;
    final percentage = totalCount > 0 ? (doneCount / totalCount * 100).round() : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF6750A4).withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progress: $doneCount/$totalCount',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                '$percentage%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: percentage >= 80 ? Colors.green : (percentage >= 50 ? Colors.orange : Colors.grey[700]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: totalCount > 0 ? doneCount / totalCount : 0,
              minHeight: 6,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                percentage >= 80 ? Colors.green : (percentage >= 50 ? Colors.orange : const Color(0xFF6750A4)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Instance Card Widget
class _InstanceCard extends ConsumerWidget {
  final DailyInstance instance;
  final String dateStr;
  final String Function(String) formatTime;
  final Color Function(InstanceStatus) getStatusColor;
  final String Function(InstanceStatus) getStatusEmoji;
  final VoidCallback onTap;
  final Function(InstanceStatus) onStatusChange;
  final bool isCurrent;

  const _InstanceCard({
    required this.instance,
    required this.dateStr,
    required this.formatTime,
    required this.getStatusColor,
    required this.getStatusEmoji,
    required this.onTap,
    required this.onStatusChange,
    this.isCurrent = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = instance.categoryColor != null
        ? Color(int.parse(instance.categoryColor!.replaceFirst('#', '0xFF')))
        : Colors.grey;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isCurrent
            ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      elevation: isCurrent ? 4 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current indicator banner
            if (isCurrent)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(10),
                    topRight: Radius.circular(10),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.play_arrow, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'NOW',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            // Main content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 4,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              instance.routineName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.schedule, size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(
                                  '${formatTime(instance.plannedStart)} - ${formatTime(instance.plannedEnd)}',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '(${(instance.plannedMinutes / 60).toStringAsFixed(1)} hrs)',
                                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Text(
                        getStatusEmoji(instance.status),
                        style: const TextStyle(fontSize: 24),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Status buttons
                  Wrap(
                    spacing: 8,
                    children: [
                      _statusButton(
                        context,
                        'Done',
                        InstanceStatus.done,
                        Icons.check_circle,
                        const Color(0xFF10B981),
                      ),
                      _statusButton(
                        context,
                        'Partial',
                        InstanceStatus.partial,
                        Icons.bolt,
                        const Color(0xFFF59E0B),
                      ),
                      _statusButton(
                        context,
                        'Skip',
                        InstanceStatus.skipped,
                        Icons.skip_next,
                        Colors.grey,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusButton(
    BuildContext context,
    String label,
    InstanceStatus status,
    IconData icon,
    Color color,
  ) {
    final isSelected = instance.status == status;
    
    return OutlinedButton.icon(
      onPressed: () => onStatusChange(status),
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: isSelected ? Colors.white : color,
        backgroundColor: isSelected ? color : null,
        side: BorderSide(color: color),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }
}
