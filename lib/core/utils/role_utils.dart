bool isSuperAdminRole(String? role) {
  final normalized =
      (role ?? '').trim().replaceAll(RegExp(r'[\s-]+'), '_').toUpperCase();
  return normalized == 'SUPER_ADMIN';
}
