import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/providers/daily_instance_provider.dart';
import '../../core/services/quote_service.dart';
import '../../core/models/daily_instance_model.dart';
import '../focus/focus_mode_screen.dart';
import '../pomodoro/pomodoro_timer_screen.dart';

// Quote provider
final dailyQuoteProvider = FutureProvider<Quote?>((ref) async {
  final service = QuoteService();
  return service.getDailyQuote();
});

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final instancesAsync = ref.watch(todaysInstancesProvider);
    final quoteAsync = ref.watch(dailyQuoteProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App Bar with Date & Greetings
          SliverAppBar(
            floating: true,
            expandedHeight: 120,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
              title: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('EEEE, MMM d').format(DateTime.now()),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.normal,
                      color: Colors.white70,
                    ),
                  ),
                  const Text(
                    'Today\'s Focus',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              background: _buildHeaderBackground(context, quoteAsync),
            ),
          ),

          // Content
          instancesAsync.when(
            data: (instances) {
              if (instances.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.weekend, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          'No routines scheduled for today',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            // Navigate to routines tab
                            // This would typically involve using a specialized provider or callback
                          },
                          child: const Text('Manage Routines'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // Segregate instances
              final pending = instances
                  .where((i) =>
                      i.status == InstanceStatus.pending ||
                      i.status == InstanceStatus.partial)
                  .toList();
              final completed = instances
                  .where((i) =>
                      i.status == InstanceStatus.done ||
                      i.status == InstanceStatus.skipped ||
                      i.status == InstanceStatus.missed)
                  .toList();

              return SliverList(
                delegate: SliverChildListDelegate([
                  if (pending.isNotEmpty) ...[
                    _buildSectionHeader('UP NEXT'),
                    ...pending.map(
                        (instance) => _buildInstanceCard(context, ref, instance)),
                  ],
                  if (completed.isNotEmpty) ...[
                    _buildSectionHeader('COMPLETED'),
                    ...completed.map((instance) =>
                        _buildInstanceCard(context, ref, instance, isDone: true)),
                  ],
                  const SizedBox(height: 80), // Bottom padding
                ]),
              );
            },
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, s) => SliverFillRemaining(
              child: Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Open Pomodoro Timer without specific routine
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const PomodoroTimerScreen(),
            ),
          );
        },
        icon: const Icon(Icons.timer),
        label: const Text('Focus'),
      ),
    );
  }

  Widget _buildHeaderBackground(
      BuildContext context, AsyncValue<Quote?> quoteAsync) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6750A4), Color(0xFF9C27B0)],
        ),
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            right: -50,
            top: -50,
            child: CircleAvatar(
              radius: 100,
              backgroundColor: Colors.white.withOpacity(0.1),
            ),
          ),
          
          // Quote
          Positioned(
            top: 40,
            left: 20,
            right: 20,
            child: quoteAsync.when(
              data: (quote) => quote != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '"${quote.text}"',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontStyle: FontStyle.italic,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "- ${quote.author}",
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    )
                  : const SizedBox(),
              loading: () => const SizedBox(),
              error: (_, __) => const SizedBox(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildInstanceCard(
      BuildContext context, WidgetRef ref, DailyInstance instance,
      {bool isDone = false}) {
    // In a real app, resolve routine details from provider/repo
    // For now, assume routineName is sufficient or available
    
    return Dismissible(
      key: Key(instance.id.toString()),
      background: Container(
        color: Colors.green,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Icon(Icons.check, color: Colors.white),
      ),
      secondaryBackground: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.close, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        if (isDone) return false; // Already done, maybe allow un-doing later

        final status = direction == DismissDirection.startToEnd
            ? InstanceStatus.done
            : InstanceStatus.skipped;
        
        // Update status via provider
        final notifier = ref.read(dailyInstancesProvider(instance.date).notifier);
        await notifier.updateStatus(instance.id!, status);
        
        return false; // Don't actually remove from list (let provider refresh move it)
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        elevation: isDone ? 0 : 2,
        color: isDone ? Colors.grey[100] : Colors.white,
        child: ListTile(
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isDone ? Colors.grey[300] : const Color(0xFF6750A4).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isDone ? Icons.check : Icons.circle_outlined,
              color: isDone ? Colors.grey[600] : const Color(0xFF6750A4),
            ),
          ),
          title: Text(
            instance.routineName,
            style: TextStyle(
              decoration: isDone ? TextDecoration.lineThrough : null,
              color: isDone ? Colors.grey : Colors.black,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            '${instance.plannedStart} - ${instance.plannedEnd} (${instance.plannedMinutes}m)',
            style: TextStyle(color: isDone ? Colors.grey[400] : Colors.grey[600]),
          ),
          trailing: isDone
              ? null
              : IconButton(
                  icon: const Icon(Icons.play_arrow),
                  color: Colors.green,
                  onPressed: () {
                    // Start Focus Mode
                    // Need to fetch full routine object in real app
                    // Simulating for now
                    /*
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FocusModeScreen(
                          routine: routine_object,
                          durationMinutes: instance.plannedMinutes,
                        ),
                      ),
                    );
                    */
                  },
                ),
        ),
      ),
    );
  }
}
