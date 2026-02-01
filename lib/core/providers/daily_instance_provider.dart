import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/daily_instance_model.dart';
import '../repositories/daily_instance_repository.dart';
import '../services/instance_generator_service.dart';
import '../services/gamification_service.dart';

// Daily Instance Repository Provider
final dailyInstanceRepositoryProvider = Provider<DailyInstanceRepository>((ref) {
  return DailyInstanceRepository();
});

// Instance Generator Service Provider
final instanceGeneratorProvider = Provider<InstanceGeneratorService>((ref) {
  return InstanceGeneratorService();
});

// Gamification Service Provider
final gamificationServiceProvider = Provider<GamificationService>((ref) {
  return GamificationService();
});

// Selected Date Provider (for Today tab)
final selectedDateProvider = StateProvider<DateTime>((ref) {
  return DateTime.now();
});

// Daily Instances State Notifier
class DailyInstanceNotifier extends StateNotifier<AsyncValue<List<DailyInstance>>> {
  final DailyInstanceRepository _repository;
  final InstanceGeneratorService _generator;
  final GamificationService _gamificationService;
  final String _date;

  DailyInstanceNotifier(
    this._repository,
    this._generator,
    this._gamificationService,
    this._date,
  ) : super(const AsyncValue.loading()) {
    loadInstances();
  }

  Future<void> loadInstances() async {
    state = const AsyncValue.loading();
    try {
      // First, try to generate instances for this date if needed
      await _generator.generateForDate(DateTime.parse(_date));
      
      // Then load instances
      final instances = await _repository.getByDate(_date);
      state = AsyncValue.data(instances);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> updateStatus(
    String instanceId,
    InstanceStatus status, {
    int? actualMinutes,
    String? notes,
  }) async {
    try {
      await _repository.updateStatus(
        instanceId,
        status,
        actualMinutes: actualMinutes,
        notes: notes,
      );
      
      // Check for achievements if status is done or partial
      if (status == InstanceStatus.done || status == InstanceStatus.partial) {
        await _gamificationService.checkAchievements();
        await _gamificationService.updateStats();
      }
      
      await loadInstances(); // Refresh
    } catch (e) {
      print('Error updating instance status: $e');
    }
  }

  Future<void> deleteInstance(String instanceId) async {
    try {
      await _repository.delete(instanceId);
      await loadInstances(); // Refresh
    } catch (e) {
      print('Error deleting instance: $e');
    }
  }
}

// Daily instances provider for a specific date
final dailyInstancesProvider =
    StateNotifierProvider.family<DailyInstanceNotifier, AsyncValue<List<DailyInstance>>, String>(
  (ref, date) {
    final repository = ref.watch(dailyInstanceRepositoryProvider);
    final generator = ref.watch(instanceGeneratorProvider);
    final gamification = ref.watch(gamificationServiceProvider);
    return DailyInstanceNotifier(repository, generator, gamification, date);
  },
);

// Convenience provider for today's instances
final todayInstancesProvider = Provider<AsyncValue<List<DailyInstance>>>((ref) {
  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
  return ref.watch(dailyInstancesProvider(today));
});

// Convenience provider for selected date instances (for Today tab)
final selectedDateInstancesProvider = Provider<AsyncValue<List<DailyInstance>>>((ref) {
  final selectedDate = ref.watch(selectedDateProvider);
  final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
  return ref.watch(dailyInstancesProvider(dateStr));
});

// Date stats provider
final dateStatsProvider = FutureProvider.family<Map<String, int>, String>((ref, date) async {
  final repository = ref.watch(dailyInstanceRepositoryProvider);
  return repository.getDateStats(date);
});

// Generation status provider
final generationStatusProvider = FutureProvider.family<Map<String, dynamic>, DateTime>((ref, date) async {
  final generator = ref.watch(instanceGeneratorProvider);
  return generator.getGenerationStatus(date);
});
