import 'dart:convert';
import 'package:dart_frog/dart_frog.dart';
import 'package:http/http.dart' as http;

// Point this at wherever the Python inference service is running
const _visionServiceUrl = 'http://localhost:8001/predict';

Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: 405);
  }

  final body = jsonDecode(await context.request.body()) as Map<String, dynamic>;
  final imageBase64 = body['image_base64'] as String?;

  if (imageBase64 == null || imageBase64.isEmpty) {
    return Response.json(statusCode: 400, body: {'error': 'image_base64 is required'});
  }

  late final List<int> imageBytes;
  try {
    imageBytes = base64Decode(imageBase64);
  } catch (_) {
    return Response.json(statusCode: 400, body: {'error': 'invalid base64'});
  }

  try {
    final visionRes = await http.post(
      Uri.parse(_visionServiceUrl),
      headers: {'Content-Type': 'application/octet-stream'},
      body: imageBytes,
    );

    if (visionRes.statusCode != 200) {
      return Response.json(statusCode: 502, body: {'error': 'vision service error'});
    }

    // Pass the prediction straight through to the app
    return Response(
      body: visionRes.body,
      headers: {'Content-Type': 'application/json'},
    );
  } catch (e) {
    return Response.json(statusCode: 502, body: {'error': 'vision service unreachable'});
  }
}