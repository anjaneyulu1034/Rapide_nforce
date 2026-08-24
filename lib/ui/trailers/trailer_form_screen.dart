import 'package:flutter/material.dart';
import 'package:rapide_nforce/ui/widgets/gradient_page_background.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/core/utils/api_feedback.dart';
import 'package:intl/intl.dart';
import 'package:rapide_nforce/core/utils/app_toast.dart';
import 'package:rapide_nforce/core/utils/role_utils.dart';
import 'package:rapide_nforce/models/maintenance_policy_model.dart';
import 'package:rapide_nforce/models/power_unit_model.dart';
import 'package:rapide_nforce/models/trailer_model.dart';
import 'package:rapide_nforce/models/truck_permit_model.dart';
import 'package:rapide_nforce/services/auth_service.dart';
import 'package:rapide_nforce/services/fleet_lookup_service.dart';
import 'package:rapide_nforce/services/ocr_service.dart';
import 'package:rapide_nforce/services/power_unit_service.dart';
import 'package:rapide_nforce/services/trailer_service.dart';
import 'package:rapide_nforce/ui/widgets/document_upload_section.dart';
import 'package:rapide_nforce/ui/widgets/ocr_document_upload_sheet.dart';
import 'package:rapide_nforce/ui/widgets/unsaved_changes_dialog.dart';
import 'package:rapide_nforce/ui/widgets/web_form_field.dart';
import 'package:rapide_nforce/ui/widgets/web_ui.dart';

const _kTrailerTypes = <String, String>{
  'dry-van': "Dry Van",
  'flatbed': 'Flatbed',
  'lowboy': 'Lowboy',
  'refrigerated': 'Refrigerated',
  'tanker': 'Tanker',
};

class TrailerFormScreen extends StatefulWidget {
  const TrailerFormScreen({super.key, this.trailerId});

  final int? trailerId;
  bool get isEdit => trailerId != null;

  @override
  State<TrailerFormScreen> createState() => _TrailerFormScreenState();
}

class _TrailerFormScreenState extends State<TrailerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  int _step = 1;
  bool _loading = true;
  bool _saving = false;
  bool _checkingVin = false;
  List<OcrDocumentEntry> _ocrDocuments = [];

  // Step 1 — Trailer Details / Technical Specs / Registration / Ownership
  final _unitNumber = TextEditingController();
  final _vin = TextEditingController();
  final _make = TextEditingController();
  final _model = TextEditingController();
  final _year = TextEditingController();
  final _color = TextEditingController();
  final _currentOdometer = TextEditingController();
  final _purchaseDate = TextEditingController();
  final _purchasePrice = TextEditingController();
  final _startDate = TextEditingController();
  String _status = 'active';
  String? _trailerType;
  int? _assignedTruckId;

  final _specType = TextEditingController();
  final _specLength = TextEditingController();
  final _specWidth = TextEditingController();
  final _specHeight = TextEditingController();
  final _specCapacity = TextEditingController();
  final _specGvwr = TextEditingController();

  final _plate = TextEditingController();
  final _registrationNumber = TextEditingController();
  int? _countryId;
  int? _stateId;
  int? _cityId;

  String _ownershipType = '';
  final _ownerName = TextEditingController();
  final _ownerEmail = TextEditingController();
  final _ownerPhone = TextEditingController();
  final _ownerAddress = TextEditingController();

  // Step 2 — Maintenance Policy & Schedule
  String? _selectedPolicy;
  final _cviExpiry = TextEditingController();
  final _pmDueDate = TextEditingController();
  final _pmDueOdometer = TextEditingController();

  // Step 3 — Annual Safety / CVIP
  final _certificateNumber = TextEditingController();
  final _inspectionDate = TextEditingController();
  final _expiryDate = TextEditingController();
  final _nextInspectionDue = TextEditingController();
  final _inspectorName = TextEditingController();
  final _inspectorLicense = TextEditingController();
  final _inspectionFacility = TextEditingController();
  final _facilityNumber = TextEditingController();
  final _criticalDefects = TextEditingController(text: '0');
  final _majorDefects = TextEditingController(text: '0');
  final _advisoryItems = TextEditingController(text: '0');
  final _inspectionSummary = TextEditingController();

  List<LookupOption> _countries = [];
  List<LookupOption> _states = [];
  List<LookupOption> _cities = [];
  List<MaintenancePolicyModel> _policies = [];
  List<PowerUnitModel> _trucks = [];

  bool get _isSuperAdmin =>
      isSuperAdminRole(AuthService.instance.currentUser?.role);

  // Guards against Form.onChanged firing while _bootstrap() populates
  // fields (edit mode load, lookups) — only field changes made after
  // bootstrap finishes count as "unsaved".
  bool _bootstrapped = false;
  bool _hasUnsavedChanges = false;

  void _onFormChanged() {
    if (!_bootstrapped || _hasUnsavedChanges) return;
    setState(() => _hasUnsavedChanges = true);
  }

  // All text controllers, listened to directly (rather than relying on
  // Form.onChanged propagation) so dirty-tracking doesn't depend on every
  // custom field widget correctly wiring itself into the ambient Form.
  List<TextEditingController> get _allControllers => [
    _unitNumber,
    _vin,
    _make,
    _model,
    _year,
    _color,
    _currentOdometer,
    _purchaseDate,
    _purchasePrice,
    _startDate,
    _specType,
    _specLength,
    _specWidth,
    _specHeight,
    _specCapacity,
    _specGvwr,
    _plate,
    _registrationNumber,
    _ownerName,
    _ownerEmail,
    _ownerPhone,
    _ownerAddress,
    _cviExpiry,
    _pmDueDate,
    _pmDueOdometer,
    _certificateNumber,
    _inspectionDate,
    _expiryDate,
    _nextInspectionDue,
    _inspectorName,
    _inspectorLicense,
    _inspectionFacility,
    _facilityNumber,
    _criticalDefects,
    _majorDefects,
    _advisoryItems,
    _inspectionSummary,
  ];

  @override
  void initState() {
    super.initState();
    _startDate.text = DateTime.now().toIso8601String().split('T').first;
    for (final c in _allControllers) {
      c.addListener(_onFormChanged);
    }
    _bootstrap();
  }

  bool _loadingStates = false;
  bool _loadingCities = false;

  Future<void> _bootstrap() async {
    final lookups = await Future.wait([
      FleetLookupService.instance.fetchCountries(),
      FleetLookupService.instance.fetchMaintenancePolicyConfigs(),
    ]);
    final trucks = await PowerUnitService.instance.fetchPowerUnits(limit: 500);

    if (widget.isEdit) {
      final trailer = await TrailerService.instance.fetchTrailerById(
        widget.trailerId!,
      );
      if (trailer.isSuccess && trailer.data != null) {
        _trailerForStateMatch = trailer.data;
        _populate(trailer.data!);
      }
    }
    if (!mounted) return;
    setState(() {
      _countries = lookups[0].data as List<LookupOption>? ?? [];
      _policies = lookups[1].data as List<MaintenancePolicyModel>? ?? [];
      _trucks = trucks.data?.items ?? [];
    });

    // Default country to Canada if not set (for new trailer)
    if (!widget.isEdit && _countryId == null && _countries.isNotEmpty) {
      final canada = _countries.where((c) => c.name.toLowerCase() == 'canada').firstOrNull;
      _countryId = canada?.id ?? _countries.first.id;
    }

    await _loadStates(_countryId);

    if (_stateId != null) {
      await _loadCities(_stateId!);
    }

    final trailer = _trailerForStateMatch;
    if (trailer != null &&
        _stateId == null &&
        trailer.state != null &&
        trailer.state!.isNotEmpty &&
        _states.isNotEmpty) {
      final match = _states.where(
        (s) => s.name.toLowerCase() == trailer.state!.toLowerCase(),
      );
      if (match.isNotEmpty) {
        setState(() => _stateId = match.first.id);
        await _loadCities(_stateId!);
      }
    }

    if (mounted) {
      setState(() {
        _loading = false;
        _bootstrapped = true;
      });
    }
  }

  TrailerModel? _trailerForStateMatch;

  String _toIsoDate(String? raw) {
    if (raw == null) return '';
    final text = raw.trim();
    if (text.isEmpty) return '';
    final parsedIso = DateTime.tryParse(text);
    if (parsedIso != null) return DateFormat('yyyy-MM-dd').format(parsedIso);
    final parts = text.split(RegExp(r'[-/]'));
    if (parts.length == 3) {
      final first = int.tryParse(parts[0]);
      final second = int.tryParse(parts[1]);
      final third = int.tryParse(parts[2]);
      if (first != null && second != null && third != null) {
        if (third > 1000) {
          return DateFormat('yyyy-MM-dd').format(DateTime(third, first, second));
        } else if (first > 1000) {
          return DateFormat('yyyy-MM-dd').format(DateTime(first, second, third));
        }
      }
    }
    return text;
  }

  void _populate(TrailerModel t) {
    _unitNumber.text = t.trailerNumber;
    _vin.text = t.vinNumber ?? '';
    _make.text = t.make ?? '';
    _model.text = t.model ?? '';
    _year.text = t.year?.toString() ?? '';
    _color.text = t.color ?? '';
    _currentOdometer.text = t.odometer?.toString() ?? '';
    _purchaseDate.text = _toIsoDate(t.purchaseDate);
    _purchasePrice.text = t.purchasePrice?.toString() ?? '';
    _startDate.text = _toIsoDate(t.startDate);
    _status = t.isActive ? 'active' : 'inactive';
    _trailerType = _kTrailerTypes.containsKey(t.type) ? t.type : null;
    _assignedTruckId = int.tryParse(t.assignedTruck ?? '');

    _specType.text = t.specType ?? '';
    _specLength.text = t.specLength ?? '';
    _specWidth.text = t.specWidth ?? '';
    _specHeight.text = t.specHeight ?? '';
    _specCapacity.text = t.specCapacity ?? '';
    _specGvwr.text = t.specGvwr ?? '';

    _plate.text = t.licensePlate ?? '';
    _registrationNumber.text = t.registrationNumber ?? '';
    _countryId = t.countryId;
    _stateId = null;
    _cityId = t.cityId;

    final ownershipType = (t.ownership ?? '').toLowerCase().trim();
    _ownershipType =
        ['owned', 'owner-operator'].contains(ownershipType) ? ownershipType : '';
    _ownerName.text = t.ownerName ?? '';
    _ownerEmail.text = t.ownerEmail ?? '';
    _ownerPhone.text = t.ownerPhone ?? '';
    _ownerAddress.text = t.ownerAddress ?? '';

    _selectedPolicy = t.maintenancePolicy;
    _cviExpiry.text = _toIsoDate(t.cviExpiry);
    _pmDueDate.text = _toIsoDate(t.pmDueDate);
    _pmDueOdometer.text = t.pmDueOdometer?.toString() ?? '';

    _certificateNumber.text = t.certificateNumber ?? '';
    _inspectionDate.text = _toIsoDate(t.inspectionDate);
    _expiryDate.text = _toIsoDate(t.expiryDate);
    _nextInspectionDue.text = _toIsoDate(t.nextInspectionDue);
    _inspectorName.text = t.inspectorName ?? '';
    _inspectorLicense.text = t.inspectorLicense ?? '';
    _inspectionFacility.text = t.inspectionFacility ?? '';
    _facilityNumber.text = t.facilityNumber ?? '';
    _criticalDefects.text = '${t.criticalDefects ?? 0}';
    _majorDefects.text = '${t.majorDefects ?? 0}';
    _advisoryItems.text = '${t.advisoryItems ?? 0}';
    _inspectionSummary.text = t.inspectionSummary ?? '';
  }

  Future<void> _loadStates(int? countryId) async {
    if (!mounted) return;
    setState(() => _loadingStates = true);
    final r = await FleetLookupService.instance.fetchStates(countryId: countryId);
    if (!mounted) return;
    setState(() {
      _states = r.data ?? [];
      _loadingStates = false;
    });
    if (!r.isSuccess && (r.message?.isNotEmpty ?? false)) {
      AppToast.showError('Failed to load states: ${r.message}');
    }
  }

  Future<void> _loadCities(int? stateId) async {
    if (stateId == null) {
      if (!mounted) return;
      setState(() {
        _cities = [];
        _loadingCities = false;
      });
      return;
    }
    if (!mounted) return;
    setState(() => _loadingCities = true);
    final r = await FleetLookupService.instance.fetchCities(stateId: stateId);
    if (!mounted) return;
    setState(() {
      _cities = r.data ?? [];
      _loadingCities = false;
    });
    if (!r.isSuccess && (r.message?.isNotEmpty ?? false)) {
      AppToast.showError('Failed to load cities: ${r.message}');
    }
  }

  @override
  void dispose() {
    for (final c in [
      _unitNumber,
      _vin,
      _make,
      _model,
      _year,
      _color,
      _currentOdometer,
      _purchaseDate,
      _purchasePrice,
      _startDate,
      _specType,
      _specLength,
      _specWidth,
      _specHeight,
      _specCapacity,
      _specGvwr,
      _plate,
      _registrationNumber,
      _ownerName,
      _ownerEmail,
      _ownerPhone,
      _ownerAddress,
      _cviExpiry,
      _pmDueDate,
      _pmDueOdometer,
      _certificateNumber,
      _inspectionDate,
      _expiryDate,
      _nextInspectionDue,
      _inspectorName,
      _inspectorLicense,
      _inspectionFacility,
      _facilityNumber,
      _criticalDefects,
      _majorDefects,
      _advisoryItems,
      _inspectionSummary,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _req(String? v, String field) =>
      (v == null || v.trim().isEmpty) ? '$field is required' : null;

  static final _alphanumericOnly = RegExp(r'^[A-Za-z0-9]*$');

  /// Mirrors the web app's VIN validation exactly: required, alphanumeric
  /// only, and exactly 17 characters.
  String? _vinValidator(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'VIN is required';
    if (!_alphanumericOnly.hasMatch(value)) {
      return 'VIN must contain only letters and numbers.';
    }
    if (value.length < 17) {
      final remaining = 17 - value.length;
      return 'VIN must be exactly 17 characters. $remaining more '
          'character${remaining == 1 ? '' : 's'} required.';
    }
    if (value.length > 17) {
      return 'VIN must be exactly 17 characters. Please remove extra characters.';
    }
    return null;
  }

  static final _emailFormat = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  static final _alphabeticOnly = RegExp(r'^[A-Za-z\s]+$');
  static final _hasLetter = RegExp(r'[A-Za-z]');

  /// Mirrors the web app's `AddTrailerPage.tsx` field rules.
  String? _nonNegativeNumberValidator(
    String? v,
    String field, {
    bool required = false,
  }) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return required ? '$field is required' : null;
    final n = double.tryParse(value);
    if (n == null || n < 0) return '$field must be a non-negative number';
    return null;
  }

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  void _applyMaintenancePolicyDefaults() {
    if (_selectedPolicy == null || _selectedPolicy!.isEmpty) return;
    final policy = _policies
        .where((p) => p.name == _selectedPolicy)
        .firstOrNull;
    if (policy == null) return;

    final allPanels = policy.allPanels;
    final activePanel = allPanels.firstWhere(
      (p) => p.type == (_selectedTypeKey ?? 'PM'),
      orElse: () => policy.pmPanel ?? const PolicySchedulePanel(type: 'PM', name: 'PM Schedule'),
    );

    // Anchor Date: prefer Inspection Date, then Start Date, then current date
    final anchorDate = DateTime.tryParse(_inspectionDate.text.trim()) ??
        DateTime.tryParse(_startDate.text.trim()) ??
        DateTime.now();

    final panelMonths = activePanel.months ?? 0;
    final panelDays = activePanel.days ?? (activePanel.months == null ? policy.pmIntervalDays : 0) ?? 0;
    final intervalKm = activePanel.km ?? policy.pmIntervalKm;
    final baseOdometer = int.tryParse(_currentOdometer.text.trim()) ?? 0;

    // Calculate due date: Anchor Date + months + days
    DateTime computedDueDate = anchorDate;
    if (panelMonths > 0) {
      computedDueDate = DateTime(
        computedDueDate.year,
        computedDueDate.month + panelMonths,
        computedDueDate.day,
      );
    }
    if (panelDays > 0) {
      computedDueDate = computedDueDate.add(Duration(days: panelDays));
    }

    setState(() {
      if (intervalKm != null && intervalKm > 0 && baseOdometer > 0) {
        _pmDueOdometer.text = (baseOdometer + intervalKm).toString();
      }
      if (panelMonths > 0 || panelDays > 0) {
        _pmDueDate.text = _isoDate(computedDueDate);
      }
      if (activePanel.nextDueDate != null && activePanel.nextDueDate!.isNotEmpty) {
        _pmDueDate.text = activePanel.nextDueDate!;
      }
      if (activePanel.nextDueOdometer != null) {
        _pmDueOdometer.text = activePanel.nextDueOdometer!.toString();
      }
    });
  }

  String? _ownerEmailValidator(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Owner Operator Email is required';
    if (!_emailFormat.hasMatch(value)) return 'Enter a valid email address';
    return null;
  }

  String? _ownerPhoneValidator(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Owner Operator Phone is required';
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10 || digits.length > 15) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  /// Letters and spaces only — matches web's `isValidInspectorName`, which
  /// (unlike the Power Unit form's version) does not allow digits.
  String? _inspectorNameValidator(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Inspector Name is required';
    if (!_alphabeticOnly.hasMatch(value) || !_hasLetter.hasMatch(value)) {
      return 'Inspector Name must contain only letters and spaces';
    }
    return null;
  }

  /// Matches web's `isValidAlphabeticText` used for Inspection Facility.
  String? _alphabeticTextValidator(String? v, String field) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return '$field is required';
    if (!_alphabeticOnly.hasMatch(value) || !_hasLetter.hasMatch(value)) {
      return '$field must contain only letters and spaces';
    }
    return null;
  }

  bool _validateStep(int step) {
    if (!_formKey.currentState!.validate()) return false;
    final missing = <String>[];

    if (step == 1) {
      if (_req(_unitNumber.text, 'Unit Number') != null) missing.add('Unit Number');
      if (_req(_vin.text, 'VIN') != null) missing.add('VIN');
      if (_req(_make.text, 'Make') != null) missing.add('Make');
      if (_req(_model.text, 'Model') != null) missing.add('Model');
      if (_req(_year.text, 'Year') != null) missing.add('Year');
      if (_req(_currentOdometer.text, 'Current Odometer') != null) missing.add('Current Odometer');
      final purchaseDateStr = _purchaseDate.text.trim();
      if (purchaseDateStr.isEmpty) {
        missing.add('Purchase Date');
      } else {
        final parsedPd = DateTime.tryParse(purchaseDateStr);
        if (parsedPd != null) {
          final today = DateTime.now();
          final pDay = DateTime(parsedPd.year, parsedPd.month, parsedPd.day);
          final tDay = DateTime(today.year, today.month, today.day);
          if (pDay.isAfter(tDay)) {
            missing.add('Purchase Date (cannot be in the future)');
          }
        }
      }
      if (_req(_purchasePrice.text, 'Purchase Price') != null) missing.add('Purchase Price');
      if (_req(_startDate.text, 'Start Date') != null) missing.add('Start Date');
      if (_req(_plate.text, 'Plate Number') != null) missing.add('Plate Number');
      if (_registrationNumber.text.trim().isNotEmpty &&
          _alphanumericOnly.hasMatch(_registrationNumber.text.trim()) == false) {
        missing.add('Registration Number (alphanumeric only)');
      }
      if (_nonNegativeNumberValidator(_specGvwr.text, 'GVWR', required: false) != null) missing.add('GVWR');
      if (_trailerType == null) missing.add('Trailer Type');
      if (_countryId == null) missing.add('Country');
      if (_stateId == null && _states.isNotEmpty) missing.add('State/Province');
      if (_ownershipType.isEmpty) missing.add('Ownership Type');
      if (_ownershipType == 'owner-operator') {
        if (_req(_ownerName.text, 'Owner Name') != null) missing.add('Owner Name');
        if (_req(_ownerEmail.text, 'Owner Email') != null) missing.add('Owner Email');
        if (_req(_ownerPhone.text, 'Owner Phone') != null) missing.add('Owner Phone');
      }
      if (missing.isNotEmpty) {
        AppToast.showError('Please fill required Step 1 field(s): ${missing.join(", ")}');
        return false;
      }
      final year = int.tryParse(_year.text.trim());
      if (year == null || year < 1900 || year > 2099) {
        AppToast.showError('Enter a valid year between 1900 and 2099');
        return false;
      }
    }

    if (step == 2) {
      if (_selectedPolicy == null || _selectedPolicy!.isEmpty) {
        AppToast.showError('Select a Maintenance Policy');
        return false;
      }
    }

    if (step == 3) {
      if (_req(_certificateNumber.text, 'Certificate Number') != null) missing.add('Certificate Number');
      if (_req(_inspectionDate.text, 'Inspection Date') != null) missing.add('Inspection Date');
      if (_req(_expiryDate.text, 'Expiry Date') != null) missing.add('Expiry Date');
      if (_req(_nextInspectionDue.text, 'Next Inspection Due') != null) missing.add('Next Inspection Due');
      if (_req(_inspectorName.text, 'Inspector Name') != null) missing.add('Inspector Name');
      if (_req(_inspectorLicense.text, 'Inspector License') != null) missing.add('Inspector License');
      if (_req(_inspectionFacility.text, 'Inspection Facility') != null) missing.add('Inspection Facility');
      if (_req(_facilityNumber.text, 'Facility Number') != null) missing.add('Facility Number');
      if (missing.isNotEmpty) {
        AppToast.showError('Please fill required Step 3 field(s): ${missing.join(", ")}');
        return false;
      }
    }
    return true;
  }

  Map<String, dynamic> _buildPayload() {
    final companyId = _isSuperAdmin
        ? AuthService.instance.selectedCompanyIdInt
        : AuthService.instance.currentUser?.companyId;
    int? toInt(String v) => int.tryParse(v.trim());
    final nextYearJan1 = DateTime(DateTime.now().year + 1, 1, 1)
        .toIso8601String()
        .split('T')
        .first;

    return {
      'trailerUnit': _unitNumber.text.trim(),
      'vehicleType': _trailerType,
      'vinNumber': _vin.text.trim(),
      'licensePlateNumber': _plate.text.trim(),
      'state':
          _states.where((s) => s.id == _stateId).map((s) => s.name).firstOrNull ??
              '',
      if (_countryId != null) 'countryId': _countryId,
      if (_cityId != null) 'cityId': _cityId,
      // Not surfaced in the web UI either — the backend still requires a
      // value, so we send the same placeholder the web app defaults to.
      'rin': 'DEFAULT-RIN',
      'nextYearDate': nextYearJan1,
      'assignedTruck': ?_assignedTruckId,
      'active': _status == 'inactive' ? 0 : 1,
      'alertFrequency': '1',
      'lastEdit': 'company',
      'make': _make.text.trim(),
      'model': _model.text.trim(),
      'year': toInt(_year.text),
      'color': _color.text.trim(),
      'purchaseDate': _purchaseDate.text.trim(),
      'purchasePrice': double.tryParse(_purchasePrice.text.trim()),
      'registrationNumber': _registrationNumber.text.trim(),
      'ownership': _ownershipType,
      'fuelType': 'Diesel',
      'odometer': toInt(_currentOdometer.text),
      if (_pmDueOdometer.text.trim().isNotEmpty)
        'pmDueOdometer': toInt(_pmDueOdometer.text),
      if (_ownershipType == 'owner-operator') ...{
        'ownerName': _ownerName.text.trim(),
        'ownerEmail': _ownerEmail.text.trim(),
        'ownerPhone': _ownerPhone.text.trim(),
        'ownerAddress': _ownerAddress.text.trim(),
      },
      'maintenancePolicy': _selectedPolicy ?? '',
      if (_cviExpiry.text.trim().isNotEmpty) 'cviExpiry': _cviExpiry.text.trim(),
      'startDate': _startDate.text.trim(),
      if (_pmDueDate.text.trim().isNotEmpty) 'pmDueDate': _pmDueDate.text.trim(),
      'specType': _specType.text.trim(),
      'specLength': _specLength.text.trim(),
      'specWidth': _specWidth.text.trim(),
      'specHeight': _specHeight.text.trim(),
      'specCapacity': _specCapacity.text.trim(),
      'specGvwr': _specGvwr.text.trim(),
      'certificateNumber': _certificateNumber.text.trim(),
      'inspectionDate': _inspectionDate.text.trim(),
      'expiryDate': _expiryDate.text.trim(),
      'nextInspectionDue': _nextInspectionDue.text.trim(),
      'inspectorName': _inspectorName.text.trim(),
      'inspectorLicense': _inspectorLicense.text.trim(),
      'inspectionFacility': _inspectionFacility.text.trim(),
      'facilityNumber': _facilityNumber.text.trim(),
      'criticalDefects': toInt(_criticalDefects.text) ?? 0,
      'majorDefects': toInt(_majorDefects.text) ?? 0,
      'advisoryItems': toInt(_advisoryItems.text) ?? 0,
      'inspectionSummary': _inspectionSummary.text.trim(),
      'companyId': ?companyId,
    };
  }

  Future<void> _save() async {
    if (!_validateStep(3)) return;
    if (_isSuperAdmin && AuthService.instance.selectedCompanyIdInt == null) {
      AppToast.showError('Select a company from the header first');
      return;
    }
    setState(() => _saving = true);
    final payload = _buildPayload();
    final result = widget.isEdit
        ? await TrailerService.instance.updateTrailer(
            widget.trailerId!,
            payload,
          )
        : await TrailerService.instance.createTrailer(
            payload,
            companyId: AuthService.instance.selectedCompanyId,
          );
    if (!mounted) return;

    if (!result.isSuccess) {
      setState(() => _saving = false);
      ApiFeedback.showError(result, fallback: 'Failed to save trailer');
      return;
    }

    // Add-mode only — matches the web app's `handleDocumentUpload`, which
    // skips re-attaching the committed documents when editing. Each row is
    // persisted as a real trailer document tagged with its picked type,
    // defaulting to a 1-year validity window the same way web does.
    if (!widget.isEdit && _ocrDocuments.isNotEmpty && result.data != null) {
      final today = DateTime.now();
      final issueDate = today.toIso8601String().split('T').first;
      final expiryDate = DateTime(today.year + 1, today.month, today.day)
          .toIso8601String()
          .split('T')
          .first;
      var anyFailed = false;
      for (final doc in _ocrDocuments) {
        if (doc.filePath == null) continue;
        final uploadResult = await TrailerService.instance.uploadDocumentFull(
          trailerId: result.data!.id,
          filePath: doc.filePath!,
          fileName: doc.fileName,
          vinNumber: _vin.text.trim(),
          documentType: doc.documentType,
          issueDate: issueDate,
          expiryDate: expiryDate,
          companyId: AuthService.instance.selectedCompanyId,
        );
        if (!uploadResult.isSuccess) anyFailed = true;
      }
      if (anyFailed && mounted) {
        AppToast.showError(
          'Trailer saved, but some documents failed to upload. '
          'Please try again from the trailer details page.',
        );
      }
    }

    if (!mounted) return;
    setState(() => _saving = false);
    AppToast.showSuccess(widget.isEdit ? 'Trailer updated' : 'Trailer created');
    Navigator.pop(context, true);
  }

  /// Opens the "Upload Documents" sheet (Document Type per row, like web),
  /// which handles its own file picking + OCR scanning; each successfully
  /// extracted document streams its fields into the form as it resolves.
  /// entityTypeId 2 = Trailer, scoping the Document Type list accordingly.
  Future<void> _openDocumentUploadSheet() async {
    final result = await showOcrDocumentUploadSheet(
      context: context,
      initialDocuments: _ocrDocuments,
      onPrefillExtracted: _applyOcrPrefill,
      entityTypeId: 2,
    );
    if (result == null || !mounted) return;
    setState(() => _ocrDocuments = result);
    _onFormChanged();
  }

  /// Fills blank controllers only — never clobbers what the user already
  /// typed, mirroring the web's `flat.x || prev.x` prefill merge.
  void _applyOcrPrefill(TruckOcrPrefill prefill) {
    void fill(TextEditingController ctrl, String? value) {
      if (ctrl.text.trim().isEmpty && value != null && value.isNotEmpty) {
        ctrl.text = value;
      }
    }

    void fillDate(TextEditingController ctrl, String? value) {
      if (ctrl.text.trim().isEmpty && value != null && value.isNotEmpty) {
        ctrl.text = OcrService.normalizeDate(value);
      }
    }

    setState(() {
      fill(_unitNumber, prefill['unitNumber']);
      fill(_vin, prefill['vin']);
      fill(_make, prefill['make']);
      fill(_model, prefill['model']);
      fill(_year, prefill['year']);
      fill(_color, prefill['color']);
      fill(_plate, prefill['plateNumber']);
      fill(_registrationNumber, prefill['registrationNumber']);
      fill(_specGvwr, prefill['specGvwr'] ?? prefill['gvwr']);
      fill(_specType, prefill['specType'] ?? prefill['vehicleType']);
      fillDate(_cviExpiry, prefill['registrationExpiry']);
      fillDate(_purchaseDate, prefill['purchaseDate']);
      fill(_currentOdometer, prefill['odometer']);
      fill(_certificateNumber, prefill['certificateNumber']);
      fillDate(_inspectionDate, prefill['inspectionDate']);
      fillDate(_expiryDate, prefill['expiryDate']);
      fillDate(_nextInspectionDue, prefill['nextInspectionDue']);
      fill(_inspectorName, prefill['inspectorName']);
      fill(_inspectorLicense, prefill['inspectorLicense']);
      fill(_inspectionFacility, prefill['inspectionFacility']);
      fill(_facilityNumber, prefill['facilityNumber']);
      fill(_ownerName, prefill['ownerName']);
      fill(_ownerEmail, prefill['ownerEmail']);
      fill(_ownerPhone, prefill['ownerPhone']);
      fill(_ownerAddress, prefill['ownerAddress']);
      fill(_criticalDefects, prefill['criticalDefects']);
      fill(_majorDefects, prefill['majorDefects']);
      fill(_advisoryItems, prefill['advisoryItems']);
      fill(_inspectionSummary, prefill['inspectionSummary']);
    });

    // Plate province → match against the already-loaded states list, same
    // pattern used for edit-mode state matching in _bootstrap().
    final province = prefill['plateProvince'];
    if (province != null && province.isNotEmpty && _stateId == null) {
      () async {
        if (_states.isEmpty) {
          await _loadStates(_countryId);
        }
        if (_states.isNotEmpty && mounted) {
          final match = _states.where(
            (s) => s.name.toLowerCase() == province.toLowerCase(),
          );
          if (match.isNotEmpty) {
            setState(() => _stateId = match.first.id);
            _loadCities(_stateId!);
          }
        }
      }();
    }
  }

  Future<void> _next() async {
    if (_step >= 3 || _checkingVin || _saving) return;
    if (!_validateStep(_step)) return;
    if (_step == 1) {
      setState(() => _checkingVin = true);
      final check = await TrailerService.instance.checkVinExists(
        vin: _vin.text.trim(),
        excludeTrailerId: widget.trailerId,
      );
      if (!mounted) return;
      setState(() => _checkingVin = false);
      if (check.isSuccess && check.data == true) {
        AppToast.showError('A trailer with this VIN already exists');
        return;
      }
    }
    if (_step < 3) {
      setState(() => _step = (_step + 1).clamp(1, 3));
    }
  }

  /// Leaves the screen, prompting for confirmation first if there are
  /// unsaved changes — mirrors web's `navigateWithUnsavedCheck`.
  Future<void> _attemptLeave() async {
    if (!_hasUnsavedChanges) {
      Navigator.pop(context);
      return;
    }
    final shouldLeave = await confirmDiscardUnsavedChanges(context);
    if (shouldLeave && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final currentStep = _step.clamp(1, 3);
    return PopScope(
      canPop: currentStep == 1 && !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (currentStep > 1) {
          setState(() => _step = currentStep - 1);
          return;
        }
        _attemptLeave();
      },
      child: GradientPageBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text(
              widget.isEdit ? 'Edit Trailer' : 'Add Trailer',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    _StepIndicator(
                      step: currentStep,
                      onStepTapped: (target) {
                        if (target <= currentStep || _validateStep(currentStep)) {
                          setState(() => _step = target);
                        }
                      },
                    ),
                    Expanded(
                      child: Form(
                        key: _formKey,
                        onChanged: _onFormChanged,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          children: [
                            if (currentStep == 1) ..._buildStep1(),
                            if (currentStep == 2) ..._buildStep2(),
                            if (currentStep == 3) ..._buildStep3(),
                          ],
                        ),
                      ),
                    ),
                    _BottomBar(
                      step: currentStep,
                      saving: _saving || _checkingVin,
                      onCancel: _attemptLeave,
                      onContinue: currentStep < 3 ? _next : null,
                      onSave: currentStep == 3 ? _save : null,
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  List<Widget> _buildStep1() => [
    DocumentUploadSection(
      documents: _ocrDocuments,
      onOpenSheet: _openDocumentUploadSheet,
      onRemove: (doc) => setState(
        () => _ocrDocuments = _ocrDocuments.where((d) => d != doc).toList(),
      ),
    ),
    const SizedBox(height: 12),
    WebFormSection(
      title: 'Trailer Details',
      initiallyExpanded: true,
      children: [
        WebTextFormField(
          controller: _unitNumber,
          label: 'Unit Number *',
          validator: (v) => _req(v, 'Unit Number'),
        ),
        WebTextFormField(
          controller: _vin,
          label: 'VIN *',
          validator: _vinValidator,
          autovalidateMode: AutovalidateMode.onUserInteraction,
        ),
        WebDropdownField<String>(
          label: 'Trailer Type *',
          value: _trailerType,
          items: (_kTrailerTypes.keys.toList()..sort(
            (a, b) => _kTrailerTypes[a]!.compareTo(_kTrailerTypes[b]!),
          )),
          itemLabel: (v) => _kTrailerTypes[v] ?? v,
          onChanged: (v) {
            setState(() => _trailerType = v);
            _onFormChanged();
          },
          validator: (v) => v == null ? 'Trailer Type is required' : null,
        ),
        WebTextFormField(
          controller: _make,
          label: 'Make *',
          validator: (v) => _req(v, 'Make'),
        ),
        WebTextFormField(
          controller: _model,
          label: 'Model *',
          validator: (v) => _req(v, 'Model'),
        ),
        WebTextFormField(
          controller: _year,
          label: 'Year *',
          keyboardType: TextInputType.number,
          validator: (v) {
            final required = _req(v, 'Year');
            if (required != null) return required;
            final year = int.tryParse((v ?? '').trim());
            if (year == null || year < 1900 || year > 2099) {
              return 'Enter a valid year between 1900 and 2099';
            }
            return null;
          },
        ),
        WebTextFormField(controller: _color, label: 'Color'),
        WebTextFormField(
          controller: _currentOdometer,
          label: 'Current Odometer (km) *',
          keyboardType: TextInputType.number,
          validator: (v) => _nonNegativeNumberValidator(
            v,
            'Current Odometer',
            required: true,
          ),
        ),
        WebDateField(
          controller: _purchaseDate,
          label: 'Purchase Date',
          required: true,
          lastDate: DateTime.now(),
          validator: (v) {
            final required = _req(v, 'Purchase Date');
            if (required != null) return required;
            final parsed = DateTime.tryParse(v ?? '');
            if (parsed != null && parsed.isAfter(DateTime.now())) {
              return 'Purchase Date cannot be in the future';
            }
            return null;
          },
        ),
        WebTextFormField(
          controller: _purchasePrice,
          label: 'Purchase Price *',
          keyboardType: TextInputType.number,
          validator: (v) =>
              _nonNegativeNumberValidator(v, 'Purchase Price', required: true),
        ),
        WebDateField(
          controller: _startDate,
          label: 'Start Date',
          required: true,
          validator: (v) => _req(v, 'Start Date'),
        ),
        WebDropdownField<String>(
          label: 'Status',
          value: _status,
          items: const ['active', 'inactive'],
          itemLabel: (v) => v == 'active' ? 'Active' : 'Inactive',
          onChanged: (v) {
            setState(() => _status = v ?? 'active');
            _onFormChanged();
          },
        ),
        WebSearchableDropdownField<int>(
          label: 'Assigned Truck',
          value: _assignedTruckId,
          items: _trucks.map((t) => t.id).toList(),
          itemLabel: (id) =>
              _trucks.firstWhere((t) => t.id == id).unitNumber,
          onChanged: (v) {
            setState(() => _assignedTruckId = v);
            _onFormChanged();
          },
          hint: 'Not assigned',
        ),
      ],
    ),
    WebFormSection(
      title: 'Technical Specifications',
      children: [
        WebTextFormField(controller: _specType, label: 'Type'),
        WebTextFormField(controller: _specLength, label: 'Length'),
        WebTextFormField(controller: _specWidth, label: 'Width'),
        WebTextFormField(controller: _specHeight, label: 'Height'),
        WebTextFormField(controller: _specCapacity, label: 'Capacity'),
        WebTextFormField(
          controller: _specGvwr,
          label: 'GVWR (Gross Vehicle Weight Rating)',
          keyboardType: TextInputType.number,
          validator: (v) => _nonNegativeNumberValidator(v, 'GVWR', required: false),
        ),
      ],
    ),
    WebFormSection(
      title: 'Registration & Plates',
      children: [
        WebTextFormField(
          controller: _plate,
          label: 'Plate Number *',
          validator: (v) => _req(v, 'Plate'),
        ),
        WebDropdownField<int>(
          label: 'Country *',
          value: _countryId,
          items: _countries.map((c) => c.id).toList(),
          itemLabel: (id) => _countries.firstWhere((c) => c.id == id).name,
          onChanged: (v) async {
            setState(() {
              _countryId = v;
              _stateId = null;
              _cityId = null;
              _states = [];
              _cities = [];
            });
            _onFormChanged();
            if (v != null) await _loadStates(v);
          },
          validator: (v) => v == null ? 'Country is required' : null,
        ),
        WebSearchableDropdownField<int>(
          label: 'State / Province *',
          value: _stateId,
          items: _states.map((s) => s.id).toList(),
          itemLabel: (id) => _states.firstWhere((s) => s.id == id).name,
          searchHint: 'Search state/province...',
          isLoading: _loadingStates,
          onTap: () {
            if (_countryId == null) {
              AppToast.showError('Please select country first');
            }
          },
          onChanged: (v) async {
            setState(() {
              _stateId = v;
              _cityId = null;
              _cities = [];
            });
            _onFormChanged();
            if (v != null) await _loadCities(v);
          },
          validator: (v) => (v == null && _states.isNotEmpty)
              ? 'State/Province is required'
              : null,
        ),
        WebSearchableDropdownField<int>(
          label: 'City',
          value: _cityId,
          items: _cities.map((c) => c.id).toList(),
          itemLabel: (id) => _cities.firstWhere((c) => c.id == id).name,
          searchHint: 'Search city...',
          isLoading: _loadingCities,
          onTap: () {
            if (_countryId == null) {
              AppToast.showError('Please select country first');
            } else if (_stateId == null) {
              AppToast.showError('Please select state / province first');
            }
          },
          onChanged: (v) {
            setState(() => _cityId = v);
            _onFormChanged();
          },
        ),
        WebTextFormField(
          controller: _registrationNumber,
          label: 'Registration Number',
        ),
      ],
    ),
    WebFormSection(
      title: 'Ownership',
      children: [
        WebDropdownField<String>(
          label: 'Ownership Type *',
          value: _ownershipType.isEmpty ? null : _ownershipType,
          items: const ['owned', 'owner-operator'],
          itemLabel: (v) => v == 'owned' ? 'Owned' : 'Owner Operator',
          onChanged: (v) {
            setState(() => _ownershipType = v ?? '');
            _onFormChanged();
          },
          validator: (v) => _req(v, 'Ownership Type'),
        ),
        if (_ownershipType == 'owner-operator') ...[
          WebFormSection(
            title: 'Owner Operator Details',
            initiallyExpanded: true,
            children: [
              WebTextFormField(
                controller: _ownerName,
                label: 'Owner Operator *',
                validator: (v) => _req(v, 'Owner Operator'),
              ),
              WebTextFormField(
                controller: _ownerEmail,
                label: 'Owner Operator Email *',
                validator: _ownerEmailValidator,
              ),
              WebTextFormField(
                controller: _ownerPhone,
                label: 'Owner Operator Phone *',
                validator: _ownerPhoneValidator,
              ),
              WebTextFormField(
                controller: _ownerAddress,
                label: 'Owner Operator Address',
              ),
            ],
          ),
        ],
      ],
    ),
  ];

  String? _selectedTypeKey = 'PM';

  List<Widget> _buildStep2() {
    final selectedPolicyObj = _policies
        .where((p) => p.name == _selectedPolicy)
        .firstOrNull;
    final activeSchedules =
        selectedPolicyObj?.schedules.where((s) => s.isActive).toList() ?? [];
    final allPanels = selectedPolicyObj?.allPanels ?? [];

    final activePanel = allPanels.firstWhere(
      (p) => p.type == (_selectedTypeKey ?? 'PM'),
      orElse: () => const PolicySchedulePanel(type: 'PM', name: 'PM Schedule'),
    );
    final activeName = activePanel.name.isNotEmpty
        ? activePanel.name
        : (activePanel.type == 'PM'
            ? 'PM Schedule'
            : activePanel.type == 'OIL'
                ? 'Oil Change'
                : activePanel.type);
    final isOil = activePanel.type.toUpperCase() == 'OIL' ||
        activeName.toLowerCase().contains('oil');
    final isReefer = activePanel.type.toUpperCase() == 'REEFER';

    final dueLabel = isOil
        ? 'Oil Due Date'
        : (isReefer ? 'Reefer Due Date' : 'PM Due Date');

    final odoLabel = isOil
        ? 'Oil Due Odometer (km)'
        : (isReefer ? 'Reefer Due Hours' : 'PM Due Odometer (km)');

    final unitLabel = isReefer ? 'hrs' : 'km';

    final progressHeader = isOil
        ? 'KM UNTIL OIL CHANGE'
        : (isReefer
            ? 'HOURS UNTIL REEFER SERVICE'
            : 'KM UNTIL PM');

    final currentOdometer = int.tryParse(_currentOdometer.text.trim()) ?? 0;
    final nextPmOdometer = int.tryParse(_pmDueOdometer.text.trim()) ?? 0;
    final pmIntervalKm = selectedPolicyObj?.pmIntervalKm ?? 10000;
    final remainingKm = (nextPmOdometer - currentOdometer)
        .clamp(0, pmIntervalKm > 0 ? pmIntervalKm * 2 : 100000);
    final progressRatio = pmIntervalKm > 0
        ? (remainingKm / pmIntervalKm).clamp(0.0, 1.0)
        : 0.0;

    return [
      WebFormSection(
        title: 'Maintenance Policy & Schedule',
        initiallyExpanded: true,
        children: [
          Text(
            'Select a maintenance policy and track intervals.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          WebDropdownField<String>(
            label: 'Maintenance Policy *',
            value: _selectedPolicy,
            items: _policies.map((p) => p.name).toList(),
            itemLabel: (v) => v,
            onChanged: (v) {
              setState(() {
                _selectedPolicy = v;
                _selectedTypeKey = 'PM';
              });
              _applyMaintenancePolicyDefaults();
              _onFormChanged();
            },
            validator: (v) => _req(v, 'Maintenance Policy'),
          ),
          Text(
            'Uses the default maintenance policy configured in Settings',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          if (activeSchedules.isNotEmpty) ...[
            const Text(
              'Schedules in this Policy',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.inputFill,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.event_note, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    activeSchedules.first.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'ACTIVE',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${allPanels.length} types configured',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (allPanels.isNotEmpty) ...[
            Text(
              'Select maintenance type to view and configure its interval',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: allPanels.map((panel) {
                  final isSelected = (_selectedTypeKey ?? 'PM') == panel.type;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      selected: isSelected,
                      selectedColor: AppColors.primary.withValues(alpha: 0.2),
                      backgroundColor: AppColors.inputFill,
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            panel.name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight:
                                  isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.check_circle,
                            size: 14,
                            color: isSelected ? AppColors.primary : Colors.green,
                          ),
                        ],
                      ),
                      onSelected: (_) {
                        setState(() => _selectedTypeKey = panel.type);
                        _applyMaintenancePolicyDefaults();
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),
          ],
          WebDateField(controller: _cviExpiry, label: 'CVI Expiry'),
          WebDateField(controller: _pmDueDate, label: dueLabel),
          WebTextFormField(
            controller: _pmDueOdometer,
            label: odoLabel,
            keyboardType: TextInputType.number,
            validator: (v) => _nonNegativeNumberValidator(v, odoLabel),
          ),
          if (pmIntervalKm > 0 && nextPmOdometer > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.inputFill,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        progressHeader,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          '$remainingKm $unitLabel',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progressRatio,
                      minHeight: 8,
                      backgroundColor: AppColors.border,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        remainingKm <= 500
                            ? AppColors.danger
                            : (remainingKm <= 2000
                                ? AppColors.warning
                                : AppColors.primary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    ];
  }

  List<Widget> _buildStep3() => [
    WebFormSection(
      title: 'Annual Safety / CVIP',
      initiallyExpanded: true,
      children: [
        WebTextFormField(
          controller: _certificateNumber,
          label: 'Certificate Number *',
          validator: (v) => _req(v, 'Certificate Number'),
        ),
        WebDateField(
          controller: _inspectionDate,
          label: 'Inspection Date',
          required: true,
          validator: (v) => _req(v, 'Inspection Date'),
        ),
        WebDateField(
          controller: _expiryDate,
          label: 'Expiry Date',
          required: true,
          validator: (v) => _req(v, 'Expiry Date'),
        ),
        WebDateField(
          controller: _nextInspectionDue,
          label: 'Next Inspection Due',
          required: true,
          validator: (v) => _req(v, 'Next Inspection Due'),
        ),
        WebTextFormField(
          controller: _inspectorName,
          label: 'Inspector Name *',
          validator: _inspectorNameValidator,
        ),
        WebTextFormField(
          controller: _inspectorLicense,
          label: 'Inspector License *',
          validator: (v) => _req(v, 'Inspector License'),
        ),
        WebTextFormField(
          controller: _inspectionFacility,
          label: 'Inspection Facility *',
          validator: (v) => _alphabeticTextValidator(v, 'Inspection Facility'),
        ),
        WebTextFormField(
          controller: _facilityNumber,
          label: 'Facility Number *',
          validator: (v) => _req(v, 'Facility Number'),
        ),
        WebTextFormField(
          controller: _criticalDefects,
          label: 'Critical Defects',
          keyboardType: TextInputType.number,
        ),
        WebTextFormField(
          controller: _majorDefects,
          label: 'Major Defects',
          keyboardType: TextInputType.number,
        ),
        WebTextFormField(
          controller: _advisoryItems,
          label: 'Advisory Items',
          keyboardType: TextInputType.number,
        ),
        WebTextFormField(
          controller: _inspectionSummary,
          label: 'Inspection Summary',
          maxLines: 4,
        ),
      ],
    ),
  ];
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.step, this.onStepTapped});
  final int step;
  final ValueChanged<int>? onStepTapped;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          for (int i = 0; i < 3; i++) ...[
            _StepNode(
              number: i + 1,
              currentStep: step,
              onTap: onStepTapped != null ? () => onStepTapped!(i + 1) : null,
            ),
            if (i < 2)
              Expanded(
                child: Container(
                  height: 2,
                  color: (i + 1) < step ? AppColors.primary : AppColors.border,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _StepNode extends StatelessWidget {
  const _StepNode({
    required this.number,
    required this.currentStep,
    this.onTap,
  });
  final int number;
  final int currentStep;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final done = number < currentStep;
    final active = number == currentStep;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: CircleAvatar(
        radius: 14,
        backgroundColor: done || active ? AppColors.primary : AppColors.surfaceTertiary,
        child: Text(
          done ? '✓' : '$number',
          style: TextStyle(
            color: done || active ? AppColors.white : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.step,
    required this.saving,
    required this.onCancel,
    this.onContinue,
    this.onSave,
  });

  final int step;
  final bool saving;
  final VoidCallback onCancel;
  final VoidCallback? onContinue;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.card,
      child: SafeArea(
        top: false,
        bottom: true,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: BoxDecoration(
            color: AppColors.card,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              TextButton(
                onPressed: saving ? null : onCancel,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                child: const Text('Cancel'),
              ),
              const Spacer(),
              onContinue != null
                  ? WebPrimaryButton(
                      label: 'Continue',
                      loading: saving,
                      onPressed: saving ? null : onContinue,
                      expand: false,
                      dense: true,
                    )
                  : WebPrimaryButton(
                      label: 'Save Trailer',
                      loading: saving,
                      onPressed: saving ? null : onSave,
                      expand: false,
                      dense: true,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
