import 'package:flutter/material.dart';
import '../../core/services/firebase_auth_service.dart';
import '../../core/services/user_profile_service.dart';
import '../../core/models/user_profile_model.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final FirebaseAuthService _authService = FirebaseAuthService();
  bool _isLoading = false;

  // Preset avatar icons for manual users
  final List<String> _avatarIcons = [
    '😊', '🎯', '⭐', '🚀', '🌟',
    '💎', '🔥', '🌈', '🎨', '🏆',
  ];

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    
    try {
      final profile = await _authService.signInWithGoogle();
      
      if (profile != null && mounted) {
        // Navigate to home
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _continueWithName() {
    showDialog(
      context: context,
      builder: (context) => _ManualProfileDialog(
        avatarIcons: _avatarIcons,
        onProfileCreated: () {
          Navigator.of(context).pushReplacementNamed('/home');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo and title
              const Icon(
                Icons.track_changes,
                size: 80,
                color: Color(0xFF6750A4),
              ),
              const SizedBox(height: 24),
              const Text(
                'AKSHA',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 6,
                  color: Color(0xFF6750A4),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Track Your Routines Honestly',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 64),

              // Google Sign-In Button
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _signInWithGoogle,
                icon: Image.asset(
                  'assets/google_logo.png',
                  height: 24,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.login, color: Colors.white);
                  },
                ),
                label: const Text(
                  'Sign in with Google',
                  style: TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4285F4), // Google Blue
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Divider with "or"
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'or',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              
              const SizedBox(height: 24),

              // Continue with Name Button
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _continueWithName,
                icon: const Icon(Icons.person_add),
                label: const Text(
                  'Continue with Name Only',
                  style: TextStyle(fontSize: 16),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Privacy note
              Text(
                'Your data stays on your device.\nNo cloud sync, no tracking.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),

              if (_isLoading) ...[
                const SizedBox(height: 24),
                const Center(child: CircularProgressIndicator()),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// Manual Profile Creation Dialog
class _ManualProfileDialog extends StatefulWidget {
  final List<String> avatarIcons;
  final VoidCallback onProfileCreated;

  const _ManualProfileDialog({
    required this.avatarIcons,
    required this.onProfileCreated,
  });

  @override
  State<_ManualProfileDialog> createState() => _ManualProfileDialogState();
}

class _ManualProfileDialogState extends State<_ManualProfileDialog> {
  final TextEditingController _nameController = TextEditingController();
  String? _selectedAvatar;
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createProfile() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name')),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      final profile = UserProfile(
        name: _nameController.text.trim(),
        avatarIcon: _selectedAvatar ?? widget.avatarIcons[0],
        isGoogleConnected: false,
        createdAt: DateTime.now(),
      );

      await UserProfileService.saveProfile(profile);

      if (mounted) {
        Navigator.of(context).pop(); // Close dialog
        widget.onProfileCreated();
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Your Profile'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name input
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Your Name',
                hintText: 'Enter your name',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              autofocus: true,
            ),
            
            const SizedBox(height: 24),
            
            // Avatar selection
            const Text(
              'Choose an avatar:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: widget.avatarIcons.map((icon) {
                final isSelected = _selectedAvatar == icon;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedAvatar = icon);
                  },
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF6750A4).withOpacity(0.2)
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF6750A4)
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        icon,
                        style: const TextStyle(fontSize: 28),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isCreating ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isCreating ? null : _createProfile,
          child: _isCreating
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Continue'),
        ),
      ],
    );
  }
}
