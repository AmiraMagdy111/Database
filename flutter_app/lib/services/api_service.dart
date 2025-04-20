import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/sensor_data.dart';

class ApiService {
  final String baseUrl;
  final http.Client _client = http.Client();

  ApiService({required this.baseUrl});

  Future<bool> checkHealth() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/api/health'),
        headers: {'Accept': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['status'] == 'healthy';
      }
      return false;
    } catch (e) {
      print('Health check failed: $e');
      return false;
    }
  }

  Future<List<String>> getSensors() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/api/sensors'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<String>.from(data['sensors']);
      } else {
        final error = json.decode(response.body);
        throw Exception(error['error'] ?? 'Failed to load sensors');
      }
    } catch (e) {
      print('Error getting sensors: $e');
      rethrow;
    }
  }

  Future<List<SensorData>> getSensorData(
    String sensorId, {
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (startTime != null) {
        queryParams['start_time'] = startTime.toIso8601String();
      }
      if (endTime != null) {
        queryParams['end_time'] = endTime.toIso8601String();
      }

      final uri = Uri.parse('$baseUrl/api/sensor/$sensorId').replace(
        queryParameters: queryParams,
      );

      final response = await _client.get(
        uri,
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['data'] as List)
            .map((json) => SensorData.fromJson(json))
            .toList();
      } else if (response.statusCode == 404) {
        throw Exception('Sensor not found');
      } else {
        final error = json.decode(response.body);
        throw Exception(error['error'] ?? 'Failed to load sensor data');
      }
    } catch (e) {
      print('Error getting sensor data: $e');
      rethrow;
    }
  }

  void dispose() {
    _client.close();
  }
}
