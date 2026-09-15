import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Frictionless anonymous identity. No login, no profile, no backend
/// account of any kind. Just a random id generated once on-device and
/// cached locally — it is never shown to other users.
class IdentityService {
  static const _prefsKey = 'anonymous_user_id';
  static const _uuid = Uuid();

  String? _cachedUserId;

  String? get currentUserId => _cachedUserId;

  Future<String> ensureSignedIn() async {
    final existing = _cachedUserId;
    if (existing != null) return existing;

    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_prefsKey);
    if (id == null) {
      id = _uuid.v4();
      await prefs.setString(_prefsKey, id);
    }
    _cachedUserId = id;
    return id;
  }
}
