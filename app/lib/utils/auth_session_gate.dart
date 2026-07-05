import 'package:flutter/foundation.dart';

/// Valid backend session while Firebase [currentUser] is still syncing (Flutter web).
class AuthSessionGate extends ChangeNotifier {
  AuthSessionGate._();
  static final AuthSessionGate instance = AuthSessionGate._();

  bool _active = false;

  bool get hasSession => _active;

  void activate() {
    if (_active) return;
    _active = true;
    notifyListeners();
  }

  void clear() {
    if (!_active) return;
    _active = false;
    notifyListeners();
  }
}
