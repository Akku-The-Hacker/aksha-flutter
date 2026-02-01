import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/category_model.dart';
import '../repositories/category_repository.dart';

// Category Repository Provider
final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository();
});

// Category State Notifier
class CategoryNotifier extends StateNotifier<AsyncValue<List<Category>>> {
  final CategoryRepository _repository;

  CategoryNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadCategories();
  }

  Future<void> loadCategories() async {
    state = const AsyncValue.loading();
    try {
      final categories = await _repository.getAllActive();
      state = AsyncValue.data(categories);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> addCategory(Category category) async {
    try {
      await _repository.insert(category);
      await loadCategories(); // Refresh list
    } catch (e) {
      print('Error adding category: $e');
    }
  }

  Future<void> updateCategory(Category category) async {
    try {
      await _repository.update(category);
      await loadCategories(); // Refresh list
    } catch (e) {
      print('Error updating category: $e');
    }
  }

  Future<void> deleteCategory(String id) async {
    try {
      await _repository.delete(id);
      await loadCategories(); // Refresh list
    } catch (e) {
      print('Error deleting category: $e');
    }
  }
}

// All active categories provider
final activeCategoriesProvider = StateNotifierProvider<CategoryNotifier, AsyncValue<List<Category>>>((ref) {
  final repository = ref.watch(categoryRepositoryProvider);
  return CategoryNotifier(repository);
});

// Alias for backward compatibility
final categoriesProvider = activeCategoriesProvider;

// Category by ID provider
final categoryByIdProvider = FutureProvider.family<Category?, String>((ref, id) async {
  final repository = ref.watch(categoryRepositoryProvider);
  return repository.getById(id);
});
