import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import '../repositories/routine_repository.dart';
import '../repositories/daily_instance_repository.dart';
import '../repositories/category_repository.dart';
import '../services/user_profile_service.dart';
import '../models/routine_model.dart';
import '../models/category_model.dart';
import '../models/daily_instance_model.dart';
import '../models/user_profile_model.dart';

class BackupService {
  final RoutineRepository _routineRepo = RoutineRepository();
  final DailyInstanceRepository _instanceRepo = DailyInstanceRepository();
  final CategoryRepository _categoryRepo = CategoryRepository();

  static const String appFolderName = 'AkshaBackups';
  static const String backupFileName = 'aksha_backup.json';
  
  DateTime? _lastBackupTime;
  static const Duration backupCooldown = Duration(minutes: 5);

  /// Check if backup is allowed (rate limiting)
  bool canBackup() {
    if (_lastBackupTime == null) return true;
    return DateTime.now().difference(_lastBackupTime!) > backupCooldown;
  }

  /// Get remaining cooldown time
  Duration getRemainingCooldown() {
    if (canBackup()) return Duration.zero;
    return backupCooldown - DateTime.now().difference(_lastBackupTime!);
  }

  /// Create backup JSON from all app data
  Future<Map<String, dynamic>> createBackupData() async {
    final routines = await _routineRepo.getAllActive();
    final categories = await _categoryRepo.getAllActive();
    final profile = await UserProfileService.getProfile();

    // Get last 90 days of instances
    final endDate = DateTime.now();
    final startDate = endDate.subtract(const Duration(days: 90));
    final instances = await _instanceRepo.getInstancesInRange(
      startDate,
      endDate,
    );

    return {
      'version': '1.0',
      'timestamp': DateTime.now().toIso8601String(),
      'device_id': profile?.email ?? 'unknown',
      'data': {
        'routines': routines.map((r) => r.toJson()).toList(),
        'categories': categories.map((c) => c.toJson()).toList(),
        'instances': instances.map((i) => i.toJson()).toList(),
        'user_profile': profile?.toJson(),
      },
      'metadata': {
        'routine_count': routines.length,
        'category_count': categories.length,
        'instance_count': instances.length,
        'last_modified': DateTime.now().toIso8601String(),
      },
    };
  }

  /// Upload backup to Google Drive
  Future<String> uploadToGoogleDrive(GoogleSignInAccount googleUser) async {
    if (!canBackup()) {
      throw Exception('Please wait ${getRemainingCooldown().inMinutes} minutes before next backup');
    }

    // Get auth headers
    final authHeaders = await googleUser.authHeaders;
    final authenticateClient = GoogleAuthClient(authHeaders);
    final driveApi = drive.DriveApi(authenticateClient);

    // Create backup data
    final backupData = await createBackupData();
    final jsonString = jsonEncode(backupData);

    // Create backup file locally
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final backupFile = File('${directory.path}/aksha_backup_$timestamp.json');
    await backupFile.writeAsString(jsonString);

    // Upload to Drive
    final media = drive.Media(backupFile.openRead(), backupFile.lengthSync());
    final driveFile = drive.File()
      ..name = 'aksha_backup_$timestamp.json'
      ..mimeType = 'application/json';

    final uploadedFile = await driveApi.files.create(
      driveFile,
      uploadMedia: media,
    );

    _lastBackupTime = DateTime.now();
    
    // Clean up local file
    await backupFile.delete();

    return uploadedFile.id ?? 'unknown';
  }

  /// List available backups from Google Drive
  Future<List<Map<String, dynamic>>> listBackups(GoogleSignInAccount googleUser) async {
    final authHeaders = await googleUser.authHeaders;
    final authenticateClient = GoogleAuthClient(authHeaders);
    final driveApi = drive.DriveApi(authenticateClient);

    final fileList = await driveApi.files.list(
      q: "name contains 'aksha_backup' and mimeType='application/json'",
      orderBy: 'createdTime desc',
      spaces: 'drive',
      $fields: 'files(id, name, createdTime, size)',
    );

    return fileList.files?.map((file) {
      return {
        'id': file.id,
        'name': file.name,
        'createdTime': file.createdTime?.toIso8601String(),
        'size': file.size,
      };
    }).toList() ?? [];
  }

  /// Download backup from Google Drive
  Future<String> downloadBackup(GoogleSignInAccount googleUser, String fileId) async {
    final authHeaders = await googleUser.authHeaders;
    final authenticateClient = GoogleAuthClient(authHeaders);
    final driveApi = drive.DriveApi(authenticateClient);

    final media = await driveApi.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final directory = await getApplicationDocumentsDirectory();
    final backupFile = File('${directory.path}/downloaded_backup.json');
    
    final List<int> dataStore = [];
    await for (var data in media.stream) {
      dataStore.addAll(data);
    }
    
    await backupFile.writeAsBytes(dataStore);
    return backupFile.path;
  }

  /// Check for conflicts before restore
  Future<Map<String, dynamic>> checkConflict(String backupFilePath) async {
    final backupFile = File(backupFilePath);
    final backupContent = await backupFile.readAsString();
    final backupData = jsonDecode(backupContent);

    final backupTimestamp = DateTime.parse(backupData['timestamp']);
    final backupLastModified = DateTime.parse(backupData['metadata']['last_modified']);

    // Get current local data
    final currentRoutines = await _routineRepo.getAllActive();
    final currentInstances = await _instanceRepo.getInstancesInRange(
      DateTime.now().subtract(const Duration(days: 90)),
      DateTime.now(),
    );

    final localLastModified = DateTime.now(); // Simplified - normally would track this

    final hasConflict = backupTimestamp.isBefore(localLastModified);
    final dataLossDays = localLastModified.difference(backupTimestamp).inDays;

    return {
      'has_conflict': hasConflict,
      'backup_date': backupTimestamp.toIso8601String(),
      'local_date': localLastModified.toIso8601String(),
      'backup_routines': backupData['metadata']['routine_count'],
      'local_routines': currentRoutines.length,
      'backup_instances': backupData['metadata']['instance_count'],
      'local_instances': currentInstances.length,
      'data_loss_days': dataLossDays,
    };
  }

  /// Restore data from backup
  Future<void> restoreBackup(String backupFilePath) async {
    final backupFile = File(backupFilePath);
    final backupContent = await backupFile.readAsString();
    final backupData = jsonDecode(backupContent);

    // Restore categories first (routines depend on them)
    if (backupData['data']['categories'] != null) {
      final categories = (backupData['data']['categories'] as List)
          .map((json) => Category.fromJson(json as Map<String, dynamic>))
          .toList();
      
      for (final category in categories) {
        // Skip system categories (they should already exist)
        if (!category.isSystem) {
          try {
            await _categoryRepo.insert(category);
          } catch (e) {
            // If insert fails (duplicate), try update
            await _categoryRepo.update(category);
          }
        }
      }
    }

    // Restore routines
    if (backupData['data']['routines'] != null) {
      final routines = (backupData['data']['routines'] as List)
          .map((json) => Routine.fromJson(json as Map<String, dynamic>))
          .toList();
      
      for (final routine in routines) {
        try {
          await _routineRepo.insert(routine);
        } catch (e) {
          // If insert fails (duplicate), try update
          await _routineRepo.update(routine);
        }
      }
    }

    // Restore daily instances
    if (backupData['data']['instances'] != null) {
      final instances = (backupData['data']['instances'] as List)
          .map((json) => DailyInstance.fromJson(json as Map<String, dynamic>))
          .toList();
      
      for (final instance in instances) {
        try {
          await _instanceRepo.insert(instance);
        } catch (e) {
          // If insert fails (duplicate), try update
          await _instanceRepo.update(instance);
        }
      }
    }

    // Restore user profile
    if (backupData['data']['user_profile'] != null) {
      final profile = UserProfile.fromJson(
        backupData['data']['user_profile'] as Map<String, dynamic>
      );
      await UserProfileService.saveProfile(profile);
    }

    // Clean up backup file
    await backupFile.delete();
  }
}

/// Custom HTTP client for Google Auth
class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }

  @override
  void close() {
    _client.close();
  }
}
