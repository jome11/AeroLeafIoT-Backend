import 'dart:convert';
import 'package:dart_frog/dart_frog.dart';
import 'package:aeroleaf_api/db.dart';

Future<Response> onRequest(RequestContext context, String id) async {
  final db = getDb();

  if (context.request.method == HttpMethod.post) {
    final body = jsonDecode(await context.request.body()) as Map<String, dynamic>;
    db.execute(
      'INSERT INTO telemetry (tower_id, tds, temperature, water_level, ph) VALUES (?, ?, ?, ?, ?)',
      [id, body['tds'], body['temperature'], body['water_level'], body['ph']],
    );
    return Response.json(statusCode: 201, body: {'status': 'saved'});
  }

  if (context.request.method == HttpMethod.get) {
    final result = db.select(
      'SELECT * FROM telemetry WHERE tower_id = ? ORDER BY recorded_at DESC LIMIT 1',
      [id],
    );
    if (result.isEmpty) {
      return Response.json(statusCode: 404, body: {'error': 'No data yet'});
    }
    final row = result.first;
    return Response.json(body: {
      'tds': row['tds'],
      'temperature': row['temperature'],
      'water_level': row['water_level'],
      'ph': row['ph'],
      'recorded_at': row['recorded_at'],
    });
  }

  return Response(statusCode: 405);
}