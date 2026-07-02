import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/models/work_order_model.dart';
import 'package:signature/signature.dart';

/// Captures a signature, then generates and shares a PDF summary of the
/// work order — mirrors the web app's client-only export (no backend
/// persistence of the PDF or the signature).
Future<void> exportWorkOrderPdf({
  required BuildContext context,
  required WorkOrderModel order,
}) async {
  final signatureBytes = await _captureSignature(context);
  if (signatureBytes == null || !context.mounted) return;

  final doc = await _buildPdf(order, signatureBytes);
  if (!context.mounted) return;

  await Printing.layoutPdf(
    onLayout: (_) => doc.save(),
    name: '${order.workOrderNumber.isNotEmpty ? order.workOrderNumber : 'work-order-${order.id}'}.pdf',
  );
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

Future<pw.Document> _buildPdf(
  WorkOrderModel order,
  Uint8List signatureBytes,
) async {
  final doc = pw.Document();
  final details = order.workOrderDetails;
  final signatureImage = pw.MemoryImage(signatureBytes);

  String fmt(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}/${d.year}';
  }

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (context) => [
        pw.Text(
          order.workOrderNumber.isNotEmpty
              ? order.workOrderNumber
              : 'Work Order #${order.id}',
          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          '${order.status.label} · ${order.isPreventativeMaintenance ? 'Preventive Maintenance' : 'Repair'}',
          style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
        ),
        pw.Divider(),
        pw.Table(
          columnWidths: const {
            0: pw.FlexColumnWidth(1),
            1: pw.FlexColumnWidth(2),
            2: pw.FlexColumnWidth(1),
            3: pw.FlexColumnWidth(2),
          },
          children: [
            _row('Unit', order.unitNumber, 'Priority',
                order.priority?.label ?? '—'),
            _row('Location', details?.location ?? '—', 'Assignee',
                details?.technicianName ?? 'Unassigned'),
            _row('Start Date', fmt(details?.startDate), 'Due Date',
                fmt(details?.dueDate)),
            _row('Odometer', details?.odometer ?? '—', 'Est. Cost',
                details?.estimatedCost != null
                    ? '\$${details!.estimatedCost!.toStringAsFixed(2)}'
                    : '—'),
            if (order.totalLabourHours != null || order.totalLabourCost != null)
              _row(
                'Labour Hours',
                order.totalLabourHours?.toString() ?? '—',
                'Labour Cost',
                order.totalLabourCost != null
                    ? '\$${order.totalLabourCost!.toStringAsFixed(2)}'
                    : '—',
              ),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Text('Issue Description',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.Text(order.issueDescription),
        if (order.workOrderParts.isNotEmpty) ...[
          pw.SizedBox(height: 16),
          pw.Text('Repairs / Parts',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: ['Part', 'Qty', 'Status', 'Description'],
            data: order.workOrderParts
                .map((p) => [
                      p.partCode ?? p.partName ?? '—',
                      p.quantityUsed?.toString() ?? '—',
                      p.repairStatus.label,
                      p.description ?? '—',
                    ])
                .toList(),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerStyle:
                pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
        ],
        if (order.isPreventativeMaintenance &&
            order.pmInspectionResults.isNotEmpty) ...[
          pw.SizedBox(height: 16),
          pw.Text('PM Inspection Summary',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: ['Item', 'Result', 'Checked'],
            data: order.pmInspectionResults
                .map((r) => [
                      r.itemName ?? 'Item #${r.itemId}',
                      r.code.label,
                      r.isChecked ? 'Yes' : 'No',
                    ])
                .toList(),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerStyle:
                pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
        ],
        if (order.pmDefects.isNotEmpty) ...[
          pw.SizedBox(height: 16),
          pw.Text('Defects',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: ['#', 'Defect', 'Qty', 'Action'],
            data: order.pmDefects
                .map((d) => [
                      d.rowNo.toString(),
                      d.defectDescription ?? '—',
                      d.quantity?.toString() ?? '—',
                      d.actionTaken ?? '—',
                    ])
                .toList(),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerStyle:
                pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
        ],
        if (order.resolutionNotes != null &&
            order.resolutionNotes!.isNotEmpty) ...[
          pw.SizedBox(height: 16),
          pw.Text('Resolution Notes',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text(order.resolutionNotes!),
        ],
        pw.SizedBox(height: 32),
        pw.Text('Technician Signature',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.Container(
          height: 80,
          width: 200,
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey)),
          ),
          child: pw.Image(signatureImage, fit: pw.BoxFit.contain),
        ),
      ],
    ),
  );

  return doc;
}

pw.TableRow _row(String label1, String value1, String label2, String value2) {
  pw.Widget cell(String text, {bool bold = false}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: bold ? PdfColors.grey700 : PdfColors.black,
          ),
        ),
      );
  return pw.TableRow(children: [
    cell(label1, bold: true),
    cell(value1),
    cell(label2, bold: true),
    cell(value2),
  ]);
}
