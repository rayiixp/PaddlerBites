import 'package:flutter/material.dart';
import '../models/app_user.dart';

class UserProvider with ChangeNotifier {
  Map<String, dynamic>? _userData;
  AppUser? _profile;

  /// Raw `users/{uid}` fields (name, isOnline, payoutAccount, ...).
  Map<String, dynamic>? get userData => _userData;

  /// Typed view with per-role approval statuses.
  AppUser? get profile => _profile;

  void setUser(String uid, Map<String, dynamic>? data) {
    _userData = data;
    _profile = data == null ? null : AppUser.fromMap(uid, data);
    notifyListeners();
  }

  void clearUser() {
    _userData = null;
    _profile = null;
    notifyListeners();
  }
}
