import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'restapi.dart';
import 'config.dart';
import 'user_model.dart';

class AuthService extends ChangeNotifier {
  UserModel? _currentUser;
  bool _isLoading = false;
  final DataService _api = DataService();

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;

  // LOGIN
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      // FIX: Mengirim 6 Parameter (token, project, collection, appid, field, value)
      final resStr = await _api.selectWhere(
          token, project, 'users', appid, 'email', email);

      if (resStr != '[]' && resStr.isNotEmpty) {
        var decoded = json.decode(resStr);
        List users = [];

        if (decoded is List) {
          users = decoded;
        } else if (decoded is Map && decoded.containsKey('data')) {
          if (decoded['data'] is List) users = decoded['data'];
        } else if (decoded is Map) {
          users = [decoded];
        }

        if (users.isNotEmpty) {
          final userData = users.firstWhere((u) => u['password'] == password,
              orElse: () => null);

          if (userData != null) {
            _currentUser = UserModel.fromMap(userData);
            print("DEBUG: Login - selfieImage: ${_currentUser!.selfieImage}");
            _saveSession(userData);
            _isLoading = false;
            notifyListeners();
            return true;
          }
        }
      }
    } catch (e) {
      // print("Login Error: $e"); // Commented for production code
    }
    _isLoading = false;
    notifyListeners();
    return false;
  }

  // REGISTER
  Future<bool> register(
      {required String name,
      required String email,
      required String password,
      required String phone,
      required String role,
      required String selfieWithKtpUrl}) async {
    _isLoading = true;
    notifyListeners();
    final profileData = json.encode({
      'name': name,
      'phone': phone,
      'selfieImage': selfieWithKtpUrl,
      'isVerified': false,
      'joinDate': DateTime.now().toIso8601String()
    });

    // FIX: Mengirim 5 Parameter (appid, email, password, role, profile_data)
    final res =
        await _api.insertUsers(appid, email, password, role, profileData);

    _isLoading = false;
    notifyListeners();
    return res != '[]' && res.toString().contains('id');
  }

  // REGISTER SIMPLE
  Future<bool> registerSimple(
      {required String name,
      required String email,
      required String password,
      required String role}) async {
    _isLoading = true;
    notifyListeners();

    final profileData = json.encode({
      'name': name,
      'isVerified': false,
      'joinDate': DateTime.now().toIso8601String()
    });

    // FIX: Mengirim 5 Parameter
    final res =
        await _api.insertUsers(appid, email, password, role, profileData);
    _isLoading = false;
    notifyListeners();
    return res != '[]' && res.toString().contains('id');
  }

  // UPDATE PROFILE (Ganti nama method agar dikenali profile_screen)
  Future<bool> updateProfile(UserModel updatedUser) async {
    if (_currentUser == null) return false;

    UserModel oldUser = _currentUser!; // Simpan data lama untuk rollback
    _currentUser = updatedUser;
    notifyListeners();

    // FIX: Mengirim 7 Parameter (field, value, token, project, collection, appid, id)
    bool success = await _api.updateId(
        'profile_data',
        _currentUser!.toProfileDataString(),
        token,
        project,
        'users',
        appid,
        _currentUser!.id);

    if (success) {
      // Simpan session baru jika berhasil
      _saveSession(_currentUser!.toMap());
      return true;
    } else {
      // Rollback jika gagal
      _currentUser = oldUser;
      notifyListeners();
      return false;
    }
  }

  // Helper untuk update foto saja (opsional)
  Future<bool> updatePhoto(String newImageName) async {
    if (_currentUser == null) return false;
    String? oldImage = _currentUser!.selfieImage;
    // Simpan filename saja, URL akan dibangun saat display
    _currentUser!.selfieImage = newImageName;
    print("DEBUG: Stored filename: ${_currentUser!.selfieImage}");
    notifyListeners();

    bool success = await _api.updateId(
        'profile_data',
        _currentUser!.toProfileDataString(),
        token,
        project,
        'users',
        appid,
        _currentUser!.id);

    if (success) {
      // Simpan session baru jika berhasil
      _saveSession(_currentUser!.toMap());
      return true;
    } else {
      // Rollback jika gagal
      _currentUser!.selfieImage = oldImage;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _currentUser = null;
    notifyListeners();
  }

  Future<void> _saveSession(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_data', json.encode(data));
  }

  Future<void> autoLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey('user_data')) {
        final data = json.decode(prefs.getString('user_data')!);
        _currentUser = UserModel.fromMap(data);
        notifyListeners();
      }
    } catch (e) {}
  }

  // Method to refresh current user data from database
  Future<bool> refreshCurrentUser() async {
    if (_currentUser == null) return false;

    try {
      final resStr = await _api.selectWhere(
          token, project, 'users', appid, 'email', _currentUser!.email);

      if (resStr != '[]' && resStr.isNotEmpty) {
        var decoded = json.decode(resStr);
        List users = [];

        if (decoded is List) {
          users = decoded;
        } else if (decoded is Map && decoded.containsKey('data')) {
          if (decoded['data'] is List) users = decoded['data'];
        } else if (decoded is Map) {
          users = [decoded];
        }

        if (users.isNotEmpty) {
          final userData = users.firstWhere((u) => u['password'] == _currentUser!.password,
              orElse: () => null);

          if (userData != null) {
            _currentUser = UserModel.fromMap(userData);
            _saveSession(userData);
            notifyListeners();
            return true;
          }
        }
      }
    } catch (e) {
      print("Refresh user error: $e");
    }
    return false;
  }
}
