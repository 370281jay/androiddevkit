import 'dart:io';
import 'package:http/http.dart' as http;

class VisionService {
  final String visionUrl;      // 例如 http://<server>/vision (对应 VisionHandler 路由)
  final String authToken;      // Bearer token（需由服务器颁发，客户端不可自行生成）
  final String deviceId;       // 与 token 中绑定的一致
  final String clientId;       // 可为应用或设备实例ID

  VisionService({
    required this.visionUrl,
    required this.authToken,
    required this.deviceId,
    required this.clientId,
  });

  Future<String> analyzeImage(File imageFile, {String question = '分析这张图片'}) async {
    if (!await imageFile.exists()) {
      throw Exception('文件不存在: ${imageFile.path}');
    }

    final uri = Uri.parse(visionUrl);
    final request = http.MultipartRequest('POST', uri);

    // 认证与标识头
    request.headers['Authorization'] = 'Bearer $authToken';
    request.headers['Device-Id'] = deviceId;
    request.headers['Client-Id'] = clientId;

    // 字段与文件
    request.fields['question'] = question;
    request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));

    final streamed = await request.send();
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode == 200) {
      // 预期返回：{"success":true,"action":"RESPONSE","response":"..."}
      final ok = body.contains('"success":true');
      if (!ok) throw Exception('识别失败: $body');
      final start = body.indexOf('"response":');
      if (start >= 0) {
        // 简化解析（建议替换为 jsonDecode）
        return body.substring(start + 11).replaceAll(RegExp(r'^[\s"]|[\s"}]+$'), '');
      }
      return '识别成功，但未返回具体结果';
    } else if (streamed.statusCode == 401) {
      throw Exception('认证失败（401），检查 Authorization/Device-Id/Client-Id');
    } else {
      throw Exception('HTTP ${streamed.statusCode}: $body');
    }
  }
}