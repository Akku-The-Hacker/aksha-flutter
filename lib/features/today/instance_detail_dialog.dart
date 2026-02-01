import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/daily_instance_model.dart';
import '../../core/providers/daily_instance_provider.dart';
import 'package:intl/intl.dart';

class InstanceDetailDialog extends ConsumerStatefulWidget {
  final DailyInstance instance;
  final String dateStr;

  const InstanceDetailDialog({
    super.key,
    required this.instance,
    required this.dateStr,
  });

  @override
  ConsumerState<InstanceDetailDialog> createState() => _InstanceDetailDialogState();
}

class _InstanceDetailDialogState extends ConsumerState<InstanceDetailDialog> {
  final _notesController = TextEditingController();
  final _actualHoursController = TextEditingController();
  late InstanceStatus _status;
  bool _isSaving = false;
  bool _showNotes = false;

  @override
  void initState() {
    super.initState();
    _status = widget.instance.status;
    _notesController.text = widget.instance.notes ?? '';
    // Show notes field if notes already exist
    _showNotes = widget.instance.notes != null && widget.instance.notes!.isNotEmpty;
    // Convert minutes to hours with 2 decimal places
    if (widget.instance.actualMinutes != null) {
      _actualHoursController.text = (widget.instance.actualMinutes! / 60).toStringAsFixed(2);
    } else {
      // Auto-fill based on current status
      _autoFillActualTime(_status);
    }
  }

  void _autoFillActualTime(InstanceStatus status) {
    final plannedHours = widget.instance.plannedMinutes / 60;
    double percentage;
    switch (status) {
      case InstanceStatus.done:
        percentage = 1.0; // 100%
        break;
      case InstanceStatus.partial:
        percentage = 0.8; // 80%
        break;
      case InstanceStatus.skipped:
      case InstanceStatus.missed:
        percentage = 0.0; // 0%
        break;
      case InstanceStatus.pending:
        percentage = 0.0; // Not completed yet
        break;
    }
    _actualHoursController.text = (plannedHours * percentage).toStringAsFixed(2);
  }

  void _onStatusChanged(InstanceStatus newStatus) {
    setState(() {
      _status = newStatus;
      // Auto-fill actual time when status changes
      _autoFillActualTime(newStatus);
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    _actualHoursController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    // Validate actual time for non-pending statuses
    if (_status != InstanceStatus.pending) {
      final actualHours = double.tryParse(_actualHoursController.text.trim());
      if (actualHours == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter actual time spent')),
        );
        return;
      }
    }

    setState(() => _isSaving = true);

    // Convert hours to minutes for storage
    final actualHours = double.tryParse(_actualHoursController.text.trim());
    final actualMinutes = actualHours != null ? (actualHours * 60).round() : null;

    await ref.read(dailyInstancesProvider(widget.dateStr).notifier).updateStatus(
      widget.instance.id,
      _status,
      actualMinutes: actualMinutes,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    );

    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  String _formatTime(String time) {
    final parts = time.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.instance.categoryColor != null
        ? Color(int.parse(widget.instance.categoryColor!.replaceFirst('#', '0xFF')))
        : Colors.grey;

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.instance.routineName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_formatTime(widget.instance.plannedStart)} - ${_formatTime(widget.instance.plannedEnd)}',
                          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status selection
                    const Text(
                      'Status',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _statusChip('Done', InstanceStatus.done, '✅', const Color(0xFF10B981)),
                        _statusChip('Partial', InstanceStatus.partial, '⚡', const Color(0xFFF59E0B)),
                        _statusChip('Skipped', InstanceStatus.skipped, '⏭️', Colors.grey),
                        _statusChip('Missed', InstanceStatus.missed, '❌', const Color(0xFFEF4444)),
                        _statusChip('Pending', InstanceStatus.pending, '⏳', Colors.blue),
                      ],
                    ),

                    const SizedBox(height: 24),

                    const Text(
                      'Actual Time Spent *',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _actualHoursController,
                      decoration: InputDecoration(
                        hintText: 'Hours (e.g., 1.5 for 1 hour 30 min)',
                        border: const OutlineInputBorder(),
                        suffixText: 'hours',
                        helperText: 'Planned: ${(widget.instance.plannedMinutes / 60).toStringAsFixed(2)} hours',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),

                    const SizedBox(height: 24),

                    // Notes toggle
                    if (!_showNotes)
                      TextButton.icon(
                        onPressed: () => setState(() => _showNotes = true),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Notes'),
                        style: TextButton.styleFrom(padding: EdgeInsets.zero),
                      ),
                    
                    if (_showNotes) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Notes',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          if (_notesController.text.isEmpty)
                            IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () => setState(() => _showNotes = false),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          hintText: 'How did it go? Any observations?',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                    ],

                    if (widget.instance.completedAt != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Completed: ${DateFormat('MMM d, h:mm a').format(widget.instance.completedAt!)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],

                    if (widget.instance.editedAfterDayEnd) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, size: 16, color: Colors.orange[700]),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Edited after day ended (retroactive)',
                                style: TextStyle(fontSize: 12, color: Colors.orange[700]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Footer
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
                    onPressed: _isSaving ? null : _save,
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String label, InstanceStatus status, String emoji, Color color) {
    final isSelected = _status == status;

    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          _onStatusChanged(status);
        }
      },
      selectedColor: color.withOpacity(0.2),
      backgroundColor: Colors.grey[200],
      side: BorderSide(
        color: isSelected ? color : Colors.grey[300]!,
        width: isSelected ? 2 : 1,
      ),
    );
  }
}
