import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/core/utils/app_toast.dart';
import 'package:rapide_nforce/models/driver_model.dart';
import 'package:rapide_nforce/services/driver_service.dart';
import 'package:rapide_nforce/ui/widgets/screen_state_builder.dart';
import 'package:rapide_nforce/ui/widgets/web_ui.dart';

enum DriverDetailTab {
  overview,
  personal,
  documents,
}

class DriverDetailScreen extends StatefulWidget {
  const DriverDetailScreen({super.key, required this.driverId});

  final int driverId;

  @override
  State<DriverDetailScreen> createState() => _DriverDetailScreenState();
}

class _DriverDetailScreenState extends State<DriverDetailScreen> {
  DriverDetailTab _tab = DriverDetailTab.overview;
  bool _loading = true;
  String? _error;
  DriverModel? _driver;

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

    final result = await DriverService.instance.fetchDriverById(widget.driverId);
    if (!mounted) return;

    if (!result.isSuccess) {
      setState(() {
        _loading = false;
        _error = result.message ?? 'Failed to load driver details';
      });
      return;
    }

    setState(() {
      _loading = false;
      _driver = result.data;
    });
  }

  Widget detailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value?.trim().isNotEmpty == true ? value!.trim() : '—',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(DriverModel d) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          detailRow('Driver ID', d.driverId),
          detailRow('Mobile Number', d.mobile),
          detailRow('Email Address', d.email),
          detailRow('License Number', d.driverLicense),
          detailRow('License Class', d.licenseClass),
          detailRow('License Expiry', d.licenseExpiry),
          detailRow('License Province', d.province),
          detailRow('Hire Date', d.hireDate),
          detailRow('Application Date', d.applicationDate),
          detailRow('Driver Type', d.driverType),
          detailRow('Canada Only', d.canadaOnly),
          detailRow('USA Only', d.usaOnly),
        ],
      ),
    );
  }

  Widget _buildPersonalTab(DriverModel d) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          detailRow('Street Address', d.streetAddress ?? d.address),
          detailRow('City', d.city),
          detailRow('Province', d.driverProvince ?? d.province),
          detailRow('Postal Code', d.postalCode),
          detailRow('Social Insurance #', d.sin),
          detailRow('Nationality', d.nationality),
          detailRow('Passport #', d.passport),
          detailRow('Passport Expiry', d.passportExpiry),
          detailRow('Work Permit #', d.workPermit),
          detailRow('Work Permit Expiry', d.workPermitExpiry),
          detailRow('Owner Operator Name', d.ownerOperatorName),
          detailRow('Incorporation Name', d.incorporationName),
          detailRow('HST #', d.hst),
        ],
      ),
    );
  }

  Widget _buildDocumentsTab(DriverModel d) {
    final docs = <({String label, String? expiry, String? file})>[];
    if (d.licenseExpiry != null) {
      docs.add((
        label: 'Driver License',
        expiry: d.licenseExpiry,
        file: d.raw?['license_attachment'] as String?
      ));
    }
    if (d.medicalDueDate != null) {
      docs.add((
        label: 'Medical Certificate',
        expiry: d.medicalDueDate,
        file: d.raw?['medical_attachment'] as String?
      ));
    }
    if (d.fastCartExpiry != null) {
      docs.add((
        label: 'FAST Card',
        expiry: d.fastCartExpiry,
        file: d.raw?['fast_card_attachment'] as String?
      ));
    }
    if (d.passportExpiry != null) {
      docs.add((
        label: 'Passport Copy',
        expiry: d.passportExpiry,
        file: d.raw?['passport_attachment'] as String?
      ));
    }
    if (d.workPermitExpiry != null) {
      docs.add((
        label: 'Work Permit',
        expiry: d.workPermitExpiry,
        file: d.raw?['work_permit_attachment'] as String?
      ));
    }

    if (docs.isEmpty) {
      return Container(
        height: 150,
        alignment: Alignment.center,
        child: Text(
          'No compliance documents uploaded.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      );
    }

    return Column(
      children: docs.map((doc) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.description_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc.label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (doc.expiry != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Expiry: ${doc.expiry}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (doc.file != null && doc.file!.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.download_rounded),
                  onPressed: () {
                    AppToast.showSuccess('Downloading ${doc.label}...');
                  },
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _driver?.fullName ?? 'Driver Details',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (_driver?.driverId != null)
              Text(
                _driver!.driverId!,
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
          ],
        ),
      ),
      body: ScreenStateBuilder(
        loading: _loading,
        error: _error,
        onRetry: _load,
        child: _driver == null
            ? const SizedBox()
            : WebPageBody(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Profile Overview Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: AppColors.primaryLight,
                            child: Icon(
                              Icons.person_outline,
                              color: AppColors.primary,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _driver!.fullName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _driver!.email ?? 'No email address',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Navigation Tabs
                    Row(
                      children: [
                        _tabButton('Overview', DriverDetailTab.overview),
                        const SizedBox(width: 8),
                        _tabButton('Personal Details', DriverDetailTab.personal),
                        const SizedBox(width: 8),
                        _tabButton('Documents', DriverDetailTab.documents),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Selected Tab Content
                    if (_tab == DriverDetailTab.overview)
                      _buildOverviewTab(_driver!)
                    else if (_tab == DriverDetailTab.personal)
                      _buildPersonalTab(_driver!)
                    else if (_tab == DriverDetailTab.documents)
                      _buildDocumentsTab(_driver!),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _tabButton(String label, DriverDetailTab targetTab) {
    final active = _tab == targetTab;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _tab = targetTab),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active ? Colors.transparent : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: active ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
