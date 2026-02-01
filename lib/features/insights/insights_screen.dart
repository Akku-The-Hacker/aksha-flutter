import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/repositories/daily_instance_repository.dart';
import '../../core/models/daily_instance_model.dart';
import '../calendar/calendar_view_screen.dart';

// Analytics provider
final weeklyStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repository = DailyInstanceRepository();
  final now = DateTime.now();
  final weekStart = now.subtract(Duration(days: now.weekday - 1));
  
  final stats = <String, int>{};
  int totalDone = 0;
  int totalInstances = 0;

  for (int i = 0; i < 7; i++) {
    final date = weekStart.add(Duration(days: i));
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final instances = await repository.getByDate(dateStr);
    
    final doneCount = instances.where((i) => i.status == InstanceStatus.done).length;
    stats[dateStr] = doneCount;
    totalDone += doneCount;
    totalInstances += instances.length;
  }

  return {
    'stats': stats,
    'totalDone': totalDone,
    'totalInstances': totalInstances,
    'percentage': totalInstances > 0 ? (totalDone / totalInstances * 100).round() : 0,
  };
});

// Streak provider
final streakProvider = FutureProvider<int>((ref) async {
  final repository = DailyInstanceRepository();
  int streak = 0;
  DateTime current = DateTime.now();

  while (true) {
    final dateStr = DateFormat('yyyy-MM-dd').format(current);
    final instances = await repository.getByDate(dateStr);
    
    if (instances.isEmpty) break;
    
    final hasAnyDone = instances.any((i) => i.status == InstanceStatus.done);
    if (!hasAnyDone) break;
    
    streak++;
    current = current.subtract(const Duration(days: 1));
    
    if (streak > 365) break; // Safety limit
  }

  return streak;
});

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weeklyStats = ref.watch(weeklyStatsProvider);
    final streak = ref.watch(streakProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('📊 Insights'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: 'Calendar View',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CalendarViewScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(weeklyStatsProvider);
              ref.invalidate(streakProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(weeklyStatsProvider);
          ref.invalidate(streakProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Streak card
            streak.when(
              data: (streak) => _buildStreakCard(streak),
              loading: () => const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (e, _) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Error loading streak: $e'),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Weekly stats
            weeklyStats.when(
              data: (data) => _buildWeeklyStats(data),
              loading: () => const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (e, _) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Error loading stats: $e'),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Tips card
            _buildTipsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildStreakCard(int streak) {
    return Card(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF6750A4).withOpacity(0.1),
              const Color(0xFF6750A4).withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            const Text(
              '🔥 Current Streak',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Text(
              streak.toString(),
              style: const TextStyle(
                fontSize: 64,
                fontWeight: FontWeight.bold,
                color: Color(0xFF6750A4),
              ),
            ),
            const Text(
              'Days',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            if (streak > 0) ...[
              const SizedBox(height: 16),
              Text(
                _getStreakMessage(streak),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getStreakMessage(int streak) {
    if (streak >= 30) return '🎉 Incredible! A full month of consistency!';
    if (streak >= 21) return '💪 Amazing! You\'re building strong habits!';
    if (streak >= 7) return '🌟 Great work! A full week completed!';
    if (streak >= 3) return '👍 Nice! Keep the momentum going!';
    return '✨ Off to a great start!';
  }

  Widget _buildWeeklyStats(Map<String, dynamic> data) {
    final stats = data['stats'] as Map<String, int>;
    final totalDone = data['totalDone'] as int;
    final totalInstances = data['totalInstances'] as int;
    final percentage = data['percentage'] as int;

    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    
    final maxValue = stats.values.isEmpty ? 1 : stats.values.reduce((a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📊 This Week',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 24),

            // Bar chart
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (index) {
                final date = weekStart.add(Duration(days: index));
                final dateStr = DateFormat('yyyy-MM-dd').format(date);
                final count = stats[dateStr] ?? 0;
                final height = maxValue > 0 ? (count / maxValue * 100).toDouble() : 0.0;

                return Column(
                  children: [
                    Text(
                      count.toString(),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 30,
                      height: height.clamp(10.0, 100.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6750A4),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('E').format(date).substring(0, 1),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                );
              }),
            ),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            // Summary
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statItem('Completed', totalDone.toString(), Icons.check_circle, Colors.green),
                _statItem('Total', totalInstances.toString(), Icons.list, Colors.blue),
                _statItem('Rate', '$percentage%', Icons.trending_up, Colors.orange),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildTipsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lightbulb, color: Color(0xFFF59E0B)),
                const SizedBox(width: 8),
                const Text(
                  'Tips for Success',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _tip('Track honestly to see real progress'),
            _tip('Small consistent steps lead to big changes'),
            _tip('Review your routines weekly and adjust'),
          ],
        ),
      ),
    );
  }

  Widget _tip(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 16)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
