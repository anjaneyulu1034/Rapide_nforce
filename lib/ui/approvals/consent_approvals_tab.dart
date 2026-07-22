import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/core/constants/app_strings.dart';
import 'package:rapide_nforce/core/utils/app_toast.dart';
import 'package:rapide_nforce/services/api_client.dart';
import 'package:rapide_nforce/ui/approvals/approval_card.dart';
import 'package:rapide_nforce/ui/widgets/screen_state_builder.dart';

class ConsentApprovalsTab extends StatefulWidget {
  const ConsentApprovalsTab({super.key});

  @override
  State<ConsentApprovalsTab> createState() => _ConsentApprovalsTabState();
}

class _ConsentApprovalsTabState extends State<ConsentApprovalsTab> {
  bool _loading = true;
  String? _error;
  List<dynamic> _items = [];
  String? _actingId;

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

    try {
      final body = await ApiClient.instance.parseJson(
        () => ApiClient.instance.get('/consent-documents'),
        onSuccess: (b) => b,
      );

      final data = body['data'] ?? body;
      final list = data['items'] ?? data['data'] ?? (data is List ? data : []);

      if (!mounted) return;
      setState(() {
        _loading = false;
        _items = List.from(list);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _act(dynamic item, String decision, String statusText) async {
    final id = item['id']?.toString() ?? '';
    if (id.isEmpty) return;

    final remarksController = TextEditingController();
    final isApprove = decision == 'APPROVED';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: (isApprove ? AppColors.statEmeraldText : AppColors.danger)
                          .withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isApprove ? Icons.check_rounded : Icons.close_rounded,
                      color: isApprove ? AppColors.statEmeraldText : AppColors.danger,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${decision[0]}${decision.substring(1).toLowerCase()} Decision',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Enter remarks for "${item['carrierName'] ?? 'this carrier'}":',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: remarksController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Remarks (Required)',
                  filled: true,
                  fillColor: AppColors.inputFill,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: BorderSide(color: AppColors.border, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        if (remarksController.text.trim().isEmpty) {
                          AppToast.showError('Remarks are mandatory.');
                          return;
                        }
                        Navigator.pop(ctx, true);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: isApprove
                            ? const Color(0xFF4B633D)
                            : AppColors.danger,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Confirm'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true) return;

    setState(() => _actingId = id);

    try {
      await ApiClient.instance.parseJson(
        () => ApiClient.instance.post('/consent-documents/$id/decision', body: {
          'decision': decision,
          'remarks': remarksController.text.trim(),
        }),
        onSuccess: (b) => b,
      );

      if (!mounted) return;
      AppToast.showSuccess('Decision submitted successfully');
      _load();
    } catch (e) {
      if (!mounted) return;
      AppToast.showError(e.toString());
    } finally {
      if (mounted) setState(() => _actingId = null);
    }
  }

  ({Color bg, Color fg}) _statusColors(String status, bool pending) {
    if (status == 'APPROVED') {
      return (bg: AppColors.statEmeraldBgEnd, fg: AppColors.statEmeraldText);
    }
    if (status == 'REJECTED') {
      return (bg: AppColors.danger.withValues(alpha: 0.12), fg: AppColors.danger);
    }
    return (bg: AppColors.statOrangeBgEnd, fg: AppColors.statOrangeText);
  }

  @override
  Widget build(BuildContext context) {
    return ScreenStateBuilder(
      loading: _loading,
      error: _error,
      onRetry: _load,
      isEmpty: _items.isEmpty,
      emptyMessage: AppStrings.noData,
      emptyIcon: Icons.assignment_turned_in_outlined,
      child: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.card,
        onRefresh: _load,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          itemCount: _items.length,
          itemBuilder: (context, i) {
            final item = _items[i];
            final id = item['id']?.toString() ?? '';
            final status = (item['status']?.toString() ?? 'PENDING').toUpperCase();
            final pending =
                status == 'SUBMITTED' || status == 'SIGNED' || status == 'PENDING';
            final acting = _actingId == id;
            final colors = _statusColors(status, pending);

            return ApprovalCard(
              icon: Icons.description_outlined,
              iconBg: AppColors.statBlueBorder,
              iconColor: AppColors.statBlueText,
              title: item['carrierName']?.toString() ?? 'Carrier Name',
              subtitle: 'Sender: ${item['senderEmail'] ?? '—'}',
              statusLabel: status,
              statusBg: colors.bg,
              statusFg: colors.fg,
              metaChips: [
                MetaChip(
                  icon: Icons.edit_outlined,
                  label: 'Signed by ${item['signedBy'] ?? '—'}',
                ),
                MetaChip(
                  icon: Icons.calendar_today_outlined,
                  label: '${item['uploadedOn'] ?? '—'}',
                ),
              ],
              pending: pending,
              acting: acting,
              onApprove: () => _act(item, 'APPROVED', 'APPROVED'),
              onReject: () => _act(item, 'REJECTED', 'REJECTED'),
            );
          },
        ),
      ),
    );
  }
}
