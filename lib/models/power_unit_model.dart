import 'package:intl/intl.dart';
import 'package:rapide_nforce/models/truck_permit_model.dart';

class PowerUnitModel {
  const PowerUnitModel({
    required this.id,
    required this.name,
    required this.unitNumber,
    required this.status,
    this.lastService,
    this.vinNumber,
    this.licensePlate,
    this.vehicleType,
    this.make,
    this.model,
    this.year,
    this.state,
    this.startDate,
    this.registrationExpiry,
    this.companyId,
    this.companyName,
    this.registrationNumber,
    this.fuelType,
    this.odometer,
    this.color,
    this.purchaseDate,
    this.purchasePrice,
    this.assignedDriver,
    this.imsNumber,
    this.gvwr,
    this.transmission,
    this.engineMake,
    this.engineModel,
    this.ownershipType,
    this.ownerName,
    this.ownerEmail,
    this.ownerPhone,
    this.ownerAddress,
    this.countryId,
    this.cityId,
    this.maintenancePolicy,
    this.cviExpiry,
    this.annualInspectionDue,
    this.lastInspection,
    this.lastPmDate,
    this.pmInterval,
    this.nextPmDue,
    this.lastPmEndOdometer,
    this.nextPmOdometer,
    this.kmUntilPm,
    this.telematicsProvider,
    this.telematicsEnabled,
    this.telematicsLastSynced,
    this.eldProvider,
    this.samsaraVehicleId,
    this.certificateNumber,
    this.inspectionDate,
    this.expiryDate,
    this.nextInspectionDue,
    this.inspectorName,
    this.inspectorLicense,
    this.inspectionFacility,
    this.facilityNumber,
    this.safetyLicensePlate,
    this.safetyVehicle,
    this.criticalDefects,
    this.majorDefects,
    this.advisoryItems,
    this.inspectionSummary,
    this.permits = const [],
    this.raw,
  });

  final int id;
  final String name;
  final String unitNumber;
  final String status;
  final String? lastService;
  final String? vinNumber;
  final String? licensePlate;
  final String? vehicleType;
  final String? make;
  final String? model;
  final int? year;
  final String? state;
  final String? startDate;
  final String? registrationExpiry;
  final int? companyId;
  final String? companyName;
  final String? registrationNumber;
  final String? fuelType;
  final int? odometer;
  final String? color;
  final String? purchaseDate;
  final num? purchasePrice;
  final String? assignedDriver;
  final String? imsNumber;
  final String? gvwr;
  final String? transmission;
  final String? engineMake;
  final String? engineModel;
  final String? ownershipType;
  final String? ownerName;
  final String? ownerEmail;
  final String? ownerPhone;
  final String? ownerAddress;
  final int? countryId;
  final int? cityId;
  final String? maintenancePolicy;
  final String? cviExpiry;
  final String? annualInspectionDue;
  final String? lastInspection;
  final String? lastPmDate;
  final String? pmInterval;
  final String? nextPmDue;
  final String? lastPmEndOdometer;
  final String? nextPmOdometer;
  final String? kmUntilPm;
  final String? telematicsProvider;
  final String? telematicsEnabled;
  final String? telematicsLastSynced;
  final String? eldProvider;
  final String? samsaraVehicleId;
  final String? certificateNumber;
  final String? inspectionDate;
  final String? expiryDate;
  final String? nextInspectionDue;
  final String? inspectorName;
  final String? inspectorLicense;
  final String? inspectionFacility;
  final String? facilityNumber;
  final String? safetyLicensePlate;
  final String? safetyVehicle;
  final int? criticalDefects;
  final int? majorDefects;
  final int? advisoryItems;
  final String? inspectionSummary;
  final List<TruckPermitModel> permits;
  final Map<String, dynamic>? raw;

  bool get isActive => status.toLowerCase() == 'active' || status == '1';
  bool get isOos =>
      status.toLowerCase() == 'oos' ||
      status.toLowerCase() == 'out of service' ||
      status.toLowerCase() == 'out_of_service';
  bool get isMaintenance =>
      status.toLowerCase() == 'maintenance' ||
      status.toLowerCase() == 'in maintenance' ||
      status.toLowerCase() == 'in_maintenance';

  String get displayTitle {
    final parts = <String>[];
    if (make != null && make!.isNotEmpty) parts.add(make!);
    if (model != null && model!.isNotEmpty) parts.add(model!);
    if (year != null) parts.add('($year)');
    return parts.isEmpty ? unitNumber : parts.join(' ');
  }

  factory PowerUnitModel.fromJson(Map<String, dynamic> json) {
    final active = json['active'];
    final statusVal = json['status'];
    String status;
    if (statusVal is String && statusVal.isNotEmpty) {
      final s = statusVal.toLowerCase();
      if (s == 'active' || s == '1') {
        status = 'Active';
      } else if (s == 'maintenance' || s == 'in maintenance' || s == 'in_maintenance') {
        status = 'Maintenance';
      } else if (s == 'oos' || s == 'out of service' || s == 'out_of_service') {
        status = 'OOS';
      } else if (s == 'inactive' || s == '0') {
        status = 'Inactive';
      } else {
        status = statusVal;
      }
    } else if (active == 1 || active == true || statusVal == 1) {
      status = 'Active';
    } else if (active == 0 || active == false || statusVal == 0) {
      status = 'Inactive';
    } else {
      status = 'Active';
    }

    final unit = json['truck_unit'] as String? ??
        json['truckUnit'] as String? ??
        json['name'] as String? ??
        json['unit_number'] as String? ??
        '';

    final permitsRaw = json['permits'] as List?;
    final permits = permitsRaw
            ?.map((e) => TruckPermitModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList() ??
        [];

    return PowerUnitModel(
      id: _toInt(json['id']) ?? 0,
      name: unit,
      unitNumber: unit,
      status: status,
      lastService: _formatDate(
        json['updated_on'] as String? ??
            json['updatedOn'] as String? ??
            json['last_edit'] as String?,
      ),
      vinNumber: json['vin_number'] as String? ?? json['vinNumber'] as String?,
      licensePlate: json['license_plate_number'] as String? ??
          json['licensePlateNumber'] as String? ??
          json['licenseplate'] as String?,
      vehicleType:
          json['vehicle_type'] as String? ?? json['vehicleType'] as String?,
      make: json['make'] as String?,
      model: json['model'] as String?,
      year: _toInt(json['year']),
      state: json['state'] as String? ?? json['plateProvince'] as String?,
      startDate: _formatDate(
        json['startDate'] as String? ?? json['start_date'] as String?,
      ),
      registrationExpiry: _formatDate(
        json['registrationExpiry'] as String? ??
            json['registration_expiry'] as String?,
      ),
      companyId: _toInt(json['companyId'] ?? json['company_id']),
      companyName: json['companyName'] as String? ??
          json['company_name'] as String?,
      registrationNumber: json['registrationNumber'] as String? ??
          json['rin'] as String?,
      fuelType: json['fuelType'] as String? ?? json['fuel_type'] as String?,
      odometer: _toInt(
        json['currentOdometer'] ?? json['current_odometer'] ?? json['odometer'],
      ),
      color: json['color'] as String?,
      purchaseDate: _formatDate(json['purchaseDate'] as String?),
      purchasePrice: _toNum(json['purchasePrice']),
      assignedDriver: json['assignedDriver'] as String?,
      imsNumber: json['imsNumber'] as String?,
      gvwr: json['gvwr']?.toString(),
      transmission: json['transmission'] as String?,
      engineMake: json['engineMake'] as String?,
      engineModel: json['engineModel'] as String?,
      ownershipType: json['ownership'] as String? ??
          json['ownershipType'] as String?,
      ownerName: json['ownerName'] as String?,
      ownerEmail: json['ownerEmail'] as String?,
      ownerPhone: json['ownerPhone'] as String?,
      ownerAddress: json['ownerAddress'] as String?,
      countryId: _toInt(json['countryId'] ?? json['country_id']),
      cityId: _toInt(json['cityId'] ?? json['city_id']),
      maintenancePolicy: json['maintenancePolicy'] as String?,
      cviExpiry: _formatDate(json['cviExpiry'] as String?),
      annualInspectionDue:
          _formatDate(json['annualInspectionDue'] as String?),
      lastInspection: _formatDate(json['lastInspection'] as String?),
      lastPmDate: _formatDate(
        json['lastPmDate'] as String? ?? json['last_pm_date'] as String?,
      ),
      pmInterval: json['pmInterval']?.toString(),
      nextPmDue: _formatDate(json['nextPmDue'] as String?),
      lastPmEndOdometer: json['lastPmEndOdometer']?.toString() ??
          json['last_pm_end_odometer']?.toString(),
      nextPmOdometer: json['nextPmOdometer']?.toString(),
      kmUntilPm: json['kmUntilPm']?.toString(),
      telematicsProvider: json['telematicsProvider'] as String?,
      telematicsEnabled: _telematicsLabel(json['telematicsEnabled']),
      telematicsLastSynced: json['telematicsLastSynced'] as String? ??
          json['telematics_last_synced'] as String?,
      eldProvider: json['eldProvider'] as String?,
      samsaraVehicleId: json['samsaraVehicleId'] as String?,
      certificateNumber: json['certificateNumber'] as String?,
      inspectionDate: _formatDate(json['inspectionDate'] as String?),
      expiryDate: _formatDate(json['expiryDate'] as String?),
      nextInspectionDue: _formatDate(
        json['nextInspectionDue'] as String? ??
            json['nextInspectionDueDate'] as String?,
      ),
      inspectorName: json['inspectorName'] as String?,
      inspectorLicense: json['inspectorLicense'] as String?,
      inspectionFacility: json['inspectorFacility'] as String? ??
          json['inspectionFacility'] as String?,
      facilityNumber: json['facilityNumber'] as String?,
      safetyLicensePlate: json['licenseplate'] as String?,
      safetyVehicle: json['vehicle'] as String?,
      criticalDefects: _toInt(json['criticalDefects']),
      majorDefects: _toInt(json['majorDefects']),
      advisoryItems: _toInt(json['advisoryItems']),
      inspectionSummary: json['inspectionSummary'] as String?,
      permits: permits,
      raw: json,
    );
  }

  static String? _telematicsLabel(dynamic value) {
    if (value == null) return null;
    if (value == 1 || value == true) return 'Active';
    if (value == 0 || value == false) return 'Inactive';
    return value.toString();
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  static num? _toNum(dynamic value) {
    if (value == null) return null;
    if (value is num) return value;
    return num.tryParse(value.toString());
  }

  static String? _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return iso;
    return DateFormat('MM-dd-yyyy').format(parsed.toLocal());
  }

  static String displayOrDash(String? value) =>
      value == null || value.trim().isEmpty ? '—' : value;
}
