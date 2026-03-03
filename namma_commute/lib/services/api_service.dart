import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  // ── Change this to your Railway URL once deployed ──────────────
  static const String baseUrl = 'https://nammacommutev30-production-production.up.railway.app/api/v1';
  // ───────────────────────────────────────────────────────────────

  static const Duration _timeout = Duration(seconds: 10);

  static final Map<String, dynamic> _cache = {};
  static final Map<String, DateTime> _cacheTime = {};
  static const Duration _cacheTtl = Duration(seconds: 25);

  static Future<dynamic> _get(String path, {bool useCache = true}) async {
    final url = '$baseUrl$path';
    final now = DateTime.now();

    if (useCache &&
        _cache.containsKey(url) &&
        _cacheTime.containsKey(url) &&
        now.difference(_cacheTime[url]!) < _cacheTtl) {
      return _cache[url];
    }

    try {
      final response = await http
          .get(Uri.parse(url), headers: {'Content-Type': 'application/json'})
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _cache[url] = data;
        _cacheTime[url] = now;
        return data;
      }
      throw Exception('HTTP ${response.statusCode}');
    } on SocketException {
      throw Exception('No internet connection');
    } on HttpException {
      throw Exception('Server error');
    } catch (e) {
      // Return cached data if available even if stale
      if (_cache.containsKey(url)) return _cache[url];
      rethrow;
    }
  }

  static Future<dynamic> _post(String path, Map<String, dynamic> body) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl$path'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(_timeout);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    }
    throw Exception('HTTP ${response.statusCode}: ${response.body}');
  }

  // ── AI Real-Time ──────────────────────────────────────────────

  static Future<Map<String, dynamic>> getLiveDashboard() async =>
      await _get('/ai/live') as Map<String, dynamic>;

  static Future<List<dynamic>> getAiHotspots() async {
    final data = await _get('/ai/traffic/hotspots') as Map<String, dynamic>;
    return data['hotspots'] as List<dynamic>;
  }

  static Future<Map<String, dynamic>> getRouteRecommendation(
      String origin, String destination) async =>
      await _get('/ai/routes/recommend?origin=$origin&destination=$destination',
          useCache: false) as Map<String, dynamic>;

  static Future<List<dynamic>> getMetroAiStatus() async {
    final data = await _get('/ai/metro/status') as Map<String, dynamic>;
    return data['lines'] as List<dynamic>;
  }

  // ── Traffic ───────────────────────────────────────────────────

  static Future<List<dynamic>> getTrafficIncidents({
    String? severity,
    String? type,
  }) async {
    String path = '/traffic/';
    final params = <String>[];
    if (severity != null) params.add('severity=$severity');
    if (type != null) params.add('type=$type');
    if (params.isNotEmpty) path += '?${params.join('&')}';
    return await _get(path) as List<dynamic>;
  }

  static Future<Map<String, dynamic>> getTrafficSummary() async =>
      await _get('/traffic/summary') as Map<String, dynamic>;

  static Future<dynamic> upvoteIncident(int id) async =>
      await _post('/traffic/$id/upvote', {});

  static Future<dynamic> createIncident(Map<String, dynamic> data) async =>
      await _post('/traffic/', data);

  // ── Metro ─────────────────────────────────────────────────────

  static Future<List<dynamic>> getMetroLines() async =>
      await _get('/metro/lines') as List<dynamic>;

  static Future<List<dynamic>> getMetroStations(int lineId) async =>
      await _get('/metro/lines/$lineId/stations') as List<dynamic>;

  static Future<List<dynamic>> getMetroSchedule(int lineId,
      {String? fromStation}) async {
    String path = '/metro/lines/$lineId/schedule';
    if (fromStation != null) path += '?from_station=$fromStation';
    return await _get(path) as List<dynamic>;
  }

  static Future<Map<String, dynamic>> getMetroStatus() async =>
      await _get('/metro/status') as Map<String, dynamic>;

  static Future<Map<String, dynamic>> getMetroFare(
      int lineId, String from, String to) async =>
      await _get('/metro/fare?line_id=$lineId&from_station=${Uri.encodeComponent(from)}&to_station=${Uri.encodeComponent(to)}')
          as Map<String, dynamic>;

  // ── Reports ───────────────────────────────────────────────────

  static Future<List<dynamic>> getCommunityReports({String? area}) async {
    String path = '/reports/?status=open';
    if (area != null) path += '&area=$area';
    return await _get(path, useCache: false) as List<dynamic>;
  }

  static Future<dynamic> submitReport(Map<String, dynamic> data) async =>
      await _post('/reports/', data);

  static Future<dynamic> upvoteReport(int id) async =>
      await _post('/reports/$id/upvote', {});

  // ── SOS ───────────────────────────────────────────────────────

  static Future<dynamic> triggerSOS(Map<String, dynamic> data) async =>
      await _post('/sos/alert', data);

  static Future<List<dynamic>> getEmergencyContacts() async =>
      await _get('/sos/contacts') as List<dynamic>;

  static Future<Map<String, dynamic>> getAccidentGuidance() async =>
      await _get('/sos/guidance') as Map<String, dynamic>;
}
