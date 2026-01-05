import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:ai_assistant/utils/device_util.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DifyService {
  final String apiKey;
  final String apiUrl;
  String? _deviceUserId;

  // 存储会话 ID 与conversation ID的映射表
  final Map<String, String> _sessionConversationMap = {};

  // SharedPreferences 键名
  static const String _conversationMapKey = 'dify_conversation_map';
  // 标记映射表是否已经加载
  bool _isMapLoaded = false;
  // 确保只加载一次的标记
  final Completer<void> _loadCompleter = Completer<void>();

  DifyService._({
    required this.apiKey,
    required this.apiUrl,
    required String deviceId,
  }) {
    _deviceUserId = deviceId;
    _loadConversationMap();
  }

  static Future<DifyService> create({
    required String apiKey,
    required String apiUrl,
  }) async {
    final deviceId = await DeviceUtil.getDeviceId();
    print('DifyService: 创建实例时获取设备ID = $deviceId');
    return DifyService._(apiKey: apiKey, apiUrl: apiUrl, deviceId: deviceId);
  }

  // 从本地存储加载会话ID映射表
  Future<void> _loadConversationMap() async {
    if (_isMapLoaded) {
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? mapJson = prefs.getString(_conversationMapKey);

      if (mapJson != null && mapJson.isNotEmpty) {
        final Map<String, dynamic> loadedMap = jsonDecode(mapJson);
        _sessionConversationMap.clear();

        // 转换动态类型的Map为String类型
        loadedMap.forEach((key, value) {
          if (value is String) {
            _sessionConversationMap[key] = value;
          }
        });

        print(
          'DifyService: 已从本地存储加载 ${_sessionConversationMap.length} 个会话ID映射',
        );

        // 打印所有已加载的会话ID，方便调试
        _sessionConversationMap.forEach((sessionId, conversationId) {
          print('DifyService: 已加载会话映射: $sessionId => $conversationId');
        });
      } else {
        print('DifyService: 没有找到存储的会话ID映射');
      }

      // 标记为已加载
      _isMapLoaded = true;
      if (!_loadCompleter.isCompleted) {
        _loadCompleter.complete();
      }
    } catch (e) {
      print('DifyService: 加载会话ID映射失败: $e');
      if (!_loadCompleter.isCompleted) {
        _loadCompleter.completeError(e);
      }
    }
  }

  // 确保映射表已加载
  Future<void> _ensureMapLoaded() async {
    if (!_isMapLoaded) {
      await _loadCompleter.future;
    }
  }

  // 保存会话ID映射表到本地存储
  Future<void> _saveConversationMap() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String mapJson = jsonEncode(_sessionConversationMap);
      await prefs.setString(_conversationMapKey, mapJson);
      print('DifyService: 已保存 ${_sessionConversationMap.length} 个会话ID映射到本地存储');
    } catch (e) {
      print('DifyService: 保存会话ID映射失败: $e');
    }
  }

  // 确保URL使用HTTP/HTTPS协议并且去除末尾斜杠
  String _ensureHttpProtocol(String url) {
    String sanitizedUrl = url;

    // 替换协议
    if (sanitizedUrl.startsWith('ws://')) {
      sanitizedUrl = sanitizedUrl.replaceFirst('ws://', 'http://');
    } else if (sanitizedUrl.startsWith('wss://')) {
      sanitizedUrl = sanitizedUrl.replaceFirst('wss://', 'https://');
    } else if (!sanitizedUrl.startsWith('http://') &&
        !sanitizedUrl.startsWith('https://')) {
      sanitizedUrl = 'https://$sanitizedUrl';
    }

    // 去除URL末尾的斜杠，确保构建路径时不会出现双斜杠
    while (sanitizedUrl.endsWith('/')) {
      sanitizedUrl = sanitizedUrl.substring(0, sanitizedUrl.length - 1);
    }

    return sanitizedUrl;
  }

  // 获取设备用户ID，确保在整个应用生命周期内保持一致
  Future<String> _getDeviceUserId() async {
    if (_deviceUserId == null) {
      _deviceUserId = await DeviceUtil.getDeviceId();
      print('DifyService: 使用设备ID作为用户标识 = $_deviceUserId');
    }
    return _deviceUserId!;
  }

  // 获取会话的conversation_id
  Future<String?> _getConversationId(String sessionId) async {
    // 确保映射表已加载
    await _ensureMapLoaded();

    // 如果此会话已有conversation_id，直接返回
    if (_sessionConversationMap.containsKey(sessionId) &&
        _sessionConversationMap[sessionId]!.isNotEmpty) {
      print(
        'DifyService: 使用现有的会话ID = ${_sessionConversationMap[sessionId]} 用于会话 $sessionId',
      );
      return _sessionConversationMap[sessionId]!;
    }

    // 对于首次聊天，返回null让API自己创建conversation_id
    print('DifyService: 未找到会话 $sessionId 的ID，将创建新会话');
    return null;
  }

  Future<String> sendMessage(
    String message, {
    String sessionId = "default_session",
    bool forceNewConversation = false, // 是否强制创建新对话
    List<String>? fileIds, // 添加文件ID列表参数
  }) async {
    try {
      // 确保映射表已加载
      await _ensureMapLoaded();

      // 如果强制创建新对话，清除当前会话的conversation_id
      if (forceNewConversation) {
        print('DifyService: 强制创建新会话，清除现有会话ID');
        _sessionConversationMap.remove(sessionId);
        await _saveConversationMap(); // 保存更改到本地存储
      }

      // 获取conversation_id（可能为null，表示首次聊天）
      String? conversationId = await _getConversationId(sessionId);

      // 确保URL使用HTTP/HTTPS协议
      final sanitizedApiUrl = _ensureHttpProtocol(apiUrl);
      final requestUrl = '$sanitizedApiUrl/chat-messages';

      print('DifyService: 发送请求到 $requestUrl');
      print(
        'DifyService: API Key = ${apiKey.substring(0, math.min(5, apiKey.length))}...',
      );
      print('DifyService: 会话 ID = $sessionId');
      print('DifyService: Conversation ID = $conversationId');
      print('DifyService: 用户 ID = $_deviceUserId');
      if (fileIds != null && fileIds.isNotEmpty) {
        print('DifyService: 文件 IDs = $fileIds');
      }

      final requestMap = {
        'inputs': {},
        'query': message,
        'response_mode': 'blocking',
        'user': _deviceUserId,
      };

      // 只有在已有conversation_id时才添加到请求中
      if (conversationId != null) {
        requestMap['conversation_id'] = conversationId;
      }

      // 添加文件（如果有）- 使用正确的格式
      if (fileIds != null && fileIds.isNotEmpty) {
        final List<Map<String, dynamic>> filesArray =
            fileIds
                .map(
                  (fileId) => {
                    'type': 'image',
                    'transfer_method': 'local_file',
                    'upload_file_id': fileId,
                  },
                )
                .toList();

        requestMap['files'] = filesArray;
      }

      final requestBody = jsonEncode(requestMap);

      final response = await http.post(
        Uri.parse(requestUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: requestBody,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // 无条件保存服务器返回的conversation_id，确保一致性
        if (data['conversation_id'] != null) {
          // 始终使用服务器返回的ID
          conversationId = data['conversation_id'] as String;
          _sessionConversationMap[sessionId] = conversationId;
          print('DifyService: 保存服务器返回的会话ID = $conversationId');
          await _saveConversationMap(); // 保存更改到本地存储
        }

        return data['answer'] ?? '无回复';
      } else {
        // 特殊处理404 Conversation Not Exists错误
        if (response.statusCode == 404 &&
            response.body.contains("Conversation Not Exists")) {
          print('DifyService: 会话不存在，创建新会话');
          // 清除会话ID并重试，但不递归太多次以避免无限循环
          _sessionConversationMap.remove(sessionId);
          await _saveConversationMap();
          // 递归调用自身，但确保不会无限循环
          return sendMessage(message, sessionId: sessionId, fileIds: fileIds);
        }

        throw Exception(
          'API 请求失败: ${response.statusCode}, 响应: ${response.body}',
        );
      }
    } catch (e) {
      print('DifyService 错误: $e');
      throw Exception('发送消息失败: $e');
    }
  }

  // 流式响应版本
  Stream<String> sendMessageStream(
    String message, {
    String sessionId = "default_session",
    bool forceNewConversation = false, // 是否强制创建新对话
    List<String>? fileIds, // 添加文件ID列表参数
  }) async* {
    try {
      // 确保映射表已加载
      await _ensureMapLoaded();

      // 如果强制创建新对话，清除当前会话的conversation_id
      if (forceNewConversation) {
        print('DifyService Stream: 强制创建新会话，清除现有会话ID');
        _sessionConversationMap.remove(sessionId);
        await _saveConversationMap(); // 保存更改到本地存储
      }

      // 获取conversation_id（可能为null，表示首次聊天）
      String? conversationId = await _getConversationId(sessionId);

      // 获取设备用户ID
      final userId = await _getDeviceUserId();

      // 确保URL使用HTTP/HTTPS协议
      final sanitizedApiUrl = _ensureHttpProtocol(apiUrl);
      final requestUrl = '$sanitizedApiUrl/chat-messages';

      print('DifyService Stream: 发送请求到 $requestUrl');
      print(
        'DifyService Stream: API Key = ${apiKey.substring(0, math.min(5, apiKey.length))}...',
      );
      print('DifyService Stream: 会话 ID = $sessionId');
      print('DifyService Stream: Conversation ID = $conversationId');
      print('DifyService Stream: 用户 ID = $userId');
      if (fileIds != null && fileIds.isNotEmpty) {
        print('DifyService Stream: 文件 IDs = $fileIds');
      }

      final request = http.Request('POST', Uri.parse(requestUrl));
      request.headers.addAll({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      });

      final requestMap = {
        'inputs': {},
        'query': message,
        'response_mode': 'streaming',
        'user': userId,
      };

      // 只有在已有conversation_id时才添加到请求中
      if (conversationId != null) {
        requestMap['conversation_id'] = conversationId;
      }

      // 添加文件IDs（如果有）
      if (fileIds != null && fileIds.isNotEmpty) {
        final List<Map<String, dynamic>> filesArray =
            fileIds
                .map(
                  (fileId) => {
                    'type': 'image',
                    'transfer_method': 'local_file',
                    'upload_file_id': fileId,
                  },
                )
                .toList();

        requestMap['files'] = filesArray;
      }

      final requestBody = jsonEncode(requestMap);
      print('DifyService Stream: 请求体 = $requestBody');
      request.body = requestBody;

      final streamedResponse = await http.Client().send(request);
      print('DifyService Stream: 响应状态码 = ${streamedResponse.statusCode}');

      if (streamedResponse.statusCode == 404) {
        // 特殊处理404错误
        final responseBody = await streamedResponse.stream.bytesToString();
        if (responseBody.contains("Conversation Not Exists")) {
          print('DifyService Stream: 会话不存在，创建新会话');
          // 清除会话ID并重试
          _sessionConversationMap.remove(sessionId);
          await _saveConversationMap();
          // 递归调用自身，但使用阻塞模式以简化处理
          final response = await sendMessage(
            message,
            sessionId: sessionId,
            fileIds: fileIds,
          );
          yield response;
          return;
        }
        throw Exception('API 请求失败: 404, 响应: $responseBody');
      } else if (streamedResponse.statusCode != 200) {
        final responseBody = await streamedResponse.stream.bytesToString();
        print('DifyService Stream: 错误响应体 = $responseBody');
        throw Exception(
          'API 请求失败: ${streamedResponse.statusCode}, 响应: $responseBody',
        );
      }

      bool isFirstChunk = true;

      await for (final chunk in streamedResponse.stream.transform(
        utf8.decoder,
      )) {
        print('DifyService Stream: 收到数据块');
        for (final line in chunk.split('\n')) {
          if (line.startsWith('data: ')) {
            try {
              final event = jsonDecode(line.substring(6));

              // 简化日志输出
              if (isFirstChunk) {
                print('DifyService Stream: 首个事件 = $event');
                isFirstChunk = false;
              } else {
                print('DifyService Stream: 收到事件');
              }

              // 无条件保存服务器返回的conversation_id，确保一致性
              if (event['conversation_id'] != null) {
                // 打印旧值与新值的对比，帮助调试
                if (conversationId != null &&
                    conversationId != event['conversation_id']) {
                  print('DifyService Stream: 警告：服务器返回的会话ID与之前存储的不同');
                  print('DifyService Stream: 旧ID = $conversationId');
                  print(
                    'DifyService Stream: 新ID = ${event['conversation_id']}',
                  );
                }

                // 始终使用服务器返回的ID
                conversationId = event['conversation_id'] as String;
                _sessionConversationMap[sessionId] = conversationId;
                print('DifyService Stream: 保存服务器返回的会话ID = $conversationId');
                await _saveConversationMap(); // 保存更改到本地存储
              }

              if (event['answer'] != null) {
                yield event['answer'];
              }
            } catch (e) {
              // 解析 JSON 可能失败，跳过这一行
              print('DifyService Stream: JSON解析错误 = $e, line = $line');
              continue;
            }
          }
        }
      }
    } catch (e) {
      print('DifyService Stream 错误: $e');
      yield "【服务响应异常】";
    }
  }

  // 清除特定会话的 conversationId，创建新对话
  Future<void> clearConversation(String sessionId) async {
    // 确保映射表已加载
    await _ensureMapLoaded();

    _sessionConversationMap.remove(sessionId);
    await _saveConversationMap(); // 保存更改到本地存储
    print('DifyService: 已清除会话 $sessionId 的ID');
  }

  // 清除所有会话
  Future<void> clearAllConversations() async {
    // 确保映射表已加载
    await _ensureMapLoaded();

    _sessionConversationMap.clear();
    await _saveConversationMap(); // 保存更改到本地存储
    print('DifyService: 已清除所有会话ID');
  }

  // 上传文件到Dify API
  Future<Map<String, dynamic>> uploadFile(
    File file, {
    String? userIdentifier,
  }) async {
    try {
      // 使用指定的用户标识或设备ID
      final userId = userIdentifier ?? _deviceUserId ?? 'unknown_user';

      // 确保URL使用HTTP/HTTPS协议
      final sanitizedApiUrl = _ensureHttpProtocol(apiUrl);
      // 直接使用API URL构建文件上传路径
      final requestUrl = '$sanitizedApiUrl/files/upload';

      // 检查文件是否存在
      if (!await file.exists()) {
        throw Exception('文件不存在: ${file.path}');
      }

      // 创建multipart请求
      final request = http.MultipartRequest('POST', Uri.parse(requestUrl));

      // 添加认证头
      request.headers['Authorization'] = 'Bearer $apiKey';

      // 添加文件
      final fileName = file.path.split('/').last;
      final fileStream = http.ByteStream(file.openRead());
      final fileLength = await file.length();

      // 推测MIME类型
      String mimeType = 'image/jpeg'; // 默认MIME类型
      if (fileName.endsWith('.png')) {
        mimeType = 'image/png';
      } else if (fileName.endsWith('.gif')) {
        mimeType = 'image/gif';
      } else if (fileName.endsWith('.webp')) {
        mimeType = 'image/webp';
      }

      final multipartFile = http.MultipartFile(
        'file',
        fileStream,
        fileLength,
        filename: fileName,
        contentType: MediaType.parse(mimeType),
      );
      request.files.add(multipartFile);

      // 添加用户标识
      request.fields['user'] = userId;

      // 发送请求
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('DifyService: 文件上传响应状态码 = ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        throw Exception('文件上传失败: ${response.statusCode}, 响应: ${response.body}');
      }
    } catch (e) {
      print('DifyService 文件上传错误: $e');
      throw Exception('上传文件失败: $e');
    }
  }
}
