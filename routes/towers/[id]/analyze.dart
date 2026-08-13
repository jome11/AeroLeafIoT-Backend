import 'dart:convert';
import 'dart:typed_data';
import 'package:dart_frog/dart_frog.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';

// Points at the small Python service that loads your .pkl models and
// returns a prediction. Run it separately from `dart_frog dev`.
const _visionServiceUrl = 'http://10.158.20.225:8001/predict';

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
  for (final part in parts) {
    final disposition = part.headers['content-disposition'] ?? '';
    if (disposition.contains('name="image"')) {
      final chunks = await part.toList();
      imageBytes = Uint8List.fromList(chunks.expand((c) => c).toList());
    }
  }

  if (imageBytes == null || imageBytes.isEmpty) {
    return Response.json(statusCode: 400, body: {'error': 'no image field found'});
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

    final prediction = jsonDecode(visionRes.body) as Map<String, dynamic>;

    return Response.json(body: {
      ...prediction,
      'analyzed_at': DateTime.now().toIso8601String(),
    });
  } catch (e) {
    return Response.json(statusCode: 502, body: {'error': 'vision service unreachable'});
  }
}