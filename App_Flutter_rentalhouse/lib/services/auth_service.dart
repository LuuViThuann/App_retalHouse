import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import '../models/user.dart';

class AuthService {
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _key = encrypt.Key.fromUtf8('SecurePassw0rdForEncryption12345678'); // Thay bằng key 32 ký tự
  final _iv = encrypt.IV.fromLength(16);

  static const String _usersCollection = "Users";

  Future<User> register(String email, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final encrypter = encrypt.Encrypter(encrypt.AES(_key));
      final encryptedPassword = encrypter.encrypt(password, iv: _iv).base64;
      final user = User(
        id: credential.user!.uid,
        email: email,
        encryptedPassword: encryptedPassword,
        createdAt: DateTime.now(),
      );
      await _firestore.collection(_usersCollection).doc(user.id).set(user.toFirestore());
      await _saveUserData(user);
      return user;
    } catch (e) {
      throw Exception('Failed to register: $e');
    }
  }

  Future<User> login(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final doc = await _firestore.collection(_usersCollection).doc(credential.user!.uid).get();
      if (!doc.exists) throw Exception('User not found in Firestore');
      final user = User.fromFirestore(doc.data()!, doc.id);
      await _saveUserData(user);
      return user;
    } catch (e) {
      throw Exception('Failed to login: $e');
    }
  }

  Future<void> changePassword(String currentPassword, String newPassword) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user logged in');
      final credential = firebase_auth.EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
      final encrypter = encrypt.Encrypter(encrypt.AES(_key));
      final encryptedPassword = encrypter.encrypt(newPassword, iv: _iv).base64;
      await _firestore.collection(_usersCollection).doc(user.uid).update({
        'encryptedPassword': encryptedPassword,
      });
    } catch (e) {
      throw Exception('Failed to change password: $e');
    }
  }

  Future<String?> getToken() async {
    final user = _auth.currentUser;
    if (user != null) {
      return await user.getIdToken();
    }
    return null;
  }

  Future<User?> getCurrentUser() async {
    final user = _auth.currentUser;
    if (user != null) {
      final doc = await _firestore.collection(_usersCollection).doc(user.uid).get();
      if (!doc.exists) return null;
      return User.fromFirestore(doc.data()!, doc.id);
    }
    return null;
  }

  Future<void> _saveUserData(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userId', user.id);
    await prefs.setString('email', user.email);
  }

  Future<void> logout() async {
    await _auth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}