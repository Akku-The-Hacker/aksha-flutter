import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../repositories/routine_repository.dart';
import '../repositories/daily_instance_repository.dart';
import '../repositories/category_repository.dart';

class ExportService {
  final RoutineRepository _routineRepo = RoutineRepository();
  final DailyInstanceRepository _instanceRepo = DailyInstanceRepository();
  final CategoryRepository _categoryRepo = CategoryRepository();

  Future<File> exportToCSV() async {
    final buffer = StringBuffer();

    // CSV Header
    buffer.writeln('Date,Routine,Category,Status,Planned Time,Actual Time,Notes');

    // Get all instances (last 90 days)
    final endDate = DateTime.now();
    final startDate = endDate.subtract(const Duration(days: 90));
    
    DateTime current = startDate;
    while (current.isBefore(endDate) || _isSameDay(current, endDate)) {
      final dateStr = DateFormat('yyyy-MM-dd').format(current);
      final instances = await _instanceRepo.getByDate(dateStr);
      
      for (final instance in instances) {
        buffer.writeln(
          '${instance.date},'
          '"${_escapeCsv(instance.routineName)}",'
          '"${_escapeCsv(instance.categoryName ?? 'Uncategorized')}",'
          '${instance.status.name},'
          '${instance.plannedMinutes},'
          '${instance.actualMinutes ?? ''},'
          '"${_escapeCsv(instance.notes ?? '')}"',
        );
      }
      
      current = current.add(const Duration(days: 1));
    }

    // Write to file
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File('${directory.path}/aksha_export_$timestamp.csv');
    await file.writeAsString(buffer.toString());

    return file;
  }

  Future<String> shareExport() async {
    final file = await exportToCSV();
    return file.path;
  }

  String _escapeCsv(String value) {
    return value.replaceAll('"', '""');
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  // Get summary report
  Future<Map<String, dynamic>> getSummaryReport() async {
    final routines = await _routineRepo.getAllActive();
    final categories = await _categoryRepo.getAllActive();
    
    // Get stats for last 30 days
    final endDate = DateTime.now();
    final startDate = endDate.subtract(const Duration(days: 30));
    
    int totalInstances = 0;
    int completedInstances = 0;
    
    DateTime current = startDate;
    while (current.isBefore(endDate) || _isSameDay(current, endDate)) {
      final dateStr = DateFormat('yyyy-MM-dd').format(current);
      final stats = await _instanceRepo.getDateStats(dateStr);
      
      totalInstances += stats['total'] ?? 0;
      completedInstances += stats['done'] ?? 0;
      
      current = current.add(const Duration(days: 1));
    }

    final completionRate = totalInstances > 0
        ? (completedInstances / totalInstances * 100).round()
        : 0;

    return {
      'total_routines': routines.length,
      'total_categories': categories.length,
      'total_instances_30d': totalInstances,
      'completed_instances_30d': completedInstances,
      'completion_rate_30d': completionRate,
      'export_date': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
    };
  }
}
