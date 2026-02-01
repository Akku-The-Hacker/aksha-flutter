import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/routine_model.dart';
import '../models/daily_instance_model.dart';
import '../repositories/routine_repository.dart';
import '../repositories/daily_instance_repository.dart';
import '../repositories/category_repository.dart';

class InstanceGeneratorService {
  final RoutineRepository _routineRepository = RoutineRepository();
  final DailyInstanceRepository _instanceRepository = DailyInstanceRepository();
  final CategoryRepository _categoryRepository = CategoryRepository();

  /// Generate instances for a specific date
  Future<int> generateForDate(DateTime date) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final dayOfWeek = date.weekday; // 1=Mon, 7=Sun

    // Get all active routines for this day
    final routines = await _routineRepository.getForDayOfWeek(dayOfWeek);

    final instances = <DailyInstance>[];

    for (final routine in routines) {
      // Check if instance already exists
      final exists = await _instanceRepository.exists(dateStr, routine.id);
      if (exists) continue; // Skip if already generated

      // Check if routine is within date range
      if (routine.startDate != null && date.isBefore(routine.startDate!)) {
        continue; // Routine hasn't started yet
      }
      if (routine.endDate != null && date.isAfter(routine.endDate!)) {
        continue; // Routine has ended
      }

      // Check if routine is paused
      if (routine.isPaused) {
        // Check if pause is temporary
        if (routine.pauseUntilDate != null) {
          final pauseDate = DateTime.parse(routine.pauseUntilDate!);
          if (date.isBefore(pauseDate) || _isSameDay(date, pauseDate)) {
            continue; // Still paused
          }
          // If past pause date, auto-resume will be handled elsewhere
        } else {
          continue; // Indefinitely paused
        }
      }

      // Get category info for snapshot
      String? categoryName;
      String? categoryColor;
      if (routine.categoryId != null) {
        final category = await _categoryRepository.getById(routine.categoryId!);
        categoryName = category?.name;
        categoryColor = category?.color;
      }

      // Create instance
      final instance = DailyInstance(
        id: const Uuid().v4(),
        date: dateStr,
        routineId: routine.id,
        routineName: routine.name,
        categoryId: routine.categoryId,
        categoryName: categoryName,
        categoryColor: categoryColor,
        plannedStart: routine.startTime,
        plannedEnd: routine.endTime,
        plannedMinutes: routine.durationMinutes,
        isOvernight: routine.isOvernight,
        status: InstanceStatus.pending,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      instances.add(instance);
    }

    // Batch insert all instances
    if (instances.isNotEmpty) {
      await _instanceRepository.batchInsert(instances);
    }

    return instances.length;
  }

  /// Generate instances for a date range (for retroactive generation)
  Future<Map<String, int>> generateForDateRange(DateTime startDate, DateTime endDate) async {
    final results = <String, int>{};
    
    DateTime current = startDate;
    while (current.isBefore(endDate) || _isSameDay(current, endDate)) {
      final count = await generateForDate(current);
      results[DateFormat('yyyy-MM-dd').format(current)] = count;
      current = current.add(const Duration(days: 1));
    }

    return results;
  }

  /// Generate instances for today
  Future<int> generateForToday() async {
    return await generateForDate(DateTime.now());
  }

  /// Generate instances for next N days (for initial setup)
  Future<Map<String, int>> generateForNextDays(int days) async {
    final today = DateTime.now();
    final endDate = today.add(Duration(days: days - 1));
    return await generateForDateRange(today, endDate);
  }

  /// Mark pending instances as missed for a specific date
  Future<int> markAsMissedForDate(DateTime date) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    return await _instanceRepository.markPendingAsMissed(dateStr);
  }

  /// Mark pending instances as missed for yesterday
  /// (Called by WorkManager at midnight)
  Future<int> markYesterdayMissed() async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return await markAsMissedForDate(yesterday);
  }

  /// Auto-resume paused routines if pause date has passed
  Future<int> autoResumePausedRoutines() async {
    final pausedRoutines = await _routineRepository.getPaused();
    int resumed = 0;

    for (final routine in pausedRoutines) {
      if (routine.pauseUntilDate != null) {
        final pauseDate = DateTime.parse(routine.pauseUntilDate!);
        final now = DateTime.now();
        
        if (now.isAfter(pauseDate)) {
          await _routineRepository.resume(routine.id);
          resumed++;
        }
      }
    }

    return resumed;
  }

  /// Midnight task: Generate today's instances and mark yesterday as missed
  Future<Map<String, dynamic>> runMidnightTask() async {
    // First, mark yesterday's pending instances as missed
    final missedCount = await markYesterdayMissed();

    // Auto-resume any paused routines that should be resumed
    final resumedCount = await autoResumePausedRoutines();

    // Generate today's instances
    final generatedCount = await generateForToday();

    return {
      'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'generated': generatedCount,
      'missed': missedCount,
      'resumed': resumedCount,
      'success': true,
    };
  }

  /// Check if two dates are the same day
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Get generation status for a date (how many instances exist)
  Future<Map<String, dynamic>> getGenerationStatus(DateTime date) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final instances = await _instanceRepository.getByDate(dateStr);
    final routines = await _routineRepository.getForDayOfWeek(date.weekday);

    return {
      'date': dateStr,
      'instances_count': instances.length,
      'expected_routines': routines.length,
      'is_fully_generated': instances.length >= routines.length,
    };
  }
}
