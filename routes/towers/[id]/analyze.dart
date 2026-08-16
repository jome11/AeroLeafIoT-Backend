import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dart_frog/dart_frog.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';

// Points at the vision service's /predict endpoint. Set VISION_SERVICE_URL
// as an environment variable in production (e.g. the vision service's
// Render URL); falls back to localhost for local dev.
String get _visionServiceUrl =>
    Platform.environment['VISION_SERVICE_URL'] ?? 'http://localhost:8001/predict';

Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: 405);
  }

  final contentType = context.request.headers['content-type'];
  if (contentType == null || !contentType.contains('multipart/form-data')) {
    return Response.json(statusCode: 400, body: {'error': 'expected multipart/form-data'});
  }

  final boundary = contentType.split('boundary=').last;
  final bodyStream = context.request.bytes(); // already a Stream<List<int>>

  final parts = await MimeMultipartTransformer(boundary)
      .bind(bodyStream)
      .toList();

  Uint8List? imageBytes;
  String filename = 'upload.jpg';
  for (final part in parts) {
    final disposition = part.headers['content-disposition'] ?? '';
    if (disposition.contains('name="image"')) {
      final chunks = await part.toList();
      imageBytes = Uint8List.fromList(chunks.expand((c) => c).toList());
      final match = RegExp('filename="(.+)"').firstMatch(disposition);
      if (match != null) filename = match.group(1)!;
    }
  }

  if (imageBytes == null || imageBytes.isEmpty) {
    return Response.json(statusCode: 400, body: {'error': 'no image field found'});
  }

  try {
    // The vision service expects multipart form data with a "file" field
    // (FastAPI's UploadFile = File(...)) — not a raw octet-stream body.
    final request = http.MultipartRequest('POST', Uri.parse(_visionServiceUrl))
      ..files.add(http.MultipartFile.fromBytes('file', imageBytes, filename: filename));

    final streamedRes = await request.send();
    final visionRes = await http.Response.fromStream(streamedRes);

    if (visionRes.statusCode != 200) {
      return Response.json(statusCode: 502, body: {'error': 'vision service error'});
    }

    final prediction = jsonDecode(visionRes.body) as Map<String, dynamic>;

    return Response.json(body: {
      ...prediction,
      'analyzed_at': DateTime.now().toIso8601String(),
    });
  } catch (e) {
    return Response.json(statusCode: 502, body: {'error': 'vision service unreachable'});
  }
}