import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_profile_model.dart';
import 'user_profile_service.dart';
import 'profile_photo_service.dart';

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'https://www.googleapis.com/auth/drive.file', // For Google Drive backup
    ],
  );

  // Sign in with Google
  Future<UserProfile?> signInWithGoogle() async {
    try {
      // Trigger Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        // User cancelled sign-in
        return null;
      }

      // Obtain auth credentials
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with Google credentials
      final UserCredential userCredential = 
          await _auth.signInWithCredential(credential);
      
      final User? firebaseUser = userCredential.user;
      
      if (firebaseUser == null) return null;

      // Download and save profile photo locally if available
      String? localPhotoPath;
      if (firebaseUser.photoURL != null) {
        localPhotoPath = await _downloadProfilePhoto(firebaseUser.photoURL!);
      }

      // Create user profile
      final profile = UserProfile(
        name: firebaseUser.displayName ?? 'User',
        email: firebaseUser.email,
        photoUrl: firebaseUser.photoURL,
        localPhotoPath: localPhotoPath,
        isGoogleConnected: true,
        createdAt: DateTime.now(),
      );

      // CRITICAL: Save to persistent storage immediately
      await UserProfileService.saveProfile(profile);
      
      return profile;
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth error: ${e.code} - ${e.message}');
      return null;
    } catch (e) {
      print('Sign-in error: $e');
      return null;
    }
  }

  // Helper: Download profile photo
  Future<String?> _downloadProfilePhoto(String url) async {
    try {
      return await ProfilePhotoService.downloadAndSavePhoto(url);
    } catch (e) {
      print('Error downloading profile photo: $e');
      return null;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
      await UserProfileService.clearProfile();
    } catch (e) {
      print('Sign-out error: $e');
    }
  }

  // Get current Firebase user
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  // Check if Firebase user is signed in
  bool isFirebaseSignedIn() {
    return _auth.currentUser != null;
  }

  // Connect Google account to existing manual profile
  Future<UserProfile?> connectGoogleToExistingProfile() async {
    try {
      // Get existing profile
      final existingProfile = await UserProfileService.getProfile();
      
      if (existingProfile == null) {
        throw Exception('No existing profile found');
      }

      // Perform Google Sign-In
      final googleProfile = await signInWithGoogle();
      
      if (googleProfile == null) return null;

      // Merge with existing profile (keep original created date)
      final mergedProfile = UserProfile(
        name: googleProfile.name,
        email: googleProfile.email,
        photoUrl: googleProfile.photoUrl,
        isGoogleConnected: true,
        createdAt: existingProfile.createdAt, // Keep original
      );

      await UserProfileService.saveProfile(mergedProfile);
      
      return mergedProfile;
    } catch (e) {
      print('Connect Google error: $e');
      return null;
    }
  }

  // Get Google Sign-In instance (for Drive API)
  GoogleSignIn get googleSignIn => _googleSignIn;
}
