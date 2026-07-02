import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:rapide_nforce/core/constants/api_constants.dart';
import 'package:rapide_nforce/core/models/api_result.dart';
import 'package:rapide_nforce/models/user_model.dart';
import 'package:rapide_nforce/services/api_client.dart';
import 'package:rapide_nforce/services/api_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Handles login and session state — aligned with web `authService.ts`.
class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';
  static const _companyKey = 'carrier_id';

  UserModel? _currentUser;
  String? _selectedCompanyId;

  UserModel? get currentUser => _currentUser;

  bool get isLoggedIn => _currentUser != null;

  String? get selectedCompanyId => _selectedCompanyId;

  int? get selectedCompanyIdInt => int.tryParse(_selectedCompanyId ?? '');

  Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    final userJson = prefs.getString(_userKey);
    _selectedCompanyId = prefs.getString(_companyKey);

    if (token != null && userJson != null) {
      try {
        final map = jsonDecode(userJson) as Map<String, dynamic>;
        _currentUser = UserModel.fromJson(map).copyWith(token: token);
      } catch (_) {
        await _clearSession(prefs);
      }
    }
  }

  void setSelectedCompanyId(String? companyId) {
    _selectedCompanyId = companyId;
    SharedPreferences.getInstance().then((prefs) {
      if (companyId == null) {
        prefs.remove(_companyKey);
      } else {
        prefs.setString(_companyKey, companyId);
      }
    });
  }

  Future<ApiResult<UserModel>> login({
    required String employeeId,
    required String password,
  }) async {
    final trimmedId = employeeId.trim();
    if (trimmedId.isEmpty) {
      return ApiResult.fail('Enter your email or username');
    }
    if (password.isEmpty) {
      return ApiResult.fail('Enter your password');
    }

    try {
      final isEmail = trimmedId.contains('@');
      final body = {
        'identifier': trimmedId,
        'password': password,
        if (isEmail) 'email': trimmedId else 'username': trimmedId,
      };

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConstants.login}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      final decoded = response.body.isNotEmpty
          ? jsonDecode(response.body) as Map<String, dynamic>
          : <String, dynamic>{};

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final token = _pickToken(decoded);
        if (token.isEmpty) {
          return ApiResult.fail('Authentication failed. No token received.');
        }

        final userMap = _pickUserMap(decoded);
        final user = UserModel.fromLoginJson(userMap, token: token);
        _currentUser = user;

        if (user.companyId != null) {
          setSelectedCompanyId(user.companyId.toString());
        }

        await _persistSession(user);
        return ApiResult.ok(user, statusCode: response.statusCode);
      }

      return ApiResult.fail(
        decoded['message'] as String? ?? 'Login failed',
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResult.fail('Network error. Please try again.');
    }
  }

  Future<ApiResult<UserModel>> fetchProfile() async {
    try {
      final body = await ApiClient.instance.parseJson(
        () => ApiClient.instance.get(ApiConstants.me),
        onSuccess: (b) => b,
      );
      final root = body is Map<String, dynamic> ? body : <String, dynamic>{};
      final data = root['data'] ?? root;
      final userMap = data is Map<String, dynamic>
          ? (data['user'] as Map<String, dynamic>? ?? data)
          : <String, dynamic>{};

      final fetched = UserModel.fromLoginJson(
        userMap,
        token: _currentUser?.token ?? '',
      );
      final user = _mergeProfile(_currentUser, fetched);
      _currentUser = user;
      if (user.companyId != null) {
        setSelectedCompanyId(user.companyId.toString());
      }
      await _persistSession(user);
      return ApiResult.ok(user);
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to load profile.');
    }
  }

  Future<ApiResult<void>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final response = await ApiClient.instance.post(
        ApiConstants.changePassword,
        body: {'currentPassword': currentPassword, 'newPassword': newPassword},
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResult.ok(null);
      }
      final body = response.body.isNotEmpty
          ? jsonDecode(response.body) as Map<String, dynamic>
          : <String, dynamic>{};
      return ApiResult.fail(
        body['message'] as String? ?? 'Failed to change password',
        statusCode: response.statusCode,
      );
    } catch (_) {
      return ApiResult.fail('Network error. Please try again.');
    }
  }

  Future<ApiResult<void>> updateProfile({
    required int userId,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final response = await ApiClient.instance.put(
        '${ApiConstants.users}/$userId',
        body: payload,
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResult.ok(null);
      }
      final body = response.body.isNotEmpty
          ? jsonDecode(response.body) as Map<String, dynamic>
          : <String, dynamic>{};
      return ApiResult.fail(
        body['message'] as String? ?? 'Failed to update profile',
        statusCode: response.statusCode,
      );
    } catch (_) {
      return ApiResult.fail('Network error. Please try again.');
    }
  }

  Future<ApiResult<int>> uploadFile(String filePath, String fileName) async {
    try {
      final file = File(filePath);
      final mimeType = _mimeFromPath(fileName);
      final multipart = http.MultipartRequest('POST', Uri.parse(''))
        ..fields['fileName'] = fileName
        ..fields['fileType'] = mimeType
        ..fields['fileSize'] = (await file.length()).toString()
        ..files.add(await http.MultipartFile.fromPath('file', filePath,
            filename: fileName));

      final response = await ApiClient.instance.postMultipart(
        ApiConstants.uploads,
        multipart,
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final data = body['data'] ?? body;
        int? id;
        if (data is Map<String, dynamic>) {
          id = data['id'] as int?;
        } else if (data is List && data.isNotEmpty) {
          id = (data.first as Map<String, dynamic>)['id'] as int?;
        }
        if (id != null) return ApiResult.ok(id);
        return ApiResult.fail('Upload succeeded but no id returned');
      }
      final body = response.body.isNotEmpty
          ? jsonDecode(response.body) as Map<String, dynamic>
          : <String, dynamic>{};
      return ApiResult.fail(
        body['message'] as String? ?? 'Upload failed',
        statusCode: response.statusCode,
      );
    } catch (_) {
      return ApiResult.fail('Network error. Please try again.');
    }
  }

  static String _mimeFromPath(String name) {
    final ext = name.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'webp':
        return 'image/webp';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> logout() async {
    _currentUser = null;
    _selectedCompanyId = null;
    final prefs = await SharedPreferences.getInstance();
    await _clearSession(prefs);
    await prefs.remove(_companyKey);
  }

  Future<void> _persistSession(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    if (user.token != null) {
      await prefs.setString(_tokenKey, user.token!);
    }
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  Future<void> _clearSession(SharedPreferences prefs) async {
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  String _pickToken(Map<String, dynamic> res) {
    final data = res['data'];
    if (data is Map<String, dynamic>) {
      return data['token'] as String? ??
          data['accessToken'] as String? ??
          data['access_token'] as String? ??
          '';
    }
    return res['token'] as String? ??
        res['accessToken'] as String? ??
        res['access_token'] as String? ??
        '';
  }

  UserModel _mergeProfile(UserModel? existing, UserModel fetched) {
    String pickString(String? next, String? prev) {
      final trimmed = next?.trim();
      if (trimmed != null && trimmed.isNotEmpty) return trimmed;
      final fallback = prev?.trim();
      return fallback ?? '';
    }

    String? pickOptional(String? next, String? prev) {
      final trimmed = next?.trim();
      if (trimmed != null && trimmed.isNotEmpty) return trimmed;
      final fallback = prev?.trim();
      return fallback != null && fallback.isNotEmpty ? fallback : null;
    }

    return UserModel(
      id: fetched.id > 0 ? fetched.id : (existing?.id ?? 0),
      employeeId: pickString(fetched.employeeId, existing?.employeeId),
      name: pickString(fetched.name, existing?.name).isNotEmpty
          ? pickString(fetched.name, existing?.name)
          : (existing?.name ?? fetched.name),
      role: pickString(fetched.role, existing?.role).isNotEmpty
          ? pickString(fetched.role, existing?.role)
          : (existing?.role ?? fetched.role),
      email: pickOptional(fetched.email, existing?.email),
      phone: pickOptional(fetched.phone, existing?.phone),
      territory: pickOptional(fetched.territory, existing?.territory),
      companyName: pickOptional(fetched.companyName, existing?.companyName),
      avatarUrl: pickOptional(fetched.avatarUrl, existing?.avatarUrl),
      token: fetched.token ?? existing?.token,
      companyId: fetched.companyId ?? existing?.companyId,
      roleId: fetched.roleId ?? existing?.roleId,
    );
  }

  Map<String, dynamic> _pickUserMap(Map<String, dynamic> res) {
    final data = res['data'];
    if (data is Map<String, dynamic>) {
      final user = data['user'];
      if (user is Map<String, dynamic>) return user;
      if (data.containsKey('id') || data.containsKey('email')) return data;
    }
    final user = res['user'];
    if (user is Map<String, dynamic>) return user;
    return res;
  }
}
