import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/routine_model.dart';
import '../repositories/routine_repository.dart';
import '../repositories/daily_instance_repository.dart';
import '../services/notification_service.dart';
import '../services/achievement_service.dart';

// Routine Repository Provider
final routineRepositoryProvider = Provider<RoutineRepository>((ref) {
  return RoutineRepository();
});

// Daily Instance Repository Provider (for cleanup)
final dailyInstanceRepoProvider = Provider<DailyInstanceRepository>((ref) {
  return DailyInstanceRepository();
});

// Routine State Notifier
class RoutineNotifier extends StateNotifier<AsyncValue<List<Routine>>> {
  final RoutineRepository _repository;
  final DailyInstanceRepository _instanceRepository;
  final NotificationService _notificationService = NotificationService();
  final AchievementService _achievementService = AchievementService();

  RoutineNotifier(this._repository, this._instanceRepository) : super(const AsyncValue.loading()) {
    loadRoutines();
  }

  Future<void> loadRoutines() async {
    state = const AsyncValue.loading();
    try {
      final routines = await _repository.getAllActive();
      state = AsyncValue.data(routines);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<bool> addRoutine(Routine routine) async {
    try {
      // Check for overlap
      final hasOverlap = await _repository.hasOverlap(routine);
      if (hasOverlap) {
        return false; // Overlap detected
      }

      await _repository.insert(routine);
      
      // Schedule notification if enabled
      if (routine.notificationEnabled) {
        await _notificationService.scheduleRoutineNotification(routine);
      }
      
      // Check for first routine achievement
      await _achievementService.awardFirstRoutine();
      
      await loadRoutines(); // Refresh list
      return true;
    } catch (e) {
      print('Error adding routine: $e');
      return false;
    }
  }

  Future<bool> updateRoutine(Routine routine) async {
    try {
      // Check for overlap (excluding current routine)
      final hasOverlap = await _repository.hasOverlap(routine, excludeId: routine.id);
      if (hasOverlap) {
        print('Overlap detected! Routine: ${routine.name}, ID: ${routine.id}');
        print('Time: ${routine.startTime} - ${routine.endTime}, Days: ${routine.repeatDays}');
        return false; // Overlap detected
      }

      // Cancel old notifications
      await _notificationService.cancelRoutineNotifications(routine.id);
      
      await _repository.update(routine);
      
      // Delete old instances so Today tab regenerates with new data
      try {
        await _instanceRepository.deleteByRoutineId(routine.id);
      } catch (e) {
        print('Warning: Instance cleanup failed: $e');
      }
      
      // Reschedule notification if enabled
      if (routine.notificationEnabled) {
        await _notificationService.scheduleRoutineNotification(routine);
      }
      
      await loadRoutines(); // Refresh list
      return true;
    } catch (e, stackTrace) {
      print('Error updating routine: $e');
      print('Stack trace: $stackTrace');
      return false;
    }
  }

  Future<void> deleteRoutine(String id) async {
    try {
      // Cancel notifications before deleting
      await _notificationService.cancelRoutineNotifications(id);
      
      // Delete instances so they don't appear in Today tab
      try {
        await _instanceRepository.deleteByRoutineId(id);
      } catch (e) {
        print('Warning: Instance cleanup failed: $e');
      }
      
      await _repository.softDelete(id);
      await loadRoutines(); // Refresh list
    } catch (e, stackTrace) {
      print('Error deleting routine: $e');
      print('Stack trace: $stackTrace');
      rethrow; // Re-throw to surface the error
    }
  }

  Future<void> pauseRoutine(String id, {String? pauseUntilDate}) async {
    try {
      // Cancel notifications when pausing
      await _notificationService.cancelRoutineNotifications(id);
      
      // Delete instances so paused routine doesn't show in Today tab
      try {
        await _instanceRepository.deleteByRoutineId(id);
      } catch (e) {
        print('Warning: Instance cleanup failed: $e');
      }
      
      await _repository.pause(id, pauseUntilDate: pauseUntilDate);
      await loadRoutines(); // Refresh list
    } catch (e, stackTrace) {
      print('Error pausing routine: $e');
      print('Stack trace: $stackTrace');
      rethrow; // Re-throw to surface the error
    }
  }

  Future<void> resumeRoutine(String id) async {
    try {
      await _repository.resume(id);
      
      // Reschedule notifications when resuming
      final routine = await _repository.getById(id);
      if (routine != null && routine.notificationEnabled) {
        await _notificationService.scheduleRoutineNotification(routine);
      }
      
      await loadRoutines(); // Refresh list
    } catch (e) {
      print('Error resuming routine: $e');
    }
  }

  Future<List<Routine>> getPausedRoutines() async {
    try {
      return await _repository.getPaused();
    } catch (e) {
      print('Error getting paused routines: $e');
      return [];
    }
  }

  Future<List<Routine>> getArchivedRoutines() async {
    try {
      return await _repository.getArchived();
    } catch (e) {
      print('Error getting archived routines: $e');
      return [];
    }
  }

  Future<void> restoreRoutine(String id) async {
    try {
      await _repository.restore(id);
      await loadRoutines(); // Refresh list
    } catch (e) {
      print('Error restoring routine: $e');
    }
  }

  Future<void> hardDeleteRoutine(String id) async {
    try {
      // Cancel notifications before deleting
      await _notificationService.cancelRoutineNotifications(id);
      
      // Delete associated daily instances permanently
      await _instanceRepository.deleteByRoutineId(id);
      
      await _repository.hardDelete(id);
      await loadRoutines(); // Refresh list
    } catch (e) {
      print('Error hard deleting routine: $e');
    }
  }
}

// Active routines provider
final activeRoutinesProvider = StateNotifierProvider<RoutineNotifier, AsyncValue<List<Routine>>>((ref) {
  final repository = ref.watch(routineRepositoryProvider);
  final instanceRepository = ref.watch(dailyInstanceRepoProvider);
  return RoutineNotifier(repository, instanceRepository);
});

// Paused routines provider
final pausedRoutinesProvider = FutureProvider<List<Routine>>((ref) async {
  final repository = ref.watch(routineRepositoryProvider);
  return repository.getPaused();
});

// Archived routines provider
final archivedRoutinesProvider = FutureProvider<List<Routine>>((ref) async {
  final repository = ref.watch(routineRepositoryProvider);
  return repository.getArchived();
});

// Main routine provider (StateNotifierProvider)
final routineProvider = StateNotifierProvider<RoutineNotifier, AsyncValue<List<Routine>>>((ref) {
  final repository = ref.watch(routineRepositoryProvider);
  final instanceRepository = ref.watch(dailyInstanceRepoProvider);
  return RoutineNotifier(repository, instanceRepository);
});
