class NavMenuItem {
  const NavMenuItem({
    required this.id,
    required this.label,
    required this.path,
    this.children = const [],
  });

  final String id;
  final String label;
  final String path;
  final List<NavMenuItem> children;

  bool get hasChildren => children.isNotEmpty;
}
