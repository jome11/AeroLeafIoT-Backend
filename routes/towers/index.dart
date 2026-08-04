import 'dart:convert';
import 'package:dart_frog/dart_frog.dart';
import '../../lib/db.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: 405);
  }

  final db = getDb();
  final body = jsonDecode(await context.request.body()) as Map<String, dynamic>;

  db.execute(
    'INSERT OR IGNORE INTO towers (id, name, crop_type) VALUES (?, ?, ?)',
    [body['id'], body['name'] ?? body['id'], body['crop_type'] ?? 'Lettuce'],
  );

  return Response.json(statusCode: 201, body: {'status': 'registered', 'id': body['id']});
}