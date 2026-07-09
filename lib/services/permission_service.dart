import 'package:rapide_nforce/core/constants/api_constants.dart';
import 'package:rapide_nforce/core/models/api_result.dart';
import 'package:rapide_nforce/core/utils/api_parse.dart';
import 'package:rapide_nforce/core/utils/role_utils.dart';
import 'package:rapide_nforce/services/api_client.dart';
import 'package:rapide_nforce/services/auth_service.dart';

/// Per-menu CRUD flags, mirroring the web app's `canCreate`/`canView`/
/// `canUpdate`/`canDelete` permission record for a menu.
class MenuPermissions {
  const MenuPermissions({
    this.canCreate = false,
    this.canView = false,
    this.canUpdate = false,
    this.canDelete = false,
  });

  static const all = MenuPermissions(
    canCreate: true,
    canView: true,
    canUpdate: true,
    canDelete: true,
  );

  final bool canCreate;
  final bool canView;
  final bool canUpdate;
  final bool canDelete;
}

/// Mirrors the web app's per-menu CRUD permission check
/// (`GET /manage-permissions/by-user/:id`) — super admins always pass;
/// everyone else is gated by their assigned menu permissions.
class PermissionService {
  PermissionService._();

  static final PermissionService instance = PermissionService._();

  final ApiClient _api = ApiClient.instance;

  Future<ApiResult<MenuPermissions>> getMenuPermissions({
    required String menuUrl,
    String? menuName,
  }) async {
    final role = AuthService.instance.currentUser?.role;
    if (isSuperAdminRole(role)) return ApiResult.ok(MenuPermissions.all);

    final userId = AuthService.instance.currentUser?.id;
    if (userId == null) return ApiResult.ok(const MenuPermissions());

    try {
      final companyId = AuthService.instance.selectedCompanyIdInt;
      final body = await _api.parseJson(
        () => _api.get(
          '${ApiConstants.managePermissionsByUser}/$userId',
          params: {
            'all': true,
            'companyId': ?companyId,
          },
        ),
        onSuccess: (b) => b,
      );

      final rows = ApiParse.listItems(body);
      Map<String, dynamic>? match;
      for (final row in rows) {
        final menu = row['menu'];
        if (menu is! Map) continue;
        final url = menu['menuUrl']?.toString();
        final name = menu['menuName']?.toString();
        if (url == menuUrl || (menuName != null && name == menuName)) {
          match = row;
          break;
        }
      }
      if (match == null) return ApiResult.ok(const MenuPermissions());

      bool flag(String camel, String snake) {
        final crud = match!['crudPermissions'] ?? match['crud_permissions'];
        final raw = match[camel] ??
            match[snake] ??
            (crud is Map ? (crud[camel] ?? crud[snake]) : null);
        return raw == true || raw == 1 || raw == 'true';
      }

      return ApiResult.ok(
        MenuPermissions(
          canCreate: flag('canCreate', 'can_create'),
          canView: flag('canView', 'can_view'),
          canUpdate: flag('canUpdate', 'can_update'),
          canDelete: flag('canDelete', 'can_delete'),
        ),
      );
    } on ApiClientException catch (e) {
      return ApiResult.fail(e.message, statusCode: e.statusCode);
    } catch (_) {
      return ApiResult.fail('Failed to check permissions.');
    }
  }

  Future<ApiResult<bool>> canCreate({
    required String menuUrl,
    String? menuName,
  }) async {
    final result =
        await getMenuPermissions(menuUrl: menuUrl, menuName: menuName);
    if (!result.isSuccess) {
      return ApiResult.fail(
        result.message ?? 'Failed to check permissions.',
        statusCode: result.statusCode,
      );
    }
    return ApiResult.ok(result.data!.canCreate);
  }
}
