import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/achievement_model.dart';
import '../services/achievement_service.dart';

/// Provider for achievement list
final achievementProvider = StateNotifierProvider<AchievementNotifier, List<Achievement>>((ref) {
  return AchievementNotifier();
});

class AchievementNotifier extends StateNotifier<List<Achievement>> {
  final AchievementService _service = AchievementService();

  AchievementNotifier() : super([]) {
    loadAchievements();
  }

  /// Load all earned achievements
  Future<void> loadAchievements() async {
    try {
      final achievements = await _service.getAllAchievements();
      state = achievements;
    } catch (e) {
      print('Error loading achievements: $e');
    }
  }

  /// Check for new achievements (call after routine completion)
  Future<List<Achievement>> checkNewAchievements() async {
    try {
      final newAchievements = await _service.checkAndAwardAchievements();
      if (newAchievements.isNotEmpty) {
        await loadAchievements(); // Refresh list
      }
      return newAchievements;
    } catch (e) {
      print('Error checking achievements: $e');
      return [];
    }
  }

  /// Award first routine achievement
  Future<Achievement?> awardFirstRoutine() async {
    try {
      final achievement = await _service.awardFirstRoutine();
      if (achievement != null) {
        await loadAchievements(); // Refresh list
      }
      return achievement;
    } catch (e) {
      print('Error awarding first routine: $e');
      return null;
    }
  }

  /// Get achievement count
  int get achievementCount => state.length;

  /// Get total earned count (including repeatable)
  int get totalEarnedCount {
    return state.fold(0, (sum, achievement) => sum + achievement.earnedCount);
  }
}
