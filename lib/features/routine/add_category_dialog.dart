import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/models/category_model.dart';
import '../../core/providers/category_provider.dart';

class AddCategoryDialog extends ConsumerStatefulWidget {
  final Category? category; // null for add, populated for edit

  const AddCategoryDialog({super.key, this.category});

  @override
  ConsumerState<AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends ConsumerState<AddCategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String? _selectedIcon;
  String? _selectedColor;

  final List<String> _iconOptions = [
    '🏃', '💪', '📚', '🧘', '🎵', '🎨', '💼', '🏠', '🌱', '❤️',
    '⚽', '🍎', '💻', '✈️', '🎯', '⏰', '📝', '🎓', '🏋️', '🧠',
  ];

  final List<String> _colorOptions = [
    '0xFF6750A4', // Purple
    '0xFF2196F3', // Blue
    '0xFF4CAF50', // Green
    '0xFFFF9800', // Orange
    '0xFFF44336', // Red
    '0xFF9C27B0', // Deep Purple
    '0xFF00BCD4', // Cyan
    '0xFFFFEB3B', // Yellow
    '0xFFE91E63', // Pink
    '0xFF795548', // Brown
  ];

  @override
  void initState() {
    super.initState();
    // If editing, populate fields
    if (widget.category != null) {
      _nameController.text = widget.category!.name;
      _selectedIcon = widget.category!.icon;
      _selectedColor = widget.category!.color;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveCategory() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedIcon == null || _selectedColor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an icon and color')),
      );
      return;
    }

    final category = Category(
      id: widget.category?.id ?? const Uuid().v4(),
      name: _nameController.text.trim(),
      icon: _selectedIcon!,
      color: _selectedColor!,
      createdAt: widget.category?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    if (widget.category != null) {
      // Edit mode
      await ref.read(activeCategoriesProvider.notifier).updateCategory(category);
    } else {
      // Add mode
      await ref.read(activeCategoriesProvider.notifier).addCategory(category);
    }

    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Color _parseColor(String colorString) {
    return Color(int.parse(colorString));
  }

  @override
  Widget build(BuildContext context) {
    final isEditMode = widget.category != null;
    
    return AlertDialog(
      title: Text(isEditMode ? 'Edit Category' : 'Add Custom Category'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name input
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Category Name',
                  hintText: 'e.g., Fitness, Study',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a category name';
                  }
                  return null;
                },
                textCapitalization: TextCapitalization.words,
              ),

              const SizedBox(height: 20),

              // Icon selection
              const Text(
                'Choose Icon:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _iconOptions.map((icon) {
                  final isSelected = _selectedIcon == icon;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedIcon = icon),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF6750A4).withOpacity(0.2) : Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF6750A4) : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(icon, style: const TextStyle(fontSize: 20)),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),

              // Color selection
              const Text(
                'Choose Color:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _colorOptions.map((colorString) {
                  final isSelected = _selectedColor == colorString;
                  final color = _parseColor(colorString);
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = colorString),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.black : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white, size: 20)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saveCategory,
          child: Text(isEditMode ? 'Update' : 'Add'),
        ),
      ],
    );
  }
}
