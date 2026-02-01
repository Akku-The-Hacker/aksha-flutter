import 'package:flutter/material.dart';
import '../../core/models/routine_model.dart';
import '../../core/models/category_model.dart';
import '../../core/repositories/routine_repository.dart';
import '../../core/repositories/category_repository.dart';
import 'add_category_dialog.dart';

class AddEditRoutineDialog extends StatefulWidget {
  final Routine? routine; // Null for new routine
  final DateTime? initialDate; // For creating a routine from a specific date context

  const AddEditRoutineDialog({super.key, this.routine, this.initialDate});

  @override
  State<AddEditRoutineDialog> createState() => _AddEditRoutineDialogState();
}

class _AddEditRoutineDialogState extends State<AddEditRoutineDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TimeOfDay _startTime;
  int _durationMinutes = 30;
  bool _isLoading = false;

  // Repeat days
  final List<bool> _selectedDays = List.filled(7, true); // Default all days

  // Category selection
  List<Category> _categories = [];
  Category? _selectedCategory;
  bool _isLoadingCategories = true;

  // Notifications
  bool _enableNotifications = true;
  int _reminderMinutes = 10;

  final RoutineRepository _routineRepo = RoutineRepository();
  final CategoryRepository _categoryRepo = CategoryRepository();

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    _nameController = TextEditingController(text: widget.routine?.name ?? '');
    
    // Initialize start time (default to prompt next hour or current time)
    if (widget.routine != null) {
      _startTime = TimeOfDay(
        hour: widget.routine!.startTime.hour,
        minute: widget.routine!.startTime.minute,
      );
      _durationMinutes = widget.routine!.durationMinutes;
      _enableNotifications = widget.routine!.notificationEnabled;
      _reminderMinutes = widget.routine!.reminderOffsetMinutes;
      
      // Load selected days
      for (int i = 0; i < 7; i++) {
        _selectedDays[i] = widget.routine!.repeatDays[i];
      }
    } else {
      final now = TimeOfDay.now();
      _startTime = TimeOfDay(hour: now.hour + 1, minute: 0); // Next hour flat
    }

    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _categoryRepo.getActiveCategories();
      setState(() {
        _categories = categories;
        _isLoadingCategories = false;
        
        // Set selected category
        if (widget.routine != null) {
          _selectedCategory = categories.firstWhere(
            (c) => c.id == widget.routine!.categoryId,
            orElse: () => categories.first,
          );
        } else if (categories.isNotEmpty) {
          _selectedCategory = categories.first;
        }
      });
    } catch (e) {
      // Handle error
      if (mounted) {
        setState(() => _isLoadingCategories = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (picked != null && picked != _startTime) {
      setState(() {
        _startTime = picked;
      });
    }
  }

  Future<void> _addNewCategory() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const AddCategoryDialog(),
    );

    if (result == true) {
      _loadCategories(); // Reload to get the new category
    }
  }

  Future<void> _saveRoutine() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category')),
      );
      return;
    }
    if (!_selectedDays.contains(true)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one day')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Create routine object
      final routine = Routine(
        id: widget.routine?.id,
        name: _nameController.text.trim(),
        categoryId: _selectedCategory!.id!,
        startTime: DateTime(2000, 1, 1, _startTime.hour, _startTime.minute),
        durationMinutes: _durationMinutes,
        repeatDays: List.from(_selectedDays),
        notificationEnabled: _enableNotifications,
        reminderOffsetMinutes: _reminderMinutes,
        createdAt: widget.routine?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Check for overlap
      // Note: This simplified check doesn't handle all edge cases but is a good start
      // In a real app, you might want to warn the user but allow them to proceed
      /*
      final hasOverlap = await _routineRepo.checkOverlap(routine);
      if (hasOverlap && widget.routine == null) {
        // Show warning dialog...
      }
      */

      if (widget.routine == null) {
        await _routineRepo.insert(routine);
      } else {
        await _routineRepo.update(routine);
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving routine: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.routine == null ? 'New Routine' : 'Edit Routine'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveRoutine,
            child: const Text(
              'SAVE',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: _isLoadingCategories
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Routine Name
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Routine Name',
                      hintText: 'e.g., Morning Meditation',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.edit),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    validator: (value) =>
                        value?.trim().isEmpty == true ? 'Required' : null,
                  ),
                  const SizedBox(height: 24),

                  // Category Selector
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<Category>(
                          value: _selectedCategory,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.category),
                          ),
                          items: _categories.map((c) {
                            return DropdownMenuItem(
                              value: c,
                              child: Row(
                                children: [
                                  Icon(
                                    // Use a mapping or helper here in real app
                                    Icons.label, 
                                    color: c.color,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(c.name),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) => setState(() => _selectedCategory = val),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _addNewCategory,
                        icon: const Icon(Icons.add_circle, color: Color(0xFF6750A4)),
                        tooltip: 'Add new category',
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Time and Duration
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _selectTime(context),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Start Time',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.access_time),
                            ),
                            child: Text(
                              _startTime.format(context),
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: _durationMinutes,
                          decoration: const InputDecoration(
                            labelText: 'Duration',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.timer),
                          ),
                          items: [5, 10, 15, 20, 30, 45, 60, 90, 120].map((m) {
                            return DropdownMenuItem(
                              value: m,
                              child: Text('$m min'),
                            );
                          }).toList(),
                          onChanged: (val) =>
                              setState(() => _durationMinutes = val!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Repeat Days
                  const Text(
                    'Repeat',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(7, (index) {
                      // 0 = Monday, ... 6 = Sunday. Adjust labels accordingly.
                      final labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                      return InkWell(
                        onTap: () {
                          setState(() {
                            _selectedDays[index] = !_selectedDays[index];
                          });
                        },
                        child: CircleAvatar(
                          radius: 20,
                          backgroundColor: _selectedDays[index]
                              ? const Color(0xFF6750A4)
                              : Colors.grey[200],
                          foregroundColor:
                              _selectedDays[index] ? Colors.white : Colors.black,
                          child: Text(labels[index]),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),

                  // Notifications
                  SwitchListTile(
                    title: const Text('Enable Notifications'),
                    value: _enableNotifications,
                    onChanged: (val) => setState(() => _enableNotifications = val),
                    secondary: const Icon(Icons.notifications),
                  ),
                  
                  if (_enableNotifications)
                    Padding(
                      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                      child: Row(
                        children: [
                          const Text('Remind me'),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButton<int>(
                              value: _reminderMinutes,
                              isExpanded: true,
                              items: [0, 5, 10, 15, 30, 60].map((m) {
                                return DropdownMenuItem(
                                  value: m,
                                  child: Text(
                                    m == 0 ? 'At start time' : '$m min before',
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) =>
                                  setState(() => _reminderMinutes = val!),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
