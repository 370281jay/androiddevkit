import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async'; // 添加：Timer、Future、Stream 等
import 'dart:math' as math;
import 'dart:convert'; // 用于 json.encode
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ai_assistant/services/vision_service.dart';
import 'package:ai_assistant/providers/conversation_provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ai_assistant/services/influxdb_service.dart';
import 'package:ai_assistant/utils/logging.dart';

import 'package:ai_assistant/models/conversation.dart';
import 'package:ai_assistant/models/message.dart';
import 'package:ai_assistant/models/xiaozhi_config.dart';
import 'package:ai_assistant/models/dify_config.dart';
import 'package:ai_assistant/services/dify_service.dart';
import 'package:ai_assistant/services/xiaozhi_service.dart';
// ignore_for_file: unused_field, unused_element

import 'package:ai_assistant/providers/config_provider.dart';
import 'package:ai_assistant/widgets/message_bubble.dart';
import 'package:ai_assistant/screens/voice_call_screen.dart';
import 'package:ai_assistant/widgets/native_camerax_preview.dart';
import 'package:ai_assistant/widgets/camerax_right_preview.dart';
import 'package:ai_assistant/models/experiment.dart';
import 'package:ai_assistant/widgets/experiment_control_panel.dart';
import 'package:ai_assistant/widgets/experiment_dialogs.dart';

class ChatScreen extends StatefulWidget {
  final Conversation conversation;

  const ChatScreen({super.key, required this.conversation});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  XiaozhiService? _xiaozhiService;
  DifyService? _difyService;
  Timer? _connectionCheckTimer;
  Timer? _autoReconnectTimer;

  // 语音输入相关
  bool _isVoiceInputMode = false;
  bool _isRecording = false;
  bool _isCancelling = false;
  double _startDragY = 0.0;
  final double _cancelThreshold = 50.0;
  Timer? _waveAnimationTimer;
  final List<double> _waveHeights = List.filled(20, 0.0);
  double _minWaveHeight = 5.0;
  double _maxWaveHeight = 30.0;
  final math.Random _random = math.Random();

  bool _showCameraPane = false;
  double _cameraRotation = 0;

  // ✅ 新增：自动实时监听状态
  bool _isAutoListening = false;

  // 添加自动拍照相关变量
  Timer? _autoPhotoTimer;
  bool _autoPhotoEnabled = false;
  int _photoCount = 0;

  late InfluxDBService _influxDBService;

  // 体征显示与轮询
  Timer? _vitalsTimer;
  bool _vitalsLoading = false;
  double? _heartRateBpm;
  double? _respirationBpm;
  DateTime? _vitalsUpdatedAt;

  // 实验相关
  Experiment? _selectedExperiment;
  int _currentStepIndex = 0;
  PageController? _stepsPageController;
  bool _showStepDetails = false;
  ScrollController _stepsScrollController = ScrollController(); // 新增：步骤列表滚动控制器
  int? _expandedStepIndex;
  bool _experimentEnded = false; // 新增：实验是否已结束

  get response => null; // 新增：当前展开的步骤索引

  // 新增：播报结束防抖定时器
  Timer? _ttsDebounceTimer; // 新增：播报结束防抖定时器
  String _currentAnswerText = ''; // 新增：当前助手回答累计文本
  DateTime? _lastAnswerCaptureAt; // 新增：节流，避免过频触发
  // 新增：记录“已为该用户问题拍照”的最后一条用户文本消息ID与内容
  String? _lastCapturedUserMessageId;
  String? _lastCapturedUserQuestion;

  @override
  void initState() {
    super.initState();
    debugPrint('🔵 [ChatScreen.initState] 开始初始化');

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
    );

    _influxDBService = InfluxDBService();
    _stepsPageController = PageController(viewportFraction: 0.9);

    debugPrint('🔵 [ChatScreen.initState] 准备 addPostFrameCallback');

    // ✅ 仅一个 addPostFrameCallback，统一处理所有初始化
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      debugPrint(
        '🟢 [PostFrameCallback] 执行开始 - 会话类型: ${widget.conversation.type}',
      );

      // 1️⃣ 标记已读
      debugPrint('🔵 [PostFrameCallback] 标记会话已读');
      Provider.of<ConversationProvider>(
        context,
        listen: false,
      ).markConversationAsRead(widget.conversation.id);

      // 2️⃣ 根据对话类型初始化服务
      if (widget.conversation.type == ConversationType.xiaozhi) {
        debugPrint('🔵 [PostFrameCallback] 检测到 Xiaozhi 会话，开始初始化 WebSocket');

        try {
          // 先连小智
          debugPrint('🔵 [PostFrameCallback] 调用 _initXiaozhiService()');
          await _initXiaozhiService();
          debugPrint(
            '🟢 [PostFrameCallback] _initXiaozhiService() 完成，连接状态: ${_xiaozhiService?.isConnected}',
          );
        } catch (e) {
          debugPrint('🔴 [PostFrameCallback] _initXiaozhiService() 失败: $e');
        }

        // 监控连接状态
        debugPrint('🔵 [PostFrameCallback] 启动连接监控定时器');
        _connectionCheckTimer = Timer.periodic(const Duration(seconds: 2), (_) {
          if (!mounted || _xiaozhiService == null) return;
          final wasConnected = _xiaozhiService!.isConnected;
          debugPrint('🟡 [ConnectionCheck] 连接状态: $wasConnected');
          setState(() {});
          if (wasConnected &&
              !_xiaozhiService!.isConnected &&
              _autoReconnectTimer == null) {
            debugPrint('⚠️ [ConnectionCheck] 连接断开，触发重连');
            _scheduleReconnect();
          }
        });

        // 默认启用语音输入
        debugPrint('🔵 [PostFrameCallback] 启用语音输入模式');
        setState(() => _isVoiceInputMode = true);

        // ✅ 连接就绪后自动开启实时监听（auto）
        Future.microtask(_maybeStartAutoListening);

        // ✅ WebSocket 连接成功后，显示实验选择
        debugPrint('🔵 [PostFrameCallback] 调用 _scheduleExperimentSelection()');
        _scheduleExperimentSelection();
      } else if (widget.conversation.type == ConversationType.dify) {
        debugPrint('🔵 [PostFrameCallback] 检测到 Dify 会话');
        _initDifyService();
      }

      // 3️⃣ 启动其他后台服务
      debugPrint('🔵 [PostFrameCallback] 启动 InfluxDB 烟雾测试');
      _influxSmokeTest();

      debugPrint('🔵 [PostFrameCallback] 启动体征数据轮询');
      _startVitalsPolling();

      // 4️⃣ 横屏自动显示摄像头
      if (MediaQuery.of(context).orientation == Orientation.landscape &&
          mounted) {
        debugPrint('🔵 [PostFrameCallback] 横屏检测到，启用摄像头');
        setState(() => _showCameraPane = true);
      }

      debugPrint('🟢 [PostFrameCallback] 执行完成');
    });

    debugPrint('🔵 [ChatScreen.initState] 初始化完成');
  }

  // 🆕 延迟显示实验选择对话框
  void _scheduleExperimentSelection() {
    debugPrint('🟡 [_scheduleExperimentSelection] 安排延迟1秒后显示实验选择');
    // 等待WebSocket连接稳定后再显示
    Timer(const Duration(seconds: 1), () {
      debugPrint('🟡 [_scheduleExperimentSelection] 1秒延迟触发');
      debugPrint('  - mounted: $mounted');
      debugPrint('  - _selectedExperiment: $_selectedExperiment');
      debugPrint('  - _xiaozhiService: $_xiaozhiService');
      debugPrint('  - isConnected: ${_xiaozhiService?.isConnected}');

      if (mounted &&
          _selectedExperiment == null &&
          _xiaozhiService?.isConnected == true) {
        debugPrint('🟢 [_scheduleExperimentSelection] 条件满足，显示对话框');
        _showExperimentSelectionDialog();
      } else {
        debugPrint('🔴 [_scheduleExperimentSelection] 条件不满足，取消显示');
      }
    });
  }

  Future<void> _influxSmokeTest() async {
    logInflux('SmokeTest: start');
    const q = '''
from(bucket: "vitals_data")
  |> range(start: -2m)
  |> filter(fn: (r) => r["device_id"] == "84F7035346E0")
  |> keep(columns: ["_time","_field","_value"])
  |> limit(n: 5)
''';
    final res = await _influxDBService.query(query: q);
    if (res.hasError) {
      logInflux('SmokeTest: error=${res.error}');
    } else {
      logInflux('SmokeTest: rows=${res.results?.length ?? 0}');
      await logInfluxLargeAsync('SmokeTest results:\n${res.results}');
    }
  }

  // 安排自动重连
  void _scheduleReconnect() {
    // 取消现有重连定时器
    _autoReconnectTimer?.cancel();

    // 创建新的重连定时器，5秒后尝试重连
    _autoReconnectTimer = Timer(const Duration(seconds: 5), () async {
      debugPrint('正在尝试自动重连...');
      if (_xiaozhiService != null && !_xiaozhiService!.isConnected && mounted) {
        try {
          await _xiaozhiService!.disconnect();
          await _xiaozhiService!.connect();

          setState(() {});
          debugPrint('自动重连 ${_xiaozhiService!.isConnected ? "成功" : "失败"}');

          // 如果重连失败，则继续尝试重连
          if (!_xiaozhiService!.isConnected) {
            _scheduleReconnect();
          } else {
            _autoReconnectTimer = null;
          }
        } catch (e) {
          debugPrint('自动重连出错: $e');
          _scheduleReconnect(); // 出错后继续尝试
        }
      } else {
        _autoReconnectTimer = null;
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _connectionCheckTimer?.cancel();
    _autoReconnectTimer?.cancel();
    _waveAnimationTimer?.cancel();
    _autoPhotoTimer?.cancel(); // 取消自动拍照定时器
    _vitalsTimer?.cancel();
    _stepsPageController?.dispose();
    _stepsScrollController.dispose(); // 新增：释放滚动控制器
    _ttsDebounceTimer?.cancel(); // 新增：释放播报结束定时器

    if (_xiaozhiService != null) {
      // 离开页面时显式停止监听与播放
      _xiaozhiService!.stopListeningCall();
      _xiaozhiService!.stopPlayback();
      _xiaozhiService!.disconnect();
    }

    super.dispose();
  }

  // 显示实验选择对话框（改为下拉选择 + 确认）
  void _showExperimentSelectionDialog() {
    Experiment? tempSelected =
        experiments.isNotEmpty ? experiments.first : null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: StatefulBuilder(
              builder: (context, setStateDialog) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '选择实验项目',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '请选择要进行的实验',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 16),

                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: 56, // 按钮区的合理最小高度
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: DropdownButtonFormField<Experiment>(
                          value: tempSelected,
                          isExpanded: true,
                          itemHeight: null, // 菜单项允许自适应多行高度
                          menuMaxHeight: 400,
                          // 关键：为“按钮区”提供单行展示，避免使用多行 Column 造成溢出
                          selectedItemBuilder: (context) {
                            return experiments.map((exp) {
                              return Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  exp.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            }).toList();
                          },
                          items:
                              experiments.map((exp) {
                                return DropdownMenuItem<Experiment>(
                                  value: exp,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          exp.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          exp.description,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                          onChanged:
                              (v) => setStateDialog(() => tempSelected = v),
                          decoration: const InputDecoration.collapsed(
                            hintText: '',
                          ),
                          icon: Icon(
                            Icons.keyboard_arrow_down,
                            color: Colors.grey.shade600,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.grey.shade100,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(5),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text(
                              '取消',
                              style: TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed:
                                tempSelected == null
                                    ? null
                                    : () {
                                      setState(() {
                                        _selectedExperiment = tempSelected;
                                        _currentStepIndex = 0;
                                        _showStepDetails = false;
                                      });
                                      Navigator.pop(context);
                                    },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              '确认',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  // 构建实验步骤容器（纵向，从上到下展示，容器高度固定，最多展示3个可见项）
  Widget _buildExperimentStepsBar() {
    if (_selectedExperiment == null) return const SizedBox.shrink();

    final steps = _selectedExperiment!.steps;
    const double itemHeight = 46.0;
    final double containerHeight = itemHeight * 3 + 24; // 固定高度

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题和关闭
          Row(
            children: [
              Expanded(
                child: Text(
                  _selectedExperiment!.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () {
                  setState(() {
                    _selectedExperiment = null;
                    _expandedStepIndex = null;
                    _showStepDetails = false;
                  });
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                splashRadius: 16,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 列表 + 滚动条提示（固定高度）
          SizedBox(
            height: containerHeight,
            child: Scrollbar(
              controller: _stepsScrollController,
              thumbVisibility: true, // 始终显示滚动条拇指以提示可滚动
              trackVisibility: true,
              thickness: 4,
              radius: const Radius.circular(6),
              child: ListView.separated(
                controller: _stepsScrollController,
                physics: const BouncingScrollPhysics(),
                itemCount: steps.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                padding: EdgeInsets.zero,
                itemBuilder: (context, index) {
                  final step = steps[index];
                  final isActive = index == _expandedStepIndex;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 步骤条
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            // 同步当前步骤索引，用于高亮
                            _currentStepIndex = index;
                            // 就地展开/折叠
                            _expandedStepIndex = isActive ? null : index;
                            _showStepDetails = _expandedStepIndex != null;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          height: itemHeight,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color:
                                isActive
                                    ? Colors.blue.shade50
                                    : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color:
                                  isActive
                                      ? Colors.blue.shade300
                                      : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color:
                                      isActive
                                          ? Colors.blue
                                          : Colors.grey.shade400,
                                ),
                                child: Center(
                                  child: Text(
                                    '${step.index}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  step.name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        isActive
                                            ? Colors.blue.shade800
                                            : Colors.grey.shade700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Icon(
                                isActive
                                    ? Icons.expand_less
                                    : Icons.chevron_right,
                                color:
                                    isActive
                                        ? Colors.blue
                                        : Colors.grey.shade500,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // 就地展开的说明（在该步骤下方显示）
                      AnimatedSize(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeInOut,
                        child:
                            isActive
                                ? Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Colors.blue.shade100,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${step.index}. ${step.name}',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.blue,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          step.instruction,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade800,
                                            height: 1.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                : const SizedBox.shrink(),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          // 移除底部统一详情块（不再在最下方弹出）
          // ...已删除原先的 if (_showStepDetails ...) 底部说明...
        ],
      ),
    );
  }

  // 初始化小智服务
  Future<void> _initXiaozhiService() async {
    debugPrint('🟡 [_initXiaozhiService] 开始初始化');
    final configProvider = Provider.of<ConfigProvider>(context, listen: false);
    final xiaozhiConfig = configProvider.xiaozhiConfigs.firstWhere(
      (config) => config.id == widget.conversation.configId,
    );

    debugPrint(
      '🟡 [_initXiaozhiService] 配置 - URL: ${xiaozhiConfig.websocketUrl}, MAC: ${xiaozhiConfig.macAddress}',
    );

    _xiaozhiService = XiaozhiService(
      websocketUrl: xiaozhiConfig.websocketUrl,
      macAddress: xiaozhiConfig.macAddress,
      token: xiaozhiConfig.token,
    );

    // 添加消息监听器
    _xiaozhiService!.addListener(_handleXiaozhiMessage);

    // 连接服务
    debugPrint('🟡 [_initXiaozhiService] 调用 connect()');
    try {
      await _xiaozhiService!.connect();
      debugPrint(
        '🟢 [_initXiaozhiService] 连接成功，状态: ${_xiaozhiService!.isConnected}',
      );
    } catch (e) {
      debugPrint('🔴 [_initXiaozhiService] 连接失败: $e');
      rethrow;
    }

    // 连接后刷新UI状态
    if (mounted) {
      setState(() {});
    }
  }

  // 处理小智消息
  void _handleXiaozhiMessage(XiaozhiServiceEvent event) {
    if (!mounted) return;
    final conversationProvider = Provider.of<ConversationProvider>(
      context,
      listen: false,
    );

    if (event.type == XiaozhiServiceEventType.textMessage) {
      // 直接使用文本内容
      String content = event.data as String;
      debugPrint('收到消息内容: $content');

      // 忽略空消息
      if (content.isNotEmpty) {
        conversationProvider.addMessage(
          conversationId: widget.conversation.id,
          role: MessageRole.assistant,
          content: content,
        );

        // 新增：助手文本“防抖”判定播报结束（本地判断，不依赖后端）
        _currentAnswerText =
            (_currentAnswerText.isEmpty)
                ? content
                : '$_currentAnswerText $content';

        // 根据文本长度动态估计播报时延
        // 基础时延：1秒，每个中文字符/单词约150ms，加上网络和TTS处理时延
        int textLength = content.length;
        int estimatedDelayMs = 1000 + (textLength * 150); // 基础1秒+文本时延
        int maxDelayMs = 30000; // 最多等待30秒
        int finalDelayMs = estimatedDelayMs.clamp(2000, maxDelayMs);

        debugPrint(
          '文本长度: $textLength, 估计播报时延: ${finalDelayMs}ms',
        );

        // 每次收到助手文本都重置防抖；在估计的时延内若无新的文本则认定播报结束
        _ttsDebounceTimer?.cancel();
        _ttsDebounceTimer = Timer(Duration(milliseconds: finalDelayMs), () {
          debugPrint('播报完成（节流），执行拍照逻辑');
          // 播报结束后执行一次拍照并发送
          _captureAfterAnswerOnce();
          // 清空当前累计文本
          _currentAnswerText = '';
        });
      }
    } else if (event.type == XiaozhiServiceEventType.userMessage) {
      // 处理用户的语音识别文本
      String content = event.data as String;
      debugPrint('收到用户语音识别内容: $content');

      // 只有在语音输入模式下才添加用户消息
      if (content.isNotEmpty && _isVoiceInputMode) {
        // 语音消息可能有延迟，使用Future.microtask确保UI已更新
        Future.microtask(() {
          conversationProvider.addMessage(
            conversationId: widget.conversation.id,
            role: MessageRole.user,
            content: content,
          );
        });
      }
    } else if (event.type == XiaozhiServiceEventType.connected ||
        event.type == XiaozhiServiceEventType.disconnected) {
      // ✅ 连接变更时联动实时监听
      if (event.type == XiaozhiServiceEventType.connected) {
        _maybeStartAutoListening();
      } else {
        if (_isAutoListening) {
          _stopWaveAnimation();
          setState(() {
            _isAutoListening = false;
          });
        }
      }
      setState(() {});
    }
  }

  // 初始化 DifyService
  Future<void> _initDifyService() async {
    final configProvider = Provider.of<ConfigProvider>(context, listen: false);
    final String? configId = widget.conversation.configId;
    DifyConfig? difyConfig;

    if (configId != null && configId.isNotEmpty) {
      difyConfig =
          configProvider.difyConfigs
              .where((config) => config.id == configId)
              .firstOrNull;
    }

    if (difyConfig == null) {
      if (configProvider.difyConfigs.isEmpty) {
        throw Exception("未设置Dify配置，请先在设置中配置Dify API");
      }
      difyConfig = configProvider.difyConfigs.first;
    }

    _difyService = await DifyService.create(
      apiKey: difyConfig.apiKey,
      apiUrl: difyConfig.apiUrl,
    );
  }

  // 开始轮询体征数据
  void _startVitalsPolling() {
    _vitalsTimer?.cancel();
    _pollVitals(); // 立即拉一次
    _vitalsTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _pollVitals(),
    );
  }

  // 拉取体征数据
  Future<void> _pollVitals() async {
    if (_vitalsLoading) return;
    _vitalsLoading = true;
    try {
      // 拉取最近20秒内的心率、呼吸频率
      const flux = '''
from(bucket: "vitals_data")
  |> range(start: -20s)
  |> filter(fn: (r) => r["device_id"] == "84F7035346E0")
  |> filter(fn: (r) => r["_field"] == "heart_rate_bpm" or r["_field"] == "respiration_bpm")
  |> keep(columns: ["_time","_field","_value"])
  |> sort(columns: ["_time"], desc: true)
  |> limit(n: 20)
'''; // 修复：这里应为三个引号结尾

      final res = await _influxDBService.query(query: flux);
      if (res.hasError || !res.hasResults) {
        logInflux('Vitals query failed: ${res.error ?? "no data"}');
        return;
      }

      // 从 CSV 行中取每个字段的最新一条
      final rows = res.results as List;
      DateTime? hrTime;
      DateTime? rrTime;
      double? hr;
      double? rr;

      for (final row in rows) {
        if (row is! Map) continue;
        final field = (row['_field'] ?? '').toString();
        final valueStr = (row['_value'] ?? '').toString();
        final timeStr = (row['_time'] ?? '').toString();
        if (field.isEmpty || valueStr.isEmpty || timeStr.isEmpty) continue;

        DateTime? t;
        try {
          // Influx CSV 的时间是 ISO8601
          t = DateTime.parse(timeStr);
        } catch (_) {
          continue;
        }

        final v = double.tryParse(valueStr);
        if (v == null) continue;

        if (field == 'heart_rate_bpm') {
          if (hrTime == null || t.isAfter(hrTime)) {
            hrTime = t;
            hr = v;
          }
        } else if (field == 'respiration_bpm') {
          if (rrTime == null || t.isAfter(rrTime)) {
            rrTime = t;
            rr = v;
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _heartRateBpm = hr;
        _respirationBpm = rr;
        // 取两者中较新的时间作为“更新时间”
        _vitalsUpdatedAt = [hrTime, rrTime]
            .whereType<DateTime>()
            .fold<DateTime?>(null, (p, e) => p == null || e.isAfter(p) ? e : p);
      });

      logInflux(
        'Vitals updated HR=${_heartRateBpm ?? "-"} bpm, RR=${_respirationBpm ?? "-"} bpm at ${_vitalsUpdatedAt ?? "-"}',
      );
    } catch (e) {
      logInflux('Vitals error: $e');
    } finally {
      _vitalsLoading = false;
    }
  }

  Widget _buildVitalsBar() {
    final hr = _heartRateBpm != null ? _heartRateBpm!.toStringAsFixed(0) : '—';
    final rr =
        _respirationBpm != null ? _respirationBpm!.toStringAsFixed(0) : '—';
    final ts =
        _vitalsUpdatedAt != null
            ? _vitalsUpdatedAt!.toLocal().toIso8601String().substring(11, 19)
            : '--:--:--';

    Color hrColor;
    if (_heartRateBpm == null) {
      hrColor = Colors.grey;
    } else if (_heartRateBpm! < 50 || _heartRateBpm! > 110) {
      hrColor = Colors.redAccent;
    } else {
      hrColor = Colors.green;
    }

    Color rrColor;
    if (_respirationBpm == null) {
      rrColor = Colors.grey;
    } else if (_respirationBpm! < 10 || _respirationBpm! > 24) {
      rrColor = Colors.redAccent;
    } else {
      rrColor = Colors.blue;
    }

    return SizedBox(
      height: 64, // 固定高度：由原 52 提升到 64
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ), // 垂直内边距增大
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.favorite, color: hrColor, size: 22), // 原 18
            const SizedBox(width: 8),
            Text(
              '心率 $hr bpm',
              style: TextStyle(
                color: hrColor,
                fontWeight: FontWeight.w600,
                fontSize: 16, // 明确字号
              ),
            ),
            const SizedBox(width: 20),
            Icon(Icons.air, color: rrColor, size: 22), // 原 18
            const SizedBox(width: 8),
            Text(
              '呼吸 $rr bpm',
              style: TextStyle(
                color: rrColor,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const Spacer(),
            Icon(
              _vitalsLoading ? Icons.sync : Icons.schedule,
              size: 20,
              color: Colors.grey[600],
            ), // 原 16
            const SizedBox(width: 6),
            Text(
              ts,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ), // 原 12
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 确保状态栏设置正确
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        toolbarHeight: 56,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        actions: [
          if (widget.conversation.type == ConversationType.dify)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.black, size: 24),
              tooltip: '开始新对话',
              onPressed: _resetConversation,
            ),
          if (widget.conversation.type == ConversationType.xiaozhi)
            Container(
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: _navigateToVoiceCall,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.phone, color: Colors.black, size: 16),
                    ),
                  ),
                ),
              ),
            ),
        ],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black, size: 26),
          onPressed: () {
            // 返回前停止监听与播放
            if (_xiaozhiService != null) {
              _xiaozhiService!.stopListeningCall();
              _xiaozhiService!.stopPlayback();
            }
            Navigator.of(context).pop();
          },
        ),
        title:
            widget.conversation.type == ConversationType.xiaozhi
                ? Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.3),
                            blurRadius: 8,
                            spreadRadius: 0,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.grey.shade700,
                        child: const Icon(
                          Icons.mic,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.conversation.title,
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 1,
                                spreadRadius: 0,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: const Text(
                            '语音',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                )
                : Consumer<ConfigProvider>(
                  builder: (context, configProvider, child) {
                    // 查找此会话对应的Dify配置
                    final String? configId = widget.conversation.configId;
                    String configName = widget.conversation.title;

                    // 如果配置ID存在，则从中获取名称
                    if (configId != null && configId.isNotEmpty) {
                      final difyConfig =
                          configProvider.difyConfigs
                              .where((config) => config.id == configId)
                              .firstOrNull;

                      if (difyConfig != null) {
                        configName = difyConfig.name;
                      }
                    }

                    return Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.3),
                                blurRadius: 8,
                                spreadRadius: 0,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.blue.shade400,
                            child: const Icon(
                              Icons.chat_bubble_outline,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              configName,
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.03),
                                    blurRadius: 1,
                                    spreadRadius: 0,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: const Text(
                                '文本',
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
      ),

      body: _buildResponsiveBody(),
    );
  }

  Widget _buildResponsiveBody() {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    if (!isLandscape) {
      return Column(
        children: [
          if (widget.conversation.type == ConversationType.xiaozhi)
            _buildXiaozhiInfo(),
          // 新增：实验步骤容器
          if (_selectedExperiment != null) _buildExperimentStepsBar(),
          Expanded(child: _buildMessageList()),
          _buildInputArea(),
        ],
      );
    }

    return Row(
      children: [
        // 左侧：摄像头预览（含体征条悬浮）
        Expanded(
          flex: 2,
          child:
              _showCameraPane
                  ? Stack(
                    children: [
                      // 先放预览，再放叠加层
                      RotatedBox(
                        quarterTurns: 3, // 逆时针90度
                        child: const CameraXRightPreview(
                          lensFacing: 'external',
                          implementationMode: 'COMPATIBLE', // 强制TextureView
                          scaleType: 'FILL_CENTER',
                        ),
                      ),
                      Positioned(
                        top: 12,
                        left: 12,
                        right: 72,
                        child: _buildVitalsBar(),
                      ),
                      Positioned(
                        top: 16,
                        right: 16,
                        child: Row(
                          children: [
                            // 自动拍照按钮
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: IconButton(
                                icon: Icon(
                                  _autoPhotoEnabled
                                      ? Icons.camera_roll
                                      : Icons.camera_alt_outlined,
                                  color:
                                      _autoPhotoEnabled
                                          ? Colors.red
                                          : Colors.white,
                                  size: 24,
                                ),
                                onPressed: _toggleAutoPhoto,
                                tooltip:
                                    _autoPhotoEnabled ? '停止自动拍照' : '启动自动拍照',
                              ),
                            ),
                            const SizedBox(width: 8),
                            // 关闭摄像头
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: IconButton(
                                icon: Icon(
                                  _showCameraPane
                                      ? Icons.videocam_off
                                      : Icons.videocam,
                                  color: Colors.white,
                                  size: 24,
                                ),
                                onPressed: () {
                                  setState(
                                    () => _showCameraPane = !_showCameraPane,
                                  );
                                  if (!_showCameraPane) _stopAutoPhoto();
                                },
                                tooltip: _showCameraPane ? '关闭摄像头' : '打开摄像头',
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // 实验控制面板（底部悬浮）
                      Positioned(
                        bottom: 60,
                        left: 12,
                        right: 12,
                        child: ExperimentControlPanel(
                          selectedExperiment: _selectedExperiment,
                          isConnected: _xiaozhiService?.isConnected ?? false,
                          experimentEnded: _experimentEnded,
                          onPauseExperiment: _pauseExperiment,
                          onEndExperiment: _endExperiment,
                          onViewReport: _viewExperimentReport,
                        ),
                      ),
                    ],
                  )
                  : _buildRightPlaceholder(),
        ),
        Container(width: 1, color: Colors.grey.withOpacity(0.2)),
        // 右侧：聊天区域
        Expanded(
          flex: 1,
          child: Column(
            children: [
              if (widget.conversation.type == ConversationType.xiaozhi)
                _buildXiaozhiInfo(),
              if (_selectedExperiment != null) _buildExperimentStepsBar(),
              Expanded(child: _buildMessageList()),
              _buildInputArea(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRightPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.camera_alt_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            '摄像头未开启',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 16),
          ),
          const SizedBox(height: 8),
          if (widget.conversation.type == ConversationType.xiaozhi)
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _showCameraPane = true;
                });
              },
              icon: const Icon(Icons.videocam, size: 18),
              label: const Text('开启摄像头'),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.blue.shade600,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildXiaozhiInfo() {
    final configProvider = Provider.of<ConfigProvider>(context);
    final xiaozhiConfig = configProvider.xiaozhiConfigs.firstWhere(
      (config) => config.id == widget.conversation.configId,
      orElse:
          () => XiaozhiConfig(
            id: '',
            name: '未知服务',
            websocketUrl: '',
            macAddress: '',
            token: '',
          ),
    );

    final bool isConnected = _xiaozhiService?.isConnected ?? false;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 连接状态指示器
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isConnected ? Colors.green : Colors.red,
              boxShadow: [
                BoxShadow(
                  color: (isConnected ? Colors.green : Colors.red).withOpacity(
                    0.4,
                  ),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            isConnected ? '已连接' : '未连接',
            style: TextStyle(
              fontSize: 13,
              color: isConnected ? Colors.green : Colors.red,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 12),

          // 分隔线
          Container(width: 1, height: 16, color: Colors.grey.withOpacity(0.3)),
          const SizedBox(width: 12),

          // WebSocket信息
          Expanded(
            child: Text(
              '${xiaozhiConfig.websocketUrl}',
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          if (xiaozhiConfig.macAddress.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 4,
                      spreadRadius: 0,
                      offset: const Offset(0, 1),
                    ),
                    BoxShadow(
                      color: Colors.white.withOpacity(0.9),
                      blurRadius: 3,
                      spreadRadius: 0,
                      offset: const Offset(0, -1),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.devices, size: 12, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      '${xiaozhiConfig.macAddress}',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return Consumer<ConversationProvider>(
      builder: (context, provider, child) {
        final messages = provider.getMessages(widget.conversation.id);

        if (messages.isEmpty) {
          return Center(
            child: Text(
              '开始新对话',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 16),
            ),
          );
        }

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          reverse: true,
          itemCount: messages.length + (_isLoading ? 1 : 0),
          cacheExtent: 1000.0,
          addRepaintBoundaries: true,
          addAutomaticKeepAlives: true,
          physics: const ClampingScrollPhysics(),
          itemBuilder: (context, index) {
            if (_isLoading && index == 0) {
              return MessageBubble(
                message: Message(
                  id: 'loading',
                  conversationId: '',
                  role: MessageRole.assistant,
                  content: '思考中...',
                  timestamp: DateTime.now(),
                ),
                isThinking: true,
                conversationType: widget.conversation.type,
              );
            }

            final adjustedIndex = _isLoading ? index - 1 : index;
            final message = messages[messages.length - 1 - adjustedIndex];

            return RepaintBoundary(
              child: MessageBubble(
                key: ValueKey(message.id),
                message: message,
                conversationType: widget.conversation.type,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInputArea() {
    final bool hasText = _textController.text.trim().isNotEmpty;

    // 根据状态决定显示文本输入还是语音输入
    if (_isVoiceInputMode &&
        widget.conversation.type == ConversationType.xiaozhi) {
      return _buildVoiceInputArea();
    } else {
      return _buildTextInputArea(hasText);
    }
  }

  // 文本输入区域
  Widget _buildTextInputArea(bool hasText) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 16,
        top: 16,
        right: 16,
        bottom: 16 + MediaQuery.of(context).padding.bottom,
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7F9),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.07),
                    blurRadius: 8,
                    spreadRadius: 0,
                    offset: const Offset(0, 3),
                  ),
                  BoxShadow(
                    color: Colors.white.withOpacity(0.8),
                    blurRadius: 5,
                    spreadRadius: 0,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      decoration: const InputDecoration(
                        hintText: '输入消息...',
                        hintStyle: TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 16,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                      ),
                      style: const TextStyle(
                        color: Color(0xFF1F2937),
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  if (widget.conversation.type == ConversationType.dify &&
                      !hasText)
                    IconButton(
                      icon: const Icon(
                        Icons.add_circle_outline,
                        color: Color(0xFF9CA3AF),
                        size: 24,
                      ),
                      onPressed: _showImagePickerOptions,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      constraints: const BoxConstraints(),
                      splashRadius: 22,
                    ),
                  if (widget.conversation.type == ConversationType.xiaozhi &&
                      !hasText)
                    _buildCameraAction(),
                  _buildSendButton(hasText),
                  // 文本输入区域内麦克风按钮
                  if (widget.conversation.type == ConversationType.xiaozhi &&
                      !hasText)
                    IconButton(
                      icon: const Icon(
                        Icons.mic,
                        color: Color.fromARGB(255, 108, 108, 112),
                        size: 24,
                      ),
                      onPressed: () {
                        setState(() {
                          _isVoiceInputMode = true;
                        });
                        // ✅ 进入语音模式后，立刻尝试开启实时监听
                        _maybeStartAutoListening();
                      },
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      constraints: const BoxConstraints(),
                      splashRadius: 22,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 语音输入区域
  Widget _buildVoiceInputArea() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 16,
        top: 16,
        right: 16,
        bottom: 16 + MediaQuery.of(context).padding.bottom,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            // ⬇️ 移除长按手势，改为纯展示
            child: Container(
              height: 54,
              decoration: BoxDecoration(
                color:
                    _isAutoListening
                        ? Colors.blue.shade50
                        : const Color(0xFFF5F7F9),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.07),
                    blurRadius: 8,
                    spreadRadius: 0,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (_isAutoListening) _buildWaveAnimationIndicator(),
                  Center(
                    child: Text(
                      _isAutoListening ? "自动实时监听中..." : "自动监听就绪",
                      style: TextStyle(
                        color:
                            _isAutoListening
                                ? Colors.blue.shade700
                                : const Color.fromARGB(255, 9, 9, 9),
                        fontSize: 16,
                        fontWeight:
                            _isAutoListening
                                ? FontWeight.w500
                                : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          // 相机按钮
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  spreadRadius: 0,
                  offset: const Offset(0, 2),
                ),
                BoxShadow(
                  color: Colors.white.withOpacity(0.8),
                  blurRadius: 4,
                  spreadRadius: 0,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                borderRadius: BorderRadius.circular(25),
                onTap: _captureAndSendToVision,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Icon(
                    Icons.camera_alt,
                    color: Colors.grey.shade700,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // 键盘按钮（切回文本并停止实时监听）
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  spreadRadius: 0,
                  offset: const Offset(0, 2),
                ),
                BoxShadow(
                  color: Colors.white.withOpacity(0.8),
                  blurRadius: 4,
                  spreadRadius: 0,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                borderRadius: BorderRadius.circular(25),
                onTap: () {
                  _stopAutoListening();
                  setState(() {
                    _isVoiceInputMode = false;
                    _isRecording = false;
                    _isCancelling = false;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Icon(
                    Icons.keyboard,
                    color: Colors.grey.shade700,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 发送按钮（在输入栏右侧使用）
  Widget _buildSendButton(bool hasText) {
    return IconButton(
      icon: const Icon(Icons.send, size: 24),
      onPressed: hasText ? _sendMessage : null, // 无内容时禁用
      tooltip: '发送',
    );
  }

  // 底部操作按钮（发送、语音、相机）
  Widget _buildBottomActions() {
    final bool hasText = _textController.text.trim().isNotEmpty;

    return Row(
      children: [
        // 相机按钮（仅在小智对话中显示）
        _buildCameraAction(),

        // 语音输入按钮
        if (widget.conversation.type == ConversationType.xiaozhi)
          IconButton(
            icon: const Icon(Icons.mic, size: 24),
            onPressed: () {
              setState(() {
                _isVoiceInputMode = true;
              });
            },
            tooltip: '语音输入',
          ),

        // 发送按钮
        _buildSendButton(hasText),
      ],
    );
  }

  // 示例：在输入栏旁新增一个相机图标按钮（仅 Xiaozhi 会话显示）
  Widget _buildCameraAction() {
    final isXiaozhi = widget.conversation.type == ConversationType.xiaozhi;
    if (!isXiaozhi) return const SizedBox.shrink();
    return IconButton(
      icon: const Icon(Icons.camera_alt, size: 22),
      onPressed: _captureAndSendToVision,
      tooltip: '拍照识别',
    );
  }

  // 尝试开启自动监听
  void _maybeStartAutoListening() {
    if (!mounted) return;
    if (widget.conversation.type != ConversationType.xiaozhi) return;
    if (_xiaozhiService?.isConnected != true) return;
    if (!_isVoiceInputMode) return;
    if (_isAutoListening) return;
    _startAutoListening();
  }

  // 开启自动监听（由后端VAD分段、停声即发送）
  Future<void> _startAutoListening() async {
    if (_xiaozhiService == null) return;
    try {
      await _xiaozhiService!.startListeningCall();
      if (!mounted) return;
      setState(() {
        _isAutoListening = true;
      });
      _startWaveAnimation();
      debugPrint('🟢 [Chat] 已进入自动监听模式');
    } catch (e) {
      debugPrint('🔴 [Chat] 自动监听启动失败: $e');
      _showCustomSnackbar('监听启动失败: $e');
      if (!mounted) return;
      setState(() {
        _isAutoListening = false;
      });
    }
  }

  // 停止自动监听
  Future<void> _stopAutoListening() async {
    try {
      await _xiaozhiService?.stopListeningCall();
    } catch (e) {
      debugPrint('⚠️ [Chat] 停止自动监听异常: $e');
    } finally {
      if (!mounted) return;
      setState(() {
        _isAutoListening = false;
      });
      _stopWaveAnimation();
    }
  }

  // 开始录音
  void _startRecording() async {
    if (widget.conversation.type != ConversationType.xiaozhi ||
        _xiaozhiService == null) {
      _showCustomSnackbar('语音功能仅适用于小智对话');
      setState(() {
        _isVoiceInputMode = false;
      });
      return;
    }

    try {
      // 震动反馈
      HapticFeedback.mediumImpact();

      // 开始录音
      await _xiaozhiService!.startListening();
    } catch (e) {
      debugPrint('开始录音失败: $e');
      _showCustomSnackbar('无法开始录音: ${e.toString()}');
      setState(() {
        _isRecording = false;
        _isVoiceInputMode = false;
      });
    }
  }

  // 停止录音并发送
  void _stopRecording() async {
    try {
      setState(() {
        _isLoading = true;
        _isRecording = false;
        // 不要立即关闭语音输入模式，让用户可以看到识别结果
        // _isVoiceInputMode = false;
      });

      // 震动反馈
      HapticFeedback.mediumImpact();

      // 停止录音
      await _xiaozhiService?.stopListening();

      _scrollToBottom();
    } catch (e) {
      debugPrint('停止录音失败: $e');
      _showCustomSnackbar('语音发送失败: ${e.toString()}');

      // 出错时关闭语音输入模式
      setState(() {
        _isVoiceInputMode = false;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 取消录音
  void _cancelRecording() async {
    try {
      setState(() {
        _isRecording = false;
      });

      // 震动反馈
      HapticFeedback.heavyImpact();

      // 取消录音
      await _xiaozhiService?.abortListening();

      // 使用自定义的拟物化提示，显示在顶部且带有圆角
      _showCustomSnackbar('已取消发送');
    } catch (e) {
      debugPrint('取消录音失败: $e');
    }
  }

  // 显示自定义Snackbar
  void _showCustomSnackbar(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    final snackBar = SnackBar(
      content: Text(
        message,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.black.withOpacity(0.7),
      duration: const Duration(seconds: 2),
      margin: EdgeInsets.only(
        bottom: MediaQuery.of(context).size.height - 120,
        left: 16,
        right: 16,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 8,
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  void _resetConversation() async {
    // 给用户一个清晰的提示
    _showCustomSnackbar('正在开始新对话...');

    final conversationProvider = Provider.of<ConversationProvider>(
      context,
      listen: false,
    );

    if (_difyService != null) {
      // 使用会话的ID作为sessionId，确保与发送消息时使用相同的标识符
      final sessionId = widget.conversation.id;

      // 清除当前会话的conversation_id
      await _difyService!.clearConversation(sessionId);

      // 添加系统消息表明这是一个新对话
      await conversationProvider.addMessage(
        conversationId: widget.conversation.id,
        role: MessageRole.system,
        content: '--- 开始新对话 ---',
      );

      _showCustomSnackbar('已开始新对话');
    } else {
      _showCustomSnackbar('Dify配置未设置，无法重置对话');
    }
  }

  void _sendMessage() async {
    final message = _textController.text.trim();
    if (message.isEmpty || _isLoading) return;

    _textController.clear();

    final conversationProvider = Provider.of<ConversationProvider>(
      context,
      listen: false,
    );

    // Add user message
    await conversationProvider.addMessage(
      conversationId: widget.conversation.id,
      role: MessageRole.user,
      content: message,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    _scrollToBottom();

    try {
      if (widget.conversation.type == ConversationType.dify) {
        if (_difyService == null) {
          await _initDifyService();
        }

        if (_difyService == null) {
          throw Exception("未设置Dify配置，请先在设置中配置Dify API");
        }

        // 使用会话的ID作为sessionId，使每次请求保持相同的对话上下文
        final sessionId = widget.conversation.id;

        // 使用阻塞式响应
        final response = await _difyService!.sendMessage(
          message,
          sessionId: sessionId, // 使用一致的会话ID
          // 永远不要在普通消息中使用forceNewConversation，除非用户明确请求开始新对话
          forceNewConversation: false,
        );

        if (!mounted) return; // 再次检查组件是否还在widget树中

        // 添加助手回复
        await conversationProvider.addMessage(
          conversationId: widget.conversation.id,
          role: MessageRole.assistant,
          content: response,
        );
      } else {
        // 确保服务已连接
        if (_xiaozhiService == null) {
          await _initXiaozhiService();
        } else if (!_xiaozhiService!.isConnected) {
          // 如果未连接，尝试重新连接
          debugPrint('聊天屏幕: 服务未连接，尝试重新连接');
          await _xiaozhiService!.connect();

          // 如果重连失败，提示用户
          if (!_xiaozhiService!.isConnected) {
            throw Exception("无法连接到小智服务，请检查网络或服务配置");
          }

          // 刷新UI显示连接状态
          setState(() {});
        }

        // 发送消息
        await _xiaozhiService!.sendTextMessage(message);
      }
    } catch (e) {
      debugPrint('聊天屏幕: 发送消息错误: $e');

      if (!mounted) return;

      // Add error message
      await conversationProvider.addMessage(
        conversationId: widget.conversation.id,
        role: MessageRole.assistant,
        content: '发生错误: ${e.toString()}',
      );
    } finally {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _navigateToVoiceCall() {
    final configProvider = Provider.of<ConfigProvider>(context, listen: false);
    final xiaozhiConfig = configProvider.xiaozhiConfigs.firstWhere(
      (config) => config.id == widget.conversation.configId,
    );

    // 导航前停止当前音频播放
    if (_xiaozhiService != null) {
      _xiaozhiService!.stopPlayback();
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => VoiceCallScreen(
              conversation: widget.conversation,
              xiaozhiConfig: xiaozhiConfig,
            ),
      ),
    ).then((_) {
      // 页面返回后，确保重新初始化服务以恢复正常对话功能
      if (_xiaozhiService != null &&
          widget.conversation.type == ConversationType.xiaozhi) {
        // 重新连接服务
        _xiaozhiService!.connect();
      }
    });
  }

  // 启动波形动画
  void _startWaveAnimation() {
    _waveAnimationTimer?.cancel();
    _waveAnimationTimer = Timer.periodic(const Duration(milliseconds: 100), (
      timer,
    ) {
      if (_isRecording && !_isCancelling) {
        setState(() {
          for (int i = 0; i < _waveHeights.length; i++) {
            _waveHeights[i] = 0.5 + _random.nextDouble() * 0.5;
          }
        });
      }
    });
  }

  // 停止波形动画
  void _stopWaveAnimation() {
    _waveAnimationTimer?.cancel();
    _waveAnimationTimer = null;

    _waveAnimationTimer = null;
  }

  // 构建波形动画指示器
  Widget _buildWaveAnimationIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(
          16,
          (index) => AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: 3,
            height: 20 * _waveHeights[index],
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.6),
              borderRadius: BorderRadius.circular(1.5),
            ),
            curve: Curves.easeInOut,
          ),
        ),
      ),
    );
  }

  // 显示图片选择器选项
  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      elevation: 20,
      barrierColor: Colors.black.withOpacity(0.5),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 顶部拖动条
              Container(
                width: 36,
                height: 5,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 1,
                      spreadRadius: 0,
                      offset: const Offset(0, 0.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // 从相册选择选项
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 10,
                        spreadRadius: 0,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 6,
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.1),
                              blurRadius: 4,
                              spreadRadius: 0,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.photo_library,
                          color: Colors.blue.shade600,
                          size: 24,
                        ),
                      ),
                      title: const Text(
                        '从相册选择',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      subtitle: Text(
                        '选择已有照片',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      onTap: () {
                        Navigator.of(context).pop();
                        _pickImage(true);
                      },
                    ),
                  ),
                ),
              ),

              // 拍照选项
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 10,
                        spreadRadius: 0,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 6,
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.1),
                              blurRadius: 4,
                              spreadRadius: 0,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.camera_alt,
                          color: Colors.green.shade600,
                          size: 24,
                        ),
                      ),
                      title: const Text(
                        '拍照',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      subtitle: Text(
                        '拍摄新照片',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      onTap: () {
                        Navigator.of(context).pop();
                        _pickImage(false);
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage(bool fromGallery) async {
    if (widget.conversation.type != ConversationType.dify) {
      _showCustomSnackbar('图片上传功能仅适用于Dify对话');
      return;
    }

    try {
      setState(() {
        _isLoading = true;
      });

      if (_difyService == null) {
        await _initDifyService();
      }

      if (_difyService == null) {
        throw Exception("未设置Dify配置，请先在设置中配置Dify API");
      }

      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: fromGallery ? ImageSource.gallery : ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1500,
      );

      if (pickedFile == null) {
        _showCustomSnackbar('已取消选择');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // 获取应用的文档目录
      final appDir = await getApplicationDocumentsDirectory();
      final conversationDir = Directory(
        '${appDir.path}/conversations/${widget.conversation.id}/images',
      );
      await conversationDir.create(recursive: true);

      // 生成唯一的文件名
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = pickedFile.path.split('.').last;
      final fileName = 'image_$timestamp.$extension';
      final localPath = '${conversationDir.path}/$fileName';

      // 复制图片到永久存储
      final File imageFile = File(pickedFile.path);
      await imageFile.copy(localPath);

      debugPrint('图片已保存到永久存储: $localPath');

      final sessionId = widget.conversation.id;

      // 在消息列表中显示用户上传的图片消息
      final conversationProvider = Provider.of<ConversationProvider>(
        context,
        listen: false,
      );

      // 添加用户消息，使用永久存储的路径
      await conversationProvider.addMessage(
        conversationId: widget.conversation.id,
        role: MessageRole.user,
        content: "[图片上传中...]",
        isImage: true,
        imageLocalPath: localPath,
      );

      if (response.containsKey('id')) {
        final fileId = response['id'];
        final messageContent = "";

        // 更新最后一条用户消息为 实际的图片消息
        await conversationProvider.updateLastUserMessage(
          conversationId: widget.conversation.id,
          content: messageContent,
          fileId: fileId,
          isImage: true,
          imageLocalPath: localPath,
        );

        final textPrompt = "分析这张图片";
        final chatResponse = await _difyService!.sendMessage(
          textPrompt,
          sessionId: sessionId,
          fileIds: [fileId],
        );

        await conversationProvider.addMessage(
          conversationId: widget.conversation.id,
          role: MessageRole.assistant,
          content: chatResponse,
        );
      } else {
        throw Exception("上传成功但服务器未返回文件ID: $response");
      }

      _showCustomSnackbar('图片上传成功');
    } catch (e) {
      debugPrint('图片上传失败: $e');

      final conversationProvider = Provider.of<ConversationProvider>(
        context,
        listen: false,
      );
      await conversationProvider.addMessage(
        conversationId: widget.conversation.id,
        role: MessageRole.assistant,
        content: '图片上传失败: ${e.toString()}',
      );

      _showCustomSnackbar('图片上传失败: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  // 拍照并发送到视觉服务
  Future<void> _captureAndSendToVision({bool isAutoCapture = false}) async {
    try {
      // 申请权限并拍照
      final status = await Permission.camera.request();
      if (status != PermissionStatus.granted) {
        if (!isAutoCapture) _showCustomSnackbar('未授予相机权限');
        return;
      }

      final picker = ImagePicker();
      final XFile? shot = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1500,
      );
      if (shot == null) return;

      // 保存到会话目录
      final appDir = await getApplicationDocumentsDirectory();
      final dir = Directory(
        '${appDir.path}/conversations/${widget.conversation.id}/images',
      );
      await dir.create(recursive: true);

      final prefix = isAutoCapture ? 'auto' : 'manual';
      final fileName = '${prefix}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedFile = File('${dir.path}/$fileName');
      await File(shot.path).copy(savedFile.path);

      // 插入用户图片消息（识别中）
      final conversationProvider = Provider.of<ConversationProvider>(
        context,
        listen: false,
      );

      final content =
          isAutoCapture ? '[自动拍照 #$_photoCount - 识别中...]' : '[手动拍照 - 识别中...]';

      await conversationProvider.addMessage(
        conversationId: widget.conversation.id,
        role: MessageRole.user,
        content: content,
        isImage: true,
        imageLocalPath: savedFile.path,
      );

      // 读取小智配置以复用认证
      final configProvider = Provider.of<ConfigProvider>(
        context,
        listen: false,
      );
      final xiaozhiConfig = configProvider.xiaozhiConfigs.firstWhere(
        (c) => c.id == widget.conversation.configId,
      );

      // 视觉服务调用
      final vs = VisionService(
        visionUrl: 'http://183.251.85.225:8003/mcp/vision/explain',
        authToken: _xiaozhiService!.getAuthToken(),
        deviceId: xiaozhiConfig.macAddress,
        clientId: 'android-client',
      );

      final prompt = isAutoCapture ? '请简要分析这张自动拍摄的图片内容' : '请识别这张图片的内容';

      final responseText = await vs.analyzeImage(savedFile, question: prompt);

      // Unicode解码处理
      String decodedResponse = _decodeUnicodeString(responseText);

      // 插入助手消息
      await conversationProvider.addMessage(
        conversationId: widget.conversation.id,
        role: MessageRole.assistant,
        content: decodedResponse,
      );

      if (!isAutoCapture) {
        _scrollToBottom();
      }
    } catch (e) {
      if (!isAutoCapture) {
        _showCustomSnackbar('图片识别失败: $e');
      }
      debugPrint('拍照识别失败: $e');
    }
  }

  // 处理来自CameraPane的拍照结果
  Future<void> _handleCameraPhotoTaken(File imageFile) async {
    try {
      // 保存到会话目录
      final appDir = await getApplicationDocumentsDirectory();
      final dir = Directory(
        '${appDir.path}/conversations/${widget.conversation.id}/images',
      );
      await dir.create(recursive: true);

      final fileName = 'camera_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedFile = File('${dir.path}/$fileName');
      await imageFile.copy(savedFile.path);

      // 插入用户图片消息
      final conversationProvider = Provider.of<ConversationProvider>(
        context,
        listen: false,
      );

      final content =
          _autoPhotoEnabled
              ? '[自动拍照 #$_photoCount - 识别中...]'
              : '[摄像头拍照 - 识别中...]';

      await conversationProvider.addMessage(
        conversationId: widget.conversation.id,
        role: MessageRole.user,
        content: content,
        isImage: true,
        imageLocalPath: savedFile.path,
      );

      // 调用视觉识别服务
      final configProvider = Provider.of<ConfigProvider>(
        context,
        listen: false,
      );
      final xiaozhiConfig = configProvider.xiaozhiConfigs.firstWhere(
        (c) => c.id == widget.conversation.configId,
      );

      final vs = VisionService(
        visionUrl: 'http://183.251.85.225:8003/mcp/vision/explain',
        authToken: _xiaozhiService!.getAuthToken(),
        deviceId: xiaozhiConfig.macAddress,
        clientId: 'android-client',
      );

      final prompt = _autoPhotoEnabled ? '请简要分析这张自动拍摄的图片内容' : '请识别这张摄像头拍摄的图片内容';

      final responseText = await vs.analyzeImage(savedFile, question: prompt);

      // Unicode解码处理
      String decodedResponse = _decodeUnicodeString(responseText);

      // 插入助手消息
      await conversationProvider.addMessage(
        conversationId: widget.conversation.id,
        role: MessageRole.assistant,
        content: decodedResponse,
      );

      if (!_autoPhotoEnabled) {
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('摄像头拍照识别失败: $e');
      if (!_autoPhotoEnabled) {
        _showCustomSnackbar('图片识别失败: $e');
      }
    }
  }

  // 切换自动拍照状态
  void _toggleAutoPhoto() {
    setState(() {
      _autoPhotoEnabled = !_autoPhotoEnabled;
    });

    // 取消已有定时器，避免重复
    _autoPhotoTimer?.cancel();
    _autoPhotoTimer = null;

    if (_autoPhotoEnabled) {
      _photoCount = 0;
      _showCustomSnackbar('自动拍照已启动（每10秒一次）');

      // 启动定时器，周期触发原生 CameraX 拍照
      _autoPhotoTimer = Timer.periodic(const Duration(seconds: 10), (
        timer,
      ) async {
        if (!mounted || !_showCameraPane) return;
        if (_xiaozhiService?.isConnected != true) {
          debugPrint('自动拍照跳过：服务未连接');
          return;
        }

        try {
          final String? path = await CameraXBridge.takePicture();
          if (path == null || path.isEmpty) {
            debugPrint('自动拍照失败：未返回路径');
            return;
          }
          _photoCount++;
          await _handleCameraXPhotoPath(path, isAutoCapture: true);
        } catch (e) {
          debugPrint('自动拍照异常: $e');
        }
      });
    } else {
      _showCustomSnackbar('自动拍照已停止');
    }
  }

  // 停止自动拍照
  void _stopAutoPhoto() {
    _autoPhotoTimer?.cancel();
    _autoPhotoTimer = null;
    setState(() {
      _autoPhotoEnabled = false;
      _photoCount = 0;
    });
  }

  // ========== 实验控制相关方法 ==========
  
  // 暂停实验
  void _pauseExperiment() async {
    if (_selectedExperiment == null) return;

    final shouldReconnect = await ExperimentDialogs.showPauseDialog(
      context,
      _selectedExperiment!,
    );

    if (shouldReconnect == true) {
      // 重新连接
      _reconnectToExperiment();
    } else {
      // 断开连接
      await _disconnectExperiment();
    }
  }

  // 结束实验
  void _endExperiment() async {
    if (_selectedExperiment == null) return;

    final shouldEnd = await ExperimentDialogs.showEndDialog(
      context,
      _selectedExperiment!,
    );

    if (shouldEnd == true) {
      // 结束实验并断开连接
      await _disconnectExperiment();
      
      // 标记实验已结束，但保留实验信息以便查看报告
      setState(() {
        _experimentEnded = true;
        _currentStepIndex = 0;
        _expandedStepIndex = null;
        _showStepDetails = false;
      });

      _showCustomSnackbar('实验已结束');
    }
  }

  // 查看实验报告
  void _viewExperimentReport() async {
    if (_selectedExperiment == null) return;

    ExperimentDialogs.showReportDialog(context, _selectedExperiment!);
  }

  // 断开实验连接
  Future<void> _disconnectExperiment() async {
    try {
      // 停止自动监听
      await _stopAutoListening();
      
      // 断开WebSocket连接
      if (_xiaozhiService != null) {
        await _xiaozhiService!.disconnect();
      }
      
      // 停止自动拍照
      _stopAutoPhoto();
      
      setState(() {});
    } catch (e) {
      debugPrint('断开实验连接失败: $e');
    }
  }

  // 重新连接实验
  void _reconnectToExperiment() async {
    try {
      if (_xiaozhiService != null) {
        await _xiaozhiService!.connect();
        
        // 重新启动自动监听
        if (_isVoiceInputMode) {
          _maybeStartAutoListening();
        }
        
        setState(() {});
        _showCustomSnackbar('重新连接成功');
      }
    } catch (e) {
      _showCustomSnackbar('重新连接失败: $e');
    }
  }

  // ========== 实验控制相关方法结束 ==========

  // 查找最近一条用户文本消息（对象）
  Message? _getLastUserTextMessage() {
    final provider = Provider.of<ConversationProvider>(context, listen: false);
    final msgs = provider.getMessages(widget.conversation.id);
    for (int i = msgs.length - 1; i >= 0; i--) {
      final m = msgs[i];
      if (m.role == MessageRole.user && (m.isImage != true)) {
        final txt = (m.content ?? '').trim();
        if (txt.isNotEmpty) return m;
      }
    }
    return null;
  }

  // 兼容旧用法：仅返回最近用户文本内容
  String? _getLastUserQuestion() {
    final m = _getLastUserTextMessage();
    return m?.content?.trim();
  }

  // 在播报结束后执行一次拍照（若可用），并使用用户提问作为 prompt
  Future<void> _captureAfterAnswerOnce() async {
    // 仅在小智对话、摄像头已打开的情况下触发
    if (widget.conversation.type != ConversationType.xiaozhi) return;
    if (!_showCameraPane) return;

    // 获取最近一条用户文本消息，若没有则不触发
    final lastUserMsg = _getLastUserTextMessage();
    if (lastUserMsg == null) {
      debugPrint('播报结束拍照跳过：无用户文本问题');
      return;
    }

    // 限制一次提问只拍一次：若最近用户消息ID已拍过则跳过
    if (_lastCapturedUserMessageId != null &&
        _lastCapturedUserMessageId == lastUserMsg.id) {
      debugPrint('播报结束拍照跳过：该问题已拍过 (id=${lastUserMsg.id})');
      return;
    }

    // 简单节流：避免短时间内重复触发
    final now = DateTime.now();
    if (_lastAnswerCaptureAt != null &&
        now.difference(_lastAnswerCaptureAt!).inSeconds < 3) {
      return;
    }
    _lastAnswerCaptureAt = now;

    // 使用最近的用户文本作为 prompt
    final prompt =
        lastUserMsg.content?.trim().isNotEmpty == true
            ? lastUserMsg.content!.trim()
            : '请根据用户刚才的提问分析这张图片';

    try {
      // 权限检查
      final status = await Permission.camera.request();
      if (status != PermissionStatus.granted) {
        debugPrint('播报结束拍照：相机权限未授予');
        return;
      }

      // 稍等平台视图与通道就绪
      await Future.delayed(const Duration(milliseconds: 300));

      final String? path = await CameraXBridge.takePicture();
      if (path == null || path.isEmpty) {
        debugPrint('播报结束拍照失败：未返回路径');
        return;
      }

      // 记录本次已拍的用户问题ID与内容，确保一次问题只拍一次
      _lastCapturedUserMessageId = lastUserMsg.id;
      _lastCapturedUserQuestion = lastUserMsg.content?.trim();

      // 使用覆盖 prompt 的处理流程
      await _handleCameraXPhotoPath(
        path,
        isAutoCapture: false,
        promptOverride: prompt,
      );
    } catch (e) {
      debugPrint('播报结束拍照异常: $e');
    }
  }

  // 处理来自原生 CameraX 的拍照路径（扩展：支持覆盖 prompt）
  Future<void> _handleCameraXPhotoPath(
    String path, {
    bool isAutoCapture = false,
    String? promptOverride,
  }) async {
    try {
      // 保存到会话目录
      final appDir = await getApplicationDocumentsDirectory();
      final dir = Directory(
        '${appDir.path}/conversations/${widget.conversation.id}/images',
      );
      await dir.create(recursive: true);

      final prefix = isAutoCapture ? 'auto' : 'manual';
      final fileName = '${prefix}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final saved = File('${dir.path}/$fileName');
      await File(path).copy(saved.path);

      // 插入用户图片消息（识别中）
      final conversationProvider = Provider.of<ConversationProvider>(
        context,
        listen: false,
      );
      final content =
          isAutoCapture
              ? '[自动拍照 #$_photoCount - 识别中...]'
              : (promptOverride != null
                  ? '[播报结束拍照 - 识别中...]'
                  : '[摄像头拍照 - 识别中...]');

      await conversationProvider.addMessage(
        conversationId: widget.conversation.id,
        role: MessageRole.user,
        content: content,
        isImage: true,
        imageLocalPath: saved.path,
      );

      // 调用视觉识别服务
      final configProvider = Provider.of<ConfigProvider>(
        context,
        listen: false,
      );
      final xiaozhiConfig = configProvider.xiaozhiConfigs.firstWhere(
        (c) => c.id == widget.conversation.configId,
      );

      if (_xiaozhiService == null || !_xiaozhiService!.isConnected) {
        await _initXiaozhiService();
      }

      final vs = VisionService(
        visionUrl: 'http://183.251.85.225:8003/mcp/vision/explain',
        authToken: _xiaozhiService!.getAuthToken(),
        deviceId: xiaozhiConfig.macAddress,
        clientId: 'android-client',
      );

      // 使用覆盖的 prompt；否则退回默认提示
      final prompt =
          (promptOverride != null && promptOverride.trim().isNotEmpty)
              ? promptOverride.trim()
              : (isAutoCapture ? '请简要分析这张自动拍摄的图片内容' : '请识别这张摄像头拍摄的图片内容');

      final responseText = await vs.analyzeImage(saved, question: prompt);
      debugPrint('视觉服务响应原文: $responseText');
      // Unicode解码处理
      final decodedResponse = _decodeUnicodeString(responseText);

      // 插入助手消息
      await conversationProvider.addMessage(
        conversationId: widget.conversation.id,
        role: MessageRole.assistant,
        content: decodedResponse,
      );

      if (!isAutoCapture) {
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('CameraX 拍照识别失败: $e');
      if (!isAutoCapture) {
        _showCustomSnackbar('图片识别失败: $e');
      }
    }
  }

  // // Unicode解码处理
  // String _decodeUnicodeString(String input) {
  //   StringBuffer result = StringBuffer();
  //   RegExp exp = RegExp(r'\\u([0-9a-fA-F]{4})');

  //   input.replaceAllMapped(exp, (Match match) {
  //     int codePoint = int.parse(match[1]!, radix: 16);
  //     result.write(String.fromCharCode(codePoint));
  //     return '';
  //   });

  //   return result.toString();
  // }

  String _decodeUnicodeString(String input) {
    StringBuffer result = StringBuffer();
    int i = 0;

    while (i < input.length) {
      // 检查当前位置是否是 \u 开头
      if (i + 6 <= input.length && input.substring(i, i + 2) == r'\u') {
        // 提取可能的4位十六进制
        String hexStr = input.substring(i + 2, i + 6);

        // 验证这确实是4位十六进制数
        if (RegExp(r'^[0-9a-fA-F]{4}$').hasMatch(hexStr)) {
          // 解码Unicode字符
          int codePoint = int.parse(hexStr, radix: 16);
          result.write(String.fromCharCode(codePoint));
          i += 6; // 跳过整个 \uXXXX
          continue;
        }
      }

      // 如果不是\uXXXX格式，直接复制字符
      result.write(input[i]);
      i++;
    }

    return result.toString();
  }

  // 查询设备数据的示例方法
  Future<void> _queryDeviceData() async {
    try {
      // 查询温度数据（时间移动平均）
      final tempResponse = await _influxDBService.query(
        field: 'temperature',
        mode: 'tma2m',
        deviceId: '84F7035346E0', // 可以从配置中获取
      );

      if (tempResponse.hasError) {
        _showCustomSnackbar('数据查询失败: ${tempResponse.error}');
        return;
      }

      if (tempResponse.hasResults) {
        final results = tempResponse.results!;
        _showCustomSnackbar('查询到 ${results.length} 条温度数据');

        // 处理查询结果
        for (final result in results) {
          if (result is Map<String, dynamic>) {
            debugPrint('时间: ${result['_time']}, 温度: ${result['_value']}');
          }
        }
      } else {
        _showCustomSnackbar('未查询到数据');
      }
    } catch (e) {
      _showCustomSnackbar('查询异常: $e');
    }
  }

  // 查询湿度数据（最近平均值）
  Future<void> _queryHumidityData() async {
    try {
      final response = await _influxDBService.query(
        field: 'humidity',
        mode: 'mean5m',
      );

      if (response.hasResults) {
        final results = response.results as List<Map<String, String>>;
        for (final result in results) {
          debugPrint('湿度平均值: ${result['_value']}');
        }
      }
    } catch (e) {
      debugPrint('湿度查询失败: $e');
    }
  }

  // 自定义查询
  Future<void> _customQuery() async {
    const customQuery = '''
from(bucket: "vitals_data")
  |> range(start: -1h)
  |> filter(fn: (r) => r["device_id"] == "84F7035346E0")
  |> filter(fn: (r) => r["_field"] == "heart_rate")
  |> last()
''';

    final response = await _influxDBService.query(query: customQuery);

    if (response.hasResults) {
      debugPrint('最新心率数据: ${response.results}');
    }
  }

  // 测试 InfluxDB 数据获取
  Future<void> _testInfluxDBData() async {
    try {
      debugPrint('开始测试 InfluxDB 数据获取...');

      // 测试1: 查询温度数据 (时间移动平均)
      debugPrint('\n=== 测试1: 温度数据 (tma2m) ===');
      final tempResponse = await _influxDBService.query(
        field: 'temperature',
        mode: 'tma2m',
        deviceId: '84F7035346E0',
      );

      debugPrint('Temperature Response:');
      debugPrint('- hasError: ${tempResponse.hasError}');
      debugPrint('- hasResults: ${tempResponse.hasResults}');
      if (tempResponse.hasError) {
        debugPrint('- error: ${tempResponse.error}');
      }
      if (tempResponse.hasResults) {
        debugPrint('- results count: ${tempResponse.results?.length}');
        debugPrint('- results type: ${tempResponse.results.runtimeType}');
        debugPrint('- results full data: ${tempResponse.results}');

        // 详细打印前几条数据
        final results = tempResponse.results as List;
        for (int i = 0; i < (results.length > 3 ? 3 : results.length); i++) {
          debugPrint('  [$i]: ${results[i]} (type: ${results[i].runtimeType})');
          if (results[i] is Map) {
            final map = results[i] as Map;
            map.forEach((key, value) {
              debugPrint('    $key: $value (${value.runtimeType})');
            });
          }
        }
      }

      // 测试2: 查询湿度数据 (平均值)
      debugPrint('\n=== 测试2: 湿度数据 (mean5m) ===');
      final humidityResponse = await _influxDBService.query(
        field: 'humidity',
        mode: 'mean5m',
        deviceId: '84F7035346E0',
      );

      debugPrint('Humidity Response:');
      debugPrint('- hasError: ${humidityResponse.hasError}');
      debugPrint('- hasResults: ${humidityResponse.hasResults}');
      if (humidityResponse.hasError) {
        debugPrint('- error: ${humidityResponse.error}');
      }
      if (humidityResponse.hasResults) {
        debugPrint('- results: ${humidityResponse.results}');
      }

      // 测试3: 自定义查询
      debugPrint('\n=== 测试3: 自定义查询 (最新心率) ===');
      const customQuery = '''
from(bucket: "vitals_data")
  |> range(start: -1h)
  |> filter(fn: (r) => r["device_id"] == "84F7035346E0")
  |> filter(fn: (r) => r["_field"] == "heart_rate")
  |> last()
''';

      final customResponse = await _influxDBService.query(query: customQuery);
      debugPrint('Custom Query Response:');
      debugPrint('- hasError: ${customResponse.hasError}');
      debugPrint('- hasResults: ${customResponse.hasResults}');
      if (customResponse.hasError) {
        debugPrint('- error: ${customResponse.error}');
      }
      if (customResponse.hasResults) {
        debugPrint('- results: ${customResponse.results}');
      }

      // 测试4: 查询所有可用字段
      debugPrint('\n=== 测试4: 查询所有字段 ===');
      const allFieldsQuery = '''
from(bucket: "vitals_data")
  |> range(start: -10m)
  |> filter(fn: (r) => r["device_id"] == "84F7035346E0")
  |> keep(columns: ["_time", "_field", "_value"])
  |> limit(n: 20)
''';

      final allFieldsResponse = await _influxDBService.query(
        query: allFieldsQuery,
      );
      debugPrint('All Fields Response:');
      debugPrint('- hasError: ${allFieldsResponse.hasError}');
      debugPrint('- hasResults: ${allFieldsResponse.hasResults}');
      if (allFieldsResponse.hasResults) {
        debugPrint('- results: ${allFieldsResponse.results}');
      }

      // 在聊天中显示测试结果摘要
      final conversationProvider = Provider.of<ConversationProvider>(
        context,
        listen: false,
      );

      String summary = '📊 InfluxDB 数据测试结果:\n\n';
      summary +=
          '🌡️ 温度数据: ${tempResponse.hasResults ? '✅ ${tempResponse.results?.length} 条记录' : '❌ ${tempResponse.error ?? '无数据'}'}\n';
      summary +=
          '💧 湿度数据: ${humidityResponse.hasResults ? '✅ 有数据' : '❌ ${humidityResponse.error ?? '无数据'}'}\n';
      summary +=
          '❤️ 心率数据: ${customResponse.hasResults ? '✅ 有数据' : '❌ ${customResponse.error ?? '无数据'}'}\n';
      summary +=
          '📈 所有字段: ${allFieldsResponse.hasResults ? '✅ ${allFieldsResponse.results?.length} 条记录' : '❌ ${allFieldsResponse.error ?? '无数据'}'}\n\n';
      summary += '详细数据请查看控制台输出';

      await conversationProvider.addMessage(
        conversationId: widget.conversation.id,
        role: MessageRole.assistant,
        content: summary,
      );

      _scrollToBottom();
      _showCustomSnackbar('InfluxDB 数据测试完成，请查看控制台');
    } catch (e) {
      debugPrint('InfluxDB 测试异常: $e');
      _showCustomSnackbar('InfluxDB 测试失败: $e');
    }
  }

  // 修改数据命令处理，添加测试功能
  Future<void> _handleDataCommand(String command) async {
    _textController.clear();

    // 添加用户命令消息
    final conversationProvider = Provider.of<ConversationProvider>(
      context,
      listen: false,
    );
    await conversationProvider.addMessage(
      conversationId: widget.conversation.id,
      role: MessageRole.user,
      content: command,
    );

    try {
      // 特殊命令：测试完整数据
      if (command.toLowerCase().contains('test') ||
          command.toLowerCase().contains('测试')) {
        await _testInfluxDBData();
        return;
      }

      // 特殊命令：查看原始响应
      if (command.toLowerCase().contains('raw') ||
          command.toLowerCase().contains('原始')) {
        await _testRawInfluxDBResponse();
        return;
      }

      String? field;
      String mode = 'mean5m';

      // 解析命令参数
      if (command.contains('temperature') || command.contains('温度')) {
        field = 'temperature';
      } else if (command.contains('humidity') || command.contains('湿度')) {
        field = 'humidity';
      } else if (command.contains('heart_rate') || command.contains('心率')) {
        field = 'heart_rate';
      }

      if (command.contains('history') || command.contains('历史')) {
        mode = 'tma2m';
      }

      if (field != null) {
        final response = await _influxDBService.query(field: field, mode: mode);

        String resultText;
        if (response.hasError) {
          resultText = '数据查询失败: ${response.error}';
        } else if (response.hasResults) {
          final results = response.results as List;
          if (results.isNotEmpty) {
            resultText = '找到 ${results.length} 条 $field 数据记录\n\n';

            // 显示最新的几条数据
            final showCount = results.length > 5 ? 5 : results.length;
            for (int i = 0; i < showCount; i++) {
              final record = results[i];
              if (record is Map<String, dynamic>) {
                final time = record['_time'] ?? 'N/A';
                final value = record['_value'] ?? 'N/A';
                resultText += '${i + 1}. 时间: $time, 值: $value\n';
              } else {
                resultText += '${i + 1}. $record\n';
              }
            }

            if (results.length > 5) {
              resultText += '\n... 还有 ${results.length - 5} 条记录';
            }
          } else {
            resultText = '未找到$field数据';
          }
        } else {
          resultText = '未查询到数据';
        }

        // 添加系统响应
        await conversationProvider.addMessage(
          conversationId: widget.conversation.id,
          role: MessageRole.assistant,
          content: resultText,
        );
      } else {
        await conversationProvider.addMessage(
          conversationId: widget.conversation.id,
          role: MessageRole.assistant,
          content:
              '支持的数据查询命令:\n'
              '/data temperature - 温度数据\n'
              '/data humidity - 湿度数据\n'
              '/data heart_rate - 心率数据\n'
              '/data test - 完整数据测试\n'
              '/data raw - 原始响应测试\n'
              '添加 history 查看历史趋势',
        );
      }
    } catch (e) {
      await conversationProvider.addMessage(
        conversationId: widget.conversation.id,
        role: MessageRole.assistant,
        content: '数据查询异常: $e',
      );
    }

    _scrollToBottom();
  }

  // 测试原始 HTTP 响应
  Future<void> _testRawInfluxDBResponse() async {
    try {
      debugPrint('\n=== 原始 InfluxDB HTTP 响应测试 ===');

      // 直接测试 HTTP 请求
      final queryUrl = Uri.parse('${_influxDBService.influxUrl}/api/v2/query');
      final queryParams = {'org': _influxDBService.influxOrg};
      final finalUrl = queryUrl.replace(queryParameters: queryParams);

      const testQuery = '''
from(bucket: "vitals_data")
  |> range(start: -5m)
  |> filter(fn: (r) => r["device_id"] == "84F7035346E0")
  |> limit(n: 5)
''';

      final requestBody = json.encode({'query': testQuery});

      debugPrint('Request URL: $finalUrl');
      debugPrint(
        'Request Headers: Authorization: Token ${_influxDBService.influxToken.substring(0, 20)}...',
      );
      debugPrint('Request Body: $requestBody');

      final response = await http
          .post(
            finalUrl,
            headers: {
              'Authorization': 'Token ${_influxDBService.influxToken}',
              'Accept': 'text/csv',
              'Content-Type': 'application/json',
              'User-Agent': 'Flutter-Android-Client/1.0',
            },
            body: requestBody,
          )
          .timeout(const Duration(seconds: 30));

      debugPrint('\nRaw Response:');
      debugPrint('Status Code: ${response.statusCode}');
      debugPrint('Headers: ${response.headers}');
      debugPrint('Body Length: ${response.body.length}');
      debugPrint('Body Content:');
      debugPrint('--- START ---');
      debugPrint(response.body);
      debugPrint('--- END ---');

      // 在聊天中显示原始响应摘要
      final conversationProvider = Provider.of<ConversationProvider>(
        context,
        listen: false,
      );
      await conversationProvider.addMessage(
        conversationId: widget.conversation.id,
        role: MessageRole.assistant,
        content:
            '🔍 原始 InfluxDB 响应:\n\n'
            '状态码: ${response.statusCode}\n'
            '内容类型: ${response.headers['content-type']}\n'
            '响应长度: ${response.body.length} 字符\n\n'
            '完整响应内容请查看控制台输出',
      );
    } catch (e) {
      debugPrint('原始响应测试异常: $e');
      _showCustomSnackbar('原始响应测试失败: $e');
    }
  }
}
