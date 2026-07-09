import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/core/utils/app_toast.dart';
import 'package:rapide_nforce/services/api_client.dart';
import 'package:rapide_nforce/ui/widgets/api_error_banner.dart';
import 'package:rapide_nforce/ui/widgets/list_empty_state.dart';

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

      setState(() {
        _loading = false;
        _items = List.from(list);
      });
    } catch (e) {
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${decision.toUpperCase()} Decision'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enter remarks for "${item['carrierName'] ?? 'this carrier'}":'),
            const SizedBox(height: 10),
            TextField(
              controller: remarksController,
              decoration: const InputDecoration(
                hintText: 'Remarks (Required)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (remarksController.text.trim().isEmpty) {
                AppToast.showError('Remarks are mandatory.');
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('Confirm'),
          ),
        ],
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

      AppToast.showSuccess('Decision submitted successfully');
      _load();
    } catch (e) {
      AppToast.showError(e.toString());
    } finally {
      setState(() => _actingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ApiErrorBanner(message: _error!, onRetry: _load);
    }
    if (_items.isEmpty) {
      return ListEmptyState(
        message: 'No consent approvals pending',
        icon: Icons.assignment_turned_in_outlined,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _items.length,
      itemBuilder: (context, i) {
        final item = _items[i];
        final id = item['id']?.toString() ?? '';
        final status = (item['status']?.toString() ?? 'PENDING').toUpperCase();
        final pending = status == 'SUBMITTED' || status == 'SIGNED' || status == 'PENDING';
        final acting = _actingId == id;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderLight),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D000000),
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      item['carrierName']?.toString() ?? 'Carrier Name',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: pending ? Colors.purple.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: pending ? Colors.purple : Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Sender: ${item['senderEmail'] ?? '—'}',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                'Signed By: ${item['signedBy'] ?? '—'}',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                'Uploaded On: ${item['uploadedOn'] ?? '—'}',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              if (pending) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: acting ? null : () => _act(item, 'REJECTED', 'REJECTED'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.danger,
                          side: BorderSide(color: AppColors.danger.withValues(alpha: 0.5)),
                        ),
                        child: const Text('Reject'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: acting ? null : () => _act(item, 'APPROVED', 'APPROVED'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.statusCompleted,
                        ),
                        child: acting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Approve'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
