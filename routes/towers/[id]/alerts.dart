import 'dart:convert';
import 'package:dart_frog/dart_frog.dart';
import '../../../lib/db.dart';

Future<Response> onRequest(RequestContext context, String id) async {
  final db = getDb();

  if (context.request.method == HttpMethod.get) {
    final result = db.select(
      'SELECT * FROM alerts WHERE tower_id = ? ORDER BY created_at DESC',
      [id],
    );
    final alerts = result.map((row) => {
      'id': row['id'],
      'severity': row['severity'],
      'title': row['title'],
      'description': row['description'],
      'created_at': row['created_at'],
    }).toList();
    return Response.json(body: {'alerts': alerts});
  }

  if (context.request.method == HttpMethod.post) {
    final body = jsonDecode(await context.request.body()) as Map<String, dynamic>;
    db.execute(
      'INSERT INTO alerts (tower_id, severity, title, description) VALUES (?, ?, ?, ?)',
      [id, body['severity'], body['title'], body['description']],
    );
    return Response.json(statusCode: 201, body: {'status': 'saved'});
  }

  return Response(statusCode: 405);
}