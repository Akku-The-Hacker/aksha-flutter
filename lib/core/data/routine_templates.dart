import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/routine_model.dart';

class RoutineTemplate {
  final String name;
  final String description;
  final String emoji;
  final List<RoutineData> routines;
  final String category;

  RoutineTemplate({
    required this.name,
    required this.description,
    required this.emoji,
    required this.routines,
    required this.category,
  });
}

class RoutineData {
  final String name;
  final String startTime;
  final String endTime;
  final List<int> repeatDays;
  final int notificationMinutesBefore;

  RoutineData({
    required this.name,
    required this.startTime,
    required this.endTime,
    required this.repeatDays,
    this.notificationMinutesBefore = 15,
  });
}

class RoutineTemplateLibrary {
  static final List<RoutineTemplate> templates = [
    // Morning Routines
    RoutineTemplate(
      name: 'Early Bird Morning',
      description: 'Start your day right with this energizing morning routine',
      emoji: '🌅',
      category: 'Morning',
      routines: [
        RoutineData(
          name: 'Wake Up & Hydrate',
          startTime: '06:00',
          endTime: '06:15',
          repeatDays: [1, 2, 3, 4, 5, 6, 7],
        ),
        RoutineData(
          name: 'Morning Exercise',
          startTime: '06:15',
          endTime: '06:45',
          repeatDays: [1, 2, 3, 4, 5, 6, 7],
          notificationMinutesBefore: 10,
        ),
        RoutineData(
          name: 'Shower & Get Ready',
          startTime: '06:45',
          endTime: '07:15',
          repeatDays: [1, 2, 3, 4, 5, 6, 7],
        ),
        RoutineData(
          name: 'Healthy Breakfast',
          startTime: '07:15',
          endTime: '07:45',
          repeatDays: [1, 2, 3, 4, 5, 6, 7],
        ),
      ],
    ),

    RoutineTemplate(
      name: 'Productive Morning',
      description: 'Maximize productivity with focused morning tasks',
      emoji: '⚡',
      category: 'Morning',
      routines: [
        RoutineData(
          name: 'Morning Meditation',
          startTime: '07:00',
          endTime: '07:15',
          repeatDays: [1, 2, 3, 4, 5, 6, 7],
        ),
        RoutineData(
          name: 'Journal & Plan Day',
          startTime: '07:15',
          endTime: '07:30',
          repeatDays: [1, 2, 3, 4, 5, 6, 7],
        ),
        RoutineData(
          name: 'Deep Work Session',
          startTime: '08:00',
          endTime: '10:00',
          repeatDays: [1, 2, 3, 4, 5],
          notificationMinutesBefore: 5,
        ),
      ],
    ),

    // Study Routines
    RoutineTemplate(
      name: 'Student Study Schedule',
      description: 'Balanced study routine with breaks',
      emoji: '📚',
      category: 'Study',
      routines: [
        RoutineData(
          name: 'Morning Study Block',
          startTime: '09:00',
          endTime: '11:00',
          repeatDays: [1, 2, 3, 4, 5],
        ),
        RoutineData(
          name: 'Afternoon Study Block',
          startTime: '14:00',
          endTime: '16:00',
          repeatDays: [1, 2, 3, 4, 5],
        ),
        RoutineData(
          name: 'Evening Review',
          startTime: '19:00',
          endTime: '20:00',
          repeatDays: [1, 2, 3, 4, 5],
        ),
      ],
    ),

    // Fitness Routines
    RoutineTemplate(
      name: 'Fitness Enthusiast',
      description: 'Complete workout schedule for the week',
      emoji: '💪',
      category: 'Fitness',
      routines: [
        RoutineData(
          name: 'Cardio Workout',
          startTime: '06:30',
          endTime: '07:30',
          repeatDays: [1, 3, 5],
        ),
        RoutineData(
          name: 'Strength Training',
          startTime: '06:30',
          endTime: '07:30',
          repeatDays: [2, 4, 6],
        ),
        RoutineData(
          name: 'Yoga & Stretching',
          startTime: '18:00',
          endTime: '18:30',
          repeatDays: [1, 2, 3, 4, 5, 6, 7],
        ),
      ],
    ),

    // Evening Routines
    RoutineTemplate(
      name: 'Wind Down Evening',
      description: 'Relax and prepare for quality sleep',
      emoji: '🌙',
      category: 'Evening',
      routines: [
        RoutineData(
          name: 'Dinner Time',
          startTime: '19:00',
          endTime: '19:45',
          repeatDays: [1, 2, 3, 4, 5, 6, 7],
        ),
        RoutineData(
          name: 'Evening Walk',
          startTime: '20:00',
          endTime: '20:30',
          repeatDays: [1, 2, 3, 4, 5, 6, 7],
        ),
        RoutineData(
          name: 'Reading Time',
          startTime: '21:00',
          endTime: '21:30',
          repeatDays: [1, 2, 3, 4, 5, 6, 7],
        ),
        RoutineData(
          name: 'Sleep Preparation',
          startTime: '22:00',
          endTime: '22:30',
          repeatDays: [1, 2, 3, 4, 5, 6, 7],
          notificationMinutesBefore: 30,
        ),
      ],
    ),

    // Work Routines
    RoutineTemplate(
      name: 'Remote Worker',
      description: 'Structured work-from-home schedule',
      emoji: '💼',
      category: 'Work',
      routines: [
        RoutineData(
          name: 'Morning Standup',
          startTime: '09:00',
          endTime: '09:15',
          repeatDays: [1, 2, 3, 4, 5],
        ),
        RoutineData(
          name: 'Focus Work Block 1',
          startTime: '09:30',
          endTime: '12:00',
          repeatDays: [1, 2, 3, 4, 5],
        ),
        RoutineData(
          name: 'Lunch Break',
          startTime: '12:00',
          endTime: '13:00',
          repeatDays: [1, 2, 3, 4, 5],
        ),
        RoutineData(
          name: 'Focus Work Block 2',
          startTime: '13:00',
          endTime: '17:00',
          repeatDays: [1, 2, 3, 4, 5],
        ),
      ],
    ),

    // Health & Wellness
    RoutineTemplate(
      name: 'Wellness Warrior',
      description: 'Holistic health and self-care routine',
      emoji: '🧘',
      category: 'Wellness',
      routines: [
        RoutineData(
          name: 'Morning Meditation',
          startTime: '06:30',
          endTime: '07:00',
          repeatDays: [1, 2, 3, 4, 5, 6, 7],
        ),
        RoutineData(
          name: 'Healthy Meal Prep',
          startTime: '10:00',
          endTime: '11:00',
          repeatDays: [7],
        ),
        RoutineData(
          name: 'Gratitude Journaling',
          startTime: '21:00',
          endTime: '21:15',
          repeatDays: [1, 2, 3, 4, 5, 6, 7],
        ),
      ],
    ),

    // Weekend Routines
    RoutineTemplate(
      name: 'Weekend Recharge',
      description: 'Balanced weekend routine for rest and productivity',
      emoji: '🎯',
      category: 'Weekend',
      routines: [
        RoutineData(
          name: 'Sleep In',
          startTime: '08:00',
          endTime: '09:00',
          repeatDays: [6, 7],
        ),
        RoutineData(
          name: 'Leisure Reading',
          startTime: '10:00',
          endTime: '11:00',
          repeatDays: [6, 7],
        ),
        RoutineData(
          name: 'Hobby Time',
          startTime: '14:00',
          endTime: '16:00',
          repeatDays: [6, 7],
        ),
        RoutineData(
          name: 'Weekly Review & Planning',
          startTime: '19:00',
          endTime: '20:00',
          repeatDays: [7],
        ),
      ],
    ),
  ];

  /// Convert template routine to actual Routine model
  static Routine templateToRoutine(RoutineData data, {String? categoryId}) {
    final now = DateTime.now();
    return Routine(
      id: const Uuid().v4(),
      name: data.name,
      categoryId: categoryId,
      startTime: data.startTime,
      endTime: data.endTime,
      isOvernight: Routine.calculateIsOvernight(data.startTime, data.endTime),
      durationMinutes: Routine.calculateDuration(data.startTime, data.endTime),
      repeatDays: data.repeatDays,
      notificationEnabled: true,
      notificationMinutesBefore: data.notificationMinutesBefore,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Get templates by category
  static List<RoutineTemplate> getByCategory(String category) {
    return templates.where((t) => t.category == category).toList();
  }

  /// Get all categories
  static List<String> getCategories() {
    return templates.map((t) => t.category).toSet().toList()..sort();
  }
}
