import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/models/routine_model.dart';
import '../../core/providers/routine_provider.dart';
import '../../core/providers/category_provider.dart';

class AddEditRoutineDialog extends ConsumerStatefulWidget {
  final Routine? routine; // null for add, populated for edit

  const AddEditRoutineDialog({
    super.key,
    this.routine,
  });

  @override
  ConsumerState<AddEditRoutineDialog> createState() => _AddEditRoutineDialogState();
}

class _AddEditRoutineDialogState extends ConsumerState<AddEditRoutineDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  
  String? _selectedCategoryId;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 0);
  Set<int> _selectedDays = {1, 2, 3, 4, 5}; // Mon-Fri by default
  bool _notificationEnabled = false;
  int _notificationMinutesBefore = 15;
  DateTime? _startDate;
  DateTime? _endDate;
  
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    
    if (widget.routine != null) {
      // Edit mode - populate fields
      _nameController.text = widget.routine!.name;
      _selectedCategoryId = widget.routine!.categoryId;
      
      final startParts = widget.routine!.startTime.split(':');
      _startTime = TimeOfDay(
        hour: int.parse(startParts[0]),
        minute: int.parse(startParts[1]),
      );
      
      final endParts = widget.routine!.endTime.split(':');
      _endTime = TimeOfDay(
        hour: int.parse(endParts[0]),
        minute: int.parse(endParts[1]),
      );
      
      _selectedDays = widget.routine!.repeatDays.toSet();
      _notificationEnabled = widget.routine!.notificationEnabled;
      _notificationMinutesBefore = widget.routine!.notificationMinutesBefore;
      
      _startDate = widget.routine!.startDate;
      _endDate = widget.routine!.endDate;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _timeToString(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  int _calculateDuration() {
    final startMinutes = _startTime.hour * 60 + _startTime.minute;
    final endMinutes = _endTime.hour * 60 + _endTime.minute;
    
    if (endMinutes < startMinutes) {
      // Overnight
      return (24 * 60) - startMinutes + endMinutes;
    } else {
      return endMinutes - startMinutes;
    }
  }

  bool _isOvernight() {
    final startMinutes = _startTime.hour * 60 + _startTime.minute;
    final endMinutes = _endTime.hour * 60 + _endTime.minute;
    return endMinutes < startMinutes;
  }

  Future<void> _pickTime(BuildContext context, bool isStartTime) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStartTime ? _startTime : _endTime,
    );

    if (picked != null) {
      setState(() {
        if (isStartTime) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _saveRoutine() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category')),
      );
      return;
    }

    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one day')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final startTimeStr = _timeToString(_startTime);
    final endTimeStr = _timeToString(_endTime);
    final isOvernight = _isOvernight();
    final duration = _calculateDuration();

    final routine = Routine(
      id: widget.routine?.id ?? const Uuid().v4(),
      name: _nameController.text.trim(),
      categoryId: _selectedCategoryId,
      startTime: startTimeStr,
      endTime: endTimeStr,
      isOvernight: isOvernight,
      durationMinutes: duration,
      repeatDays: _selectedDays.toList()..sort(),
      notificationEnabled: _notificationEnabled,
      notificationMinutesBefore: _notificationMinutesBefore,
      isPaused: widget.routine?.isPaused ?? false,
      pauseUntilDate: widget.routine?.pauseUntilDate,
      startDate: _startDate,
      endDate: _endDate,
      createdAt: widget.routine?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      archivedAt: widget.routine?.archivedAt,
    );

    final notifier = ref.read(activeRoutinesProvider.notifier);
    bool success;
    
    if (widget.routine == null) {
      success = await notifier.addRoutine(routine);
    } else {
      success = await notifier.updateRoutine(routine);
    }

    if (mounted) {
      setState(() => _isSaving = false);
      
      if (success) {
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Time conflict! This routine overlaps with another.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(activeCategoriesProvider);
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            AppBar(
              title: Text(widget.routine == null ? 'Add Routine' : 'Edit Routine'),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),

            // Form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Routine Name *',
                          hintText: 'e.g., Morning Workout',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a routine name';
                          }
                          return null;
                        },
                        textCapitalization: TextCapitalization.sentences,
                      ),

                      const SizedBox(height: 16),

                      // Category
                      categoriesAsync.when(
                        data: (categories) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DropdownButtonFormField<String>(
                                value: _selectedCategoryId,
                                decoration: const InputDecoration(
                                  labelText: 'Category *',
                                  border: OutlineInputBorder(),
                                ),
                                items: [
                                  ...categories.map((category) {
                                    return DropdownMenuItem(
                                      value: category.id,
                                      child: Row(
                                        children: [
                                          if (category.icon != null) ...[ 
                                            Text(category.icon!, style: const TextStyle(fontSize: 20)),
                                            const SizedBox(width: 8),
                                          ],
                                          Text(category.name),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                                onChanged: (value) {
                                  setState(() => _selectedCategoryId = value);
                                },
                              ),
                            ],
                          );
                        },
                        loading: () => const CircularProgressIndicator(),
                        error: (e, _) => Text('Error loading categories: $e'),
                      ),

                      const SizedBox(height: 24),

                      // Time Section
                      const Text(
                        'Time',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _pickTime(context, true),
                              child: Column(
                                children: [
                                  const Text('Start Time', style: TextStyle(fontSize: 12)),
                                  const SizedBox(height: 4),
                                  Text(
                                    _startTime.format(context),
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _pickTime(context, false),
                              child: Column(
                                children: [
                                  const Text('End Time', style: TextStyle(fontSize: 12)),
                                  const SizedBox(height: 4),
                                  Text(
                                    _endTime.format(context),
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Duration info
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.schedule, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Duration: ${_calculateDuration()} min',
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            if (_isOvernight()) ...[
                              const SizedBox(width: 8),
                              const Chip(
                                label: Text('Overnight', style: TextStyle(fontSize: 11)),
                                backgroundColor: Colors.orange,
                                labelPadding: EdgeInsets.symmetric(horizontal: 4),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Repeat Days
                      const SizedBox(height: 12),

                      Wrap(
                        spacing: 8,
                        children: [
                          _dayChip('Mon', 1),
                          _dayChip('Tue', 2),
                          _dayChip('Wed', 3),
                          _dayChip('Thu', 4),
                          _dayChip('Fri', 5),
                          _dayChip('Sat', 6),
                          _dayChip('Sun', 7),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Date Range (Optional)
                      const Text(
                        'Date',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _startDate ?? DateTime.now(),
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                                );
                                if (picked != null) {
                                  setState(() => _startDate = picked);
                                }
                              },
                              icon: const Icon(Icons.calendar_today, size: 18),
                              label: Text(
                                _startDate != null
                                    ? '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}'
                                    : 'Start',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _endDate ?? (_startDate ?? DateTime.now()),
                                  firstDate: _startDate ?? DateTime.now(),
                                  lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                                );
                                if (picked != null) {
                                  setState(() => _endDate = picked);
                                }
                              },
                              icon: const Icon(Icons.event, size: 18),
                              label: Text(
                                _endDate != null
                                    ? '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'
                                    : 'End',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      if (_startDate != null || _endDate != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (_startDate != null)
                              TextButton.icon(
                                onPressed: () => setState(() => _startDate = null),
                                icon: const Icon(Icons.clear, size: 16),
                                label: const Text('Clear Start'),
                                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                              ),
                            const SizedBox(width: 8),
                            if (_endDate != null)
                              TextButton.icon(
                                onPressed: () => setState(() => _endDate = null),
                                icon: const Icon(Icons.clear, size: 16),
                                label: const Text('Clear End'),
                                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                              ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Notifications
                      SwitchListTile(
                        title: const Text('Enable Notifications'),
                        subtitle: const Text('Remind me before this routine'),
                        value: _notificationEnabled,
                        onChanged: (value) {
                          setState(() => _notificationEnabled = value);
                        },
                        contentPadding: EdgeInsets.zero,
                      ),

                      if (_notificationEnabled) ...[
                        const SizedBox(height: 8),
                        DropdownButtonFormField<int>(
                          value: _notificationMinutesBefore,
                          decoration: const InputDecoration(
                            labelText: 'Remind me',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 0, child: Text('At the time')),
                            DropdownMenuItem(value: 5, child: Text('5 minutes before')),
                            DropdownMenuItem(value: 15, child: Text('15 minutes before')),
                            DropdownMenuItem(value: 30, child: Text('30 minutes before')),
                            DropdownMenuItem(value: 60, child: Text('1 hour before')),
                          ],
                          onChanged: (value) {
                            setState(() => _notificationMinutesBefore = value!);
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // Footer buttons
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _saveRoutine,
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(widget.routine == null ? 'Add' : 'Save'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayChip(String label, int dayNumber) {
    final isSelected = _selectedDays.contains(dayNumber);
    
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedDays.remove(dayNumber);
          } else {
            _selectedDays.add(dayNumber);
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6750A4) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF6750A4) : Colors.grey[400]!,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
