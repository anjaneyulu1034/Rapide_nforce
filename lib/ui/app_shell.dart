import 'package:flutter/material.dart';

import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/core/enums/app_route.dart';
import 'package:rapide_nforce/core/utils/api_feedback.dart';
import 'package:rapide_nforce/core/utils/menu_route_mapper.dart';
import 'package:rapide_nforce/core/utils/role_utils.dart';
import 'package:rapide_nforce/models/company_model.dart';

import 'package:rapide_nforce/models/nav_menu_item.dart';
import 'package:rapide_nforce/services/menu_service.dart';

import 'package:rapide_nforce/services/auth_service.dart';
import 'package:rapide_nforce/services/company_service.dart';

import 'package:rapide_nforce/ui/approvals_screen.dart';

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

  List<CompanyModel> _companies = [];
  List<NavMenuItem> _menuItems = [];
  String? _selectedCompanyId;
  bool _loadingCompanies = false;
  bool _loadingMenus = false;
  bool _bootstrapping = false;

  bool get _isLoggedIn => AuthService.instance.isLoggedIn;

  List<AppRoute> get _bottomNavRoutes {
    final routes = <AppRoute>[
      AppRoute.dashboard,
      AppRoute.maintenance,
    ];

    final hasApprovals = _menuItems.any((item) =>
        MenuRouteMapper.routeFromPath(item.path) == AppRoute.approvals ||
        item.children.any((c) => MenuRouteMapper.routeFromPath(c.path) == AppRoute.approvals));

    final hasRequests = _menuItems.any((item) =>
        MenuRouteMapper.routeFromPath(item.path) == AppRoute.requests ||
        item.children.any((c) => MenuRouteMapper.routeFromPath(c.path) == AppRoute.requests));

    if (hasApprovals) {
      routes.add(AppRoute.approvals);
    } else if (hasRequests) {
      routes.add(AppRoute.requests);
    } else {
      final role = AuthService.instance.currentUser?.role;
      if (isAdminRole(role) || (role != null && role.toUpperCase().contains('LEAD'))) {
        routes.add(AppRoute.approvals);
      } else {
        routes.add(AppRoute.requests);
      }
    }

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
    });
  }

  void _onRouteSelected(AppRoute route) {
    setState(() => _currentRoute = route);
  }

  void _onCompanyChanged(String companyId) {
    AuthService.instance.setSelectedCompanyId(companyId);

    setState(() => _selectedCompanyId = companyId);
  }

  Widget _screenFor(AppRoute route) {
    switch (route) {
      case AppRoute.dashboard:
        return DashboardScreen(onNavigate: _onRouteSelected);

      case AppRoute.carriers:
        return const CarriersScreen();

      case AppRoute.powerUnit:
        return PowerUnitScreen(key: ValueKey(_powerUnitRefreshKey));

      case AppRoute.myTrailers:
        return const TrailersScreen();

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
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoggedIn) {
      return LoginScreen(onLoginSuccess: _onLoginSuccess);
    }

    if (_bootstrapping) {
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
        centerTitle: _currentRoute == AppRoute.profile,
        title: _currentRoute == AppRoute.dashboard
            ? null
            : Text(
                _currentRoute.title,
                style: const TextStyle(fontWeight: FontWeight.w700),
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
        menuItems: _menuItems,
        menusLoading: _loadingMenus,
      ),

      body: KeyedSubtree(
        key: ValueKey(_selectedCompanyId),

        child: _screenFor(_currentRoute),
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
                  setState(() => _powerUnitRefreshKey++);
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
                  setState(() => _workOrderRefreshKey++);
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
