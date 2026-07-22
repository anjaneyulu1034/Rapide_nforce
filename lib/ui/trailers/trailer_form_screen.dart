import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:rapide_nforce/ui/widgets/gradient_page_background.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/core/utils/api_feedback.dart';
import 'package:rapide_nforce/core/utils/app_toast.dart';
import 'package:rapide_nforce/core/utils/role_utils.dart';
import 'package:rapide_nforce/models/power_unit_model.dart';
import 'package:rapide_nforce/models/trailer_model.dart';
import 'package:rapide_nforce/models/truck_permit_model.dart';
import 'package:rapide_nforce/services/auth_service.dart';
import 'package:rapide_nforce/services/fleet_lookup_service.dart';
import 'package:rapide_nforce/services/ocr_service.dart';
import 'package:rapide_nforce/services/power_unit_service.dart';
import 'package:rapide_nforce/services/trailer_service.dart';
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
  String? _browseFileName;
  String? _browseFilePath;

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
  List<LookupOption> _policies = [];
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

  Future<void> _bootstrap() async {
    final lookups = await Future.wait([
      FleetLookupService.instance.fetchCountries(),
      FleetLookupService.instance.fetchMaintenancePolicies(),
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
      _loading = false;
      _countries = lookups[0].data ?? [];
      _policies = lookups[1].data ?? [];
      _trucks = trucks.data?.items ?? [];
    });
    if (_countryId != null) await _loadStates(_countryId!);
    if (_stateId != null) await _loadCities(_stateId!);
    final trailer = _trailerForStateMatch;
    if (trailer != null &&
        _stateId == null &&
        trailer.state != null &&
        _states.isNotEmpty) {
      final match = _states.where(
        (s) => s.name.toLowerCase() == trailer.state!.toLowerCase(),
      );
      if (match.isNotEmpty) {
        setState(() => _stateId = match.first.id);
        await _loadCities(_stateId!);
      }
    }
    if (mounted) _bootstrapped = true;
  }

  TrailerModel? _trailerForStateMatch;

  void _populate(TrailerModel t) {
    _unitNumber.text = t.trailerNumber;
    _vin.text = t.vinNumber ?? '';
    _make.text = t.make ?? '';
    _model.text = t.model ?? '';
    _year.text = t.year?.toString() ?? '';
    _color.text = t.color ?? '';
    _currentOdometer.text = t.odometer?.toString() ?? '';
    _purchaseDate.text = t.purchaseDate ?? '';
    _purchasePrice.text = t.purchasePrice?.toString() ?? '';
    _startDate.text = t.startDate ?? _startDate.text;
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
    _cviExpiry.text = t.cviExpiry ?? '';
    _pmDueDate.text = t.pmDueDate ?? '';
    _pmDueOdometer.text = t.pmDueOdometer?.toString() ?? '';

    _certificateNumber.text = t.certificateNumber ?? '';
    _inspectionDate.text = t.inspectionDate ?? '';
    _expiryDate.text = t.expiryDate ?? '';
    _nextInspectionDue.text = t.nextInspectionDue ?? '';
    _inspectorName.text = t.inspectorName ?? '';
    _inspectorLicense.text = t.inspectorLicense ?? '';
    _inspectionFacility.text = t.inspectionFacility ?? '';
    _facilityNumber.text = t.facilityNumber ?? '';
    _criticalDefects.text = '${t.criticalDefects ?? 0}';
    _majorDefects.text = '${t.majorDefects ?? 0}';
    _advisoryItems.text = '${t.advisoryItems ?? 0}';
    _inspectionSummary.text = t.inspectionSummary ?? '';
  }

  Future<void> _loadStates(int countryId) async {
    final r = await FleetLookupService.instance.fetchStates(countryId: countryId);
    if (!mounted) return;
    setState(() => _states = r.data ?? []);
  }

  Future<void> _loadCities(int stateId) async {
    final r = await FleetLookupService.instance.fetchCities(stateId: stateId);
    if (!mounted) return;
    setState(() => _cities = r.data ?? []);
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
    if (step == 1) {
      if (_req(_unitNumber.text, 'Unit Number') != null ||
          _req(_vin.text, 'VIN') != null ||
          _req(_make.text, 'Make') != null ||
          _req(_model.text, 'Model') != null ||
          _req(_year.text, 'Year') != null ||
          _req(_currentOdometer.text, 'Current Odometer') != null ||
          _req(_purchaseDate.text, 'Purchase Date') != null ||
          _req(_purchasePrice.text, 'Purchase Price') != null ||
          _req(_startDate.text, 'Start Date') != null ||
          _req(_plate.text, 'Plate Number') != null ||
          _trailerType == null ||
          _ownershipType.isEmpty) {
        AppToast.showError('Complete all required Trailer Details fields');
        return false;
      }
      final year = int.tryParse(_year.text.trim());
      if (year == null || year < 1900 || year > 2099) {
        AppToast.showError('Enter a valid year between 1900 and 2099');
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
            _req(_ownerPhone.text, 'Owner Phone') != null) {
          AppToast.showError('Complete owner operator details');
          return false;
        }
      }
    }
    if (step == 2) {
      if (_selectedPolicy == null || _selectedPolicy!.isEmpty) {
        AppToast.showError('Select a Maintenance Policy');
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
          _req(_facilityNumber.text, 'Facility Number') != null) {
        AppToast.showError('Complete all required Annual Safety / CVIP fields');
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

    // Add-mode only — matches the web app, which skips re-attaching the
    // scanned document to the trailer record when editing.
    if (!widget.isEdit && _browseFilePath != null && result.data != null) {
      await TrailerService.instance.uploadDocumentFull(
        trailerId: result.data!.id,
        filePath: _browseFilePath!,
        fileName: _browseFileName ?? 'document',
        vinNumber: _vin.text.trim(),
        companyId: AuthService.instance.selectedCompanyId,
      );
    }

    if (!mounted) return;
    setState(() => _saving = false);
    AppToast.showSuccess(widget.isEdit ? 'Trailer updated' : 'Trailer created');
    Navigator.pop(context, true);
  }

  Future<void> _pickFromCamera() async {
    try {
      final picker = ImagePicker();
      final XFile? photo = await picker.pickImage(source: ImageSource.camera);
      if (photo == null) return;
      await _runOcrScan(photo.path, photo.name);
    } catch (e) {
      AppToast.showError('Failed to capture image: $e');
    }
  }

  Future<void> _pickFromFiles() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
    );
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.first;
    if (file.path == null) {
      setState(() {
        _browseFileName = file.name;
        _browseFilePath = null;
      });
      return;
    }
    await _runOcrScan(file.path!, file.name);
  }

  Future<void> _scanDocument() async {
    try {
      final pages = await CunningDocumentScanner.getPictures(
        noOfPages: 1,
        scannerSource: ScannerSource.camera,
      );
      if (pages == null || pages.isEmpty) return;
      final path = pages.first;
      await _runOcrScan(path, path.split('/').last);
    } catch (e) {
      AppToast.showError('Failed to scan document: $e');
    }
  }

  Future<void> _runOcrScan(String filePath, String fileName) async {
    setState(() {
      _browseFileName = fileName;
      _browseFilePath = filePath;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        backgroundColor: Colors.black87,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Extracting information…',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );

    final prefill = await OcrService.instance.scanAndExtract(
      filePath: filePath,
      fileName: fileName,
      companyId: AuthService.instance.selectedCompanyId,
    );

    if (!mounted) return;
    Navigator.pop(context);

    if (prefill == null) {
      AppToast.showError(
        'No data could be extracted — you can still fill the form manually',
      );
      return;
    }
    _applyOcrPrefill(prefill);
    AppToast.showSuccess('Document scanned — fields auto-filled');
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
      fill(_specGvwr, prefill['gvwr']);
      fillDate(_purchaseDate, prefill['purchaseDate']);
      fill(_currentOdometer, prefill['odometer']);
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

  Future<void> _next() async {
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
              widget.isEdit ? 'Edit Trailer' : 'Add Trailer',
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
    WebFileUploadZone(
      fileName: _browseFileName,
      filePath: _browseFilePath,
      onBrowse: _pickFromFiles,
      onCamera: _pickFromCamera,
      onScan: _scanDocument,
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
        WebDropdownField<int>(
          label: 'State / Province *',
          value: _stateId,
          items: _states.map((s) => s.id).toList(),
          itemLabel: (id) => _states.firstWhere((s) => s.id == id).name,
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
        WebDropdownField<int>(
          label: 'City',
          value: _cityId,
          items: _cities.map((c) => c.id).toList(),
          itemLabel: (id) => _cities.firstWhere((c) => c.id == id).name,
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

  List<Widget> _buildStep2() => [
    WebFormSection(
      title: 'Maintenance Policy & Schedule',
      initiallyExpanded: true,
      children: [
        WebDropdownField<String>(
          label: 'Maintenance Policy *',
          value: _selectedPolicy,
          items: _policies.map((p) => p.name).toList(),
          itemLabel: (v) => v,
          onChanged: (v) {
            setState(() => _selectedPolicy = v);
            _onFormChanged();
          },
          validator: (v) => _req(v, 'Maintenance Policy'),
        ),
        WebDateField(controller: _cviExpiry, label: 'CVI Expiry'),
        WebDateField(controller: _pmDueDate, label: 'PM Due Date'),
        WebTextFormField(
          controller: _pmDueOdometer,
          label: 'PM Due Odometer (km)',
          keyboardType: TextInputType.number,
          validator: (v) => _nonNegativeNumberValidator(v, 'PM Due Odometer'),
        ),
      ],
    ),
  ];

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
      backgroundColor: done || active ? AppColors.primary : AppColors.surfaceTertiary,
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
      padding: const EdgeInsets.fromLTRB(16, 12, 0, 16),
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
          Flexible(
            child: onContinue != null
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
          ),
        ],
      ),
    );
  }
}
