/// Loose, null-safe access to the API's JSON. The mobile API returns the
/// same shapes the web pages render from, so screens read fields directly
/// instead of going through a model class per endpoint.
typedef Json = Map<String, dynamic>;

extension JsonX on Map<String, dynamic> {
  /// Dotted path lookup: `j.at('employee.name')`.
  Object? at(String path) {
    Object? cur = this;
    for (final key in path.split('.')) {
      if (cur is Map) {
        cur = cur[key];
      } else if (cur is List) {
        final i = int.tryParse(key);
        cur = (i != null && i >= 0 && i < cur.length) ? cur[i] : null;
      } else {
        return null;
      }
    }
    return cur;
  }

  /// String (empty when missing).
  String s(String path, [String fallback = '']) {
    final v = at(path);
    if (v == null) return fallback;
    return v.toString();
  }

  /// Nullable string - null for missing or empty.
  String? sn(String path) {
    final v = at(path);
    if (v == null) return null;
    final str = v.toString();
    return str.isEmpty ? null : str;
  }

  int i(String path, [int fallback = 0]) {
    final v = at(path);
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? fallback;
  }

  int? iN(String path) {
    final v = at(path);
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '');
  }

  double d(String path, [double fallback = 0]) {
    final v = at(path);
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? fallback;
  }

  double? dN(String path) {
    final v = at(path);
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '');
  }

  bool b(String path) {
    final v = at(path);
    return v == true || v == 'true';
  }

  bool has(String path) => at(path) != null;

  Json m(String path) {
    final v = at(path);
    return v is Map ? v.cast<String, dynamic>() : <String, dynamic>{};
  }

  Json? mN(String path) {
    final v = at(path);
    return v is Map ? v.cast<String, dynamic>() : null;
  }

  /// List of objects.
  List<Json> l(String path) {
    final v = at(path);
    if (v is! List) return const [];
    return v.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }

  /// List of scalars.
  List<T> list<T>(String path) {
    final v = at(path);
    if (v is! List) return <T>[];
    return v.whereType<T>().toList();
  }
}

Json asJson(Object? value) => value is Map ? value.cast<String, dynamic>() : <String, dynamic>{};
List<Json> asJsonList(Object? value) =>
    value is List ? value.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList() : const [];
