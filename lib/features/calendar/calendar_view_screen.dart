import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../core/repositories/daily_instance_repository.dart';
import '../../core/models/daily_instance_model.dart';

class CalendarViewScreen extends ConsumerStatefulWidget {
  const CalendarViewScreen({super.key});

  @override
  ConsumerState<CalendarViewScreen> createState() => _CalendarViewScreenState();
}

class _CalendarViewScreenState extends ConsumerState<CalendarViewScreen> {
  final DailyInstanceRepository _instanceRepo = DailyInstanceRepository();
  
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<String, List<DailyInstance>> _instancesByDate = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMonthData();
  }

  Future<void> _loadMonthData() async {
    setState(() => _isLoading = true);
    
    final startOfMonth = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final endOfMonth = DateTime(_focusedDay.year, _focusedDay.month + 1, 0);
    
    final instances = await _instanceRepo.getInstancesInRange(
      startOfMonth,
      endOfMonth,
    );

    // Group by date
    final grouped = <String, List<DailyInstance>>{};
    for (final instance in instances) {
      grouped.putIfAbsent(instance.date, () => []).add(instance);
    }

    setState(() {
      _instancesByDate = grouped;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📅 Calendar View'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildCalendar(),
                const Divider(),
                Expanded(child: _buildDayDetails()),
              ],
            ),
    );
  }

  Widget _buildCalendar() {
    return TableCalendar(
      firstDay: DateTime.utc(2020, 1, 1),
      lastDay: DateTime.utc(2030, 12, 31),
      focusedDay: _focusedDay,
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      calendarFormat: CalendarFormat.month,
      startingDayOfWeek: StartingDayOfWeek.monday,
      calendarStyle: CalendarStyle(
        todayDecoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.3),
          shape: BoxShape.circle,
        ),
        selectedDecoration: const BoxDecoration(
          color: Colors.blue,
          shape: BoxShape.circle,
        ),
        markerDecoration: const BoxDecoration(
          color: Colors.green,
          shape: BoxShape.circle,
        ),
      ),
      headerStyle: const HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
      ),
      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          _selectedDay = selectedDay;
          _focusedDay = focusedDay;
        });
      },
      onPageChanged: (focusedDay) {
        _focusedDay = focusedDay;
        _loadMonthData();
      },
      calendarBuilders: CalendarBuilders(
        markerBuilder: (context, date, events) {
          final dateStr = DateFormat('yyyy-MM-dd').format(date);
          final instances = _instancesByDate[dateStr] ?? [];
          
          if (instances.isEmpty) return null;

          final color = _getDayColor(instances);
          return Positioned(
            bottom: 1,
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
          );
        },
        defaultBuilder: (context, date, _) {
          final dateStr = DateFormat('yyyy-MM-dd').format(date);
          final instances = _instancesByDate[dateStr] ?? [];
          
          if (instances.isEmpty) {
            return null;
          }

          final color = _getDayColor(instances);
          return Container(
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 1),
            ),
            child: Center(
              child: Text(
                '${date.day}',
                style: TextStyle(color: color),
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getDayColor(List<DailyInstance> instances) {
    if (instances.isEmpty) return Colors.grey;

    final doneCount = instances.where((i) => i.status == InstanceStatus.done).length;
    final totalCount = instances.length;
    final percentage = doneCount / totalCount;

    if (percentage == 1.0) {
      return Colors.green; // Perfect day
    } else if (percentage >= 0.7) {
      return Colors.lightGreen; // Good day
    } else if (percentage >= 0.4) {
      return Colors.orange; // Partial day
    } else if (percentage > 0) {
      return Colors.red; // Poor day
    } else {
      return Colors.grey; // No completions
    }
  }

  Widget _buildDayDetails() {
    if (_selectedDay == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Select a day to view details',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDay!);
    final instances = _instancesByDate[dateStr] ?? [];

    if (instances.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No routines on this day',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    final doneCount = instances.where((i) => i.status == InstanceStatus.done).length;
    final percentage = (doneCount / instances.length * 100).round();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Day summary card
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('EEEE, MMMM d, y').format(_selectedDay!),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      percentage == 100 ? Icons.check_circle : Icons.pie_chart,
                      color: _getDayColor(instances),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$doneCount / ${instances.length} completed ($percentage%)',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Routines',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...instances.map((instance) => _buildInstanceCard(instance)),
      ],
    );
  }

  Widget _buildInstanceCard(DailyInstance instance) {
    final statusColor = _getStatusColor(instance.status);
    final statusIcon = _getStatusIcon(instance.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.2),
          child: Icon(statusIcon, color: statusColor, size: 20),
        ),
        title: Text(instance.routineName),
        subtitle: Text(
          '${instance.plannedStart} - ${instance.plannedEnd} (${instance.plannedMinutes} min)',
        ),
        trailing: Chip(
          label: Text(
            instance.status.name.toUpperCase(),
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
          ),
          backgroundColor: statusColor.withOpacity(0.2),
          labelStyle: TextStyle(color: statusColor),
        ),
      ),
    );
  }

  Color _getStatusColor(InstanceStatus status) {
    switch (status) {
      case InstanceStatus.done:
        return Colors.green;
      case InstanceStatus.partial:
        return Colors.orange;
      case InstanceStatus.skipped:
        return Colors.grey;
      case InstanceStatus.missed:
        return Colors.red;
      case InstanceStatus.pending:
        return Colors.blue;
    }
  }

  IconData _getStatusIcon(InstanceStatus status) {
    switch (status) {
      case InstanceStatus.done:
        return Icons.check_circle;
      case InstanceStatus.partial:
        return Icons.timelapse;
      case InstanceStatus.skipped:
        return Icons.skip_next;
      case InstanceStatus.missed:
        return Icons.cancel;
      case InstanceStatus.pending:
        return Icons.pending;
    }
  }
}
