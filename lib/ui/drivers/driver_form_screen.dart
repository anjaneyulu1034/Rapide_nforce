import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/core/utils/api_feedback.dart';
import 'package:rapide_nforce/core/utils/app_toast.dart';
import 'package:rapide_nforce/models/driver_model.dart';
import 'package:rapide_nforce/services/auth_service.dart';
import 'package:rapide_nforce/services/driver_service.dart';
import 'package:rapide_nforce/ui/widgets/gradient_page_background.dart';
import 'package:rapide_nforce/ui/widgets/web_form_field.dart';

class DriverFormScreen extends StatefulWidget {
  const DriverFormScreen({super.key, this.driverId});

  final int? driverId;
  bool get isEdit => driverId != null;

  @override
  State<DriverFormScreen> createState() => _DriverFormScreenState();
}

class _DriverFormScreenState extends State<DriverFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _saving = false;

  // Controllers
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _mobile = TextEditingController();
  final _altEmail = TextEditingController();
  final _phoneCan = TextEditingController();
  final _phoneUsa = TextEditingController();
  final _driverId = TextEditingController();
  
  final _driverType = TextEditingController(text: 'Company');
  final _licenseNumber = TextEditingController();
  final _licenseClass = TextEditingController();
  final _licenseExpiry = TextEditingController();
  final _licenseProvince = TextEditingController();
  final _medicalDue = TextEditingController();
  final _fastCard = TextEditingController();
  final _fastCardExpiry = TextEditingController();
  final _passport = TextEditingController();
  final _passportExpiry = TextEditingController();
  final _workPermit = TextEditingController();
  final _workPermitExpiry = TextEditingController();

  final _street = TextEditingController();
  final _city = TextEditingController();
  final _province = TextEditingController();
  final _postal = TextEditingController();
  final _sin = TextEditingController();
  final _dob = TextEditingController();

  final _contactName = TextEditingController();
  final _contactRelationship = TextEditingController();
  final _contactPhone = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.isEdit) {
      _load();
    }
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _mobile.dispose();
    _altEmail.dispose();
    _phoneCan.dispose();
    _phoneUsa.dispose();
    _driverId.dispose();
    _driverType.dispose();
    _licenseNumber.dispose();
    _licenseClass.dispose();
    _licenseExpiry.dispose();
    _licenseProvince.dispose();
    _medicalDue.dispose();
    _fastCard.dispose();
    _fastCardExpiry.dispose();
    _passport.dispose();
    _passportExpiry.dispose();
    _workPermit.dispose();
    _workPermitExpiry.dispose();
    _street.dispose();
    _city.dispose();
    _province.dispose();
    _postal.dispose();
    _sin.dispose();
    _dob.dispose();
    _contactName.dispose();
    _contactRelationship.dispose();
    _contactPhone.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await DriverService.instance.fetchDriverById(widget.driverId!);
    if (!mounted) return;
    setState(() => _loading = false);

    if (result.isSuccess && result.data != null) {
      _populate(result.data!);
    } else {
      ApiFeedback.showError(result, fallback: 'Failed to load driver details');
    }
  }

  void _populate(DriverModel d) {
    _firstName.text = d.driverName ?? '';
    _lastName.text = d.driverLastname ?? '';
    _email.text = d.email ?? '';
    _mobile.text = d.mobile ?? '';
    _altEmail.text = d.alternativeemail ?? '';
    _phoneCan.text = d.phoneCan ?? '';
    _phoneUsa.text = d.phoneUsa ?? '';
    _driverId.text = d.driverId ?? '';
    _driverType.text = d.driverType ?? 'Company';
    _licenseNumber.text = d.driverLicense ?? '';
    _licenseClass.text = d.licenseClass ?? '';
    _licenseExpiry.text = d.licenseExpiry ?? '';
    _licenseProvince.text = d.province ?? '';
    _medicalDue.text = d.medicalDueDate ?? '';
    _fastCard.text = d.fastCardNumber ?? '';
    _fastCardExpiry.text = d.fastCartExpiry ?? '';
    _passport.text = d.passport ?? '';
    _passportExpiry.text = d.passportExpiry ?? '';
    _workPermit.text = d.workPermit ?? '';
    _workPermitExpiry.text = d.workPermitExpiry ?? '';
    _street.text = d.streetAddress ?? d.address ?? '';
    _city.text = d.city ?? '';
    _province.text = d.driverProvince ?? d.province ?? '';
    _postal.text = d.postalCode ?? '';
    _sin.text = d.sin ?? '';
    if (d.raw?['driverdetails'] is List && (d.raw?['driverdetails'] as List).isNotEmpty) {
      final detail = (d.raw?['driverdetails'] as List).first as Map;
      _dob.text = detail['dob']?.toString().split('T').first ?? '';
      _contactName.text = detail['emergencyname']?.toString() ?? '';
      _contactRelationship.text = detail['relationship']?.toString() ?? '';
    }
    _contactPhone.text = d.alternativeemail ?? d.phoneCan ?? '';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final companyId = AuthService.instance.selectedCompanyIdInt;
    if (companyId == null) {
      AppToast.showError('Select a company from the header first');
      return;
    }

    final payload = {
      'driver_name': _firstName.text.trim(),
      'driver_lastname': _lastName.text.trim(),
      'email': _email.text.trim(),
      'mobile': _mobile.text.trim(),
      'alternativeemail': _altEmail.text.trim(),
      'phone_can': _phoneCan.text.trim(),
      'phone_usa': _phoneUsa.text.trim(),
      'driver_id': _driverId.text.trim(),
      'driver_type': _driverType.text.trim(),
      'driver_license': _licenseNumber.text.trim(),
      'license_class': _licenseClass.text.trim(),
      'province': _licenseProvince.text.trim(),
      'license_expiry': _licenseExpiry.text.trim().isEmpty ? null : _licenseExpiry.text.trim(),
      'medical_due_date': _medicalDue.text.trim().isEmpty ? null : _medicalDue.text.trim(),
      'fast_card_number': _fastCard.text.trim(),
      'fast_cart_expiry': _fastCardExpiry.text.trim().isEmpty ? null : _fastCardExpiry.text.trim(),
      'passport': _passport.text.trim(),
      'passport_expiry': _passportExpiry.text.trim().isEmpty ? null : _passportExpiry.text.trim(),
      'work_permit': _workPermit.text.trim(),
      'work_permit_expiry': _workPermitExpiry.text.trim().isEmpty ? null : _workPermitExpiry.text.trim(),
      'street_address': _street.text.trim(),
      'city': _city.text.trim(),
      'driver_province': _province.text.trim(),
      'postal_code': _postal.text.trim(),
      'sin': _sin.text.trim(),
      'company_id': companyId,
      'emergencyname': _contactName.text.trim(),
      'relationship': _contactRelationship.text.trim(),
      'dob': _dob.text.trim().isEmpty ? null : _dob.text.trim(),
    };

    setState(() => _saving = true);
    final result = widget.isEdit
        ? await DriverService.instance.updateDriver(widget.driverId!, payload)
        : await DriverService.instance.createDriver(payload);

    setState(() => _saving = false);
    if (!mounted) return;

    if (result.isSuccess) {
      AppToast.showSuccess(widget.isEdit ? 'Driver updated' : 'Driver created');
      Navigator.pop(context, true);
    } else {
      ApiFeedback.showError(result, fallback: 'Save failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientPageBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            widget.isEdit ? 'Edit Driver' : 'Add Driver',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    WebFormSection(
                      title: 'Driver Information',
                      initiallyExpanded: true,
                      children: [
                        WebTextFormField(
                          controller: _firstName,
                          label: 'First Name *',
                          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                        ),
                        WebTextFormField(
                          controller: _lastName,
                          label: 'Last Name *',
                          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                        ),
                        WebTextFormField(
                          controller: _email,
                          label: 'Email Address *',
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                        ),
                        WebTextFormField(
                          controller: _mobile,
                          label: 'Mobile Phone *',
                          keyboardType: TextInputType.phone,
                          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                        ),
                        WebTextFormField(
                          controller: _driverId,
                          label: 'Driver ID',
                        ),
                        WebDropdownField<String>(
                          label: 'Driver Type',
                          value: _driverType.text,
                          items: const ['Company', 'Owner Operator', 'Contractor'],
                          itemLabel: (v) => v,
                          onChanged: (v) => setState(() => _driverType.text = v ?? 'Company'),
                        ),
                      ],
                    ),
                    WebFormSection(
                      title: 'License & Expirations',
                      children: [
                        WebTextFormField(
                          controller: _licenseNumber,
                          label: 'License Number',
                        ),
                        WebTextFormField(
                          controller: _licenseClass,
                          label: 'License Class',
                        ),
                        WebTextFormField(
                          controller: _licenseProvince,
                          label: 'License Province',
                        ),
                        WebDateField(
                          controller: _licenseExpiry,
                          label: 'License Expiry Date',
                        ),
                        WebDateField(
                          controller: _medicalDue,
                          label: 'Medical Expiry Date',
                        ),
                        WebTextFormField(
                          controller: _fastCard,
                          label: 'FAST Card Number',
                        ),
                        WebDateField(
                          controller: _fastCardExpiry,
                          label: 'FAST Card Expiry',
                        ),
                      ],
                    ),
                    WebFormSection(
                      title: 'Personal & Emergency Contact',
                      children: [
                        WebTextFormField(
                          controller: _street,
                          label: 'Street Address',
                        ),
                        WebTextFormField(
                          controller: _city,
                          label: 'City',
                        ),
                        WebTextFormField(
                          controller: _province,
                          label: 'Province',
                        ),
                        WebTextFormField(
                          controller: _postal,
                          label: 'Postal Code',
                        ),
                        WebDateField(
                          controller: _dob,
                          label: 'Date of Birth',
                        ),
                        WebTextFormField(
                          controller: _sin,
                          label: 'Social Insurance Number (SIN)',
                        ),
                        WebTextFormField(
                          controller: _contactName,
                          label: 'Emergency Contact Name',
                        ),
                        WebTextFormField(
                          controller: _contactRelationship,
                          label: 'Relationship',
                        ),
                        WebTextFormField(
                          controller: _contactPhone,
                          label: 'Emergency Phone',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textSecondary,
                              side: BorderSide(color: AppColors.border),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: _saving ? null : () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _saving ? null : _save,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
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
                                : const Icon(Icons.check_rounded, size: 18),
                            label: Text(
                              widget.isEdit ? 'Update' : 'Create',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
