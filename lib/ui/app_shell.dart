import 'package:flutter/material.dart';

import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/core/enums/app_route.dart';
import 'package:rapide_nforce/core/utils/api_feedback.dart';
import 'package:rapide_nforce/core/utils/role_utils.dart';
import 'package:rapide_nforce/models/company_model.dart';

import 'package:rapide_nforce/models/nav_menu_item.dart';
import 'package:rapide_nforce/services/menu_service.dart';

import 'package:rapide_nforce/services/auth_service.dart';
import 'package:rapide_nforce/services/company_service.dart';

import 'package:rapide_nforce/ui/approvals_screen.dart';
import 'package:rapide_nforce/ui/drivers/drivers_screen.dart';
import 'package:rapide_nforce/ui/dvir/dvir_screen.dart';

import 'package:rapide_nforce/ui/carriers_screen.dart';

import 'package:rapide_nforce/ui/dashboard_screen.dart';

import 'package:rapide_nforce/ui/documents_screen.dart';

import 'package:rapide_nforce/ui/fault_codes_screen.dart';

import 'package:rapide_nforce/ui/login_screen.dart';

import 'package:rapide_nforce/ui/inventory_screen.dart';
import 'package:rapide_nforce/ui/logs_screen.dart';
import 'package:rapide_nforce/ui/work_orders/work_orders_screen.dart';

import 'package:rapide_nforce/ui/power_unit_form_screen.dart';
import 'package:rapide_nforce/ui/power_unit_screen.dart';
import 'package:rapide_nforce/ui/work_orders/work_order_form_screen.dart';

import 'package:rapide_nforce/ui/profile_screen.dart';

import 'package:rapide_nforce/ui/reports_screen.dart';

import 'package:rapide_nforce/ui/requests_screen.dart';

import 'package:rapide_nforce/ui/trailers/trailer_form_screen.dart';
import 'package:rapide_nforce/ui/trailers_screen.dart';

import 'package:rapide_nforce/ui/widgets/app_bottom_nav.dart';

import 'package:rapide_nforce/ui/widgets/app_drawer.dart';

import 'package:rapide_nforce/ui/widgets/app_header_actions.dart';

import 'package:rapide_nforce/ui/widgets/brand_logo.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppRoute _currentRoute = AppRoute.dashboard;
  int _powerUnitRefreshKey = 0;
  int _workOrderRefreshKey = 0;
  int _trailersRefreshKey = 0;

  List<CompanyModel> _companies = [];
  List<NavMenuItem> _menuItems = [];
  String? _selectedCompanyId;
  bool _loadingCompanies = false;
  bool _loadingMenus = false;
  bool _bootstrapping = false;

  // Keeps already-visited tab screens alive so switching tabs doesn't dispose
  // and re-fetch them from scratch every time — only the first visit to a
  // route pays the network cost, matching e.g. IndexedStack-based tab bars.
  final Map<AppRoute, Widget> _screenCache = {};

  bool get _isLoggedIn => AuthService.instance.isLoggedIn;

  List<AppRoute> get _bottomNavRoutes {
    final routes = <AppRoute>[
      AppRoute.dashboard,
      AppRoute.maintenance,
    ];

    final role = AuthService.instance.currentUser?.role;
    final canApprove =
        isAdminRole(role) || (role != null && role.toUpperCase().contains('LEAD'));

    routes.add(canApprove ? AppRoute.approvals : AppRoute.requests);

    routes.add(AppRoute.profile);
    return routes;
  }

  @override
  void initState() {
    super.initState();
    _selectedCompanyId = AuthService.instance.selectedCompanyId;
    if (_isLoggedIn) {
      _bootstrapping = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrapSession());
    }
  }

  Future<void> _bootstrapSession() async {
    await Future.wait([_loadCompanies(), _loadMenus()]);
    if (!mounted) return;
    setState(() => _bootstrapping = false);
  }

  Future<void> _loadCompanies() async {
    setState(() => _loadingCompanies = true);

    final userCompanyId = AuthService.instance.currentUser?.companyId;

    var companies = <CompanyModel>[];

    final listResult = await CompanyService.instance.fetchCompanies();

    if (listResult.isSuccess && (listResult.data?.isNotEmpty ?? false)) {
      companies = listResult.data!;
    } else if (userCompanyId != null) {
      final singleResult = await CompanyService.instance.fetchCompanyById(
        userCompanyId,
      );

      if (singleResult.isSuccess && singleResult.data != null) {
        companies = [singleResult.data!];
      }
    }

    var selectedId = AuthService.instance.selectedCompanyId;

    if (selectedId == null && userCompanyId != null) {
      selectedId = userCompanyId.toString();
    }

    if (selectedId != null &&
        !companies.any((c) => c.id.toString() == selectedId)) {
      final parsedId = int.tryParse(selectedId);

      if (parsedId != null) {
        final singleResult = await CompanyService.instance.fetchCompanyById(
          parsedId,
        );

        if (singleResult.isSuccess && singleResult.data != null) {
          companies = [...companies, singleResult.data!];
        }
      }
    }

    if ((selectedId == null || selectedId.isEmpty) && companies.isNotEmpty) {
      selectedId = companies.first.id.toString();
    }

    if (selectedId != null && selectedId.isNotEmpty) {
      AuthService.instance.setSelectedCompanyId(selectedId);
    }

    if (companies.isEmpty &&
        (selectedId == null || selectedId.isEmpty) &&
        !listResult.isSuccess) {
      ApiFeedback.showError(
        listResult,
        fallback: 'Unable to load company information.',
      );
    }

    if (!mounted) return;

    setState(() {
      _companies = companies;

      _selectedCompanyId = selectedId;

      _loadingCompanies = false;
    });
  }

  Future<void> _loadMenus() async {
    setState(() => _loadingMenus = true);
    final result = await MenuService.instance.fetchMenusForCurrentUser();
    if (!mounted) return;
    setState(() {
      _loadingMenus = false;
      _menuItems = result.data ?? [];
    });
  }

  void _onLoginSuccess() {
    setState(() {
      _selectedCompanyId = AuthService.instance.selectedCompanyId;
      _bootstrapping = true;
      _screenCache.clear();
    });
    _bootstrapSession();
  }

  Future<void> _onLogout() async {
    await AuthService.instance.logout();

    if (!mounted) return;

    setState(() {
      _currentRoute = AppRoute.dashboard;

      _companies = [];
      _menuItems = [];
      _selectedCompanyId = null;
      _loadingCompanies = false;
      _bootstrapping = false;
      _screenCache.clear();
    });
  }

  void _onRouteSelected(AppRoute route) {
    setState(() {
      _currentRoute = route;
      // Approvals is a shared inbox other users/processes change constantly
      // (new requests submitted, items approved/rejected elsewhere) — unlike
      // most tabs, it must never serve a stale cached copy, so re-fetch
      // every time it's opened instead of keeping the first-load result
      // alive for the rest of the session.
      if (route == AppRoute.approvals) {
        _screenCache.remove(AppRoute.approvals);
      }
    });
  }

  void _onCompanyChanged(String companyId) {
    AuthService.instance.setSelectedCompanyId(companyId);

    setState(() {
      _selectedCompanyId = companyId;
      _screenCache.clear();
    });
  }

  Widget _screenFor(AppRoute route) {
    return _screenCache.putIfAbsent(route, () => _buildScreen(route));
  }

  Widget _buildScreen(AppRoute route) {
    switch (route) {
      case AppRoute.dashboard:
        return DashboardScreen(onNavigate: _onRouteSelected);

      case AppRoute.carriers:
        return const CarriersScreen();

      case AppRoute.powerUnit:
        return PowerUnitScreen(key: ValueKey(_powerUnitRefreshKey));

      case AppRoute.myTrailers:
        return TrailersScreen(key: ValueKey(_trailersRefreshKey));

      case AppRoute.maintenance:
        return WorkOrdersScreen(
          key: ValueKey(_workOrderRefreshKey),
        );

      case AppRoute.inventory:
        return const InventoryScreen();

      case AppRoute.logs:
        return const LogsScreen();

      case AppRoute.faultCodes:
        return const FaultCodesScreen();

      case AppRoute.documents:
        return const DocumentsScreen();

      case AppRoute.reports:
        return const ReportsScreen();

      case AppRoute.requests:
        return const RequestsScreen();

      case AppRoute.approvals:
        return const ApprovalsScreen();

      case AppRoute.profile:
        return ProfileScreen(onLogout: _onLogout);

      case AppRoute.drivers:
        return const DriversScreen();

      case AppRoute.dvir:
        return const DvirScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoggedIn) {
      return LoginScreen(onLoginSuccess: _onLoginSuccess);
    }

    // Only block on the full-screen splash when we don't even know which
    // company to scope requests to yet (true first-ever login). Once a
    // company is known (restored from disk on every subsequent launch),
    // render immediately and let the drawer/header show their own small
    // loading indicators while companies/menus refresh in the background —
    // this is what was making every login feel like two loading screens
    // back-to-back.
    if (_bootstrapping && _selectedCompanyId == null) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BrandLogo(height: 88),
              SizedBox(height: 24),
              CircularProgressIndicator(),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      extendBody: true,
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 0,
        title: const Text(
          'RAPIDÉnforce',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),

        actions: [
          AppHeaderActions(
            companies: _companies,

            selectedCompanyId: _selectedCompanyId,

            loadingCompanies: _loadingCompanies,

            onCompanyChanged: _onCompanyChanged,

            onNavigate: _onRouteSelected,
          ),
        ],
      ),

      drawer: AppDrawer(
        currentRoute: _currentRoute,
        onRouteSelected: _onRouteSelected,
        onLogout: _onLogout,
        menuItems: _menuItems,
        menusLoading: _loadingMenus,
      ),

      body: KeyedSubtree(
        key: ValueKey(_selectedCompanyId),

        child: IndexedStack(
          index: AppRoute.values.indexOf(_currentRoute),
          children: [
            for (final route in AppRoute.values)
              if (route == _currentRoute || _screenCache.containsKey(route))
                _screenFor(route)
              else
                const SizedBox.shrink(),
          ],
        ),
      ),

      floatingActionButton: _currentRoute == AppRoute.powerUnit
          ? FloatingActionButton(
              onPressed: () async {
                final changed = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => const PowerUnitFormScreen(),
                  ),
                );
                if (changed == true) {
                  setState(() {
                    _powerUnitRefreshKey++;
                    _screenCache.remove(AppRoute.powerUnit);
                  });
                }
              },
              backgroundColor: const Color(0xFF990000),
              foregroundColor: Colors.white,
              elevation: 4,
              child: const Icon(Icons.add, size: 28),
            )
          : _currentRoute == AppRoute.maintenance
          ? FloatingActionButton(
              onPressed: () async {
                final changed = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => const WorkOrderFormScreen(),
                  ),
                );
                if (changed == true) {
                  setState(() {
                    _workOrderRefreshKey++;
                    _screenCache.remove(AppRoute.maintenance);
                  });
                }
              },
              backgroundColor: const Color(0xFF990000),
              foregroundColor: Colors.white,
              elevation: 4,
              child: const Icon(Icons.add, size: 28),
            )
          : _currentRoute == AppRoute.myTrailers
          ? FloatingActionButton(
              onPressed: () async {
                final changed = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => const TrailerFormScreen(),
                  ),
                );
                if (changed == true) {
                  setState(() {
                    _trailersRefreshKey++;
                    _screenCache.remove(AppRoute.myTrailers);
                  });
                }
              },
              backgroundColor: const Color(0xFF990000),
              foregroundColor: Colors.white,
              elevation: 4,
              child: const Icon(Icons.add, size: 28),
            )
          : null,
      bottomNavigationBar: AppBottomNav(
        currentRoute: _currentRoute,
        routes: _bottomNavRoutes,
        onRouteSelected: _onRouteSelected,
      ),
    );
  }
}
