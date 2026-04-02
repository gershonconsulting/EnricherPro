import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class FileApiService {
  static const Duration _timeout = Duration(seconds: 60);

  Future<List<Map<String, dynamic>>> getFiles({int limit = 50, int offset = 0}) async {
    try {
      final headers = await AuthService.authHeaders();
      final resp = await http
          .get(Uri.parse('/api/files?limit=$limit&offset=$offset'), headers: headers)
          .timeout(_timeout);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(data['files'] as List);
      }
    } catch (_) {}
    return [];
  }

  Future<Map<String, dynamic>?> uploadCsv(
      String fileName, List<int> bytes, int recordCount) async {
    try {
      final token = await AuthService.getToken();
      final uri = Uri.parse('/api/files/upload');
      final req = http.MultipartRequest('POST', uri);
      if (token != null) req.headers['Authorization'] = 'Bearer $token';
      req.fields['record_count'] = '$recordCount';
      req.files.add(http.MultipartFile.fromBytes('file', bytes,
          filename: fileName));
      final streamed = await req.send().timeout(_timeout);
      final body = await http.Response.fromStream(streamed);
      if (body.statusCode == 202) {
        return jsonDecode(body.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  Future<bool> deleteFile(int fileId) async {
    try {
      final headers = await AuthService.authHeaders();
      final resp = await http
          .delete(Uri.parse('/api/files/$fileId'), headers: headers)
          .timeout(_timeout);
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  String originalDownloadUrl(int fileId) =>
      '/api/files/$fileId/download/original';

  String enrichedDownloadUrl(int fileId) =>
      '/api/files/$fileId/download/enriched';
}
