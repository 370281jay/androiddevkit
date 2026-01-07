import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:ai_assistant/utils/logging.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class InfluxDBService {
  final String influxUrl;
  final String influxToken;
  final String influxOrg;
  final String defaultBucket;
  final String defaultDeviceId;

  InfluxDBService({
    this.influxUrl = 'https://influx.lanhc.com',
    this.influxToken = 'kcF_lnBLOpnArrmmHytfGCeo5bGh5LQJb_d6wxyBZntWUbz-KyUv8UH_3huFP5Ac3SjOwX5KniuEmgpV_WUwYQ==',
    this.influxOrg = 'ld6002h',
    this.defaultBucket = 'vitals_data',
    this.defaultDeviceId = '84F7035346E0',
  });

  /// 查询 InfluxDB 数据
  Future<InfluxDBQueryResponse> query({
    String? query,
    String? field,
    String? mode,
    String? bucket,
    String? deviceId,
  }) async {
    try {
      logInflux('query() start field=$field mode=$mode bucket=${bucket ?? defaultBucket} device=${deviceId ?? defaultDeviceId}');
      final effectiveBucket = bucket?.isNotEmpty == true ? bucket! : defaultBucket;
      final effectiveDeviceId = deviceId?.isNotEmpty == true ? deviceId! : defaultDeviceId;
      
      String effectiveQuery = query ?? '';
      
      // 如果没有提供查询语句，根据模式生成
      if (effectiveQuery.isEmpty) {
        if (field?.isEmpty ?? true) {
          throw ArgumentError('field is required when query is empty');
        }
        
        switch (mode) {
          case 'tma2m':
            effectiveQuery = _fluxSampleTMA2M(effectiveBucket, effectiveDeviceId, field!);
            break;
          // case 'mean5m':
          //   effectiveQuery = _fluxMean5m(effectiveBucket, effectiveDeviceId, field!);
          //   break;
          default:
            throw ArgumentError('unsupported mode, use tma2m or mean5m');
        }
      }

      debugPrint('InfluxDB Query: $effectiveQuery');

      // 构建查询 URL
      final queryUrl = Uri.parse('$influxUrl/api/v2/query');
      final finalUrl = queryUrl.replace(queryParameters: {'org': influxOrg});
      final requestBody = json.encode({'query': effectiveQuery});

      logInflux('POST $finalUrl');
      logInflux('Headers: Accept=text/csv Content-Type=application/json');
      logInflux('Body size: ${requestBody.length}');
      // logInfluxLarge('Flux:\n$effectiveQuery');

      // 发送 POST 请求
      final response = await http.post(
        finalUrl,
        headers: {
          'Authorization': 'Token $influxToken',
          'Accept': 'text/csv',
          'Content-Type': 'application/json',
          'User-Agent': 'Flutter-Android-Client/1.0',
        },
        body: requestBody,
      ).timeout(const Duration(seconds: 30));

      logInflux('Status: ${response.statusCode}');
      logInflux('Content-Type: ${response.headers['content-type']}');
      logInflux('Body length: ${response.body.length}');

      // 分片异步打印（控制台查看）
      await logInfluxLargeAsync(response.body);

      // 将完整响应写入外部存储文件（便于用文件管理器或 adb pull 查看）
      final extDir = await getExternalStorageDirectory(); // /storage/emulated/0/Android/data/<pkg>/files
      final dir = Directory('${extDir?.path ?? (await getApplicationDocumentsDirectory()).path}/influx');
      await dir.create(recursive: true);
      final ts = DateTime.now().toIso8601String().replaceAll(':', '-');
      final file = File('${dir.path}/response_$ts.txt');
      await file.writeAsString(response.body);
      logInflux('Dump saved: ${file.path}');

      if (response.statusCode != 200) {
        throw HttpException('InfluxDB query failed: ${response.body}');
      }

      final contentType = response.headers['content-type'] ?? '';
      
      if (contentType.toLowerCase().contains('text/csv')) {
        // 解析 CSV 响应
        final parsedData = _parseFluxCSV(response.body);
        logInflux('Parsed CSV rows=${parsedData.length}');
        return InfluxDBQueryResponse(results: parsedData);
      } else if (contentType.contains('application/json')) {
        // 解析 JSON 响应
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        return InfluxDBQueryResponse.fromJson(jsonData);
      } else {
        throw FormatException('Unexpected content type: $contentType');
      }
    } catch (e) {
      logInflux('Error: $e');
      return InfluxDBQueryResponse(error: e.toString());
    }
  }

  /// 生成时间移动平均采样查询（过去10s）
  String _fluxSampleTMA2M(String bucket, String deviceId, String field) {
    return '''
from(bucket: "$bucket")
  |> range(start: -10s)
  |> filter(fn: (r) => r["device_id"] == "$deviceId")
  |> filter(fn: (r) => r["_field"] == "$field")
  |> filter(fn: (r) => r._value != 0)

''';
  }

//   /// 生成平均值查询（过去2分钟）
//   String _fluxMean5m(String bucket, String deviceId, String field) {
//     return '''
// from(bucket: "$bucket")
//   |> range(start: -2m)
//   |> filter(fn: (r) => r["device_id"] == "$deviceId")
//   |> filter(fn: (r) => r["_field"] == "$field")
//   |> filter(fn: (r) => r._value != 0)
//   |> mean()
// ''';
//   }

  /// 解析 Flux CSV 响应
  List<Map<String, String>> _parseFluxCSV(String csvData) {
    final lines = csvData.split('\n');
    final List<Map<String, String>> rows = [];
    List<String>? headers;

    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      
      final fields = _parseCsvLine(line);
      if (fields.isEmpty) continue;

      // 跳过注释行
      if (fields[0].startsWith('#')) {
        headers = null;
        continue;
      }

      // 设置表头
      if (headers == null) {
        headers = fields;
        continue;
      }

      // 解析数据行
      final Map<String, String> row = {};
      for (int i = 0; i < headers.length && i < fields.length; i++) {
        row[headers[i]] = fields[i];
      }
      if (row.isNotEmpty) {
        rows.add(row);
      }
    }

    return rows;
  }

  /// 简单的 CSV 行解析（处理逗号分隔）
  List<String> _parseCsvLine(String line) {
    return line.split(',').map((field) => field.trim()).toList();
  }

  // 新增：获取心率/呼吸频率最新值
  Future<VitalsData> fetchLatestVitals({
    String? deviceId,
    String? bucket,
  }) async {
    final effectiveBucket = bucket?.isNotEmpty == true ? bucket! : defaultBucket;
    final effectiveDeviceId = deviceId?.isNotEmpty == true ? deviceId! : defaultDeviceId;

    // 使用 last() 直接取每个字段的最后一条
    final flux = '''
from(bucket: "$effectiveBucket")
  |> range(start: -2m)
  |> filter(fn: (r) => r["device_id"] == "$effectiveDeviceId")
  |> filter(fn: (r) => r["_field"] == "heart_rate_bpm" or r["_field"] == "respiration_bpm")
  |> last()
''';

    final resp = await query(query: flux);
    if (resp.hasResults) {
      final rows = (resp.results as List).cast<Map>();
      int? hr;
      int? rr;
      DateTime? ts;

      for (final row in rows) {
        final field = (row['_field'] ?? '').toString();
        final valueStr = (row['_value'] ?? '').toString();
        final timeStr = (row['_time'] ?? '').toString();

        final v = int.tryParse(valueStr);
        final t = DateTime.tryParse(timeStr) ?? ts;

        if (field == 'heart_rate_bpm') {
          hr = v ?? hr;
          ts = t ?? ts;
        } else if (field == 'respiration_bpm') {
          rr = v ?? rr;
          ts = t ?? ts;
        }
      }
      return VitalsData(heartRateBpm: hr, respirationBpm: rr, time: ts);
    }
    return VitalsData();
  }
}

// 新增：生命体征数据模型
class VitalsData {
  final int? heartRateBpm;
  final int? respirationBpm;
  final DateTime? time;

  VitalsData({this.heartRateBpm, this.respirationBpm, this.time});
}

/// InfluxDB 查询请求模型
class InfluxDBQueryRequest {
  final String? query;
  final String? field;
  final String? mode;
  final String? bucket;
  final String? deviceId;

  InfluxDBQueryRequest({
    this.query,
    this.field,
    this.mode,
    this.bucket,
    this.deviceId,
  });

  Map<String, dynamic> toJson() {
    return {
      if (query != null) 'query': query,
      if (field != null) 'field': field,
      if (mode != null) 'mode': mode,
      if (bucket != null) 'bucket': bucket,
      if (deviceId != null) 'deviceId': deviceId,
    };
  }
}

/// InfluxDB 查询响应模型
class InfluxDBQueryResponse {
  final List<dynamic>? results;
  final String? error;

  InfluxDBQueryResponse({this.results, this.error});

  factory InfluxDBQueryResponse.fromJson(Map<String, dynamic> json) {
    return InfluxDBQueryResponse(
      results: json['results'] as List<dynamic>?,
      error: json['error'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (results != null) 'results': results,
      if (error != null) 'error': error,
    };
  }

  bool get hasError => error != null;
  bool get hasResults => results != null && results!.isNotEmpty;
}