class UserModel {
  const UserModel({
    required this.id,
    required this.employeeId,
    required this.name,
    required this.role,
    this.email,
    this.phone,
    this.territory,
    this.companyName,
    this.avatarUrl,
    this.token,
    this.companyId,
    this.roleId,
    this.signatureUploadId,
    this.certificateNumber,
    this.certificateUploadId,
  });

  final int id;
  final String employeeId;
  final String name;
  final String role;
  final String? email;
  final String? phone;
  final String? territory;
  final String? companyName;
  final String? avatarUrl;
  final String? token;
  final int? companyId;
  final int? roleId;
  final int? signatureUploadId;
  final String? certificateNumber;
  final int? certificateUploadId;

  String get resolvedCompanyName {
    for (final value in [companyName, territory]) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    }
    return '—';
  }

  UserModel copyWith({
    String? token,
    int? companyId,
    String? employeeId,
    String? name,
    String? role,
    String? email,
    String? phone,
    String? companyName,
    String? territory,
    int? roleId,
    int? signatureUploadId,
    bool clearSignatureUploadId = false,
    String? certificateNumber,
    int? certificateUploadId,
    bool clearCertificateUploadId = false,
  }) {
    return UserModel(
      id: id,
      employeeId: employeeId ?? this.employeeId,
      name: name ?? this.name,
      role: role ?? this.role,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      territory: territory ?? this.territory,
      companyName: companyName ?? this.companyName,
      avatarUrl: avatarUrl,
      token: token ?? this.token,
      companyId: companyId ?? this.companyId,
      roleId: roleId ?? this.roleId,
      signatureUploadId: clearSignatureUploadId
          ? null
          : (signatureUploadId ?? this.signatureUploadId),
      certificateNumber: certificateNumber ?? this.certificateNumber,
      certificateUploadId: clearCertificateUploadId
          ? null
          : (certificateUploadId ?? this.certificateUploadId),
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final roleId = json['role_id'] as int? ?? json['roleId'] as int?;
    final companyMap =
        json['company'] is Map ? json['company'] as Map<String, dynamic> : null;
    final technicianMap =
        json['technician'] is Map ? json['technician'] as Map<String, dynamic> : null;

    return UserModel(
      // Login response nests the id as lowercase `userid` (not `id`/`userId`)
      // alongside an unrelated `user` field that's actually the username —
      // mirrors the web app's `user?.userid ?? user?.userId ?? user?.id`.
      id: json['id'] as int? ??
          json['userId'] as int? ??
          json['userid'] as int? ??
          0,
      employeeId: json['employee_id'] as String? ??
          json['employeeId'] as String? ??
          json['username'] as String? ??
          '',
      name: _nameFromJson(json),
      role: _roleString(json['role'], roleId: roleId, json: json),
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      territory: json['territory'] as String?,
      companyName: json['company_name'] as String? ??
          json['companyName'] as String? ??
          companyMap?['name'] as String?,
      avatarUrl: json['avatar_url'] as String? ?? json['avatarUrl'] as String?,
      token: json['token'] as String? ??
          json['access_token'] as String? ??
          json['accessToken'] as String?,
      companyId: json['company_id'] as int? ??
          json['companyId'] as int? ??
          json['carrier_id'] as int?,
      roleId: roleId,
      signatureUploadId: _parseId(
        json['signature_upload_id'] ?? json['signatureUploadId'],
      ),
      certificateNumber: json['certificate_number'] as String? ??
          json['certificateNumber'] as String? ??
          json['certificate_id'] as String? ??
          technicianMap?['certificate_id'] as String?,
      certificateUploadId: _parseId(
        json['certificate_upload_id'] ??
            json['certificateUploadId'] ??
            json['certificate_image_id'] ??
            technicianMap?['certificate_image_id'],
      ),
    );
  }

  static int? _parseId(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  factory UserModel.fromLoginJson(
    Map<String, dynamic> json, {
    required String token,
  }) {
    return UserModel.fromJson(json).copyWith(token: token);
  }

  static String _nameFromJson(Map<String, dynamic> json) {
    final displayName = (json['displayName'] as String? ??
            json['display_name'] as String?)
        ?.trim();
    if (displayName != null && displayName.isNotEmpty) return displayName;

    final name = json['name'] as String?;
    if (name != null && name.trim().isNotEmpty) return name.trim();

    final first = json['first_name'] as String? ?? json['firstName'] as String?;
    final last = json['last_name'] as String? ?? json['lastName'] as String?;
    final combined = '${first ?? ''} ${last ?? ''}'.trim();
    if (combined.isNotEmpty) return combined;

    final username = json['username'] as String?;
    if (username != null && username.trim().isNotEmpty) return username.trim();

    return 'User';
  }

  static String _roleString(
    dynamic role, {
    int? roleId,
    Map<String, dynamic>? json,
  }) {
    String res = 'Technician';
    final roles = json?['roles'];
    if (roles is List && roles.isNotEmpty) {
      final first = roles.first;
      if (first is String && first.trim().isNotEmpty) {
        res = first.trim();
      }
    } else if (role is String && role.trim().isNotEmpty) {
      res = role.trim();
    } else if (role is Map) {
      res = role['display_name'] as String? ??
          role['displayName'] as String? ??
          role['name'] as String? ??
          'Technician';
    } else {
      final id = roleId ?? (role is int ? role : null);
      if (id != null) {
        res = _roleNameFromId(id);
      }
    }

    if (res.isNotEmpty) {
      return res.replaceAll('_', ' ').split(' ').map((word) {
        if (word.isEmpty) return '';
        return word[0].toUpperCase() + word.substring(1).toLowerCase();
      }).join(' ');
    }
    return res;
  }

  static String _roleNameFromId(int id) {
    switch (id) {
      case 1:
        return 'Super Admin';
      case 2:
        return 'Admin';
      case 3:
        return 'Technician';
      case 4:
        return 'Driver';
      case 5:
        return 'Lead Technician';
      default:
        return 'User';
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'employee_id': employeeId,
        'username': employeeId,
        'name': name,
        'displayName': name,
        'role': role,
        'role_id': roleId,
        'email': email,
        'phone': phone,
        'territory': territory,
        'company_name': companyName,
        'avatar_url': avatarUrl,
        'token': token,
        'company_id': companyId,
        'signature_upload_id': signatureUploadId,
        'certificate_number': certificateNumber,
        'certificate_upload_id': certificateUploadId,
      };
}
