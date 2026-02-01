import 'package:flutter/material.dart';
import '../../core/models/category_model.dart';
import '../../core/repositories/category_repository.dart';

class AddCategoryDialog extends StatefulWidget {
  final Category? category; // If provided, we are editing

  const AddCategoryDialog({
    super.key,
    this.category,
  });

  @override
  State<AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends State<AddCategoryDialog> {
  late TextEditingController _nameController;
  late Color _selectedColor;
  late String _selectedIcon;
  bool _isLoading = false;

  final CategoryRepository _repository = CategoryRepository();

  // Predefined colors
  final List<Color> _colors = [
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.lightBlue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lightGreen,
    Colors.lime,
    Colors.yellow,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
    Colors.brown,
    Colors.grey,
    Colors.blueGrey,
  ];

  // Predefined icons (Material Icon names mapped to Icons)
  // In a real app, you might map string names to IconData more robustly
  final Map<String, IconData> _icons = {
    'fitness_center': Icons.fitness_center,
    'spa': Icons.spa,
    'self_improvement': Icons.self_improvement,
    'work': Icons.work,
    'school': Icons.school,
    'book': Icons.book,
    'language': Icons.language,
    'code': Icons.code,
    'brush': Icons.brush,
    'palette': Icons.palette,
    'music_note': Icons.music_note,
    'movie': Icons.movie,
    'sports_esports': Icons.sports_esports,
    'restaurant': Icons.restaurant,
    'local_cafe': Icons.local_cafe,
    'home': Icons.home,
    'family_restroom': Icons.family_restroom,
    'pets': Icons.pets,
    'shopping_cart': Icons.shopping_cart,
    'attach_money': Icons.attach_money,
    'savings': Icons.savings,
    'wb_sunny': Icons.wb_sunny,
    'bedtime': Icons.bedtime,
    'health_and_safety': Icons.health_and_safety,
  };

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?.name ?? '');
    _selectedColor = widget.category?.color ?? _colors[0];
    _selectedIcon = widget.category?.iconName ?? _icons.keys.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveCategory() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a category name')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      final category = Category(
        id: widget.category?.id, // Null for new, existing ID for edit
        name: _nameController.text.trim(),
        color: _selectedColor,
        iconName: _selectedIcon,
        isSystem: widget.category?.isSystem ?? false, // Preserve system status
        createdAt: widget.category?.createdAt ?? now,
        updatedAt: now,
      );

      if (widget.category == null) {
        await _repository.insert(category);
      } else {
        await _repository.update(category);
      }

      if (mounted) {
        Navigator.pop(context, true); // Return success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving category: $e')),
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
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.category == null ? 'New Category' : 'Edit Category',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),

              // Name Name
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Category Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.label),
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 24),

              // Color Picker
              const Text('Color', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _colors.map((color) {
                  return InkWell(
                    onTap: () => setState(() => _selectedColor = color),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: _selectedColor.value == color.value
                            ? Border.all(color: Colors.black, width: 2)
                            : null,
                      ),
                      child: _selectedColor.value == color.value
                          ? const Icon(Icons.check, color: Colors.white)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Icon Picker
              const Text('Icon', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              SizedBox(
                height: 200, // Constrain height for scrolling
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _icons.length,
                  itemBuilder: (context, index) {
                    final entry = _icons.entries.elementAt(index);
                    final isSelected = _selectedIcon == entry.key;

                    return InkWell(
                      onTap: () => setState(() => _selectedIcon = entry.key),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? _selectedColor.withOpacity(0.2)
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: isSelected
                              ? Border.all(color: _selectedColor, width: 2)
                              : null,
                        ),
                        child: Icon(
                          entry.value,
                          color: isSelected ? _selectedColor : Colors.grey[600],
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 32),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveCategory,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save Category'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
