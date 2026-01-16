import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';

class EmailService {
  static const String _baseUrl = 'https://zhihu.xmjsy.com/api/email';

  /// 发送docx文件到指定邮箱
  static Future<bool> sendDocxFile({
    required String docxAssetPath,
    required String toEmail,
  }) async {
    try {
      // 验证邮箱格式
      if (!isValidEmail(toEmail)) {
        throw Exception('邮箱格式不正确');
      }

      // 从assets加载docx文件到临时文件
      final byteData = await rootBundle.load(docxAssetPath);
      final bytes = byteData.buffer.asUint8List();
      
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/experiment_report.docx');
      await tempFile.writeAsBytes(bytes);

      // 创建multipart请求
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/send-docx'),
      );

      // 添加文件 (注意：必须是小写的 'file')
      final multipartFile = await http.MultipartFile.fromPath(
        'file',
        tempFile.path,
        filename: 'experiment_report.docx',
      );
      request.files.add(multipartFile);

      // 添加接收邮箱
      request.fields['toEmail'] = toEmail;

      // 发送请求
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      // 清理临时文件
      try {
        await tempFile.delete();
      } catch (e) {
        // 忽略删除错误
      }

      // 修正成功判断逻辑
      if (response.statusCode == 201) {
        try {
          final jsonResponse = jsonDecode(response.body);
          // 检查返回的JSON中是否包含success字段且为true
          if (jsonResponse['success'] == true) {
            return true;
          } else {
            throw Exception('发送失败: ${jsonResponse['message'] ?? '未知错误'}');
          }
        } catch (e) {
          // 如果无法解析JSON，但状态码是200，也认为成功
          return true;
        }
      } else {
        throw Exception('发送失败: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('邮件发送失败: $e');
    }
  }

  /// 验证邮箱格式
  static bool isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }
}