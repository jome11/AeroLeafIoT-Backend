import 'dart:convert';
import 'package:dart_frog/dart_frog.dart';
import 'package:aeroleaf_api/db.dart';

Future<Response> onRequest(RequestContext context, String id) async {
  final db = await getDb();

  if (context.request.method == HttpMethod.get) {
    final result = await db.select('SELECT * FROM device_state WHERE tower_id = ?', [id]);

    if (result.isEmpty) {
      return Response.json(body: {
        'tower_id': id,
        'automatic_mode': true,
        'pump_manual': false,
        'pump_status': false,
        'pump_remaining_time': 0,
      });
    }

    final row = result.first;
    return Response.json(body: {
      'tower_id': id,
      'automatic_mode': row['automatic_mode'] == 1,
      'pump_manual': row['pump_manual'] == 1,
      'pump_status': row['pump_status'] == 1,
      'pump_remaining_time': row['pump_remaining_time'],
      'updated_at': row['updated_at'],
    });
  }

  if (context.request.method == HttpMethod.post) {
    final body = jsonDecode(await context.request.body()) as Map<String, dynamic>;
    final existing = await db.select('SELECT * FROM device_state WHERE tower_id = ?', [id]);
    final current = existing.isNotEmpty ? existing.first : null;

    bool boolOr(String key, bool fallback) =>
        body.containsKey(key) ? body[key] as bool : fallback;
    int intOr(String key, int fallback) =>
        body.containsKey(key) ? (body[key] as num).toInt() : fallback;

    final automaticMode = boolOr('automatic_mode', current?['automatic_mode'] == 1);
    final pumpManual = boolOr('pump_manual', current?['pump_manual'] == 1);
    final pumpStatus = boolOr('pump_status', current?['pump_status'] == 1);
    final pumpRemainingTime =
        intOr('pump_remaining_time', (current?['pump_remaining_time'] as int?) ?? 0);

    await db.execute(
      '''
      INSERT INTO device_state (tower_id, automatic_mode, pump_manual, pump_status, pump_remaining_time, updated_at)
      VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
      ON CONFLICT(tower_id) DO UPDATE SET
        automatic_mode = excluded.automatic_mode,
        pump_manual = excluded.pump_manual,
        pump_status = excluded.pump_status,
        pump_remaining_time = excluded.pump_remaining_time,
        updated_at = CURRENT_TIMESTAMP
      ''',
      [id, automaticMode ? 1 : 0, pumpManual ? 1 : 0, pumpStatus ? 1 : 0, pumpRemainingTime],
    );

    return Response.json(body: {'status': 'updated'});
  }

  return Response(statusCode: 405);
}