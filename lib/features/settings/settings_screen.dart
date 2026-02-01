import 'package:flutter/material.dart';
import '../../core/services/backup_service.dart';
import '../../core/services/export_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          _buildSectionHeader('Account'),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Profile'),
            subtitle: const Text('Manage your name and avatar'),
            onTap: () {
              // Navigate to profile edit
            },
          ),

          const Divider(),
          _buildSectionHeader('Data Management'),
          ListTile(
            leading: const Icon(Icons.backup),
            title: const Text('Cloud Backup'),
            subtitle: const Text('Google Drive Backup (Manual)'),
            onTap: () async {
              // Trigger backup check
              // This would typically involve a dedicated backup screen or dialog
              // Showing a simple dialogue for now
              await _showBackupDialog(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.file_download),
            title: const Text('Export Data'),
            subtitle: const Text('Download your history as CSV'),
            onTap: () async {
              await _handleExport(context);
            },
          ),

          const Divider(),
          _buildSectionHeader('Preferences'),
          ListTile(
            leading: const Icon(Icons.dark_mode),
            title: const Text('Theme'),
            subtitle: const Text('System Default'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Show theme picker dialog
            },
          ),
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('Notifications'),
            onTap: () {
              // Open notification settings (OS level or app detailed settings)
            },
          ),

          const Divider(),
          _buildSectionHeader('About'),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('About Aksha'),
            subtitle: const Text('Version 1.0.0'),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'Aksha',
                applicationVersion: '1.0.0',
                applicationLegalese: 'Copyright © 2024 Akku The Hacker',
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
        ),
      ),
    );
  }

  Future<void> _showBackupDialog(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cloud Backup'),
        content: const Text(
          'Backup your routines and history to your personal Google Drive.\n\n'
          'Note: This does not restore automatically. You must manually restore if you reinstall the app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              // Trigger backup logic
              Navigator.pop(context);
              final backupService = BackupService();
              // In a real scenario, handle auth and loading state properly
              backupService.createBackup().then((_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Backup started...')),
                );
              });
            },
            child: const Text('Backup Now'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleExport(BuildContext context) async {
      try {
        final exportService = ExportService();
        final path = await exportService.exportToCsv();
        if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Exported to $path')),
            );
        }
      } catch (e) {
          if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Export failed: $e')),
              );
          }
      }
  }
}
