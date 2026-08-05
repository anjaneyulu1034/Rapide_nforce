import 'package:flutter/material.dart';
import 'package:rapide_nforce/ui/widgets/gradient_page_background.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/core/utils/api_feedback.dart';
import 'package:intl/intl.dart';
import 'package:rapide_nforce/core/utils/app_toast.dart';
import 'package:rapide_nforce/core/utils/date_format.dart';
import 'package:rapide_nforce/core/utils/role_utils.dart';
import 'package:rapide_nforce/models/maintenance_policy_model.dart';
import 'package:rapide_nforce/models/power_unit_model.dart';
import 'package:rapide_nforce/models/truck_permit_model.dart';
import 'package:rapide_nforce/services/auth_service.dart';
import 'package:rapide_nforce/services/fleet_lookup_service.dart';
import 'package:rapide_nforce/services/maintenance_service.dart';
import 'package:rapide_nforce/services/ocr_service.dart';
import 'package:rapide_nforce/services/power_unit_service.dart';
import 'package:rapide_nforce/ui/widgets/document_upload_section.dart';
import 'package:rapide_nforce/ui/widgets/ocr_document_upload_sheet.dart';
import 'package:rapide_nforce/ui/widgets/unsaved_changes_dialog.dart';
import 'package:rapide_nforce/ui/widgets/web_form_field.dart';
import 'package:rapide_nforce/ui/widgets/web_ui.dart';

class PowerUnitFormScreen extends StatefulWidget {
  const PowerUnitFormScreen({super.key, this.powerUnitId});

  final int? powerUnitId;
  bool get isEdit => powerUnitId != null;

  @override
  State<PowerUnitFormScreen> createState() => _PowerUnitFormScreenState();
}

class _PowerUnitFormScreenState extends State<PowerUnitFormScreen> {
  final _formKey = GlobalKey<FormState>();
  int _step = 1;
  bool _loading = true;
  bool _saving = false;
  bool _checkingVin = false;
  bool _refreshingOdometer = false;
  List<OcrDocumentEntry> _ocrDocuments = [];

  // Step 1
  final _unitNumber = TextEditingController();
  final _vin = TextEditingController();
  final _make = TextEditingController();
  final _model = TextEditingController();
  final _year = TextEditingController();
  final _color = TextEditingController();
  final _purchaseDate = TextEditingController();
  final _purchasePrice = TextEditingController();
  final _startDate = TextEditingController();
  final _plate = TextEditingController();
  final _registrationNumber = TextEditingController();
  final _registrationExpiry = TextEditingController();
  final _imsNumber = TextEditingController();
  final _gvwr = TextEditingController();
  final _transmission = TextEditingController();
  final _engineMake = TextEditingController();
  final _engineModel = TextEditingController();
  final _ownerName = TextEditingController();
  final _ownerEmail = TextEditingController();
  final _ownerPhone = TextEditingController();
  final _ownerAddress = TextEditingController();
  String _status = 'active';
  final _assignedDriver = TextEditingController();
  String? _fuelType;
  int? _countryId;
  int? _stateId;
  int? _cityId;
  String _ownershipType = '';
  // Odometer captured when an existing unit was loaded — current odometer
  // can't be edited to a value below this (mirrors web's Initial Odometer
  // sanity check).
  int? _initialOdometer;

  // Step 2
  final _maintenancePolicy = TextEditingController();
  final _cviExpiry = TextEditingController();
  final _currentOdometer = TextEditingController();
  final _annualInspectionDue = TextEditingController();
  final _lastInspection = TextEditingController();
  final _pmInterval = TextEditingController();
  final _nextPmDue = TextEditingController();
  final _nextPmOdometer = TextEditingController();
  final _telematicsProvider = TextEditingController();
  final _eldProvider = TextEditingController();
  String _telematicsEnabled = 'active';
  String? _selectedPolicy;
  final List<TruckPermitModel> _permits = [];
  String? _selectedPermitType;
  final _permitNumber = TextEditingController();
  final _permitIssue = TextEditingController();
  final _permitExpiry = TextEditingController();
  final _customPermitType = TextEditingController();
  static const _kOtherPermitType = '__OTHER__';

  // Step 3
  final _certificateNumber = TextEditingController();
  final _inspectionDate = TextEditingController();
  final _expiryDate = TextEditingController();
  final _nextInspectionDue = TextEditingController();
  final _inspectorName = TextEditingController();
  final _inspectorLicense = TextEditingController();
  final _inspectionFacility = TextEditingController();
  final _facilityNumber = TextEditingController();
  final _safetyPlate = TextEditingController();
  final _safetyVehicle = TextEditingController();
  final _safetyVehicleType = TextEditingController();
  final _criticalDefects = TextEditingController(text: '0');
  final _majorDefects = TextEditingController(text: '0');
  final _advisoryItems = TextEditingController(text: '0');
  final _inspectionSummary = TextEditingController();

  List<LookupOption> _countries = [];
  List<LookupOption> _states = [];
  List<LookupOption> _cities = [];
  List<LookupOption> _fuelTypes = [];
  List<String> get _fuelTypeOptions {
    const staticDefaults = ['CNG', 'Diesel', 'Petrol'];
    final dynamicNames = _fuelTypes.map((f) => f.name).toList();
    final combined = <String>[];
    final seen = <String>{};

    for (final name in [...staticDefaults, ...dynamicNames]) {
      final trimmed = name.trim();
      final lower = trimmed.toLowerCase();
      if (trimmed.isNotEmpty && !seen.contains(lower)) {
        seen.add(lower);
        combined.add(trimmed);
      }
    }
    if (_fuelType != null && _fuelType!.trim().isNotEmpty) {
      final valTrimmed = _fuelType!.trim();
      final valLower = valTrimmed.toLowerCase();
      if (!seen.contains(valLower)) {
        combined.add(valTrimmed);
      }
    }
    return combined;
  }
  List<LookupOption> _policies = [];
  List<MaintenancePolicyModel> _policyConfigs = [];
  List<LookupOption> _permitTypes = [];

  bool get _isSuperAdmin =>
      isSuperAdminRole(AuthService.instance.currentUser?.role);

  // Guards against Form.onChanged firing while _bootstrap() populates
  // fields (edit mode load, lookups, CVIP recalculation) — only field
  // changes made after bootstrap finishes count as "unsaved".
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
    _purchaseDate,
    _purchasePrice,
    _startDate,
    _plate,
    _registrationNumber,
    _registrationExpiry,
    _imsNumber,
    _gvwr,
    _transmission,
    _engineMake,
    _engineModel,
    _ownerName,
    _ownerEmail,
    _ownerPhone,
    _ownerAddress,
    _assignedDriver,
    _maintenancePolicy,
    _cviExpiry,
    _currentOdometer,
    _annualInspectionDue,
    _lastInspection,
    _pmInterval,
    _nextPmDue,
    _nextPmOdometer,
    _telematicsProvider,
    _eldProvider,
    _permitNumber,
    _permitIssue,
    _permitExpiry,
    _customPermitType,
    _certificateNumber,
    _inspectionDate,
    _expiryDate,
    _nextInspectionDue,
    _inspectorName,
    _inspectorLicense,
    _inspectionFacility,
    _facilityNumber,
    _safetyPlate,
    _safetyVehicle,
    _safetyVehicleType,
    _criticalDefects,
    _majorDefects,
    _advisoryItems,
    _inspectionSummary,
  ];

  @override
  void initState() {
    super.initState();
    _startDate.text = DateTime.now().toIso8601String().split('T').first;
    _inspectionDate.addListener(_recalculateCvipExpiry);
    _startDate.addListener(_applyMaintenancePolicyDefaults);
    _currentOdometer.addListener(_applyMaintenancePolicyDefaults);
    for (final c in _allControllers) {
      c.addListener(_onFormChanged);
    }
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // Started before the Future.wait group below so it fetches in parallel
    // with the others despite having a different result type.
    final policyConfigsFuture = FleetLookupService.instance
        .fetchMaintenancePolicyConfigs();
    final lookups = await Future.wait([
      FleetLookupService.instance.fetchCountries(),
      FleetLookupService.instance.fetchFuelTypes(),
      FleetLookupService.instance.fetchMaintenancePolicies(),
      FleetLookupService.instance.fetchPermitTypes(),
    ]);
    final policyConfigsResult = await policyConfigsFuture;
    if (widget.isEdit) {
      final unit = await PowerUnitService.instance.fetchPowerUnitById(
        widget.powerUnitId!,
      );
      if (unit.isSuccess && unit.data != null) {
        _unitForStateMatch = unit.data;
        _populate(unit.data!);
      }
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _countries = lookups[0].data ?? [];
      _fuelTypes = lookups[1].data ?? [];
      _policies = lookups[2].data ?? [];
      _permitTypes = lookups[3].data ?? [];
      _policyConfigs = policyConfigsResult.data ?? [];
    });
    if (_countryId != null) await _loadStates(_countryId!);
    if (_stateId != null) await _loadCities(_stateId!);
    // Match province name to state id after states load (edit mode).
    final unit = _unitForStateMatch;
    if (unit != null &&
        _stateId == null &&
        unit.state != null &&
        _states.isNotEmpty) {
      final match = _states.where(
        (s) => s.name.toLowerCase() == unit.state!.toLowerCase(),
      );
      if (match.isNotEmpty) {
        setState(() => _stateId = match.first.id);
        await _loadCities(_stateId!);
      }
    }
    _recalculateCvipExpiry();
    _applyMaintenancePolicyDefaults();
    if (mounted) _bootstrapped = true;
  }

  PowerUnitModel? _unitForStateMatch;

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
          return DateFormat(
            'yyyy-MM-dd',
          ).format(DateTime(third, first, second));
        } else if (first > 1000) {
          return DateFormat(
            'yyyy-MM-dd',
          ).format(DateTime(first, second, third));
        }
      }
    }
    return text;
  }

  void _populate(PowerUnitModel u) {
    _unitNumber.text = u.unitNumber;
    _vin.text = u.vinNumber ?? '';
    _make.text = u.make ?? '';
    _model.text = u.model ?? '';
    _year.text = u.year?.toString() ?? '';
    _color.text = u.color ?? '';
    _purchaseDate.text = _toIsoDate(
      u.purchaseDate ?? u.raw?['purchaseDate'] as String?,
    );
    _purchasePrice.text = u.purchasePrice?.toString() ?? '';
    _startDate.text = _toIsoDate(u.startDate ?? u.raw?['startDate'] as String?);
    _status = u.isActive ? 'active' : 'inactive';
    _assignedDriver.text = u.assignedDriver ?? '';
    _plate.text = u.licensePlate ?? '';
    _countryId = u.countryId;
    _stateId = null;
    _cityId = u.cityId;
    _registrationNumber.text = u.registrationNumber ?? '';
    _registrationExpiry.text = _toIsoDate(
      u.registrationExpiry ?? u.raw?['registrationExpiry'] as String?,
    );
    _imsNumber.text = u.imsNumber ?? '';
    final ownershipType = (u.ownershipType ?? '').toLowerCase().trim();
    _ownershipType = ['owned', 'owner-operator'].contains(ownershipType)
        ? ownershipType
        : '';
    _ownerName.text = u.ownerName ?? '';
    _ownerEmail.text = u.ownerEmail ?? '';
    _ownerPhone.text = u.ownerPhone ?? '';
    _ownerAddress.text = u.ownerAddress ?? '';
    _gvwr.text = u.gvwr ?? '';
    final rawFuel = u.fuelType?.trim();
    if (rawFuel != null && rawFuel.isNotEmpty) {
      final match = _fuelTypeOptions.firstWhere(
        (o) => o.toLowerCase() == rawFuel.toLowerCase(),
        orElse: () => rawFuel,
      );
      _fuelType = match;
    } else {
      _fuelType = null;
    }
    _transmission.text = u.transmission ?? '';
    _engineMake.text = u.engineMake ?? '';
    _engineModel.text = u.engineModel ?? '';
    _maintenancePolicy.text = u.maintenancePolicy ?? '';
    _selectedPolicy = u.maintenancePolicy;
    _cviExpiry.text = _toIsoDate(u.cviExpiry ?? u.raw?['cviExpiry'] as String?);
    _currentOdometer.text = u.odometer?.toString() ?? '';
    _initialOdometer = u.odometer;
    _annualInspectionDue.text = _toIsoDate(
      u.annualInspectionDue ?? u.raw?['annualInspectionDue'] as String?,
    );
    _lastInspection.text = _toIsoDate(
      u.lastInspection ?? u.raw?['lastInspection'] as String?,
    );
    _pmInterval.text = u.pmInterval ?? '';
    _nextPmDue.text = _toIsoDate(u.nextPmDue ?? u.raw?['nextPmDue'] as String?);
    _nextPmOdometer.text = u.nextPmOdometer ?? '';
    _telematicsProvider.text = u.telematicsProvider ?? '';
    _telematicsEnabled =
        (u.telematicsEnabled ?? 'active').toLowerCase().contains('inact')
        ? 'inactive'
        : 'active';
    _eldProvider.text = u.eldProvider ?? '';
    _permits.addAll(u.permits);
    _certificateNumber.text = u.certificateNumber ?? '';
    _inspectionDate.text = _toIsoDate(
      u.inspectionDate ?? u.raw?['inspectionDate'] as String?,
    );
    _expiryDate.text = _toIsoDate(
      u.expiryDate ?? u.raw?['expiryDate'] as String?,
    );
    _nextInspectionDue.text = _toIsoDate(
      u.nextInspectionDue ?? u.raw?['nextInspectionDue'] as String?,
    );
    _inspectorName.text = u.inspectorName ?? '';
    _inspectorLicense.text = u.inspectorLicense ?? '';
    _inspectionFacility.text = u.inspectionFacility ?? '';
    _facilityNumber.text = u.facilityNumber ?? '';
    _safetyPlate.text = u.safetyLicensePlate ?? u.licensePlate ?? '';
    _safetyVehicle.text = u.safetyVehicle ?? '';
    _safetyVehicleType.text = u.vehicleType ?? '';
    _criticalDefects.text = '${u.criticalDefects ?? 0}';
    _majorDefects.text = '${u.majorDefects ?? 0}';
    _advisoryItems.text = '${u.advisoryItems ?? 0}';
    _inspectionSummary.text = u.inspectionSummary ?? '';
  }

  Future<void> _loadStates(int countryId) async {
    final r = await FleetLookupService.instance.fetchStates(
      countryId: countryId,
    );
    if (!mounted) return;
    setState(() => _states = r.data ?? []);
  }

  Future<void> _loadCities(int stateId) async {
    final r = await FleetLookupService.instance.fetchCities(stateId: stateId);
    if (!mounted) return;
    setState(() => _cities = r.data ?? []);
  }

  /// Mirrors the web app's `calculateCVIPExpiry`: BC/SK get 6 months
  /// validity, every other province gets 12 — using plain `DateTime` month
  /// arithmetic so day/month overflow rolls over the same way JS's
  /// `Date.setMonth` does (e.g. Aug 31 + 6mo -> Mar 3, not Feb 28).
  DateTime _calculateCvipExpiry(DateTime inspectionDate, String province) {
    final p = province.trim().toLowerCase();
    final shortValidity =
        p == 'british columbia' ||
        p == 'bc' ||
        p == 'saskatchewan' ||
        p == 'sk';
    return DateTime(
      inspectionDate.year,
      inspectionDate.month + (shortValidity ? 6 : 12),
      inspectionDate.day,
    );
  }

  /// Recomputes the Annual Safety / CVIP "Expiry Date" from Inspection Date
  /// + the Registration & Plates province — always overwrites, matching the
  /// web app's reactive recalculation (the field is not user-editable).
  void _recalculateCvipExpiry() {
    final province = _states
        .where((s) => s.id == _stateId)
        .map((s) => s.name)
        .firstOrNull;
    if (province == null || province.isEmpty) return;
    final inspectionDate = DateTime.tryParse(_inspectionDate.text.trim());
    if (inspectionDate == null) return;
    final expiry = _calculateCvipExpiry(inspectionDate, province);
    final formatted =
        '${expiry.year.toString().padLeft(4, '0')}-${expiry.month.toString().padLeft(2, '0')}-${expiry.day.toString().padLeft(2, '0')}';
    if (_expiryDate.text != formatted) {
      setState(() => _expiryDate.text = formatted);
    }
  }

  static const Map<String, int> _inspectionDaysByFrequency = {
    'Monthly': 30,
    'Quarterly': 90,
    'Semi Annual': 180,
    'Annual': 365,
  };

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Auto-fills PM Interval / Next PM Due / Next PM Odometer / Annual
  /// Inspection Due / CVIP Due from the selected Maintenance Policy's
  /// configuration, anchored to Start Date and Current Odometer — mirrors
  /// the web app's reactive recalculation (`AddTruckPage.tsx`), so these
  /// fields always reflect the backend-configured policy the same way on
  /// both platforms. Always overwrites, same as [_recalculateCvipExpiry].
  void _applyMaintenancePolicyDefaults() {
    if (_selectedPolicy == null || _selectedPolicy!.isEmpty) return;
    final policy = _policyConfigs
        .where((p) => p.name == _selectedPolicy)
        .firstOrNull;
    if (policy == null) return;

    final allPanels = policy.allPanels;
    final activePanel = allPanels.firstWhere(
      (p) => p.type == (_selectedTypeKey ?? 'PM'),
      orElse: () =>
          policy.pmPanel ??
          const PolicySchedulePanel(type: 'PM', name: 'PM Schedule'),
    );

    // Anchor Date: prefer Last Inspection Date, then Start Date, then current date
    final anchorDate =
        DateTime.tryParse(_lastInspection.text.trim()) ??
        DateTime.tryParse(_startDate.text.trim()) ??
        DateTime.now();

    final panelMonths = activePanel.months ?? 0;
    final panelDays =
        activePanel.days ??
        (activePanel.months == null ? policy.pmIntervalDays : 0) ??
        0;
    final intervalKm = activePanel.km ?? policy.pmIntervalKm;
    final baseOdometer = int.tryParse(_currentOdometer.text.trim());

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

    final annualInspectionDays =
        _inspectionDaysByFrequency[policy.inspectionFrequency] ?? 365;

    setState(() {
      if (intervalKm != null && intervalKm > 0) {
        _pmInterval.text = intervalKm.toString();
        if (baseOdometer != null) {
          _nextPmOdometer.text = (baseOdometer + intervalKm).toString();
        }
      }

      if (panelMonths > 0 || panelDays > 0) {
        _nextPmDue.text = _isoDate(computedDueDate);
      }

      if (activePanel.nextDueDate != null &&
          activePanel.nextDueDate!.isNotEmpty) {
        _nextPmDue.text = activePanel.nextDueDate!;
      }

      if (activePanel.nextDueOdometer != null) {
        _nextPmOdometer.text = activePanel.nextDueOdometer!.toString();
      }

      final annualDueIso = _isoDate(
        anchorDate.add(Duration(days: annualInspectionDays)),
      );
      if (_annualInspectionDue.text.isEmpty) {
        _annualInspectionDue.text = annualDueIso;
      }
      if (_cviExpiry.text.isEmpty) {
        _cviExpiry.text = annualDueIso;
      }
    });
  }

  /// Mirrors the web's `canRefreshOdometer` gate on the Current Odometer
  /// field's sync button: telematics must not be explicitly disabled, and
  /// both Unit Number and VIN must be filled in (needed to look the vehicle
  /// up with the telematics provider).
  bool get _canRefreshOdometer =>
      _telematicsEnabled != 'inactive' &&
      _unitNumber.text.trim().isNotEmpty &&
      _vin.text.trim().isNotEmpty;

  /// Pulls a live odometer reading from the connected telematics provider
  /// (e.g. Samsara) and fills it into Current Odometer — mirrors the web's
  /// "Sync odometer" refresh button next to the Current Odometer field.
  Future<void> _refreshOdometer() async {
    if (!_canRefreshOdometer || _refreshingOdometer) return;
    setState(() => _refreshingOdometer = true);
    final companyId = _isSuperAdmin
        ? AuthService.instance.selectedCompanyIdInt
        : AuthService.instance.currentUser?.companyId;
    final result = await MaintenanceService.instance.fetchSamsaraOdometer(
      unitNumber: _unitNumber.text.trim(),
      vin: _vin.text.trim(),
      companyId: companyId,
    );
    if (!mounted) return;
    setState(() => _refreshingOdometer = false);
    final value = result.data?.trim();
    if (result.isSuccess && value != null && value.isNotEmpty) {
      setState(() => _currentOdometer.text = value);
    } else if (!result.isSuccess) {
      ApiFeedback.showError(result, fallback: 'Failed to sync odometer');
    } else {
      AppToast.showError('No live odometer reading available for this unit');
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
      _purchaseDate,
      _purchasePrice,
      _startDate,
      _plate,
      _registrationNumber,
      _registrationExpiry,
      _imsNumber,
      _gvwr,
      _transmission,
      _engineMake,
      _engineModel,
      _ownerName,
      _ownerEmail,
      _ownerPhone,
      _ownerAddress,
      _assignedDriver,
      _maintenancePolicy,
      _cviExpiry,
      _currentOdometer,
      _annualInspectionDue,
      _lastInspection,
      _pmInterval,
      _nextPmDue,
      _nextPmOdometer,
      _telematicsProvider,
      _eldProvider,
      _permitNumber,
      _permitIssue,
      _permitExpiry,
      _customPermitType,
      _certificateNumber,
      _inspectionDate,
      _expiryDate,
      _nextInspectionDue,
      _inspectorName,
      _inspectorLicense,
      _inspectionFacility,
      _facilityNumber,
      _safetyPlate,
      _safetyVehicle,
      _safetyVehicleType,
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

  /// Mirrors the web app's VIN validation exactly (`AddTruckPage.tsx`):
  /// required, alphanumeric only, and exactly 17 characters.
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

  /// Mirrors the web app's `truckFormValidation.ts` field rules.
  String? _yearValidator(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Year is required';
    if (!RegExp(r'^\d{4}$').hasMatch(value)) {
      return 'Year must be a 4-digit number';
    }
    return null;
  }

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

  String? _nonNegativeIntValidator(
    String? v,
    String field, {
    bool required = false,
  }) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return required ? '$field is required' : null;
    final n = int.tryParse(value);
    if (n == null || n < 0) {
      return '$field must be a non-negative whole number';
    }
    return null;
  }

  String? _alphanumericValidator(
    String? v,
    String field, {
    bool required = false,
  }) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return required ? '$field is required' : null;
    if (!_alphanumericOnly.hasMatch(value)) {
      return '$field must contain only letters and numbers';
    }
    return null;
  }

  String? _ownerEmailValidator(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Owner Email is required';
    if (!_emailFormat.hasMatch(value)) return 'Enter a valid email address';
    return null;
  }

  String? _ownerPhoneValidator(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Owner Phone is required';
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10 || digits.length > 15) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  String? _inspectorNameValidator(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Inspector Name is required';
    if (!RegExp(r'^[A-Za-z0-9\s]+$').hasMatch(value) ||
        !RegExp(r'[A-Za-z0-9]').hasMatch(value)) {
      return 'Inspector Name must contain only letters, numbers and spaces';
    }
    return null;
  }

  bool _validateStep(int step) {
    if (!_formKey.currentState!.validate()) return false;
    if (step == 1) {
      if (_req(_unitNumber.text, 'Unit Number') != null ||
          _req(_vin.text, 'VIN') != null ||
          _req(_make.text, 'Make') != null ||
          _req(_model.text, 'Model') != null ||
          _req(_year.text, 'Year') != null ||
          _req(_color.text, 'Color') != null ||
          _req(_purchaseDate.text, 'Purchase Date') != null ||
          _req(_purchasePrice.text, 'Purchase Price') != null ||
          _req(_startDate.text, 'Start Date') != null ||
          _req(_plate.text, 'Plate Number') != null ||
          _req(_registrationExpiry.text, 'Registration Expiry') != null ||
          _req(_transmission.text, 'Transmission') != null ||
          _nonNegativeIntValidator(_gvwr.text, 'GVWR', required: false) !=
              null ||
          _ownershipType.isEmpty) {
        AppToast.showError('Complete all required Step 1 fields');
        return false;
      }
      if (_countryId == null) {
        AppToast.showError('Select country');
        return false;
      }
      if (_stateId == null && _states.isNotEmpty) {
        AppToast.showError('Select state/province');
        return false;
      }
      if (_ownershipType == 'owner-operator') {
        if (_req(_ownerName.text, 'Owner Name') != null ||
            _req(_ownerEmail.text, 'Owner Email') != null ||
            _req(_ownerPhone.text, 'Owner Phone') != null ||
            _req(_ownerAddress.text, 'Owner Address') != null) {
          AppToast.showError('Complete owner operator details');
          return false;
        }
      }
    }
    if (step == 2) {
      if (_req(_maintenancePolicy.text, 'Maintenance Policy') != null ||
          _req(_cviExpiry.text, 'CVIP Due') != null ||
          _req(_currentOdometer.text, 'Current Odometer') != null ||
          _req(_lastInspection.text, 'Last Inspection') != null ||
          _req(_pmInterval.text, 'PM Interval') != null ||
          _req(_nextPmDue.text, 'Next PM Due') != null ||
          _req(_nextPmOdometer.text, 'Next PM Odometer') != null ||
          _req(_telematicsProvider.text, 'Telematics Provider') != null ||
          _req(_eldProvider.text, 'ELD Provider') != null) {
        AppToast.showError('Complete all required Step 2 fields');
        return false;
      }
      final currentOdometer = int.tryParse(_currentOdometer.text.trim());
      if (_initialOdometer != null &&
          currentOdometer != null &&
          currentOdometer < _initialOdometer!) {
        AppToast.showError(
          'Current Odometer cannot be less than the Initial Odometer ($_initialOdometer)',
        );
        return false;
      }
      if (_permits.isEmpty) {
        AppToast.showError('Add at least one permit before continuing');
        return false;
      }
    }
    if (step == 3) {
      if (_req(_certificateNumber.text, 'Certificate Number') != null ||
          _req(_inspectionDate.text, 'Inspection Date') != null ||
          _req(_expiryDate.text, 'Expiry Date') != null ||
          _req(_nextInspectionDue.text, 'Next Inspection Due') != null ||
          _req(_inspectorName.text, 'Inspector Name') != null ||
          _req(_inspectorLicense.text, 'Inspector License') != null ||
          _req(_inspectionFacility.text, 'Inspection Facility') != null ||
          _req(_facilityNumber.text, 'Facility Number') != null ||
          _req(_safetyPlate.text, 'License Plate') != null) {
        AppToast.showError('Complete all required Step 3 fields');
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

    return {
      'unitNumber': _unitNumber.text.trim(),
      'vin': _vin.text.trim(),
      'make': _make.text.trim(),
      'model': _model.text.trim(),
      'year': toInt(_year.text),
      'color': _color.text.trim(),
      'purchaseDate': _toIsoDate(_purchaseDate.text),
      'purchasePrice': double.tryParse(_purchasePrice.text.trim()),
      'startDate': _toIsoDate(_startDate.text),
      'status': _status,
      if (_assignedDriver.text.trim().isNotEmpty)
        'assignedDriver': _assignedDriver.text.trim(),
      'plateNumber': _plate.text.trim(),
      'plateProvince':
          _states
              .where((s) => s.id == _stateId)
              .map((s) => s.name)
              .firstOrNull ??
          '',
      if (_countryId != null) 'countryId': _countryId,
      if (_cityId != null) 'cityId': _cityId,
      'registrationNumber': _registrationNumber.text.trim(),
      'registrationExpiry': _toIsoDate(_registrationExpiry.text),
      'imsNumber': _imsNumber.text.trim(),
      'ownershipType': _ownershipType,
      if (_ownershipType == 'owner-operator') ...{
        'ownerName': _ownerName.text.trim(),
        'ownerEmail': _ownerEmail.text.trim(),
        'ownerPhone': _ownerPhone.text.trim(),
        'ownerAddress': _ownerAddress.text.trim(),
      },
      'gvwr': toInt(_gvwr.text),
      if (_fuelType != null) 'fuelType': _fuelType,
      'transmission': _transmission.text.trim(),
      'engineMake': _engineMake.text.trim(),
      'engineModel': _engineModel.text.trim(),
      'maintenancePolicy': _maintenancePolicy.text.trim(),
      'cviExpiry': _toIsoDate(_cviExpiry.text),
      'currentOdometer': toInt(_currentOdometer.text),
      'odometer': toInt(_currentOdometer.text),
      'annualInspectionDue': _toIsoDate(_annualInspectionDue.text),
      'lastInspection': _toIsoDate(_lastInspection.text),
      'pmInterval': toInt(_pmInterval.text),
      'nextPmDue': _toIsoDate(_nextPmDue.text),
      'nextPmOdometer': toInt(_nextPmOdometer.text),
      'telematicsProvider': _telematicsProvider.text.trim(),
      'telematicsEnabled': _telematicsEnabled,
      'eldProvider': _eldProvider.text.trim(),
      'certificateNumber': _certificateNumber.text.trim(),
      'inspectionDate': _toIsoDate(_inspectionDate.text),
      'expiryDate': _toIsoDate(_expiryDate.text),
      'nextInspectionDue': _toIsoDate(_nextInspectionDue.text),
      'inspectorName': _inspectorName.text.trim(),
      'inspectorLicense': _inspectorLicense.text.trim(),
      'inspectionFacility': _inspectionFacility.text.trim(),
      'facilityNumber': _facilityNumber.text.trim(),
      'licenseplate': _safetyPlate.text.trim(),
      'vehicle': _safetyVehicle.text.trim(),
      'vehicleType': _safetyVehicleType.text.trim(),
      'criticalDefects': toInt(_criticalDefects.text) ?? 0,
      'majorDefects': toInt(_majorDefects.text) ?? 0,
      'advisoryItems': toInt(_advisoryItems.text) ?? 0,
      'inspectionSummary': _inspectionSummary.text.trim(),
      'permits': _permits.map((p) => p.toPayload()).toList(),
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
        ? await PowerUnitService.instance.updatePowerUnit(
            widget.powerUnitId!,
            payload,
          )
        : await PowerUnitService.instance.createPowerUnit(
            payload,
            companyId: AuthService.instance.selectedCompanyId,
          );
    if (!mounted) return;
    setState(() => _saving = false);
    if (result.isSuccess) {
      AppToast.showSuccess(
        widget.isEdit ? 'Power unit updated' : 'Power unit created',
      );
      Navigator.pop(context, true);
    } else {
      ApiFeedback.showError(result, fallback: 'Failed to save power unit');
    }
  }

  /// Opens the "Upload Documents" sheet (Document Type per row, like web),
  /// which handles its own file picking + OCR scanning; each successfully
  /// extracted document streams its fields into the form as it resolves.
  Future<void> _openDocumentUploadSheet() async {
    final result = await showOcrDocumentUploadSheet(
      context: context,
      initialDocuments: _ocrDocuments,
      onPrefillExtracted: _applyOcrPrefill,
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
      fill(_vin, prefill['vin']);
      fill(_make, prefill['make']);
      fill(_model, prefill['model']);
      fill(_year, prefill['year']);
      fill(_color, prefill['color']);
      fill(_plate, prefill['plateNumber']);
      fill(_registrationNumber, prefill['registrationNumber']);
      fillDate(_registrationExpiry, prefill['registrationExpiry']);
      fill(_gvwr, prefill['gvwr']);
      fill(_transmission, prefill['transmission']);
      fill(_engineMake, prefill['engineMake']);
      fill(_engineModel, prefill['engineModel']);
      fillDate(_purchaseDate, prefill['purchaseDate']);
      fill(_certificateNumber, prefill['certificateNumber']);
      fillDate(_inspectionDate, prefill['inspectionDate']);
      fillDate(_expiryDate, prefill['expiryDate']);
      fill(_inspectorName, prefill['inspectorName']);
      fill(_inspectorLicense, prefill['inspectorLicense']);
      fill(_inspectionFacility, prefill['inspectionFacility']);
      fill(_facilityNumber, prefill['facilityNumber']);
      fill(_ownerName, prefill['ownerName']);
      fill(_ownerEmail, prefill['ownerEmail']);
      fill(_ownerPhone, prefill['ownerPhone']);
      fill(_ownerAddress, prefill['ownerAddress']);
      fill(_imsNumber, prefill['imsNumber']);
      fill(_currentOdometer, prefill['odometer']);
      fill(_safetyVehicleType, prefill['vehicleType']);

      final extractedFuelType = prefill['fuelType']?.toString().trim();
      if ((_fuelType == null || _fuelType!.isEmpty) &&
          extractedFuelType != null &&
          extractedFuelType.isNotEmpty) {
        final match = _fuelTypeOptions.where(
          (o) => o.toLowerCase() == extractedFuelType.toLowerCase(),
        );
        _fuelType = match.isNotEmpty ? match.first : extractedFuelType;
      }
    });

    // Plate province → match against the already-loaded states list, same
    // pattern used for edit-mode state matching in _bootstrap().
    final province = prefill['plateProvince'];
    if (province != null && _stateId == null && _states.isNotEmpty) {
      final match = _states.where(
        (s) => s.name.toLowerCase() == province.toLowerCase(),
      );
      if (match.isNotEmpty) {
        setState(() => _stateId = match.first.id);
        _loadCities(_stateId!);
      }
    }
  }

  Future<void> _addPermit() async {
    final isOther = _selectedPermitType == _kOtherPermitType;
    final resolvedType = isOther
        ? _customPermitType.text.trim().toUpperCase()
        : (_selectedPermitType ?? '');
    if (resolvedType.isEmpty ||
        _permitNumber.text.trim().isEmpty ||
        _permitIssue.text.trim().isEmpty ||
        _permitExpiry.text.trim().isEmpty) {
      AppToast.showError('Fill all permit fields');
      return;
    }

    if (isOther) {
      final exists = _permitTypes.any(
        (p) => p.name.toLowerCase() == resolvedType.toLowerCase(),
      );
      if (!exists) {
        // Non-blocking: the permit itself is still added below even if this
        // fails to persist — matches web's behavior.
        final created = await FleetLookupService.instance.createPermitType(
          resolvedType,
        );
        if (created.isSuccess && created.data != null && mounted) {
          setState(() => _permitTypes = [..._permitTypes, created.data!]);
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _permits.add(
        TruckPermitModel(
          permitType: resolvedType,
          permitNumber: _permitNumber.text.trim(),
          issueDate: _permitIssue.text.trim(),
          expiryDate: _permitExpiry.text.trim(),
        ),
      );
      _permitNumber.clear();
      _permitIssue.clear();
      _permitExpiry.clear();
      _selectedPermitType = null;
      _customPermitType.clear();
    });
  }

  Future<void> _next() async {
    if (!_validateStep(_step)) return;
    if (_step == 1 && !widget.isEdit) {
      final vin = _vin.text.trim();
      if (vin.isNotEmpty) {
        setState(() => _checkingVin = true);
        final check = await PowerUnitService.instance.checkVinExists(vin: vin);
        if (!mounted) return;
        setState(() => _checkingVin = false);
        if (check.isSuccess && check.data == true) {
          AppToast.showError(
            'This VIN number already exists. Please use a different VIN.',
          );
          return;
        }
      }
    }
    setState(() => _step++);
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
    return PopScope(
      canPop: _step == 1 && !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_step > 1) {
          setState(() => _step--);
          return;
        }
        _attemptLeave();
      },
      child: GradientPageBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text(
              widget.isEdit ? 'Edit Power Unit' : 'Add Power Unit',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    _StepIndicator(step: _step),
                    Expanded(
                      child: Form(
                        key: _formKey,
                        onChanged: _onFormChanged,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          children: [
                            if (_step == 1) ..._buildStep1(),
                            if (_step == 2) ..._buildStep2(),
                            if (_step == 3) ..._buildStep3(),
                          ],
                        ),
                      ),
                    ),
                    _BottomBar(
                      step: _step,
                      saving: _saving || _checkingVin,
                      onCancel: _attemptLeave,
                      onContinue: _step < 3 ? _next : null,
                      onSave: _step == 3 ? _save : null,
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
      title: 'Vehicle Details',
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
          validator: _yearValidator,
        ),
        WebTextFormField(
          controller: _color,
          label: 'Color *',
          validator: (v) => _req(v, 'Color'),
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
          label: 'Status *',
          value: _status,
          items: const ['active', 'inactive'],
          itemLabel: (v) => v == 'active' ? 'Active' : 'Inactive',
          onChanged: (v) {
            setState(() => _status = v ?? 'active');
            _onFormChanged();
          },
        ),
        WebTextFormField(controller: _assignedDriver, label: 'Assigned Driver'),
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
          onChanged: (v) async {
            setState(() {
              _stateId = v;
              _cityId = null;
              _cities = [];
            });
            _onFormChanged();
            if (v != null) await _loadCities(v);
            _recalculateCvipExpiry();
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
          onChanged: (v) {
            setState(() => _cityId = v);
            _onFormChanged();
          },
        ),
        WebTextFormField(
          controller: _registrationNumber,
          label: 'Registration Number',
          validator: (v) => _alphanumericValidator(v, 'Registration Number'),
        ),
        WebDateField(
          controller: _registrationExpiry,
          label: 'Registration Expiry',
          required: true,
          validator: (v) => _req(v, 'Registration Expiry'),
        ),
        WebTextFormField(
          controller: _imsNumber,
          label: 'IMS Number',
          validator: (v) => _alphanumericValidator(v, 'IMS Number'),
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
          WebTextFormField(
            controller: _ownerName,
            label: 'Owner Name *',
            validator: (v) => _req(v, 'Owner Name'),
          ),
          WebTextFormField(
            controller: _ownerEmail,
            label: 'Owner Email *',
            validator: _ownerEmailValidator,
          ),
          WebTextFormField(
            controller: _ownerPhone,
            label: 'Owner Phone *',
            validator: _ownerPhoneValidator,
          ),
          WebTextFormField(
            controller: _ownerAddress,
            label: 'Owner Address *',
            validator: (v) => _req(v, 'Owner Address'),
          ),
        ],
      ],
    ),
    WebFormSection(
      title: 'Technical Specifications',
      children: [
        WebTextFormField(
          controller: _gvwr,
          label: 'GVWR',
          keyboardType: TextInputType.number,
          validator: (v) =>
              _nonNegativeIntValidator(v, 'GVWR', required: false),
        ),
        WebDropdownField<String>(
          label: 'Fuel Type',
          value: _fuelType,
          items: _fuelTypeOptions,
          itemLabel: (v) => v,
          onChanged: (v) {
            setState(() => _fuelType = v);
            _onFormChanged();
          },
        ),
        WebTextFormField(
          controller: _transmission,
          label: 'Transmission *',
          validator: (v) => _req(v, 'Transmission'),
        ),
        WebTextFormField(controller: _engineMake, label: 'Engine Make'),
        WebTextFormField(controller: _engineModel, label: 'Engine Model'),
      ],
    ),
  ];

  String? _selectedTypeKey = 'PM';

  List<Widget> _buildStep2() {
    final selectedPolicyObj = _policyConfigs
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
    final isOil =
        activePanel.type.toUpperCase() == 'OIL' ||
        activeName.toLowerCase().contains('oil');
    final isReefer = activePanel.type.toUpperCase() == 'REEFER';

    final dueLabel = isOil
        ? 'Next Oil Due'
        : (isReefer ? 'Next Reefer Due' : 'Next PM Due');

    final odoLabel = isOil
        ? 'Next Oil Odometer *'
        : (isReefer ? 'Next Reefer Hours *' : 'Next PM Odometer *');

    final unitLabel = isReefer ? 'hrs' : 'km';

    final progressHeader = isOil
        ? 'KM UNTIL OIL CHANGE'
        : (isReefer ? 'HOURS UNTIL REEFER SERVICE' : 'KM UNTIL PM');

    final currentOdometer = int.tryParse(_currentOdometer.text.trim()) ?? 0;
    final nextPmOdometer = int.tryParse(_nextPmOdometer.text.trim()) ?? 0;
    final pmIntervalKm =
        int.tryParse(_pmInterval.text.trim()) ??
        (selectedPolicyObj?.pmIntervalKm ?? 10000);
    final remainingKm = (nextPmOdometer - currentOdometer).clamp(
      0,
      pmIntervalKm > 0 ? pmIntervalKm * 2 : 100000,
    );
    final progressRatio = pmIntervalKm > 0
        ? (remainingKm / pmIntervalKm).clamp(0.0, 1.0)
        : 0.0;

    return [
      WebFormSection(
        title: 'Maintenance Policy',
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
                _maintenancePolicy.text = v ?? '';
                _selectedTypeKey = 'PM';
              });
              _onFormChanged();
              _applyMaintenancePolicyDefaults();
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
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
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
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
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
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.check_circle,
                            size: 14,
                            color: isSelected
                                ? AppColors.primary
                                : Colors.green,
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
          WebDateField(
            controller: _cviExpiry,
            label: 'CVIP/Annual Inspection Due',
            required: true,
            validator: (v) => _req(v, 'CVIP/Annual Inspection Due'),
          ),
          WebDateField(
            controller: _lastInspection,
            label: 'Last Inspection',
            required: true,
            validator: (v) => _req(v, 'Last Inspection'),
            onChanged: (_) => _applyMaintenancePolicyDefaults(),
          ),
          WebTextFormField(
            controller: _currentOdometer,
            label: 'Current Odometer *',
            keyboardType: TextInputType.number,
            validator: (v) => _nonNegativeNumberValidator(
              v,
              'Current Odometer',
              required: true,
            ),
            suffix: IconButton(
              tooltip: _canRefreshOdometer
                  ? 'Sync odometer from telematics'
                  : 'Requires Unit Number, VIN, and active telematics',
              icon: _refreshingOdometer
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync, size: 18),
              onPressed: (_canRefreshOdometer && !_refreshingOdometer)
                  ? _refreshOdometer
                  : null,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Last Sync (24 Hours)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade800,
                  ),
                ),
              ],
            ),
          ),
          WebDateField(
            controller: _nextPmDue,
            label: dueLabel,
            required: true,
            validator: (v) => _req(v, dueLabel),
          ),
          WebTextFormField(
            controller: _nextPmOdometer,
            label: odoLabel,
            keyboardType: TextInputType.number,
            validator: (v) => _nonNegativeNumberValidator(
              v,
              odoLabel.replaceAll(' *', ''),
              required: true,
            ),
          ),
          WebTextFormField(
            controller: TextEditingController(
              text: _initialOdometer?.toString() ?? '1,000',
            ),
            label: 'Initial Odometer',
            readOnly: true,
          ),
          Text(
            'This value is captured when creating the Power Unit.',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 12),
          if (pmIntervalKm > 0) ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(top: 4, bottom: 8),
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
      WebFormSection(
        title: 'Telematics & ELD',
        children: [
          WebDropdownField<String>(
            label: 'Telematics Status *',
            value: _telematicsEnabled,
            items: const ['active', 'inactive'],
            itemLabel: (v) => v == 'active' ? 'Active' : 'Inactive',
            onChanged: (v) {
              setState(() => _telematicsEnabled = v ?? 'active');
              _onFormChanged();
            },
          ),
          WebTextFormField(
            controller: _telematicsProvider,
            label: 'Telematics Provider *',
            validator: (v) => _req(v, 'Telematics Provider'),
          ),
          WebTextFormField(
            controller: _eldProvider,
            label: 'ELD Provider *',
            validator: (v) => _req(v, 'ELD Provider'),
          ),
        ],
      ),
      WebFormSection(
        title: 'Unit-Specific Permits',
        children: [
          WebDropdownField<String>(
            label: 'Permit Type *',
            value: _selectedPermitType,
            items: [..._permitTypes.map((p) => p.name), _kOtherPermitType],
            itemLabel: (v) => v == _kOtherPermitType ? 'Other' : v,
            onChanged: (v) {
              setState(() => _selectedPermitType = v);
              _onFormChanged();
            },
          ),
          if (_selectedPermitType == _kOtherPermitType)
            WebTextFormField(
              controller: _customPermitType,
              label: 'Custom Permit Type *',
              hint: 'Enter a new permit type name',
            ),
          WebTextFormField(controller: _permitNumber, label: 'Permit Number *'),
          WebDateField(
            controller: _permitIssue,
            label: 'Issue Date',
            required: true,
          ),
          WebDateField(
            controller: _permitExpiry,
            label: 'Expiry Date',
            required: true,
          ),
          OutlinedButton.icon(
            onPressed: _addPermit,
            icon: const Icon(Icons.add),
            label: const Text('Add Permit'),
          ),
          ..._permits.map(
            (p) => ListTile(
              title: Text('${p.permitType} — ${p.permitNumber}'),
              subtitle: Text(
                '${formatDateMMDDYYYY(p.issueDate)} → ${formatDateMMDDYYYY(p.expiryDate)}',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => setState(() => _permits.remove(p)),
              ),
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _buildStep3() => [
    WebFormSection(
      title: 'Annual Safety / CVIP',
      children: [
        WebTextFormField(
          controller: _certificateNumber,
          label: 'Certificate Number *',
          validator: (v) =>
              _alphanumericValidator(v, 'Certificate Number', required: true),
        ),
        WebDateField(
          controller: _inspectionDate,
          label: 'Inspection Date',
          required: true,
          validator: (v) => _req(v, 'Inspection Date'),
        ),
        WebTextFormField(
          controller: _expiryDate,
          label: 'Expiry Date *',
          readOnly: true,
          hint: 'Auto-calculated from Inspection Date + Province',
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
          validator: (v) =>
              _alphanumericValidator(v, 'Inspector License', required: true),
        ),
        WebTextFormField(
          controller: _inspectionFacility,
          label: 'Inspection Facility *',
          validator: (v) => _req(v, 'Inspection Facility'),
        ),
        WebTextFormField(
          controller: _facilityNumber,
          label: 'Facility Number *',
          validator: (v) =>
              _alphanumericValidator(v, 'Facility Number', required: true),
        ),
        WebTextFormField(
          controller: _safetyPlate,
          label: 'License Plate *',
          validator: (v) =>
              _alphanumericValidator(v, 'License Plate', required: true),
        ),
        WebTextFormField(
          controller: _safetyVehicle,
          label: 'Vehicle',
          validator: (v) => _alphanumericValidator(v, 'Vehicle'),
        ),
        WebTextFormField(
          controller: _safetyVehicleType,
          label: 'Vehicle Type',
          validator: (v) => _alphanumericValidator(v, 'Vehicle Type'),
        ),
        WebTextFormField(
          controller: _criticalDefects,
          label: 'Critical Defects',
          keyboardType: TextInputType.number,
          validator: (v) => _nonNegativeIntValidator(v, 'Critical Defects'),
        ),
        WebTextFormField(
          controller: _majorDefects,
          label: 'Major Defects',
          keyboardType: TextInputType.number,
          validator: (v) => _nonNegativeIntValidator(v, 'Major Defects'),
        ),
        WebTextFormField(
          controller: _advisoryItems,
          label: 'Advisory Items',
          keyboardType: TextInputType.number,
          validator: (v) => _nonNegativeIntValidator(v, 'Advisory Items'),
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
  const _StepIndicator({required this.step});
  final int step;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          for (int i = 0; i < 3; i++) ...[
            _StepNode(number: i + 1, currentStep: step),
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
  const _StepNode({required this.number, required this.currentStep});
  final int number;
  final int currentStep;

  @override
  Widget build(BuildContext context) {
    final done = number < currentStep;
    final active = number == currentStep;
    return CircleAvatar(
      radius: 14,
      backgroundColor: done || active
          ? AppColors.primary
          : AppColors.surfaceTertiary,
      child: Text(
        done ? '✓' : '$number',
        style: TextStyle(
          color: done || active ? AppColors.white : AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
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
                      onPressed: onContinue,
                      expand: false,
                      dense: true,
                    )
                  : WebPrimaryButton(
                      label: 'Save Power Unit',
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
