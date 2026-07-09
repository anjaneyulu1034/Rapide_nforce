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
import 'package:rapide_nforce/models/truck_permit_model.dart';
import 'package:rapide_nforce/services/auth_service.dart';
import 'package:rapide_nforce/services/fleet_lookup_service.dart';
import 'package:rapide_nforce/services/ocr_service.dart';
import 'package:rapide_nforce/services/power_unit_service.dart';
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
  String? _browseFileName;

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
  List<LookupOption> _policies = [];
  List<LookupOption> _permitTypes = [];

  bool get _isSuperAdmin =>
      isSuperAdminRole(AuthService.instance.currentUser?.role);

  @override
  void initState() {
    super.initState();
    _startDate.text = DateTime.now().toIso8601String().split('T').first;
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final lookups = await Future.wait([
      FleetLookupService.instance.fetchCountries(),
      FleetLookupService.instance.fetchFuelTypes(),
      FleetLookupService.instance.fetchMaintenancePolicies(),
      FleetLookupService.instance.fetchPermitTypes(),
    ]);
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
  }

  PowerUnitModel? _unitForStateMatch;

  void _populate(PowerUnitModel u) {
    _unitNumber.text = u.unitNumber;
    _vin.text = u.vinNumber ?? '';
    _make.text = u.make ?? '';
    _model.text = u.model ?? '';
    _year.text = u.year?.toString() ?? '';
    _color.text = u.color ?? '';
    _purchaseDate.text = u.purchaseDate ?? '';
    _purchasePrice.text = u.purchasePrice?.toString() ?? '';
    _startDate.text = u.startDate ?? '';
    _status = u.isActive ? 'active' : 'inactive';
    _assignedDriver.text = u.assignedDriver ?? '';
    _plate.text = u.licensePlate ?? '';
    _countryId = u.countryId;
    _stateId = null;
    _cityId = u.cityId;
    _registrationNumber.text = u.registrationNumber ?? '';
    _registrationExpiry.text = u.registrationExpiry ?? '';
    _imsNumber.text = u.imsNumber ?? '';
    final ownershipType = (u.ownershipType ?? '').toLowerCase().trim();
    _ownershipType =
        ['owned', 'owner-operator'].contains(ownershipType)
            ? ownershipType
            : '';
    _ownerName.text = u.ownerName ?? '';
    _ownerEmail.text = u.ownerEmail ?? '';
    _ownerPhone.text = u.ownerPhone ?? '';
    _ownerAddress.text = u.ownerAddress ?? '';
    _gvwr.text = u.gvwr ?? '';
    _fuelType = u.fuelType;
    _transmission.text = u.transmission ?? '';
    _engineMake.text = u.engineMake ?? '';
    _engineModel.text = u.engineModel ?? '';
    _maintenancePolicy.text = u.maintenancePolicy ?? '';
    _selectedPolicy = u.maintenancePolicy;
    _cviExpiry.text = u.cviExpiry ?? '';
    _currentOdometer.text = u.odometer?.toString() ?? '';
    _annualInspectionDue.text = u.annualInspectionDue ?? '';
    _lastInspection.text = u.lastInspection ?? '';
    _pmInterval.text = u.pmInterval ?? '';
    _nextPmDue.text = u.nextPmDue ?? '';
    _nextPmOdometer.text = u.nextPmOdometer ?? '';
    _telematicsProvider.text = u.telematicsProvider ?? '';
    _telematicsEnabled =
        (u.telematicsEnabled ?? 'active').toLowerCase().contains('inact')
        ? 'inactive'
        : 'active';
    _eldProvider.text = u.eldProvider ?? '';
    _permits.addAll(u.permits);
    _certificateNumber.text = u.certificateNumber ?? '';
    _inspectionDate.text = u.inspectionDate ?? '';
    _expiryDate.text = u.expiryDate ?? '';
    _nextInspectionDue.text = u.nextInspectionDue ?? '';
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
      'purchaseDate': _purchaseDate.text.trim(),
      'purchasePrice': double.tryParse(_purchasePrice.text.trim()),
      'startDate': _startDate.text.trim(),
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
      'registrationExpiry': _registrationExpiry.text.trim(),
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
      'cviExpiry': _cviExpiry.text.trim(),
      'currentOdometer': toInt(_currentOdometer.text),
      'odometer': toInt(_currentOdometer.text),
      'annualInspectionDue': _annualInspectionDue.text.trim(),
      'lastInspection': _lastInspection.text.trim(),
      'pmInterval': toInt(_pmInterval.text),
      'nextPmDue': _nextPmDue.text.trim(),
      'nextPmOdometer': toInt(_nextPmOdometer.text),
      'telematicsProvider': _telematicsProvider.text.trim(),
      'telematicsEnabled': _telematicsEnabled,
      'eldProvider': _eldProvider.text.trim(),
      'certificateNumber': _certificateNumber.text.trim(),
      'inspectionDate': _inspectionDate.text.trim(),
      'expiryDate': _expiryDate.text.trim(),
      'nextInspectionDue': _nextInspectionDue.text.trim(),
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
      if (companyId != null) 'companyId': companyId,
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
      // No filesystem path available (e.g. some web/desktop pickers) — keep
      // the file attached but skip OCR, which needs a real path to upload.
      setState(() => _browseFileName = file.name);
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

  /// Uploads the picked/captured file, runs it through the real OCR
  /// pipeline (same `/documents` + `/ocr/ocr-results` flow the web app
  /// uses), and auto-fills blank form fields from whatever gets extracted.
  Future<void> _runOcrScan(String filePath, String fileName) async {
    setState(() => _browseFileName = fileName);

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

      final extractedFuelType = prefill['fuelType'];
      if ((_fuelType == null || _fuelType!.isEmpty) && extractedFuelType != null) {
        final match = _fuelTypes.where(
          (f) => f.name.toLowerCase() == extractedFuelType.toLowerCase(),
        );
        if (match.isNotEmpty) _fuelType = match.first.name;
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

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(
                    Icons.camera_alt_outlined,
                    color: AppColors.primary,
                  ),
                  title: const Text(
                    'Camera',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickFromCamera();
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.folder_open_outlined,
                    color: AppColors.primary,
                  ),
                  title: const Text(
                    'Browse File',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickFromFiles();
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.document_scanner_outlined,
                    color: AppColors.primary,
                  ),
                  title: const Text(
                    'Scan to File',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _scanDocument();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _addPermit() {
    if ((_selectedPermitType ?? '').isEmpty ||
        _permitNumber.text.trim().isEmpty ||
        _permitIssue.text.trim().isEmpty ||
        _permitExpiry.text.trim().isEmpty) {
      AppToast.showError('Fill all permit fields');
      return;
    }
    setState(() {
      _permits.add(
        TruckPermitModel(
          permitType: _selectedPermitType!,
          permitNumber: _permitNumber.text.trim(),
          issueDate: _permitIssue.text.trim(),
          expiryDate: _permitExpiry.text.trim(),
        ),
      );
      _permitNumber.clear();
      _permitIssue.clear();
      _permitExpiry.clear();
      _selectedPermitType = null;
    });
  }

  void _next() {
    if (!_validateStep(_step)) return;
    setState(() => _step++);
  }

  @override
  Widget build(BuildContext context) {
    return GradientPageBackground(
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
                    saving: _saving,
                    onPrevious: _step > 1
                        ? () => setState(() => _step--)
                        : null,
                    onCancel: () => Navigator.pop(context),
                    onContinue: _step < 3 ? _next : null,
                    onSave: _step == 3 ? _save : null,
                  ),
                ],
              ),
      ),
    );
  }

  List<Widget> _buildStep1() => [
    WebFileUploadZone(
      fileName: _browseFileName,
      onBrowse: _showAttachmentOptions,
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
          validator: (v) => _req(v, 'VIN'),
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
          validator: (v) => _req(v, 'Year'),
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
        ),
        WebTextFormField(
          controller: _purchasePrice,
          label: 'Purchase Price *',
          keyboardType: TextInputType.number,
          validator: (v) => _req(v, 'Purchase Price'),
        ),
        WebDateField(
          controller: _startDate,
          label: 'Start Date',
          required: true,
        ),
        WebDropdownField<String>(
          label: 'Status *',
          value: _status,
          items: const ['active', 'inactive'],
          itemLabel: (v) => v == 'active' ? 'Active' : 'Inactive',
          onChanged: (v) => setState(() => _status = v ?? 'active'),
        ),
        WebTextFormField(
          controller: _assignedDriver,
          label: 'Assigned Driver',
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
            if (v != null) await _loadStates(v);
          },
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
            if (v != null) await _loadCities(v);
          },
        ),
        WebDropdownField<int>(
          label: 'City',
          value: _cityId,
          items: _cities.map((c) => c.id).toList(),
          itemLabel: (id) => _cities.firstWhere((c) => c.id == id).name,
          onChanged: (v) => setState(() => _cityId = v),
        ),
        WebTextFormField(
          controller: _registrationNumber,
          label: 'Registration Number',
        ),
        WebDateField(
          controller: _registrationExpiry,
          label: 'Registration Expiry',
          required: true,
        ),
        WebTextFormField(controller: _imsNumber, label: 'IMS Number'),
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
          onChanged: (v) => setState(() => _ownershipType = v ?? ''),
        ),
        if (_ownershipType == 'owner-operator') ...[
          WebTextFormField(controller: _ownerName, label: 'Owner Name *'),
          WebTextFormField(controller: _ownerEmail, label: 'Owner Email *'),
          WebTextFormField(controller: _ownerPhone, label: 'Owner Phone *'),
          WebTextFormField(controller: _ownerAddress, label: 'Owner Address *'),
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
        ),
        WebDropdownField<String>(
          label: 'Fuel Type',
          value: _fuelType,
          items: _fuelTypes.map((f) => f.name).toList(),
          itemLabel: (v) => v,
          onChanged: (v) => setState(() => _fuelType = v),
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

  List<Widget> _buildStep2() => [
    WebFormSection(
      title: 'Maintenance Policy',
      children: [
        WebDropdownField<String>(
          label: 'Maintenance Policy *',
          value: _selectedPolicy,
          items: _policies.map((p) => p.name).toList(),
          itemLabel: (v) => v,
          onChanged: (v) => setState(() {
            _selectedPolicy = v;
            _maintenancePolicy.text = v ?? '';
          }),
        ),
        WebDateField(
          controller: _cviExpiry,
          label: 'CVIP/Annual Inspection Due',
          required: true,
        ),
        WebDateField(
          controller: _lastInspection,
          label: 'Last Inspection',
          required: true,
        ),
        WebTextFormField(
          controller: _currentOdometer,
          label: 'Current Odometer *',
          keyboardType: TextInputType.number,
        ),
        WebTextFormField(
          controller: _annualInspectionDue,
          label: 'Annual Inspection Due',
        ),
        WebTextFormField(
          controller: _pmInterval,
          label: 'PM Interval *',
          keyboardType: TextInputType.number,
        ),
        WebDateField(
          controller: _nextPmDue,
          label: 'Next PM Due',
          required: true,
        ),
        WebTextFormField(
          controller: _nextPmOdometer,
          label: 'Next PM Odometer *',
          keyboardType: TextInputType.number,
        ),
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
          onChanged: (v) => setState(() => _telematicsEnabled = v ?? 'active'),
        ),
        WebTextFormField(
          controller: _telematicsProvider,
          label: 'Telematics Provider *',
        ),
        WebTextFormField(controller: _eldProvider, label: 'ELD Provider *'),
      ],
    ),
    WebFormSection(
      title: 'Unit-Specific Permits',
      children: [
        WebDropdownField<String>(
          label: 'Permit Type *',
          value: _selectedPermitType,
          items: _permitTypes.map((p) => p.name).toList(),
          itemLabel: (v) => v,
          onChanged: (v) => setState(() => _selectedPermitType = v),
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
            subtitle: Text('${p.issueDate} → ${p.expiryDate}'),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => setState(() => _permits.remove(p)),
            ),
          ),
        ),
      ],
    ),
  ];

  List<Widget> _buildStep3() => [
    WebFormSection(
      title: 'Annual Safety / CVIP',
      children: [
        WebTextFormField(
          controller: _certificateNumber,
          label: 'Certificate Number *',
        ),
        WebDateField(
          controller: _inspectionDate,
          label: 'Inspection Date',
          required: true,
        ),
        WebDateField(
          controller: _expiryDate,
          label: 'Expiry Date',
          required: true,
        ),
        WebDateField(
          controller: _nextInspectionDue,
          label: 'Next Inspection Due',
          required: true,
        ),
        WebTextFormField(controller: _inspectorName, label: 'Inspector Name *'),
        WebTextFormField(
          controller: _inspectorLicense,
          label: 'Inspector License *',
        ),
        WebTextFormField(
          controller: _inspectionFacility,
          label: 'Inspection Facility *',
        ),
        WebTextFormField(
          controller: _facilityNumber,
          label: 'Facility Number *',
        ),
        WebTextFormField(controller: _safetyPlate, label: 'License Plate *'),
        WebTextFormField(controller: _safetyVehicle, label: 'Vehicle'),
        WebTextFormField(controller: _safetyVehicleType, label: 'Vehicle Type'),
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
    this.onPrevious,
    required this.onCancel,
    this.onContinue,
    this.onSave,
  });

  final int step;
  final bool saving;
  final VoidCallback? onPrevious;
  final VoidCallback onCancel;
  final VoidCallback? onContinue;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          if (onPrevious != null)
            OutlinedButton(
              onPressed: onPrevious,
              child: const Text('Previous'),
            ),
          const Spacer(),
          TextButton(
            onPressed: saving ? null : onCancel,
            child: const Text('Cancel'),
          ),
          const SizedBox(width: 8),
          if (onContinue != null)
            WebPrimaryButton(
              label: 'Continue',
              onPressed: onContinue,
              expand: false,
            )
          else
            WebPrimaryButton(
              label: 'Save Power Unit',
              loading: saving,
              onPressed: saving ? null : onSave,
              expand: false,
            ),
        ],
      ),
    );
  }
}
