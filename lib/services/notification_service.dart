import 'package:rapide_nforce/core/constants/api_constants.dart';
import 'package:rapide_nforce/core/models/api_result.dart';
import 'package:rapide_nforce/core/utils/api_parse.dart';
import 'package:rapide_nforce/core/utils/notification_helpers.dart';
import 'package:rapide_nforce/models/expiring_document_model.dart';
import 'package:rapide_nforce/models/notification_model.dart';
import 'package:rapide_nforce/models/user_model.dart';
import 'package:rapide_nforce/services/api_client.dart';
import 'package:rapide_nforce/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();
  final ApiClient _api = ApiClient.instance;

  static const _readIdsKey = 'cm_notifications_read_ids';

  Future<Set<String>> _readIds() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_readIdsKey) ?? [];
    return list.toSet();
  }

  Future<void> _addReadId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final set = await _readIds();
    set.add(id);
    await prefs.setStringList(_readIdsKey, set.toList());
  }

  Future<void> _addReadIds(Iterable<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    final set = await _readIds();
    set.addAll(ids);
    await prefs.setStringList(_readIdsKey, set.toList());
  }

  Future<ApiResult<List<NotificationModel>>> fetchMergedNotifications({
    UserModel? user,
    int limit = 100,
  }) async {
    final current = user ?? AuthService.instance.currentUser;
    try {
      final userFuture = getUserNotifications(limit: limit);
      final expiryFuture = canViewFleetExpiryNotifications(current)
          ? getExpiryNotifications()
          : Future<List<NotificationModel>>.value([]);

      final results = await Future.wait([userFuture, expiryFuture]);
      final merged = sortNotificationsNewestFirst([
        ...results[0],
        ...results[1],
      ]);
      return ApiResult.ok(merged);
    } catch (_) {
      return ApiResult.fail('Failed to load notifications.');
    }
  }

  Future<List<NotificationModel>> getUserNotifications({
    int limit = 100,
  }) async {
    final body = await _api.parseJson(
      () => _api.get(ApiConstants.notifications, params: {'limit': limit}),
      onSuccess: (b) => b,
    );

    final rows = <Map<String, dynamic>>[];
    rows.addAll(ApiParse.listItems(body));
    if (rows.isEmpty) {
      final root = ApiParse.asMap(body);
      final data = ApiParse.asMap(root?['data']);
      final items = data?['items'];
      if (items is List) {
        for (final row in items) {
          if (row is Map) {
            rows.add(Map<String, dynamic>.from(row));
          }
        }
      }
    }

    return rows.map((row) {
      final item = NotificationModel.fromApiJson(row);
      return NotificationModel(
        id: item.id,
        title: item.title,
        description: item.description,
        time: notificationRelativeTime(item.createdAt),
        type: item.type,
        unread: item.unread,
        createdAt: item.createdAt,
        payload: item.payload,
      );
    }).toList();
  }

  Future<List<NotificationModel>> getExpiryNotifications() async {
    final cid = AuthService.instance.selectedCompanyIdInt;
    final readSet = await _readIds();

    final expiring = await _fetchExpiringDocs(ApiConstants.documentsExpiring);
    final noExpiry = await _fetchExpiringDocs(
      ApiConstants.documentsNoExpiry,
      companyId: cid,
    );

    final docs = [...expiring, ...noExpiry];
    final items = <NotificationModel>[];
    for (final doc in docs) {
      final n = _mapDocumentToNotification(doc, readSet);
      if (n != null) items.add(n);
    }
    return items;
  }

  Future<List<ExpiringDocumentModel>> _fetchExpiringDocs(
    String path, {
    int? companyId,
  }) async {
    try {
      final body = await _api.parseJson(
        () => _api.get(
          path,
          params: {'companyId': ?companyId},
          companyId: companyId?.toString(),
        ),
        onSuccess: (b) => b,
      );
      return ApiParse.listItems(
        body,
      ).map(ExpiringDocumentModel.fromJson).toList();
    } catch (_) {
      return [];
    }
  }

  NotificationModel? _mapDocumentToNotification(
    ExpiringDocumentModel doc,
    Set<String> readSet,
  ) {
    final days = _daysUntilExpiry(doc.expiryDate);
    if (days == null) return null;

    final label = (doc.documentType?.trim().isNotEmpty ?? false)
        ? doc.documentType!.trim()
        : 'Document';
    final entity = _entityLabel(doc);
    final title = '$label Expiry Alert';
    final entityType = doc.unitType?.toLowerCase() == 'trailer'
        ? 'trailer'
        : 'truck';
    final entityId = doc.vehicleId != null && doc.vehicleId! > 0
        ? '${doc.vehicleId}'
        : '';
    final payload = <String, dynamic>{
      'entityType': entityType,
      'documentId': doc.id,
      'documentType': doc.documentType,
      'expiryDate': doc.expiryDate,
      if (entityId.isNotEmpty) 'entityId': entityId,
    };

    if (days <= 7) {
      final id = 'doc-critical-${doc.id}';
      final description = days < 0
          ? '$label for $entity expired ${days.abs()} day${days.abs() == 1 ? '' : 's'} ago.'
          : days == 0
          ? '$label for $entity expires today.'
          : '$label for $entity expires in $days day${days == 1 ? '' : 's'}.';
      return NotificationModel(
        id: id,
        title: title,
        description: description,
        time: notificationRelativeTime(doc.expiryDate),
        createdAt: doc.createdAt ?? doc.expiryDate,
        type: NotificationType.critical,
        unread: !readSet.contains(id),
        payload: payload,
      );
    }

    if (days >= 8 && days <= 30) {
      final id = 'doc-warning-${doc.id}';
      return NotificationModel(
        id: id,
        title: title,
        description: '$label for $entity expires in $days days.',
        time: notificationRelativeTime(doc.expiryDate),
        createdAt: doc.createdAt ?? doc.expiryDate,
        type: NotificationType.warning,
        unread: !readSet.contains(id),
        payload: payload,
      );
    }

    return null;
  }

  int? _daysUntilExpiry(String? value) {
    if (value == null || value.isEmpty) return null;
    final expiry = DateTime.tryParse(value);
    if (expiry == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(expiry.year, expiry.month, expiry.day);
    return target.difference(today).inDays;
  }

  String _entityLabel(ExpiringDocumentModel doc) {
    final direct =
        doc.vehicleUnit?.trim() ??
        doc.entityTypeName?.trim() ??
        doc.companyName?.trim();
    if (direct != null && direct.isNotEmpty) return direct;
    final id = doc.vehicleId;
    if (id == null || id <= 0) return 'Selected unit';
    return doc.unitType?.toLowerCase() == 'trailer'
        ? 'Trailer $id'
        : 'Engine $id';
  }

  Future<ApiResult<void>> markAsRead(String id) async {
    try {
      if (isSyntheticNotificationId(id)) {
        await _addReadId(id);
        return ApiResult.ok(null);
      }
      await _api.parseJson(
        () => _api.patch('${ApiConstants.notifications}/$id/read'),
        onSuccess: (b) => b,
      );
      return ApiResult.ok(null);
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to mark notification as read.');
    }
  }

  Future<ApiResult<void>> markAllAsRead(List<String> ids) async {
    try {
      await _api.parseJson(
        () => _api.patch('${ApiConstants.notifications}/read-all'),
        onSuccess: (b) => b,
      );
      final synthetic = ids.where(isSyntheticNotificationId);
      if (synthetic.isNotEmpty) await _addReadIds(synthetic);
      return ApiResult.ok(null);
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to mark all as read.');
    }
  }
}
