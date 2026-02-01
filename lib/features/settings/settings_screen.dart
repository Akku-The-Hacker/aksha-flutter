import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/user_profile_service.dart';
import '../../core/services/firebase_auth_service.dart';
import '../../core/services/export_service.dart';
import '../../core/services/backup_service.dart';
import '../../core/models/user_profile_model.dart';
import '../../core/providers/theme_provider.dart';
import '../auth/sign_in_screen.dart';
import 'edit_profile_dialog.dart';
import 'manage_categories_screen.dart';
import '../achievements/achievements_screen.dart';
import '../templates/template_library_screen.dart';
import '../tags/manage_tags_screen.dart';
import '../pomodoro/pomodoro_timer_screen.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../core/database/database_helper.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}


class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final FirebaseAuthService _authService = FirebaseAuthService();
  UserProfile? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await UserProfileService.getProfile();
    setState(() {
      _profile = profile;
      _isLoading = false;
    });
  }

  Future<void> _connectGoogle() async {
    final profile = await _authService.connectGoogleToExistingProfile();
    
    if (profile != null && mounted) {
      setState(() => _profile = profile);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('✅ Google account connected!'),
            ],
          ),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    }
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text(
          'Are you sure you want to sign out? Your data will remain on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await _authService.signOut();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SignInScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _deleteAllData() async {
    // First confirmation
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete All Data?'),
          ],
        ),
        content: const Text(
          'This will permanently delete:\n'
          '• All routines\n'
          '• All categories (except defaults)\n'
          '• All progress and achievements\n'
          '• All daily instances\n\n'
          'This action CANNOT be undone!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete Everything', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Second confirmation - type DELETE
    final secondConfirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Final Confirmation'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Type "DELETE" to confirm:'),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'DELETE',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.trim().toUpperCase() == 'DELETE') {
                  Navigator.of(context).pop(true);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Type "DELETE" to confirm')),
                  );
                }
              },
              child: const Text('Confirm Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (secondConfirm != true || !mounted) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Clear all data
      await DatabaseHelper.instance.clearAllData();

      if (mounted) {
        Navigator.pop(context); // Close loading
        
        // Sign out and navigate to sign-in screen
        await _authService.signOut();
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const SignInScreen()),
          (route) => false,
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ All data deleted. Start fresh!')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Failed to delete data: $e')),
        );
      }
    }
  }

  Future<void> _backupToDrive() async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final backupService = BackupService();

      // Check cooldown
      if (!backupService.canBackup()) {
        if (mounted) Navigator.pop(context);
        final remaining = backupService.getRemainingCooldown();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⏳ Please wait ${remaining.inMinutes} minute(s) before next backup'),
          ),
        );
        return;
      }

      // Get Google account
      final googleSignIn = GoogleSignIn(scopes: [
        'email',
        'https://www.googleapis.com/auth/drive.file',
      ]);
      
      GoogleSignInAccount? googleUser = await googleSignIn.signInSilently();
      googleUser ??= await googleSignIn.signIn();

      if (googleUser == null) {
        if (mounted) Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Google Sign-In cancelled')),
        );
        return;
      }

      // Upload backup
      await backupService.uploadToGoogleDrive(googleUser);

      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Backup uploaded successfully!'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Backup failed: $e')),
        );
      }
    }
  }

  Future<void> _restoreFromDrive() async {
    try {
      // Get Google account
      final googleSignIn = GoogleSignIn(scopes: [
        'email',
        'https://www.googleapis.com/auth/drive.file',
      ]);
      
      GoogleSignInAccount? googleUser = await googleSignIn.signInSilently();
      googleUser ??= await googleSignIn.signIn();

      if (googleUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Google Sign-In cancelled')),
        );
        return;
      }

      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final backupService = BackupService();

      // List backups
      final backups = await backupService.listBackups(googleUser);

      if (mounted) Navigator.pop(context); // Close loading

      if (backups.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ℹ️ No backups found')),
        );
        return;
      }

      // Show backup selection dialog
      final selectedBackup = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select Backup'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: backups.length,
              itemBuilder: (context, index) {
                final backup = backups[index];
                final createdTime = DateTime.parse(backup['createdTime']);
                return ListTile(
                  title: Text(backup['name']),
                  subtitle: Text('Created: ${createdTime.toLocal()}'),
                  onTap: () => Navigator.pop(context, backup),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );

      if (selectedBackup == null) return;

      // Download backup
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final backupPath = await backupService.downloadBackup(
        googleUser,
        selectedBackup['id'],
      );

      // Check for conflicts
      final conflictInfo = await backupService.checkConflict(backupPath);

      if (mounted) Navigator.pop(context); // Close loading

      if (conflictInfo['has_conflict']) {
        // Show conflict warning
        final shouldRestore = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('⚠️ Restore Warning'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('This backup is ${conflictInfo['data_loss_days']} day(s) old.'),
                const SizedBox(height: 8),
                Text('Backup: ${conflictInfo['backup_routines']} routines, ${conflictInfo['backup_instances']} instances'),
                Text('Current: ${conflictInfo['local_routines']} routines, ${conflictInfo['local_instances']} instances'),
                const SizedBox(height: 16),
                const Text(
                  'Restoring will REPLACE all current data. Continue?',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: const Text('Restore Anyway'),
              ),
            ],
          ),
        );

        if (shouldRestore != true) return;
      }

      // Restore
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      await backupService.restoreBackup(backupPath);

      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Restore completed! Please restart the app.'),
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        // Close any dialogs
        Navigator.of(context).popUntil((route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Restore failed: $e')),
        );
      }
    }
  }

  String _getThemeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'Follow system settings';
      case ThemeMode.light:
        return 'Always light';
      case ThemeMode.dark:
        return 'Always dark';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Aksha'),
      ),
      body: ListView(
        children: [
          // Profile Section
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF6750A4).withOpacity(0.1),
                  const Color(0xFF6750A4).withOpacity(0.05),
                ],
              ),
            ),
            child: Row(
              children: [
                // Profile picture with fallback: Local → Google → Default Icon
                CircleAvatar(
                  key: ValueKey('${_profile?.localPhotoPath}_${_profile?.photoUrl}'),
                  radius: 40,
                  backgroundColor: const Color(0xFF6750A4),
                  backgroundImage: _profile?.localPhotoPath != null
                      ? FileImage(File(_profile!.localPhotoPath!))
                      : (_profile?.photoUrl != null
                          ? NetworkImage(_profile!.photoUrl!)
                          : null) as ImageProvider?,
                  child: _profile?.localPhotoPath == null && _profile?.photoUrl == null
                      ? const Icon(Icons.person, size: 40, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _profile?.name ?? 'User',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_profile?.email != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _profile!.email!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            _profile?.isGoogleConnected == true
                                ? Icons.cloud_done
                                : Icons.cloud_off,
                            size: 16,
                            color: _profile?.isGoogleConnected == true
                                ? Colors.green
                                : Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _profile?.isGoogleConnected == true
                                ? 'Google Connected'
                                : 'Local Only',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () async {
                    if (_profile != null) {
                      final result = await showDialog<UserProfile>(
                        context: context,
                        builder: (_) => EditProfileDialog(profile: _profile!),
                      );
                      if (result != null) {
                        setState(() => _profile = result);
                      }
                    }
                  },
                  tooltip: 'Edit Profile',
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Connect Google Account (if not connected)
          if (_profile?.isGoogleConnected != true)
            ListTile(
              leading: const Icon(Icons.link, color: Colors.blue),
              title: const Text('Connect Google Account'),
              subtitle: const Text('Link your account for backup & sync'),
              onTap: _connectGoogle,
            ),


          const Divider(),

          // Backup to Drive
          ListTile(
            leading: const Icon(Icons.cloud_upload, color: Colors.blue),
            title: const Text('Backup to Drive'),
            subtitle: const Text('Save your data to Google Drive'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _backupToDrive,
          ),

          // Restore from Drive
          ListTile(
            leading: const Icon(Icons.cloud_download, color: Colors.green),
            title: const Text('Restore from Drive'),
            subtitle: const Text('Restore from backup'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _restoreFromDrive,
          ),

          const Divider(),

          // Dark Mode
          ListTile(
            leading: const Icon(Icons.brightness_6, color: Colors.indigo),
            title: const Text('Dark Mode'),
            subtitle: Text(_getThemeModeLabel(ref.watch(themeModeProvider))),
            trailing: DropdownButton<ThemeMode>(
              value: ref.watch(themeModeProvider),
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(
                  value: ThemeMode.system,
                  child: Text('System'),
                ),
                DropdownMenuItem(
                  value: ThemeMode.light,
                  child: Text('Light'),
                ),
                DropdownMenuItem(
                  value: ThemeMode.dark,
                  child: Text('Dark'),
                ),
              ],
              onChanged: (mode) {
                if (mode != null) {
                  ref.read(themeModeProvider.notifier).setThemeMode(mode);
                }
              },
            ),
          ),

          const Divider(),

          // Manage Categories
          ListTile(
            leading: const Icon(Icons.category, color: Color(0xFF6750A4)),
            title: const Text('Manage Categories'),
            subtitle: const Text('Edit and organize your categories'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ManageCategoriesScreen(),
                ),
              );
            },
          ),

          // Manage Tags
          ListTile(
            leading: const Icon(Icons.label, color: Colors.teal),
            title: const Text('Manage Tags'),
            subtitle: const Text('Create and edit custom tags'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ManageTagsScreen(),
                ),
              );
            },
          ),

          const Divider(),

          // Achievements
          ListTile(
            leading: const Icon(Icons.emoji_events, color: Colors.amber),
            title: const Text('Achievements'),
            subtitle: const Text('View your badges'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AchievementsScreen(),
                ),
              );
            },
          ),

          // Routine Templates
          ListTile(
            leading: const Icon(Icons.library_books, color: Colors.purple),
            title: const Text('Routine Templates'),
            subtitle: const Text('Import pre-built routines'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TemplateLibraryScreen(),
                ),
              );
            },
          ),

          // Pomodoro Timer
          ListTile(
            leading: const Icon(Icons.timer, color: Colors.red),
            title: const Text('Pomodoro Timer'),
            subtitle: const Text('Focus timer with breaks'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PomodoroTimerScreen(),
                ),
              );
            },
          ),


          // Export Data
          ListTile(
            leading: const Icon(Icons.file_download, color: Colors.green),
            title: const Text('Export Data'),
            subtitle: const Text('Export to CSV'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              // Show loading
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => const Center(child: CircularProgressIndicator()),
              );

              try {
                final ExportService exportService = ExportService();
                final filePath = await exportService.shareExport();
                
                if (mounted) {
                  Navigator.pop(context); // Close loading
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('✅ Exported to: $filePath')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context); // Close loading
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('❌ Export failed: $e')),
                  );
                }
              }
            },
          ),



          const Divider(),

          // About
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('About Aksha'),
            subtitle: const Text('Version 1.0.2'),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'Aksha',
                applicationVersion: '1.0.2',
                applicationLegalese:
                    'Aksha does not collect, transmit, or store your personal data on any server. All your data stays on your device. You own your data completely.',
              );
            },
          ),

          const Divider(),

          // Delete All Data
          ListTile(
            leading: const Icon(Icons.delete_sweep, color: Colors.red),
            title: const Text(
              'Delete All Data',
              style: TextStyle(color: Colors.red),
            ),
            subtitle: const Text('Start fresh - deletes everything'),
            onTap: () => _deleteAllData(),
          ),

          // Sign Out
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text(
              'Sign Out',
              style: TextStyle(color: Colors.red),
            ),
            onTap: _signOut,
          ),
        ],
      ),
    );
  }
}
