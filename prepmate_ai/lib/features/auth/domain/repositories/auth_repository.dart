import 'package:firebase_auth/firebase_auth.dart';
import '../entities/user_entity.dart';

abstract class AuthRepository {
  Stream<User?> get authStateChanges;
  Future<UserEntity> signInWithEmail(String email, String password);
  Future<UserEntity> signUpWithEmail(String email, String password, String name);
  Future<void> signOut();
  Future<void> sendPasswordResetEmail(String email);
  Future<UserEntity?> getCurrentUser();
  Future<void> updateUserProfile(String uid, Map<String, dynamic> data);
}
