import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile_model.dart';

class UserProfileService {
  static const String _key = 'user_profile';

  // Save user profile to SharedPreferences
  static Future<void> saveProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(profile.toJson());
    await prefs.setString(_key, jsonString);
  }

  // Get user profile from SharedPreferences
  static Future<UserProfile?> getProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_key);
    
    if (jsonString == null) return null;
    
    try {
      final Map<String, dynamic> json = jsonDecode(jsonString);
      return UserProfile.fromJson(json);
    } catch (e) {
      // If parsing fails, return null and clear corrupted data
      await clearProfile();
      return null;
    }
  }

  // Check if user is signed in
  static Future<bool> isSignedIn() async {
    return await getProfile() != null;
  }

  // Clear user profile (sign out)
  static Future<void> clearProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  // Update profile (merge existing with new data)
  static Future<void> updateProfile(UserProfile profile) async {
    await saveProfile(profile);
  }
}
