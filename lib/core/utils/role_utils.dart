bool isSuperAdminRole(String? role) {
  final normalized =
      (role ?? '').trim().replaceAll(RegExp(r'[\s-]+'), '_').toUpperCase();
  return normalized == 'SUPER_ADMIN';
}

bool isAdminRole(String? role) {
  if (role == null) return false;
  final normalized =
      role.trim().replaceAll(RegExp(r'[\s-]+'), '_').toUpperCase();
  return normalized == 'ADMIN' || normalized == 'SUPER_ADMIN';
}
