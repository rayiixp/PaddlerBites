import 'package:flutter/material.dart';

class UserProvider with ChangeNotifier {
  Map<String, dynamic>? _userData;
  Map<String, dynamic>? get userData => _userData;

  void setUser(Map<String, dynamic>? data) {
    _userData = data;
    notifyListeners();
  }

  void clearUser() {
    _userData = null;
    notifyListeners();
  }
}
