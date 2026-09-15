import 'package:firebase_auth/firebase_auth.dart';

/// Frictionless anonymous identity. No profile, no email, no password.
/// The uid from Firebase Anonymous Auth is the only identifier used
/// anywhere in the data model, and it is never shown to other users.
class IdentityService {
  IdentityService(this._auth);

  final FirebaseAuth _auth;

  String? get currentUserId => _auth.currentUser?.uid;

  Future<String> ensureSignedIn() async {
    final existing = _auth.currentUser;
    if (existing != null) return existing.uid;
    final credential = await _auth.signInAnonymously();
    final uid = credential.user?.uid;
    if (uid == null) {
      throw StateError('Anonymous sign-in did not return a user id.');
    }
    return uid;
  }
}
