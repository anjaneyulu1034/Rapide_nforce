import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/models/work_order_model.dart';
import 'package:rapide_nforce/services/auth_service.dart';
import 'package:rapide_nforce/services/carrier_service.dart';
import 'package:rapide_nforce/services/maintenance_service.dart';
import 'package:signature/signature.dart';

/// Captures a signature, then generates and shares a PDF summary of the
/// work order — mirrors the web app's "Repair Work Order" PDF export
/// (client-only, no backend persistence of the PDF or the signature).
Future<void> exportWorkOrderPdf({
  required BuildContext context,
  required WorkOrderModel order,
}) async {
  final signatureBytes = await _captureSignature(context);
  if (signatureBytes == null || !context.mounted) return;

  final techResult = await MaintenanceService.instance.getTechnicians();
  final technicians = techResult.data ?? const <TechnicianSummary>[];
  if (!context.mounted) return;

  final logoBytes = await _fetchCompanyLogo(order.companyId);
  if (!context.mounted) return;

  final doc = await _buildPdf(order, signatureBytes, technicians, logoBytes);
  if (!context.mounted) return;

  await Printing.layoutPdf(
    onLayout: (_) => doc.save(),
    name: '${order.workOrderNumber.isNotEmpty ? order.workOrderNumber : 'work-order-${order.id}'}.pdf',
  );
}

/// Best-effort logo fetch — the PDF still renders (with the company name as
/// a text fallback) if the carrier has no logo or the request fails.
Future<Uint8List?> _fetchCompanyLogo(int? companyId) async {
  if (companyId == null) return null;
  try {
    final result = await CarrierService.instance.getLogo(companyId);
    final logoUrl = result.data;
    if (logoUrl == null || logoUrl.isEmpty) return null;
    final response = await http.get(Uri.parse(logoUrl));
    if (response.statusCode != 200) return null;
    return response.bodyBytes;
  } catch (_) {
    return null;
  }
}

Future<Uint8List?> _captureSignature(BuildContext context) {
  return showModalBottomSheet<Uint8List?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _SignatureSheet(),
  );
}

class _SignatureSheet extends StatefulWidget {
  const _SignatureSheet();

  @override
  State<_SignatureSheet> createState() => _SignatureSheetState();
}

class _SignatureSheetState extends State<_SignatureSheet> {
  final _controller = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_controller.isEmpty) return;
    final bytes = await _controller.toPngBytes();
    if (mounted) Navigator.pop(context, bytes);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Sign to export PDF',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: AppColors.textSecondary),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Signature(
              controller: _controller,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _controller.clear(),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Clear'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1A1A1A),
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Save & Export'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

const _emptyCell = '-';
const _cellBorder = pw.TableBorder();

String _fmtDate(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  return '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}-${d.year}';
}

String _fmtToday() {
  final d = DateTime.now();
  return '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}-${d.year}';
}

String _technicianName(List<TechnicianSummary> technicians, int? id) {
  if (id == null) return _emptyCell;
  for (final t in technicians) {
    if ((t.userId != 0 ? t.userId : t.id) == id) return t.name;
  }
  return _emptyCell;
}

Future<pw.Document> _buildPdf(
  WorkOrderModel order,
  Uint8List signatureBytes,
  List<TechnicianSummary> technicians,
  Uint8List? logoBytes,
) async {
  final doc = pw.Document();
  final details = order.workOrderDetails;
  final signatureImage = pw.MemoryImage(signatureBytes);
  final logoImage = logoBytes != null ? pw.MemoryImage(logoBytes) : null;
  final isCompleted = order.status == WorkOrderStatus.completed;

  final user = AuthService.instance.currentUser;
  final role = (user?.role ?? '').toLowerCase();
  final isLeadTechnician = role.contains('lead') && role.contains('technician');
  final isAdmin = role == 'admin' || role.contains('super');

  final certificationText = isLeadTechnician
      ? "I certify that I reviewed this vehicle during the work order process in accordance with the Lead Technician's guidelines and procedures"
      : isAdmin
          ? 'I certify that I have reviewed and authorized this work order as an Admin'
          : "I certify that I reviewed this vehicle during the work order process in accordance with the Technician's guidelines and procedures";

  final nameLabel = isLeadTechnician
      ? 'Lead Technician Name:'
      : isAdmin
          ? 'Admin Name:'
          : 'Technician Name:';

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.letter,
      margin: const pw.EdgeInsets.fromLTRB(30, 40, 30, 40),
      build: (context) => [
        _header(order, logoImage),
        pw.SizedBox(height: 10),
        _infoGrid(order, details, isCompleted),
        if ((order.notes.isNotEmpty ? order.notes.first.description : '')
            .trim()
            .isNotEmpty) ...[
          pw.SizedBox(height: 8),
          _wrappedBox('Notes:', order.notes.first.description),
        ],
        pw.SizedBox(height: 12),
        _repairTable(order, technicians),
        pw.SizedBox(height: 10),
        _totalsAndCost(order, details),
        pw.SizedBox(height: 12),
        _wrappedBox(
          'Resolution Notes:',
          (order.resolutionNotes ?? '').trim().isNotEmpty
              ? order.resolutionNotes!
              : 'No Resolution Notes Available',
        ),
        pw.SizedBox(height: 16),
        pw.Text(certificationText, style: const pw.TextStyle(fontSize: 9)),
        pw.SizedBox(height: 24),
        _signatureBlock(nameLabel, user?.name, signatureImage),
      ],
    ),
  );

  return doc;
}

pw.Widget _header(WorkOrderModel order, pw.MemoryImage? logoImage) {
  final title = order.isPreventativeMaintenance
      ? 'Preventive Maintenance Work Order'
      : 'Repair Work Order';
  return pw.Container(
    height: 60,
    decoration: pw.BoxDecoration(
      color: PdfColor.fromInt(0xFFFAFAFC),
      border: pw.Border.all(color: PdfColors.black, width: 1),
    ),
    padding: const pw.EdgeInsets.symmetric(horizontal: 15),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Expanded(
          child: logoImage != null
              ? pw.Container(
                  height: 45,
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                )
              : pw.Text(
                  order.companyName ?? '',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
                ),
        ),
        pw.Expanded(
          flex: 2,
          child: pw.Center(
            child: pw.Text(
              title,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18),
            ),
          ),
        ),
        pw.Expanded(
          child: pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.RichText(
              text: pw.TextSpan(children: [
                pw.TextSpan(
                  text: 'Date: ',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                ),
                pw.TextSpan(text: _fmtToday(), style: const pw.TextStyle(fontSize: 10)),
              ]),
            ),
          ),
        ),
      ],
    ),
  );
}

pw.Widget _infoCell(String label, String value) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(value, style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
    );

pw.Widget _splitOdometerCell(String? startOdo, String? endOdo) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Start Odometer:',
                    style: pw.TextStyle(
                        fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                pw.SizedBox(height: 2),
                pw.Text(startOdo ?? '—', style: const pw.TextStyle(fontSize: 8)),
              ],
            ),
          ),
          pw.Container(width: 0.8, height: 26, color: PdfColors.black),
          pw.SizedBox(width: 6),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('End Odometer:',
                    style: pw.TextStyle(
                        fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                pw.SizedBox(height: 2),
                pw.Text(endOdo ?? '—', style: const pw.TextStyle(fontSize: 8)),
              ],
            ),
          ),
        ],
      ),
    );

pw.Widget _infoGrid(
  WorkOrderModel order,
  WorkOrderDetails? details,
  bool isCompleted,
) {
  final unit = details?.odometerDisplayUnit ?? 'km';
  final odometerCell = isCompleted
      ? _splitOdometerCell(
          details?.startOdometer != null ? '${details!.startOdometer} $unit' : null,
          details?.endOdometer != null ? '${details!.endOdometer} $unit' : null,
        )
      : _infoCell(
          'Odometer:',
          details?.odometer != null ? '${details!.odometer} $unit' : '—',
        );

  final rows = <List<pw.Widget>>[
    [
      _infoCell('Plate:', order.plateNumber ?? '—'),
      _infoCell('Unit:', order.unitNumber),
      _infoCell('VIN:', order.vin ?? '—'),
    ],
    [
      _infoCell('Make:', order.make ?? '—'),
      _infoCell('Year:', order.year ?? '—'),
      odometerCell,
    ],
    [
      _infoCell('Created By:', order.createdByName ?? '—'),
      _infoCell(
        'Work Order #:',
        order.workOrderNumber.isNotEmpty ? order.workOrderNumber : '—',
      ),
      _infoCell('Due Date:', _fmtDate(details?.dueDate)),
    ],
    [
      _infoCell('Priority:', order.priority?.label ?? '—'),
      _infoCell('Start Date:', _fmtDate(details?.startDate)),
      _infoCell('End Date:', _fmtDate(details?.endDate)),
    ],
    [
      _infoCell('Unit Type:', order.entityTypeName ?? '—'),
      _infoCell('Status:', order.status.label),
      _infoCell('Company:', order.companyName ?? '—'),
    ],
  ];

  return pw.Table(
    border: pw.TableBorder.all(color: PdfColors.black, width: 0.8),
    columnWidths: const {
      0: pw.FlexColumnWidth(1),
      1: pw.FlexColumnWidth(1),
      2: pw.FlexColumnWidth(1),
    },
    children: rows.map((r) => pw.TableRow(children: r)).toList(),
  );
}

pw.Widget _wrappedBox(String label, String value) => pw.Container(
      width: double.infinity,
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 0.8)),
      padding: const pw.EdgeInsets.all(8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label,
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 3),
          pw.Text(value, style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
    );

String _fmtHours(num? hours) {
  if (hours == null) return _emptyCell;
  final totalMinutes = (hours.toDouble() * 60).round();
  final h = totalMinutes ~/ 60;
  final m = totalMinutes % 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:00';
}

pw.Widget _repairTable(WorkOrderModel order, List<TechnicianSummary> technicians) {
  final headers = [
    'Description',
    'Repaired By',
    'Repair Status',
    'Reference',
    'Assign To',
    'Notes',
    'Part Type',
    'Hours',
  ];

  final data = order.workOrderParts.isEmpty
      ? List<List<String>>.generate(6, (_) => List.filled(headers.length, _emptyCell))
      : order.workOrderParts
          .map((p) => [
                (p.description ?? '').trim().isNotEmpty ? p.description! : 'No description',
                p.repairPerformedBy.label,
                p.repairStatus.label,
                _emptyCell,
                _technicianName(technicians, p.assignedTechnicianId),
                (p.repairNotes ?? '').trim().isNotEmpty ? p.repairNotes! : _emptyCell,
                p.partTypeName ?? p.partCode ?? p.partName ?? _emptyCell,
                _fmtHours(p.defectHours),
              ])
          .toList();

  return pw.TableHelper.fromTextArray(
    border: _cellBorder,
    headers: headers,
    data: data,
    headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF2F2F2)),
    headerStyle: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
    cellStyle: const pw.TextStyle(fontSize: 8),
    cellAlignment: pw.Alignment.centerLeft,
    columnWidths: const {
      0: pw.FlexColumnWidth(2.2),
      1: pw.FlexColumnWidth(1),
      2: pw.FlexColumnWidth(1.2),
      3: pw.FlexColumnWidth(1),
      4: pw.FlexColumnWidth(1.4),
      5: pw.FlexColumnWidth(1.4),
      6: pw.FlexColumnWidth(1.2),
      7: pw.FlexColumnWidth(1),
    },
    cellDecoration: (index, data, rowNum) =>
        pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 0.8)),
  );
}

pw.Widget _totalsAndCost(WorkOrderModel order, WorkOrderDetails? details) {
  final hoursText = order.totalLabourHours != null && order.totalLabourHours != 0
      ? _fmtHours(order.totalLabourHours)
      : null;
  final costText = order.totalLabourCost != null
      ? '\$${order.totalLabourCost!.toStringAsFixed(2)}'
      : '\$0.00';
  final estimatedText = details?.estimatedCost != null
      ? '\$${details!.estimatedCost!.toStringAsFixed(2)}'
      : '\$0.00';

  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (hoursText != null)
              pw.Text('Total Labour Hours: $hoursText',
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text('Total Labour Cost: $costText',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          ],
        ),
      ),
      pw.Text('Estimated Cost: $estimatedText',
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
    ],
  );
}

pw.Widget _signatureBlock(String nameLabel, String? technicianName, pw.MemoryImage signatureImage) {
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Expanded(
        child: pw.RichText(
          text: pw.TextSpan(children: [
            pw.TextSpan(
                text: nameLabel,
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
            pw.TextSpan(text: '  ${technicianName ?? '—'}', style: const pw.TextStyle(fontSize: 9)),
          ]),
        ),
      ),
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Signature:',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
            pw.SizedBox(height: 4),
            pw.Container(
              height: 40,
              width: 160,
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey)),
              ),
              child: pw.Image(signatureImage, fit: pw.BoxFit.contain),
            ),
          ],
        ),
      ),
    ],
  );
}
