import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/tag_model.dart';
import '../repositories/tag_repository.dart';

/// Provider for tag list
final tagProvider = StateNotifierProvider<TagNotifier, List<Tag>>((ref) {
  return TagNotifier();
});

class TagNotifier extends StateNotifier<List<Tag>> {
  final TagRepository _repository = TagRepository();

  TagNotifier() : super([]) {
    loadTags();
  }

  /// Load all tags
  Future<void> loadTags() async {
    try {
      final tags = await _repository.getAll();
      state = tags;
    } catch (e) {
      print('Error loading tags: $e');
    }
  }

  /// Add new tag
  Future<bool> addTag(Tag tag) async {
    try {
      // Check if name already exists
      final exists = await _repository.nameExists(tag.name);
      if (exists) {
        return false; // Name already exists
      }

      await _repository.insert(tag);
      await loadTags();
      return true;
    } catch (e) {
      print('Error adding tag: $e');
      return false;
    }
  }

  /// Update tag
  Future<bool> updateTag(Tag tag) async {
    try {
      // Check if name already exists (excluding current tag)
      final exists = await _repository.nameExists(tag.name, excludeId: tag.id);
      if (exists) {
        return false; // Name already exists
      }

      await _repository.update(tag);
      await loadTags();
      return true;
    } catch (e) {
      print('Error updating tag: $e');
      return false;
    }
  }

  /// Delete tag
  Future<void> deleteTag(String id) async {
    try {
      await _repository.delete(id);
      await loadTags();
    } catch (e) {
      print('Error deleting tag: $e');
    }
  }

  /// Get tags for a routine
  Future<List<Tag>> getTagsForRoutine(String routineId) async {
    try {
      return await _repository.getTagsForRoutine(routineId);
    } catch (e) {
      print('Error getting tags for routine: $e');
      return [];
    }
  }

  /// Assign tag to routine
  Future<void> assignTagToRoutine(String routineId, String tagId) async {
    try {
      await _repository.assignTagToRoutine(routineId, tagId);
    } catch (e) {
      print('Error assigning tag: $e');
    }
  }

  /// Remove tag from routine
  Future<void> removeTagFromRoutine(String routineId, String tagId) async {
    try {
      await _repository.removeTagFromRoutine(routineId, tagId);
    } catch (e) {
      print('Error removing tag: $e');
    }
  }

  /// Get usage count for a tag
  Future<int> getUsageCount(String tagId) async {
    try {
      return await _repository.getUsageCount(tagId);
    } catch (e) {
      print('Error getting usage count: $e');
      return 0;
    }
  }
}
