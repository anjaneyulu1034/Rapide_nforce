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

bool isLeadTechnicianRole(String? role) {
  if (role == null) return false;
  final normalized =
      role.trim().replaceAll(RegExp(r'[\s-]+'), '_').toUpperCase();
  return normalized == 'LEAD_TECHNICIAN';
}

bool isTechnicianRole(String? role) {
  if (role == null) return false;
  final normalized =
      role.trim().replaceAll(RegExp(r'[\s-]+'), '_').toUpperCase();
  return normalized == 'TECHNICIAN';
}

/// Matches web's `isTechnicianOrLeadTechnician(user)` — used to gate the
/// "at least one inventory part required" rule before a Technician or Lead
/// Technician can mark a Work Order Completed.
bool isTechnicianOrLeadTechnicianRole(String? role) =>
    isTechnicianRole(role) || isLeadTechnicianRole(role);
