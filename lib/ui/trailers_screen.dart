import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/core/constants/app_strings.dart';
import 'package:rapide_nforce/models/trailer_model.dart';
import 'package:rapide_nforce/services/trailer_service.dart';
import 'package:rapide_nforce/ui/trailer_detail_screen.dart';
import 'package:rapide_nforce/ui/widgets/screen_state_builder.dart';
import 'package:rapide_nforce/ui/widgets/status_chip.dart';
import 'package:rapide_nforce/ui/widgets/web_ui.dart';

class TrailersScreen extends StatefulWidget {
  const TrailersScreen({super.key});

  @override
  State<TrailersScreen> createState() => _TrailersScreenState();
}

class _TrailersScreenState extends State<TrailersScreen> {
  bool _loading = true;
  String? _error;
  List<TrailerModel> _items = [];

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
    final result = await TrailerService.instance.fetchTrailers();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result.isSuccess) {
        _items = result.data?.items ?? [];
      } else {
        _error = result.message ?? 'Failed to load trailers';
      }
    });
  }

  String? _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return iso;
    return DateFormat('MM-dd-yyyy').format(parsed.toLocal());
  }

  void _openDetail(TrailerModel trailer) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TrailerDetailScreen(trailerId: trailer.id),
      ),
    );
  }

  Widget _buildCard(TrailerModel t) {
    final bool isActive = t.status.toLowerCase() == 'active' || t.status == '1';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openDetail(t),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'TRAILER # ',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        t.trailerNumber,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    isActive
                        ? StatusChip.active('Active')
                        : StatusChip.inactive('Inactive'),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  height: 1,
                  color: AppColors.borderLight,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.category,
                                size: 12,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'TYPE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            t.type,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.credit_card,
                                size: 12,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'PLATE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            t.licensePlate ?? '—',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.fingerprint,
                                size: 12,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'VIN',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            t.vinNumber ?? '—',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.event_busy,
                                size: 12,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'EXPIRY',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _formatDate(t.registrationExpiry) ?? '—',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScreenStateBuilder(
      loading: _loading,
      error: _error,
      onRetry: _load,
      isEmpty: _items.isEmpty,
      emptyMessage: AppStrings.noData,
      emptyIcon: Icons.inventory_2_outlined,
      child: WebListPage(
        title: 'My Trailers',
        subtitle: '${_items.length} trailers',
        onRefresh: _load,
        sliver: SliverToBoxAdapter(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 600) {
                return Column(
                  children: _items.map((t) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _buildCard(t),
                    );
                  }).toList(),
                );
              } else {
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _items.length,
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 500,
                    mainAxisExtent: 250,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemBuilder: (context, i) {
                    return _buildCard(_items[i]);
                  },
                );
              }
            },
          ),
        ),
      ),
    );
  }
}
