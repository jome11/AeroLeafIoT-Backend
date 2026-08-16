import 'dart:convert';
import 'package:dart_frog/dart_frog.dart';
import '../../lib/db.dart';

Future<Response> onRequest(RequestContext context) async {
  final db = await getDb();

  switch (context.request.method) {
    case HttpMethod.post:
      final body = jsonDecode(await context.request.body()) as Map<String, dynamic>;

      final id = body['id'] as String?;
      if (id == null || id.isEmpty) {
        return Response.json(statusCode: 400, body: {'error': 'id is required'});
      }

      await db.execute(
        'INSERT OR IGNORE INTO towers (id, name, crop_type) VALUES (?, ?, ?)',
        [id, body['name'] ?? id, body['crop_type'] ?? 'Lettuce'],
      );

      return Response.json(statusCode: 201, body: {'status': 'registered', 'id': id});

    case HttpMethod.get:
      final result = await db.select('SELECT id, name, crop_type, created_at FROM towers');
      final towers = result
          .map((row) => {
                'id': row['id'],
                'name': row['name'],
                'crop_type': row['crop_type'],
                'created_at': row['created_at'],
              })
          .toList();

      return Response.json(body: towers);

    default:
      return Response(statusCode: 405);
  }
}