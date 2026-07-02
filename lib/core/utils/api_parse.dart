/// Helpers for parsing standard Rapide nforce API response shapes.
class ApiParse {
  ApiParse._();

  static Map<String, dynamic>? asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  static List<Map<String, dynamic>> listItems(dynamic body) {
    if (body == null) return [];

    if (body is List) {
      return body
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    final root = asMap(body);
    if (root == null) return [];

    final data = root['data'];
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    final dataMap = asMap(data);
    if (dataMap == null) return [];

    final nested = dataMap['data'];
    if (nested is List) {
      return nested
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    if (dataMap.containsKey('items') && dataMap['items'] is List) {
      return (dataMap['items'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    return [];
  }

  static Map<String, dynamic> pagination(dynamic body) {
    final root = asMap(body);
    final data = asMap(root?['data']);
    final pagination = asMap(data?['pagination']) ?? asMap(root?['pagination']);
    return pagination ?? const {};
  }

  static dynamic unwrapData(dynamic body) {
    final root = asMap(body);
    if (root == null) return body;
    return root['data'] ?? root;
  }
}
