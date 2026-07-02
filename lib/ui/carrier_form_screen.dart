import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:rapide_nforce/ui/widgets/gradient_page_background.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/core/utils/api_feedback.dart';
import 'package:rapide_nforce/core/utils/app_toast.dart';
import 'package:rapide_nforce/models/carrier_model.dart';
import 'package:rapide_nforce/services/carrier_service.dart';
import 'package:rapide_nforce/ui/widgets/web_form_field.dart';
import 'package:rapide_nforce/ui/widgets/web_ui.dart';

class CarrierFormScreen extends StatefulWidget {
  const CarrierFormScreen({super.key, this.carrierId});

  final int? carrierId;

  bool get isEdit => carrierId != null;

  @override
  State<CarrierFormScreen> createState() => _CarrierFormScreenState();
}

class _CarrierFormScreenState extends State<CarrierFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _legalName = TextEditingController();
  final _operatingName = TextEditingController();
  final _startDate = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _province = TextEditingController();
  final _postalCode = TextEditingController();
  final _website = TextEditingController();
  final _cvor = TextEditingController();
  final _nsc = TextEditingController();
  final _usdot = TextEditingController();
  final _mc = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _adminEmail = TextEditingController();
  final _directPhone = TextEditingController();

  List<PlanOption> _plans = [];
  List<BillingCycleOption> _billingCycles = [];
  int? _planId;
  int? _billingCycleId;
  bool _loadingMeta = true;
  bool _saving = false;
  String? _consentFileName;

  @override
  void initState() {
    super.initState();
    _loadMeta();
  }

  @override
  void dispose() {
    _legalName.dispose();
    _operatingName.dispose();
    _startDate.dispose();
    _email.dispose();
    _phone.dispose();
    _address.dispose();
    _city.dispose();
    _province.dispose();
    _postalCode.dispose();
    _website.dispose();
    _cvor.dispose();
    _nsc.dispose();
    _usdot.dispose();
    _mc.dispose();
    _firstName.dispose();
    _lastName.dispose();
    _adminEmail.dispose();
    _directPhone.dispose();
    super.dispose();
  }

  String _digitsOnly(String value) => value.replaceAll(RegExp(r'\D'), '');

  Future<void> _loadMeta() async {
    final plansResult = await CarrierService.instance.fetchPlans();
    final cyclesResult = await CarrierService.instance.fetchBillingCycles();

    if (widget.isEdit) {
      final carrierResult = await CarrierService.instance.fetchCarrierById(
        widget.carrierId!,
      );
      if (!mounted) return;
      if (carrierResult.isSuccess && carrierResult.data != null) {
        _populate(carrierResult.data!);
      }
    } else {
      _startDate.text = DateTime.now().toIso8601String().split('T').first;
    }

    if (!mounted) return;
    setState(() {
      _loadingMeta = false;
      _plans = plansResult.data ?? [];
      _billingCycles = cyclesResult.data ?? [];
      _planId ??= _plans.isNotEmpty ? _plans.first.id : 1;
      _billingCycleId ??= _billingCycles.isNotEmpty
          ? _billingCycles.first.id
          : 1;
    });
  }

  void _populate(CarrierModel carrier) {
    _legalName.text = carrier.name;
    _operatingName.text = carrier.dba ?? '';
    _startDate.text = carrier.startDate ?? '';
    _email.text = carrier.email ?? '';
    _phone.text = carrier.phone ?? '';
    _address.text = carrier.address ?? '';
    _city.text = carrier.city ?? '';
    _province.text = carrier.province ?? '';
    _postalCode.text = carrier.postalCode ?? '';
    _website.text = carrier.website ?? '';
    _cvor.text = carrier.cvorNumber ?? '';
    _nsc.text = carrier.nscNumber ?? '';
    _usdot.text = carrier.usdotNumber ?? '';
    _mc.text = carrier.mcNumber ?? '';
  }

  Future<void> _pickConsent() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
    );
    if (picked == null || picked.files.isEmpty) return;
    setState(() => _consentFileName = picked.files.first.name);
    _consentPath = picked.files.first.path;
  }

  String? _consentPath;

  Map<String, dynamic> _buildPayload() {
    final startDate = _startDate.text.trim().isNotEmpty
        ? _startDate.text.trim()
        : DateTime.now().toIso8601String();

    return {
      'name': _legalName.text.trim(),
      'dba': _operatingName.text.trim().isEmpty
          ? null
          : _operatingName.text.trim(),
      'email': _email.text.trim(),
      'phone': _digitsOnly(_phone.text),
      'start_date': startDate,
      'sendWelcomeEmail': true,
      'isActive': true,
      'companyDetails': {'start_date': startDate},
      'address': {
        'address': _address.text.trim(),
        'city': _city.text.trim(),
        'province': _province.text.trim(),
        'countryId': 1,
        'postalCode': _postalCode.text.trim(),
        'phoneNumber': _digitsOnly(_phone.text),
        'companyEmail': _email.text.trim(),
        if (_website.text.trim().isNotEmpty) 'website': _website.text.trim(),
      },
      'regulatoryProfile': {
        'cvorNumber': _cvor.text.trim(),
        'nscNumber': _nsc.text.trim(),
        'usdotNumber': _usdot.text.trim(),
        'mcNumber': _mc.text.trim(),
        'autoIntegrationEnabled': true,
      },
      'subscription': {
        'planId': _planId ?? 1,
        'billingCycleId': _billingCycleId ?? 1,
        'start_date': startDate,
        'status': 'active',
      },
      if (!widget.isEdit)
        'users': [
          {
            'username': _adminEmail.text.trim().isNotEmpty
                ? _adminEmail.text.trim()
                : '${_firstName.text.trim()} ${_lastName.text.trim()}'.trim(),
            'email': _adminEmail.text.trim(),
            'firstName': _firstName.text.trim(),
            'lastName': _lastName.text.trim(),
            if (_directPhone.text.trim().isNotEmpty)
              'directPhone': _digitsOnly(_directPhone.text),
            'roleId': 2,
            'isActive': true,
          },
        ],
    };
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_planId == null || _billingCycleId == null) {
      AppToast.showError('Select plan and billing cycle');
      return;
    }

    setState(() => _saving = true);
    final payload = _buildPayload();

    final result = widget.isEdit
        ? await CarrierService.instance.updateCarrier(
            widget.carrierId!,
            payload,
          )
        : await CarrierService.instance.createCarrier(payload);

    if (!mounted) return;

    if (!result.isSuccess) {
      setState(() => _saving = false);
      ApiFeedback.showError(result, fallback: 'Failed to save carrier');
      return;
    }

    final carrierId = result.data?.id ?? widget.carrierId;
    if (_consentPath != null && carrierId != null) {
      await CarrierService.instance.uploadConsent(
        companyId: carrierId,
        filePath: _consentPath!,
        fileName: _consentFileName ?? 'consent.pdf',
      );
    }

    if (!mounted) return;
    setState(() => _saving = false);
    AppToast.showSuccess(widget.isEdit ? 'Carrier updated' : 'Carrier created');
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return GradientPageBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          widget.isEdit ? 'Edit Carrier' : 'Add Carrier',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: _loadingMeta
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                children: [
                  WebFormSection(
                    title: 'Company Details',
                    children: [
                      WebTextFormField(
                        controller: _legalName,
                        label: 'Legal Name *',
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      WebTextFormField(
                        controller: _operatingName,
                        label: 'Operating Name (DBA)',
                      ),
                      WebTextFormField(
                        controller: _startDate,
                        label: 'Start Date',
                        hint: 'YYYY-MM-DD',
                      ),
                      WebTextFormField(
                        controller: _email,
                        label: 'Company Email *',
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      WebTextFormField(
                        controller: _phone,
                        label: 'Phone Number *',
                        keyboardType: TextInputType.phone,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      WebTextFormField(
                        controller: _address,
                        label: 'Street Address *',
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      WebTextFormField(
                        controller: _city,
                        label: 'City *',
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      WebTextFormField(
                        controller: _province,
                        label: 'Province *',
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      WebTextFormField(
                        controller: _postalCode,
                        label: 'Postal Code *',
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      WebTextFormField(controller: _website, label: 'Website'),
                    ],
                  ),
                  WebFormSection(
                    title: 'Regulatory',
                    children: [
                      WebTextFormField(controller: _cvor, label: 'CVOR #'),
                      WebTextFormField(controller: _nsc, label: 'NSC #'),
                      WebTextFormField(controller: _usdot, label: 'USDOT #'),
                      WebTextFormField(controller: _mc, label: 'MC #'),
                    ],
                  ),
                  if (!widget.isEdit)
                    WebFormSection(
                      title: 'Administrator',
                      children: [
                        WebTextFormField(
                          controller: _firstName,
                          label: 'First Name *',
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                        ),
                        WebTextFormField(
                          controller: _lastName,
                          label: 'Last Name *',
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                        ),
                        WebTextFormField(
                          controller: _adminEmail,
                          label: 'Admin Email *',
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                        ),
                        WebTextFormField(
                          controller: _directPhone,
                          label: 'Direct Phone',
                          keyboardType: TextInputType.phone,
                        ),
                      ],
                    ),
                  WebFormSection(
                    title: 'Subscription',
                    children: [
                      DropdownButtonFormField<int>(
                        initialValue: _planId,
                        dropdownColor: AppColors.card,
                        style: TextStyle(color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Plan',
                          filled: true,
                          fillColor: AppColors.inputFill,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: _plans
                            .map(
                              (p) => DropdownMenuItem(
                                value: p.id,
                                child: Text(p.name),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _planId = v),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        initialValue: _billingCycleId,
                        dropdownColor: AppColors.card,
                        style: TextStyle(color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Billing Cycle',
                          filled: true,
                          fillColor: AppColors.inputFill,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: _billingCycles
                            .map(
                              (b) => DropdownMenuItem(
                                value: b.id,
                                child: Text(b.name),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _billingCycleId = v),
                      ),
                    ],
                  ),
                  WebFormSection(
                    title: 'Carrier Consent',
                    children: [
                      OutlinedButton.icon(
                        onPressed: _pickConsent,
                        icon: const Icon(Icons.attach_file),
                        label: Text(
                          _consentFileName ?? 'Upload consent document',
                        ),
                      ),
                    ],
                  ),
                  WebPrimaryButton(
                    label: widget.isEdit ? 'Save Changes' : 'Create Carrier',
                    loading: _saving,
                    onPressed: _saving ? null : _save,
                  ),
                ],
              ),
            ),
      ),
    );
  }
}
