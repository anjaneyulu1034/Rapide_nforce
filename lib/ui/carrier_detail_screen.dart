import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:rapide_nforce/ui/widgets/gradient_page_background.dart';
import 'package:rapide_nforce/core/utils/api_feedback.dart';
import 'package:rapide_nforce/core/utils/app_toast.dart';
import 'package:rapide_nforce/models/carrier_model.dart';
import 'package:rapide_nforce/services/carrier_service.dart';
import 'package:rapide_nforce/ui/carrier_form_screen.dart';
import 'package:rapide_nforce/ui/widgets/screen_state_builder.dart';
import 'package:rapide_nforce/ui/widgets/status_chip.dart';
import 'package:rapide_nforce/ui/widgets/vehicle_info_section.dart';
import 'package:rapide_nforce/ui/widgets/web_ui.dart';

class CarrierDetailScreen extends StatefulWidget {
  const CarrierDetailScreen({super.key, required this.carrierId});

  final int carrierId;

  @override
  State<CarrierDetailScreen> createState() => _CarrierDetailScreenState();
}

class _CarrierDetailScreenState extends State<CarrierDetailScreen> {
  bool _loading = true;
  String? _error;
  CarrierModel? _carrier;
  bool _uploadingConsent = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result =
        await CarrierService.instance.fetchCarrierById(widget.carrierId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result.isSuccess) {
        _carrier = result.data;
      } else {
        _error = result.message ?? 'Failed to load carrier';
      }
    });
  }

  Future<void> _uploadConsent() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
    );
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.first;
    if (file.path == null) return;

    setState(() => _uploadingConsent = true);
    final result = await CarrierService.instance.uploadConsentForCompany(
      companyId: widget.carrierId,
      filePath: file.path!,
      fileName: file.name,
    );
    if (!mounted) return;
    setState(() => _uploadingConsent = false);

    if (result.isSuccess) {
      AppToast.showSuccess('Consent document uploaded');
      _load();
      Navigator.of(context).pop(true);
    } else {
      ApiFeedback.showError(result, fallback: 'Failed to upload consent');
    }
  }

  Future<void> _openEdit() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CarrierFormScreen(carrierId: widget.carrierId),
      ),
    );
    if (changed == true) {
      _load();
      if (mounted) Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final carrier = _carrier;
    return GradientPageBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          carrier?.displayName ?? 'Carrier Details',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          if (carrier != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: _openEdit,
            ),
        ],
      ),
      body: ScreenStateBuilder(
        loading: _loading,
        error: _error,
        onRetry: _load,
        child: carrier == null
            ? const SizedBox.shrink()
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      StatusChip.consent(carrier.consentStatusLabel),
                      const SizedBox(width: 8),
                      carrier.isActive == false
                          ? StatusChip.inactive('Inactive')
                          : StatusChip.active('Active'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  VehicleInfoSection(
                    title: 'Company Information',
                    rows: [
                      VehicleInfoRow(
                        label: 'Legal Name',
                        value: carrier.displayName,
                      ),
                      if (carrier.dba != null)
                        VehicleInfoRow(label: 'DBA', value: carrier.dba!),
                      VehicleInfoRow(
                        label: 'Email',
                        value: carrier.email ?? '—',
                      ),
                      VehicleInfoRow(
                        label: 'Phone',
                        value: carrier.phone ?? '—',
                      ),
                      VehicleInfoRow(
                        label: 'Start Date',
                        value: carrier.startDate ?? '—',
                      ),
                      VehicleInfoRow(
                        label: 'Address',
                        value: carrier.address ?? '—',
                      ),
                      VehicleInfoRow(
                        label: 'City',
                        value: carrier.city ?? '—',
                      ),
                      VehicleInfoRow(
                        label: 'Province',
                        value: carrier.province ?? '—',
                      ),
                      VehicleInfoRow(
                        label: 'Postal Code',
                        value: carrier.postalCode ?? '—',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  VehicleInfoSection(
                    title: 'Regulatory',
                    rows: [
                      VehicleInfoRow(
                        label: 'CVOR #',
                        value: carrier.cvorNumber ?? '—',
                      ),
                      VehicleInfoRow(
                        label: 'NSC #',
                        value: carrier.nscNumber ?? '—',
                      ),
                      VehicleInfoRow(
                        label: 'USDOT #',
                        value: carrier.usdotNumber ?? '—',
                      ),
                      VehicleInfoRow(
                        label: 'MC #',
                        value: carrier.mcNumber ?? '—',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  VehicleInfoSection(
                    title: 'Subscription',
                    rows: [
                      VehicleInfoRow(
                        label: 'Plan',
                        value: carrier.planName ?? '—',
                      ),
                      VehicleInfoRow(
                        label: 'Billing Cycle',
                        value: carrier.billingCycleName ?? '—',
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  WebPrimaryButton(
                    label: _uploadingConsent
                        ? 'Uploading…'
                        : 'Upload Consent Document',
                    onPressed: _uploadingConsent ? null : _uploadConsent,
                    icon: Icons.upload_file_outlined,
                  ),
                ],
              ),
      ),
    ),
  );
}
}
