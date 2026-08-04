import 'dart:convert';
import 'package:dart_frog/dart_frog.dart';
import '../../../lib/db.dart';

Future<Response> onRequest(RequestContext context, String id) async {
  final db = getDb();

  if (context.request.method == HttpMethod.get) {
    final result = db.select(
      'SELECT * FROM automation_schedules WHERE tower_id = ?',
      [id],
    );
    final schedules = result.map((row) => {
      'id': row['id'],
      'name': row['name'],
      'cycle_interval_mins': row['cycle_interval_mins'],
      'duration_secs': row['duration_secs'],
      'active': row['active'] == 1,
      'last_triggered': row['last_triggered'],
    }).toList();
    return Response.json(body: {'schedules': schedules});
  }

  if (context.request.method == HttpMethod.post) {
    final body = jsonDecode(await context.request.body()) as Map<String, dynamic>;
    db.execute(
      'INSERT INTO automation_schedules (tower_id, name, cycle_interval_mins, duration_secs, active) VALUES (?, ?, ?, ?, ?)',
      [id, body['name'], body['cycle_interval_mins'], body['duration_secs'], body['active'] == true ? 1 : 0],
    );
    return Response.json(statusCode: 201, body: {'status': 'saved'});
  }

  return Response(statusCode: 405);
}