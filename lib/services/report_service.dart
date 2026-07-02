import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/constants/api_constants.dart';
import 'package:rapide_nforce/core/models/api_result.dart';
import 'package:rapide_nforce/core/models/paginated_result.dart';
import 'package:rapide_nforce/core/utils/api_parse.dart';
import 'package:rapide_nforce/services/api_client.dart';
import 'package:rapide_nforce/services/auth_service.dart';

class ReportDefinition {
  const ReportDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.icon,
    this.enabled = false,
    this.superAdminOnly = false,
  });

  final String id;
  final String title;
  final String description;
  final String category;
  final IconData icon;
  final bool enabled;
  final bool superAdminOnly;
}

class OcrAuditLog {
  const OcrAuditLog({
    required this.id,
    required this.documentType,
    required this.status,
    required this.processingAttempts,
    required this.companyName,
    this.errorMessage,
  });

  final int id;
  final String documentType;
  final String status;
  final int processingAttempts;
  final String companyName;
  final String? errorMessage;

  factory OcrAuditLog.fromJson(Map<String, dynamic> json) {
    return OcrAuditLog(
      id: json['id'] as int? ?? 0,
      documentType: json['documentType'] as String? ?? 'Unknown',
      status: json['status'] as String? ?? '—',
      processingAttempts: json['processingAttempts'] as int? ?? 0,
      companyName: json['companyName'] as String? ?? '—',
      errorMessage: json['errorMessage'] as String?,
    );
  }
}

class FleetMaintenanceRow {
  const FleetMaintenanceRow({
    required this.unitNo,
    required this.vin,
    required this.plate,
    required this.make,
    required this.model,
  });

  final String unitNo;
  final String vin;
  final String plate;
  final String make;
  final String model;

  factory FleetMaintenanceRow.fromJson(Map<String, dynamic> json) {
    final vehicle =
        json['vehicleInfo'] ?? json['vehicle_info'] ?? json['vehicle'];
    final vehicleMap = vehicle is Map
        ? Map<String, dynamic>.from(vehicle)
        : null;

    String pick(List<String> keys) {
      for (final key in keys) {
        final value = json[key] ?? vehicleMap?[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString().trim();
        }
      }
      return '—';
    }

    return FleetMaintenanceRow(
      unitNo: pick(['unitNo', 'unit_no', 'unitNumber', 'unit_number', 'unit']),
      vin: pick(['vin', 'vinNumber', 'vin_number']),
      plate: pick(['plate', 'licensePlate', 'license_plate_number']),
      make: pick(['make']),
      model: pick(['model']),
    );
  }
}

class ReportService {
  ReportService._();

  static final ReportService instance = ReportService._();

  final ApiClient _api = ApiClient.instance;

  static const assetTypePowerUnit = 'power_unit';
  static const assetTypeTrailer = 'trailer';

  static int? assetTypeToEntityTypeId(String? assetType) {
    final normalized = (assetType ?? '').trim().toLowerCase();
    if (normalized.contains('power') ||
        normalized == 'truck' ||
        normalized == 'powerunit') {
      return 1;
    }
    if (normalized.contains('trailer')) return 2;
    return null;
  }

  static const availableReports = [
    ReportDefinition(
      id: 'fleet-maintenance',
      title: 'Fleet Maintenance Report',
      description: 'Maintenance schedules, work orders, and service history',
      category: 'Maintenance',
      icon: Icons.local_shipping_outlined,
      enabled: true,
    ),
    ReportDefinition(
      id: 'ocr-audit',
      title: 'OCR Audit Logs Report',
      description:
          'Monitor OCR processing activity, identify failures, and analyze extraction performance',
      category: 'OCR Audit Report',
      icon: Icons.description_outlined,
      enabled: true,
      superAdminOnly: true,
    ),
    ReportDefinition(
      id: 'driver-safety',
      title: 'Driver Safety Summary',
      description:
          'Comprehensive safety scores, violations, and incident history for drivers',
      category: 'Safety & Compliance',
      icon: Icons.people_outline,
    ),
    ReportDefinition(
      id: 'telematics',
      title: 'Telematics Activity Summary',
      description:
          'Driver behavior metrics, HOS compliance, and telematics data',
      category: 'Operations',
      icon: Icons.bar_chart_outlined,
    ),
    ReportDefinition(
      id: 'expired-docs',
      title: 'Expired Documents Report',
      description: 'Documents approaching expiration or already expired',
      category: 'Safety & Compliance',
      icon: Icons.warning_amber_outlined,
    ),
    ReportDefinition(
      id: 'hos',
      title: 'HOS Compliance Report',
      description: 'Hours of Service violations and compliance trends',
      category: 'Safety & Compliance',
      icon: Icons.schedule_outlined,
    ),
    ReportDefinition(
      id: 'utilization',
      title: 'Vehicle Utilization Report',
      description: 'Fleet usage statistics, mileage, and efficiency metrics',
      category: 'Operations',
      icon: Icons.speed_outlined,
    ),
    ReportDefinition(
      id: 'incidents',
      title: 'Incident & Accident Report',
      description: 'Detailed accident history, claims, and incident trends',
      category: 'Safety & Compliance',
      icon: Icons.report_problem_outlined,
    ),
    ReportDefinition(
      id: 'driver-performance',
      title: 'Driver Performance Report',
      description: 'Individual driver performance metrics and KPIs',
      category: 'Operations',
      icon: Icons.trending_up_outlined,
    ),
  ];

  Future<ApiResult<PaginatedResult<OcrAuditLog>>> fetchOcrAuditLogs({
    String dateRange = '30',
    int page = 1,
    int limit = 50,
    int? companyId,
    String? assetType,
  }) async {
    final cid = companyId ?? AuthService.instance.selectedCompanyIdInt;
    final entityTypeId = assetTypeToEntityTypeId(assetType);
    try {
      final body = await _api.parseJson(
        () => _api.get(
          ApiConstants.reportsOcrAuditLogs,
          params: {
            'dateRange': dateRange,
            'page': page,
            'limit': limit,
            'companyId': ?cid,
            'entityTypeId': ?entityTypeId,
          },
          companyId: cid?.toString(),
        ),
        onSuccess: (b) => b,
      );

      final items = ApiParse.listItems(body).map(OcrAuditLog.fromJson).toList();
      final pagination = ApiParse.pagination(body);

      return ApiResult.ok(
        PaginatedResult(
          items: items,
          total: pagination['total'] as int? ?? items.length,
          page: pagination['page'] as int? ?? page,
          limit: pagination['limit'] as int? ?? limit,
          totalPages: pagination['totalPages'] as int? ?? 1,
        ),
      );
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to load OCR audit logs.');
    }
  }

  Future<ApiResult<List<FleetMaintenanceRow>>> fetchFleetMaintenanceReport({
    String timeframe = 'Last 30 Days',
    String assetType = assetTypePowerUnit,
    int? companyId,
  }) async {
    final cid = companyId ?? AuthService.instance.selectedCompanyIdInt;
    try {
      final body = await _api.parseJson(
        () => _api.get(
          ApiConstants.reportsTruckSafety,
          params: {
            'dateRange': timeframe,
            'assetType': assetType,
            'companyId': ?cid,
          },
          companyId: cid?.toString(),
        ),
        onSuccess: (b) => b,
      );

      final rows = ApiParse.listItems(
        body,
      ).map(FleetMaintenanceRow.fromJson).toList();
      return ApiResult.ok(rows);
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to load fleet maintenance report.');
    }
  }
}
