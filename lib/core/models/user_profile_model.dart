class UserProfile {
  final String name;
  final String? email;
  final String? photoUrl; // Remote URL (from Google)
  final String? localPhotoPath; // Local file path for offline access
  final String? avatarIcon; // For manual users (preset emoji avatar)
  final bool isGoogleConnected;
  final DateTime createdAt;

  UserProfile({
    required this.name,
    this.email,
    this.photoUrl,
    this.localPhotoPath,
    this.avatarIcon,
    this.isGoogleConnected = false,
    required this.createdAt,
  });

  // Convert to JSON for SharedPreferences
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'localPhotoPath': localPhotoPath,
      'avatarIcon': avatarIcon,
      'isGoogleConnected': isGoogleConnected,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // Create from JSON
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      name: json['name'] as String,
      email: json['email'] as String?,
      photoUrl: json['photoUrl'] as String?,
      localPhotoPath: json['localPhotoPath'] as String?,
      avatarIcon: json['avatarIcon'] as String?,
      isGoogleConnected: json['isGoogleConnected'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  // Copy with
  UserProfile copyWith({
    String? name,
    String? email,
    String? photoUrl,
    String? localPhotoPath,
    String? avatarIcon,
    bool? isGoogleConnected,
    DateTime? createdAt,
    bool clearLocalPhotoPath = false,
    bool clearAvatarIcon = false,
  }) {
    return UserProfile(
      name: name ?? this.name,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      localPhotoPath: clearLocalPhotoPath ? null : (localPhotoPath ?? this.localPhotoPath),
      avatarIcon: clearAvatarIcon ? null : (avatarIcon ?? this.avatarIcon),
      isGoogleConnected: isGoogleConnected ?? this.isGoogleConnected,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'UserProfile{name: $name, email: $email, isGoogleConnected: $isGoogleConnected}';
  }
}
