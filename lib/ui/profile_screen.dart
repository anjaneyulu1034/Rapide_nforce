import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/core/constants/app_gradients.dart';
import 'package:rapide_nforce/core/constants/app_strings.dart';
import 'package:rapide_nforce/core/utils/app_toast.dart';
import 'package:rapide_nforce/core/utils/document_download_service.dart';
import 'package:rapide_nforce/core/utils/role_utils.dart';
import 'package:rapide_nforce/models/user_model.dart';
import 'package:rapide_nforce/services/auth_service.dart';
import 'package:rapide_nforce/services/company_service.dart';
import 'package:rapide_nforce/ui/widgets/gradient_page_background.dart';
import 'package:rapide_nforce/ui/widgets/screen_state_builder.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.onLogout});

  final VoidCallback onLogout;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loading = true;
  String? _error;
  UserModel? _user;
  _Tab _tab = _Tab.profile;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await AuthService.instance.fetchProfile();
    var user = result.isSuccess
        ? result.data
        : AuthService.instance.currentUser;

    if (user != null &&
        user.resolvedCompanyName == '—' &&
        user.companyId != null) {
      final cResult = await CompanyService.instance.fetchCompanyById(
        user.companyId!,
      );
      if (cResult.isSuccess && cResult.data != null) {
        user = user.copyWith(companyName: cResult.data!.name);
      }
    }

    if (!mounted) return;
    setState(() {
      _loading = false;
      _user = user;
      _error = user == null
          ? (result.message ?? 'Failed to load profile')
          : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user =
        _user ??
        AuthService.instance.currentUser ??
        const UserModel(
          id: 0,
          employeeId: '',
          name: 'User',
          role: 'Technician',
        );

    return GradientPageBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: ScreenStateBuilder(
          loading: _loading,
          error: _error,
          onRetry: _load,
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).padding.bottom + 80,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ProfileHero(user: user),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _TabToggle(
                    active: _tab,
                    onChanged: (t) => setState(() => _tab = t),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _tab == _Tab.profile
                      ? _ProfileTab(
                          user: user,
                          onReload: _load,
                          onLogout: widget.onLogout,
                        )
                      : const _SecurityTab(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Tab enum ────────────────────────────────────────────────────────────────

enum _Tab { profile, security }

// ─── Hero Header ─────────────────────────────────────────────────────────────

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.user});
  final UserModel user;

  @override
  Widget build(BuildContext context) {
    final initials = _initials(user.name);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 52, 16, 24),
      child: Column(
        children: [
          // Avatar — dark circle with white initials
          Container(
            width: 88,
            height: 88,
            decoration: const BoxDecoration(
              color: Color(0xFF4B633D),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initials,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Name
          Text(
            user.name,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 6),
          // Role chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              gradient: AppGradients.goldAccent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              user.role,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.black,
                letterSpacing: 0.5,
              ),
            ),
          ),
          if (user.employeeId.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'ID: ${user.employeeId}',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }
}

// ─── Tab Toggle ──────────────────────────────────────────────────────────────

class _TabToggle extends StatelessWidget {
  const _TabToggle({required this.active, required this.onChanged});

  final _Tab active;
  final ValueChanged<_Tab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _chip('Profile', _Tab.profile),
          const SizedBox(width: 4),
          _chip('Change Password', _Tab.security),
        ],
      ),
    );
  }

  Widget _chip(String label, _Tab tab) {
    final selected = active == tab;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(tab),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF2563EB) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Profile Tab ─────────────────────────────────────────────────────────────

class _ProfileTab extends StatefulWidget {
  const _ProfileTab({
    required this.user,
    required this.onReload,
    required this.onLogout,
  });

  final UserModel user;
  final VoidCallback onReload;
  final VoidCallback onLogout;

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  late final TextEditingController _phone;
  late final TextEditingController _certificateNumber;
  bool _saving = false;
  int? _signatureUploadId;
  String? _signatureFileName;
  String? _signatureLocalPath;
  bool _signatureUploading = false;
  bool _signaturePreviewLoading = false;
  int? _certificateUploadId;
  String? _certificateFileName;
  String? _certificateLocalPath;
  bool _certificateUploading = false;
  bool _certificatePreviewLoading = false;

  bool get _isLeadTechnician => isLeadTechnicianRole(widget.user.role);

  @override
  void initState() {
    super.initState();
    _phone = TextEditingController(text: widget.user.phone ?? '');
    _certificateNumber = TextEditingController(
      text: widget.user.certificateNumber ?? '',
    );
    _signatureUploadId = widget.user.signatureUploadId;
    if (_signatureUploadId != null) {
      _loadUploadFileName(_signatureUploadId!, isSignature: true);
    }
    _certificateUploadId = widget.user.certificateUploadId;
    if (_certificateUploadId != null) {
      _loadUploadFileName(_certificateUploadId!, isSignature: false);
    }
  }

  // Only the upload id is persisted server-side, so on load we resolve it to
  // a display file name the same way web's SignatureUpload component does —
  // falling back to a generic label if the lookup fails.
  Future<void> _loadUploadFileName(int uploadId, {required bool isSignature}) async {
    final result = await AuthService.instance.fetchUploadMeta(uploadId);
    if (!mounted) return;
    final name = result.isSuccess ? result.data?.fileName : null;
    if (isSignature) {
      if (_signatureUploadId != uploadId) return;
      setState(() => _signatureFileName = name ?? 'Signature uploaded');
    } else {
      if (_certificateUploadId != uploadId) return;
      setState(() => _certificateFileName = name ?? 'Certificate uploaded');
    }
  }

  @override
  void dispose() {
    _phone.dispose();
    _certificateNumber.dispose();
    super.dispose();
  }

  Future<void> _pickSignature() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
    );
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.first;
    if (file.path == null) return;

    setState(() => _signatureUploading = true);
    final result = await AuthService.instance.uploadFile(file.path!, file.name);
    if (!mounted) return;
    setState(() => _signatureUploading = false);
    if (result.isSuccess) {
      setState(() {
        _signatureUploadId = result.data;
        _signatureFileName = file.name;
        _signatureLocalPath = file.path;
      });
    } else {
      AppToast.showError(result.message ?? 'Upload failed');
    }
  }

  Future<void> _pickCertificate() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
    );
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.first;
    if (file.path == null) return;

    setState(() => _certificateUploading = true);
    final result = await AuthService.instance.uploadFile(file.path!, file.name);
    if (!mounted) return;
    setState(() => _certificateUploading = false);
    if (result.isSuccess) {
      setState(() {
        _certificateUploadId = result.data;
        _certificateFileName = file.name;
        _certificateLocalPath = file.path;
      });
    } else {
      AppToast.showError(result.message ?? 'Upload failed');
    }
  }

  Future<void> _previewSignature() => _previewFile(
    uploadId: _signatureUploadId,
    localPath: _signatureLocalPath,
    displayName: _signatureFileName,
    setLoading: (v) => setState(() => _signaturePreviewLoading = v),
  );

  Future<void> _previewCertificate() => _previewFile(
    uploadId: _certificateUploadId,
    localPath: _certificateLocalPath,
    displayName: _certificateFileName,
    setLoading: (v) => setState(() => _certificatePreviewLoading = v),
  );

  // A freshly-picked file can be opened straight from its local path; a
  // previously-saved one only has an upload id, so we resolve a short-lived
  // signed URL first and hand it to the shared download-and-open helper
  // (same pattern already used for document attachments elsewhere).
  Future<void> _previewFile({
    required int? uploadId,
    required String? localPath,
    required String? displayName,
    required ValueChanged<bool> setLoading,
  }) async {
    if (localPath != null) {
      final result = await OpenFilex.open(localPath);
      if (mounted && result.type != ResultType.done) {
        AppToast.showError('Could not open file: ${result.message}');
      }
      return;
    }
    if (uploadId == null) return;

    setLoading(true);
    final result = await AuthService.instance.fetchUploadMeta(uploadId);
    if (!mounted) return;
    setLoading(false);

    final signedUrl = result.isSuccess ? result.data?.signedUrl : null;
    if (signedUrl == null || signedUrl.isEmpty) {
      AppToast.showError(result.message ?? 'Preview unavailable');
      return;
    }
    await DocumentDownloadService.instance.downloadAndOpenDirect(
      context: context,
      url: signedUrl,
      displayFileName: displayName ?? 'file',
    );
  }

  Future<void> _save() async {
    final userId = widget.user.id;
    if (userId == 0) {
      AppToast.showError('Unable to determine user ID');
      return;
    }
    if (_signatureUploadId == null) {
      AppToast.showError('Signature is required');
      return;
    }

    setState(() => _saving = true);
    final parts = widget.user.name.split(' ');
    final payload = <String, dynamic>{
      'username': widget.user.employeeId,
      'email': widget.user.email ?? '',
      'role_id': widget.user.roleId ?? 0,
      'is_active': true,
      'company_id': widget.user.companyId,
      'first_name': parts.first,
      'last_name': parts.skip(1).join(' '),
      'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      'signature_upload_id': _signatureUploadId,
    };
    if (_isLeadTechnician) {
      payload['certificate_number'] =
          _certificateNumber.text.trim().isEmpty ? null : _certificateNumber.text.trim();
      payload['certificate_upload_id'] = _certificateUploadId;
    }
    final result = await AuthService.instance.updateProfile(
      userId: userId,
      payload: payload,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (result.isSuccess) {
      AppToast.showSuccess('Profile updated');
      widget.onReload();
    } else {
      AppToast.showError(result.message ?? 'Failed to update profile');
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 36),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 32,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.logout,
                    color: AppColors.danger,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Log Out',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Are you sure you want to log out?',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          side: BorderSide(color: AppColors.border, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.danger,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.logout, size: 16),
                        label: const Text(
                          AppStrings.logout,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (confirmed == true) widget.onLogout();
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    final parts = u.name.split(' ');
    final firstName = parts.first;
    final lastName = parts.skip(1).join(' ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Account Info (read-only) ────────────────────────────────
        _SectionCard(
          title: 'Account Info',
          icon: Icons.person_outline,
          children: [
            _InfoRow(label: 'Username', value: u.employeeId),
            _InfoRow(label: 'First Name', value: firstName),
            _InfoRow(
              label: 'Last Name',
              value: lastName.isEmpty ? '—' : lastName,
            ),
            _InfoRow(label: 'Email', value: u.email ?? '—'),
            _InfoRow(label: 'Company', value: u.resolvedCompanyName),
          ],
        ),
        const SizedBox(height: 14),

        // ── Editable Fields ─────────────────────────────────────────
        _SectionCard(
          title: 'Contact Details',
          icon: Icons.contacts_outlined,
          children: [
            _FieldLabel(label: 'Phone Number'),
            const SizedBox(height: 6),
            _InputField(
              controller: _phone,
              hint: 'Enter phone number',
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 14),
            _FieldLabel(label: 'Signature', required: true),
            const SizedBox(height: 6),
            _FileField(
              fileName: _signatureFileName,
              uploading: _signatureUploading,
              previewLoading: _signaturePreviewLoading,
              onPick: _pickSignature,
              onPreview: _previewSignature,
              onRemove: () => setState(() {
                _signatureUploadId = null;
                _signatureFileName = null;
                _signatureLocalPath = null;
              }),
            ),
            if (_isLeadTechnician) ...[
              const SizedBox(height: 14),
              _FieldLabel(label: 'Certificate Number'),
              const SizedBox(height: 6),
              _InputField(
                controller: _certificateNumber,
                hint: 'Enter certificate number',
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                ],
              ),
              const SizedBox(height: 14),
              _FieldLabel(label: 'Certificate Upload'),
              const SizedBox(height: 6),
              _FileField(
                fileName: _certificateFileName,
                uploading: _certificateUploading,
                previewLoading: _certificatePreviewLoading,
                onPick: _pickCertificate,
                onPreview: _previewCertificate,
                onRemove: () => setState(() {
                  _certificateUploadId = null;
                  _certificateFileName = null;
                  _certificateLocalPath = null;
                }),
              ),
            ],
          ],
        ),
        const SizedBox(height: 20),

        // ── Save button ─────────────────────────────────────────────
        SizedBox(
          height: 50,
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF4B633D),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_outlined, size: 18),
            label: const Text(
              'Save Changes',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // ── Logout ───────────────────────────────────────────────────
        _SectionCard(
          title: 'Session',
          icon: Icons.security_outlined,
          children: [
            OutlinedButton.icon(
              onPressed: _confirmLogout,
              icon: const Icon(Icons.logout, color: AppColors.danger, size: 18),
              label: const Text(
                AppStrings.logout,
                style: TextStyle(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
                side: const BorderSide(color: AppColors.danger),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Security Tab ─────────────────────────────────────────────────────────────

class _SecurityTab extends StatefulWidget {
  const _SecurityTab();

  @override
  State<_SecurityTab> createState() => _SecurityTabState();
}

class _SecurityTabState extends State<_SecurityTab> {
  final _current = TextEditingController();
  final _newPass = TextEditingController();
  final _confirm = TextEditingController();
  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;
  bool _saving = false;
  String? _error;
  bool _success = false;

  @override
  void dispose() {
    _current.dispose();
    _newPass.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool get _hasMinLen => _newPass.text.length >= 8;
  bool get _hasUpper => RegExp(r'[A-Z]').hasMatch(_newPass.text);
  bool get _hasLower => RegExp(r'[a-z]').hasMatch(_newPass.text);
  bool get _hasNumber => RegExp(r'\d').hasMatch(_newPass.text);
  bool get _hasSpecial => RegExp(r'[^A-Za-z0-9]').hasMatch(_newPass.text);
  bool get _passwordValid =>
      _hasMinLen && _hasUpper && _hasLower && _hasNumber && _hasSpecial;
  bool get _passwordsMatch =>
      _newPass.text.isNotEmpty && _newPass.text == _confirm.text;

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _success = false;
    });
    if (_current.text.isEmpty ||
        _newPass.text.isEmpty ||
        _confirm.text.isEmpty) {
      setState(() => _error = 'All fields are required.');
      return;
    }
    if (!_passwordsMatch) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    if (!_passwordValid) {
      setState(() => _error = 'Password does not meet requirements.');
      return;
    }
    setState(() => _saving = true);
    final result = await AuthService.instance.changePassword(
      currentPassword: _current.text,
      newPassword: _newPass.text,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (result.isSuccess) {
      setState(() => _success = true);
      _current.clear();
      _newPass.clear();
      _confirm.clear();
    } else {
      setState(() => _error = result.message ?? 'Failed to change password');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Change password card ─────────────────────────────────────
        _SectionCard(
          title: 'Change Password',
          icon: Icons.lock_outline,
          children: [
            _FieldLabel(label: 'Current Password'),
            const SizedBox(height: 6),
            _PasswordField(
              controller: _current,
              hint: 'Enter current password',
              show: _showCurrent,
              onToggle: () => setState(() => _showCurrent = !_showCurrent),
            ),
            const SizedBox(height: 14),
            _FieldLabel(label: 'New Password'),
            const SizedBox(height: 6),
            _PasswordField(
              controller: _newPass,
              hint: 'Enter new password',
              show: _showNew,
              onToggle: () => setState(() => _showNew = !_showNew),
              onChanged: (_) => setState(() => _error = null),
            ),
            const SizedBox(height: 10),
            // Strength checklist
            _StrengthBar(
              hasMinLen: _hasMinLen,
              hasUpper: _hasUpper,
              hasLower: _hasLower,
              hasNumber: _hasNumber,
              hasSpecial: _hasSpecial,
            ),
            const SizedBox(height: 14),
            _FieldLabel(label: 'Confirm New Password'),
            const SizedBox(height: 6),
            _PasswordField(
              controller: _confirm,
              hint: 'Confirm new password',
              show: _showConfirm,
              onToggle: () => setState(() => _showConfirm = !_showConfirm),
              onChanged: (_) => setState(() => _error = null),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              _StatusBanner(message: _error!, isError: true),
            ],
            if (_success) ...[
              const SizedBox(height: 10),
              _StatusBanner(
                message: 'Password updated successfully.',
                isError: false,
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),

        // ── Submit ───────────────────────────────────────────────────
        SizedBox(
          height: 50,
          child: FilledButton.icon(
            onPressed: _saving ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF4B633D),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.lock_reset_outlined, size: 18),
            label: const Text(
              'Change Password',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Version 1.0.0',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ─── Reusable card section ─────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppGradients.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF374151),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 15, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          // Card body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Info row (read-only) ─────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Field label ──────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label, this.required = false});

  final String label;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        if (required)
          const Text(
            ' *',
            style: TextStyle(color: AppColors.required, fontSize: 12),
          ),
      ],
    );
  }
}

// ─── Text input ───────────────────────────────────────────────────────────────

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    this.hint,
    this.keyboardType,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
      decoration: _inputDeco(hint),
    );
  }
}

// ─── Password input ───────────────────────────────────────────────────────────

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.hint,
    required this.show,
    required this.onToggle,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final bool show;
  final VoidCallback onToggle;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: !show,
      onChanged: onChanged,
      style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
      decoration: _inputDeco(hint).copyWith(
        suffixIcon: IconButton(
          icon: Icon(
            show ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: 18,
            color: AppColors.textSecondary,
          ),
          onPressed: onToggle,
        ),
      ),
    );
  }
}

InputDecoration _inputDeco(String? hint) => InputDecoration(
  hintText: hint,
  hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13),
  filled: true,
  fillColor: AppColors.inputFill,
  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: AppColors.border),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: AppColors.border),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: Color(0xFF374151), width: 1.5),
  ),
);

// ─── File picker field ────────────────────────────────────────────────────────

class _FileField extends StatelessWidget {
  const _FileField({
    required this.onPick,
    required this.onRemove,
    this.fileName,
    this.uploading = false,
    this.onPreview,
    this.previewLoading = false,
  });

  final String? fileName;
  final bool uploading;
  final bool previewLoading;
  final VoidCallback onPick;
  final VoidCallback onRemove;
  final VoidCallback? onPreview;

  @override
  Widget build(BuildContext context) {
    final canPreview = fileName != null && onPreview != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: uploading ? null : onPick,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF374151),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                uploading ? 'Uploading…' : 'Choose file',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: canPreview && !previewLoading ? onPreview : null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      fileName ?? 'No file chosen',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: canPreview
                            ? AppColors.primary
                            : fileName != null
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                        decoration: canPreview
                            ? TextDecoration.underline
                            : TextDecoration.none,
                      ),
                    ),
                  ),
                  if (previewLoading) ...[
                    const SizedBox(width: 8),
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (fileName != null)
            GestureDetector(
              onTap: onRemove,
              child: const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.close, size: 16, color: AppColors.danger),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Password strength bar ────────────────────────────────────────────────────

class _StrengthBar extends StatelessWidget {
  const _StrengthBar({
    required this.hasMinLen,
    required this.hasUpper,
    required this.hasLower,
    required this.hasNumber,
    required this.hasSpecial,
  });

  final bool hasMinLen, hasUpper, hasLower, hasNumber, hasSpecial;

  @override
  Widget build(BuildContext context) {
    final met = [
      hasMinLen,
      hasUpper,
      hasLower,
      hasNumber,
      hasSpecial,
    ].where((b) => b).length;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Password strength',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                ['', 'Weak', 'Fair', 'Good', 'Strong', 'Very Strong'][met],
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _strengthColor(met),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // 5-segment bar
          Row(
            children: List.generate(5, (i) {
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: i < 4 ? 3 : 0),
                  height: 4,
                  decoration: BoxDecoration(
                    color: i < met ? _strengthColor(met) : AppColors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _check(hasMinLen, '8+ chars'),
              _check(hasUpper, 'Uppercase'),
              _check(hasLower, 'Lowercase'),
              _check(hasNumber, 'Number'),
              _check(hasSpecial, 'Special'),
            ],
          ),
        ],
      ),
    );
  }

  Color _strengthColor(int met) {
    if (met <= 1) return AppColors.danger;
    if (met == 2) return AppColors.warning;
    if (met == 3) return const Color(0xFF22C55E);
    return AppColors.statusCompleted;
  }

  Widget _check(bool met, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          met ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 12,
          color: met ? AppColors.statusCompleted : AppColors.border,
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: met ? AppColors.textPrimary : AppColors.textSecondary,
            fontWeight: met ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

// ─── Status banner ────────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? AppColors.danger : AppColors.statusCompleted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: color,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
