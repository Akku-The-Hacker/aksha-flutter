import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/routine_model.dart';
import '../../core/models/category_model.dart';
import '../../core/providers/routine_provider.dart';
import '../../core/repositories/category_repository.dart';

class SearchRoutinesScreen extends ConsumerStatefulWidget {
  const SearchRoutinesScreen({super.key});

  @override
  ConsumerState<SearchRoutinesScreen> createState() => _SearchRoutinesScreenState();
}

class _SearchRoutinesScreenState extends ConsumerState<SearchRoutinesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedCategoryId;
  String? _selectedTagId;
  List<int> _selectedDays = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Routine> _filterRoutines(List<Routine> routines) {
    return routines.where((routine) {
      // Text search
      if (_searchQuery.isNotEmpty) {
        final matchesName = routine.name.toLowerCase().contains(_searchQuery.toLowerCase());
        if (!matchesName) return false;
      }

      // Category filter
      if (_selectedCategoryId != null && routine.categoryId != _selectedCategoryId) {
        return false;
      }

      // Day filter
      if (_selectedDays.isNotEmpty) {
        final hasMatchingDay = _selectedDays.any((day) => routine.repeatDays.contains(day));
        if (!hasMatchingDay) return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final routinesAsync = ref.watch(routineProvider);
    final categoryRepo = CategoryRepository();

    return FutureBuilder<List<Category>>(
      future: categoryRepo.getAll(),
      builder: (context, snapshot) {
        final categories = snapshot.data ?? [];
        
        return Scaffold(
          appBar: AppBar(
            title: const Text('🔍 Search Routines'),
            elevation: 0,
          ),
          body: Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search routines...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
            ),
          ),

          // Filters
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                // Category filter
                _buildFilterChip(
                  label: _selectedCategoryId == null
                      ? 'All Categories'
                      : categories.firstWhere((c) => c.id == _selectedCategoryId).name,
                  icon: Icons.category,
                  onTap: () => _showCategoryFilter(categories),
                ),
                const SizedBox(width: 8),
                
                // Day filter
                _buildFilterChip(
                  label: _selectedDays.isEmpty
                      ? 'All Days'
                      : '${_selectedDays.length} day${_selectedDays.length != 1 ? 's' : ''}',
                  icon: Icons.calendar_today,
                  onTap: _showDayFilter,
                ),
                const SizedBox(width: 8),
                
                // Clear filters
                if (_selectedCategoryId != null || _selectedDays.isNotEmpty)
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _selectedCategoryId = null;
                        _selectedDays = [];
                      });
                    },
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Clear Filters'),
                  ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Results
          Expanded(
            child: routinesAsync.when(
              data: (routines) {
                final filteredRoutines = _filterRoutines(routines);
                
                if (filteredRoutines.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No routines found',
                          style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredRoutines.length,
                  itemBuilder: (context, index) {
                    return _buildRoutineCard(filteredRoutines[index], categories);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Error: $error')),
            ),
          ),
        ],
      ),
    );
      },
    );
  }

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
    );
  }

  Widget _buildRoutineCard(Routine routine, List categories) {
    final category = categories.firstWhere(
      (c) => c.id == routine.categoryId,
      orElse: () => categories.first,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Color(int.parse('0xFF${category.color}')).withOpacity(0.2),
          child: Text(
            category.icon,
            style: const TextStyle(fontSize: 20),
          ),
        ),
        title: Text(
          routine.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${routine.startTime} - ${routine.endTime}'),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              children: routine.repeatDays.map((day) {
                return Chip(
                  label: Text(
                    ['M', 'T', 'W', 'T', 'F', 'S', 'S'][day - 1],
                    style: const TextStyle(fontSize: 10),
                  ),
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                );
              }).toList(),
            ),
          ],
        ),
        trailing: Chip(
          label: Text(category.name),
          backgroundColor: Color(int.parse('0xFF${category.color}')).withOpacity(0.2),
        ),
      ),
    );
  }

  void _showCategoryFilter(List categories) {
    showModalBottomSheet(
      context: context,
      builder: (context) => ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            leading: const Icon(Icons.all_inclusive),
            title: const Text('All Categories'),
            trailing: _selectedCategoryId == null
                ? const Icon(Icons.check, color: Colors.green)
                : null,
            onTap: () {
              setState(() => _selectedCategoryId = null);
              Navigator.pop(context);
            },
          ),
          ...categories.map((category) {
            final isSelected = _selectedCategoryId == category.id;
            return ListTile(
              leading: Text(category.icon, style: const TextStyle(fontSize: 24)),
              title: Text(category.name),
              trailing: isSelected
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: () {
                setState(() => _selectedCategoryId = category.id);
                Navigator.pop(context);
              },
            );
          }),
        ],
      ),
    );
  }

  void _showDayFilter() {
    final tempSelected = List<int>.from(_selectedDays);
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Filter by Days'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(7, (index) {
              final day = index + 1;
              final dayName = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][index];
              final isSelected = tempSelected.contains(day);
              
              return CheckboxListTile(
                title: Text(dayName),
                value: isSelected,
                onChanged: (value) {
                  setDialogState(() {
                    if (value == true) {
                      tempSelected.add(day);
                    } else {
                      tempSelected.remove(day);
                    }
                  });
                },
              );
            }),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() => _selectedDays = tempSelected);
                Navigator.pop(context);
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }
}
