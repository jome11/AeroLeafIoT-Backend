import 'dart:convert';
import 'package:http/http.dart' as http;

/// Minimal Turso client using the libSQL HTTP (v2/pipeline) API.
///
/// This avoids any native/FFI package (like `libsql_dart`, which is built as
/// a Flutter plugin and won't load under a plain `dart run` / Dart Frog
/// server). It talks to Turso the same way `fetch()` or `curl` would: plain
/// JSON over HTTPS, using the `http` package this project already depends on.
///
/// Docs: https://docs.turso.tech/sdk/http/quickstart
class TursoClient {
  TursoClient({required String databaseUrl, required this.authToken})
      : _pipelineUrl = _toPipelineUrl(databaseUrl);

  final String authToken;
  final Uri _pipelineUrl;

  static Uri _toPipelineUrl(String databaseUrl) {
    // Accepts either "libsql://xxx.turso.io" or "https://xxx.turso.io".
    final httpsUrl = databaseUrl.startsWith('libsql://')
        ? databaseUrl.replaceFirst('libsql://', 'https://')
        : databaseUrl;
    final base = httpsUrl.endsWith('/')
        ? httpsUrl.substring(0, httpsUrl.length - 1)
        : httpsUrl;
    return Uri.parse('$base/v2/pipeline');
  }

  /// Runs a statement and returns the decoded rows as
  /// `List<Map<String, dynamic>>`, keyed by column name.
  Future<List<Map<String, dynamic>>> select(
    String sql, [
    List<Object?> args = const [],
  ]) async {
    final result = await _executeOne(sql, args);
    final cols = (result['cols'] as List)
        .map((c) => (c as Map)['name'] as String)
        .toList();
    final rows = result['rows'] as List;

    return rows.map<Map<String, dynamic>>((row) {
      final values = row as List;
      return {
        for (var i = 0; i < cols.length; i++) cols[i]: _decodeValue(values[i]),
      };
    }).toList();
  }

  /// Runs a statement that doesn't return rows (INSERT/UPDATE/DELETE/DDL).
  Future<void> execute(String sql, [List<Object?> args = const []]) async {
    await _executeOne(sql, args);
  }

  Future<Map<String, dynamic>> _executeOne(
    String sql,
    List<Object?> args,
  ) async {
    final payload = {
      'requests': [
        {
          'type': 'execute',
          'stmt': {
            'sql': sql,
            'args': args.map(_encodeValue).toList(),
          },
        },
        {'type': 'close'},
      ],
    };

    final response = await http.post(
      _pipelineUrl,
      headers: {
        'Authorization': 'Bearer $authToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Turso request failed (${response.statusCode}): ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final results = decoded['results'] as List;
    final first = results.first as Map<String, dynamic>;

    if (first['type'] == 'error') {
      final error = first['error'] as Map<String, dynamic>;
      throw Exception('Turso error: ${error['message']}');
    }

    final response0 = first['response'] as Map<String, dynamic>;
    return response0['result'] as Map<String, dynamic>;
  }

  static Map<String, dynamic> _encodeValue(Object? value) {
    if (value == null) return {'type': 'null'};
    if (value is int) return {'type': 'integer', 'value': value.toString()};
    if (value is double) return {'type': 'float', 'value': value};
    if (value is bool) return {'type': 'integer', 'value': value ? '1' : '0'};
    return {'type': 'text', 'value': value.toString()};
  }

  static Object? _decodeValue(Object? raw) {
    final map = raw as Map<String, dynamic>;
    switch (map['type']) {
      case 'null':
        return null;
      case 'integer':
        return int.parse(map['value'] as String);
      case 'float':
        return (map['value'] as num).toDouble();
      case 'text':
        return map['value'] as String;
      case 'blob':
        return map['base64'] as String;
      default:
        return null;
    }
  }
}
