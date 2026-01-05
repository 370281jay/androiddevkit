import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/scheduler.dart';
import 'package:image_picker/image_picker.dart';

class CameraPane extends StatefulWidget {
  final double rotationDegrees; // 旋转角度，可任意度数
  final CameraLensDirection lensDirection; // 前/后摄像头
  const CameraPane({
    super.key,
    this.rotationDegrees = 0,
    this.lensDirection = CameraLensDirection.back,
  });

  @override
  State<CameraPane> createState() => _CameraPaneState();
}

class _CameraPaneState extends State<CameraPane> with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  double _rotation = 0;
  bool _initializing = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _rotation = widget.rotationDegrees;
    WidgetsBinding.instance.addObserver(this);
    // 延迟更长时间，确保纹理系统完全就绪后再初始化
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        // 等待额外的渲染帧，确保 Surface 完全创建
        await Future.delayed(const Duration(milliseconds: 300));
        _initAfterSized();
      }
    });
  }

  Future<void> _initAfterSized() async {
    // 等待布局完成并获得非零尺寸，最多等待 1.2s，对 external 镜头更宽容
    for (int i = 0; i < 12; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      final size = context.size;
      if (size != null && size.width > 0 && size.height > 0) {
        debugPrint('CameraPane: 面板尺寸就绪: ${size.width}x${size.height}');
        break;
      }
    }
    if (mounted) await _initCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 后台时释放，前台时尝试恢复；不早退，避免错过恢复机会
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      try {
        debugPrint('CameraPane: lifecycle=$state -> 停止并释放控制器');
        _controller?.dispose();
        _controller = null;
        _initialized = false;
      } catch (e) {
        debugPrint('CameraPane: 释放控制器异常: $e');
      }
    } else if (state == AppLifecycleState.resumed) {
      debugPrint('CameraPane: lifecycle=$state -> 尝试重新初始化相机');
      if (!_initializing) {
        _initAfterSized(); // 先确保右侧面板有尺寸
      }
    }
  }

  CameraDescription _pickBestCamera() {
    // 支持 external 镜头：按入参优先，否则按可靠性排序
    final specific = _cameras.where((c) => c.lensDirection == widget.lensDirection).toList();
    if (specific.isNotEmpty) return specific.first;

    // 按稳定性排序：后置 -> 前置 -> external -> 其它
    final back = _cameras.where((c) => c.lensDirection == CameraLensDirection.back).toList();
    if (back.isNotEmpty) return back.first;
    final front = _cameras.where((c) => c.lensDirection == CameraLensDirection.front).toList();
    if (front.isNotEmpty) return front.first;
    final external = _cameras.where((c) => c.lensDirection == CameraLensDirection.external).toList();
    if (external.isNotEmpty) return external.first;
    
    return _cameras.first;
  }

  Future<void> _initCamera() async {
    if (_initializing) return;
    _initializing = true;
    debugPrint('CameraPane: 开始初始化相机');

    final status = await Permission.camera.request();
    if (status != PermissionStatus.granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未授予相机权限')),
        );
      }
      _initializing = false;
      return;
    }

    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        debugPrint('CameraPane: availableCameras() 返回空列表');
        throw CameraException('no_cameras', '设备上未发现摄像头');
      }
      for (final c in _cameras) {
        debugPrint('CameraPane: 可用摄像头 name=${c.name}, lens=${c.lensDirection}');
      }

      CameraDescription cam = _pickBestCamera();

      // external 镜头也正常支持，不再单独警告
      debugPrint('CameraPane: 选择摄像头=${cam.name}, lens=${cam.lensDirection}');

      CameraController makeController(CameraDescription desc) {
        return CameraController(
          desc,
          ResolutionPreset.medium, // 提升分辨率，external 镜头通常支持更高分辨率
          enableAudio: false,
          imageFormatGroup: ImageFormatGroup.jpeg, // 更通用的格式，external 镜头兼容性更好
        );
      }

      const int maxRetries = 6; // 增加重试次数，external 镜头可能需要更多时间
      int attempt = 0;
      CameraController? localController = makeController(cam);

      while (attempt < maxRetries) {
        attempt++;
        try {
          debugPrint('CameraPane: 初始化尝试 #$attempt');
          // 对 external 镜头，更长的等待时间确保驱动就绪
          final waitTime = cam.lensDirection == CameraLensDirection.external ? 200 : 120;
          await Future.delayed(Duration(milliseconds: waitTime));
          
          // 检查控制器是否仍然有效，避免对已释放实例调用 initialize
          if (localController == null) {
            debugPrint('CameraPane: 控制器已被释放，重新创建');
            localController = makeController(cam);
          }
          await localController!.initialize();
          
          // 成功后再赋值到字段，避免生命周期并发导致"对已释放实例初始化"
          _controller?.dispose();
          _controller = localController;
          _initialized = true;
          break;
        } catch (e) {
          final msg = e.toString().toLowerCase();
          debugPrint('CameraPane: initialize() 异常: $e');

          if (msg.contains('no capture session')) {
            try {
              localController?.dispose();
              localController = null; // 标记为已释放
              
              // 尝试切换到备用镜头（仍保留原有的排序逻辑）
              final candidates = _cameras
                  .where((c) => c.name != cam.name)
                  .toList()
                ..sort((a, b) {
                  int rank(CameraLensDirection d) {
                    switch (d) {
                      case CameraLensDirection.back: return 0;
                      case CameraLensDirection.front: return 1;
                      case CameraLensDirection.external: return 2;
                      default: return 3;
                    }
                  }
                  return rank(a.lensDirection).compareTo(rank(b.lensDirection));
                });
              if (candidates.isNotEmpty) {
                cam = candidates.first;
                debugPrint('CameraPane: 切换备用摄像头=${cam.name}, lens=${cam.lensDirection}');
                localController = makeController(cam);
                continue;
              }
            } catch (_) {}
          }

          // 若是 disposed 控制器错误，重新创建后重试
          if (msg.contains('disposed')) {
            localController?.dispose();
            localController = makeController(cam);
            await Future.delayed(const Duration(milliseconds: 200));
            continue;
          }

          // Surface/Session 相关错误，延长等待时间后重试
          if (msg.contains('session') || msg.contains('surface')) {
            final delay = cam.lensDirection == CameraLensDirection.external ? 500 : 300;
            await Future.delayed(Duration(milliseconds: delay));
            continue;
          }
          rethrow;
        }
      }

      if (!_initialized) {
        throw CameraException('capture_session_unavailable', 
          '相机会话未建立（重试${maxRetries}次失败，镜头类型：${cam.lensDirection}）');
      }

      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('初始化摄像头失败: $e')),
        );
      }
    } finally {
      _initializing = false;
    }
  }

  void _switchCamera() async {
    if (_cameras.isEmpty) return;
    final current = _controller?.description;
    final other = _cameras.firstWhere(
      (c) => current == null || c.lensDirection != current.lensDirection,
      orElse: () => current ?? _cameras.first,
    );
    if (current == other) return;

    try {
      await _controller?.dispose();
      final local = CameraController(
        other,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      // external 镜头切换时也给予更多时间
      final waitTime = other.lensDirection == CameraLensDirection.external ? 200 : 100;
      await Future.delayed(Duration(milliseconds: waitTime));
      await local.initialize();
      _controller = local;
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('CameraPane: 切换摄像头失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('切换摄像头失败: $e')),
        );
      }
    }
  }

  @override
  void didUpdateWidget(covariant CameraPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rotationDegrees != widget.rotationDegrees) {
      setState(() => _rotation = widget.rotationDegrees);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  void _rotateBy(double delta) {
    setState(() {
      _rotation = (_rotation + delta) % 360;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      // 如果是 external 镜头且多次失败，提供按钮拍照模式
      final isExternal = _cameras.isNotEmpty && 
          _cameras.every((c) => c.lensDirection == CameraLensDirection.external);
      
      if (isExternal && !_initializing) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.camera_alt_outlined, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'External镜头连续预览不可用',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () async {
                  // 调用原有的拍照识别流程
                  final picker = ImagePicker();
                  final image = await picker.pickImage(source: ImageSource.camera);
                  if (image != null && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('图片已拍摄，可进行识别')),
                    );
                  }
                },
                icon: const Icon(Icons.camera_enhance),
                label: const Text('点击拍照'),
              ),
            ],
          ),
        );
      }

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              _initializing ? '正在初始化摄像头...' : '摄像头未就绪',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    final preview = CameraPreview(_controller!);

    return Stack(
      fit: StackFit.expand,
      children: [
        // 旋转预览
        Center(
          child: Transform.rotate(
            angle: _rotation * math.pi / 180.0,
            child: AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: preview,
            ),
          ),
        ),
        // 右下角控制条：旋转/切换摄像头
        Positioned(
          right: 12,
          bottom: 12,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.35),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.rotate_left, color: Colors.white),
                  onPressed: () => _rotateBy(-90),
                  tooltip: '左转90°',
                ),
                IconButton(
                  icon: const Icon(Icons.rotate_right, color: Colors.white),
                  onPressed: () => _rotateBy(90),
                  tooltip: '右转90°',
                ),
                if (_cameras.length > 1) // 只有多个摄像头时才显示切换按钮
                  IconButton(
                    icon: const Icon(Icons.cameraswitch, color: Colors.white),
                    onPressed: _switchCamera,
                    tooltip: '切换摄像头',
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
