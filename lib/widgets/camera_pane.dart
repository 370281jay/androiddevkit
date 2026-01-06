import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/scheduler.dart';
import 'dart:io';
import 'dart:async';

class CameraPane extends StatefulWidget {
  final double rotationDegrees;
  final CameraLensDirection lensDirection;
  final Function(File imageFile)? onPhotoTaken; // 新增：拍照回调
  final bool autoPhotoEnabled; // 新增：是否启用自动拍照
  final Duration? autoPhotoInterval; // 新增：自动拍照间隔

  const CameraPane({
    super.key,
    this.rotationDegrees = 0,
    this.lensDirection = CameraLensDirection.back,
    this.onPhotoTaken,
    this.autoPhotoEnabled = false,
    this.autoPhotoInterval = const Duration(seconds: 20),
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
  String _errorMessage = '';
  
  // 自动拍照相关
  Timer? _autoPhotoTimer;
  int _photoCount = 0;
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    _rotation = widget.rotationDegrees;
    WidgetsBinding.instance.addObserver(this);
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 500));
        _initAfterSized();
      }
    });
  }

  @override
  void didUpdateWidget(covariant CameraPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // 处理自动拍照状态变化
    if (oldWidget.autoPhotoEnabled != widget.autoPhotoEnabled) {
      if (widget.autoPhotoEnabled) {
        _startAutoPhoto();
      } else {
        _stopAutoPhoto();
      }
    }
    
    if (oldWidget.rotationDegrees != widget.rotationDegrees) {
      setState(() => _rotation = widget.rotationDegrees);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopAutoPhoto();
    _controller?.dispose();
    super.dispose();
  }

  // 启动自动拍照
  void _startAutoPhoto() {
    if (_autoPhotoTimer != null || !_initialized || widget.onPhotoTaken == null) return;
    
    debugPrint('CameraPane: 启动自动拍照，间隔${widget.autoPhotoInterval?.inSeconds}秒');
    
    _autoPhotoTimer = Timer.periodic(widget.autoPhotoInterval!, (timer) async {
      if (!mounted || !_initialized || _isCapturing) {
        return;
      }
      
      await _takePhoto(isAuto: true);
    });
  }

  // 停止自动拍照
  void _stopAutoPhoto() {
    _autoPhotoTimer?.cancel();
    _autoPhotoTimer = null;
    setState(() => _photoCount = 0);
    debugPrint('CameraPane: 停止自动拍照');
  }

  // 拍照方法
  Future<void> _takePhoto({bool isAuto = false}) async {
    if (_controller == null || !_controller!.value.isInitialized || _isCapturing) {
      debugPrint('CameraPane: 无法拍照，相机未准备好');
      return;
    }

    try {
      setState(() => _isCapturing = true);
      
      if (isAuto) {
        _photoCount++;
        debugPrint('CameraPane: 执行自动拍照 #$_photoCount');
      } else {
        debugPrint('CameraPane: 执行手动拍照');
      }

      // 使用相机控制器拍照
      final XFile photo = await _controller!.takePicture();
      final File imageFile = File(photo.path);
      
      // 调用回调函数，传递图片给父组件
      if (widget.onPhotoTaken != null) {
        widget.onPhotoTaken!(imageFile);
      }
      
      debugPrint('CameraPane: 拍照成功，路径: ${photo.path}');
      
    } catch (e) {
      debugPrint('CameraPane: 拍照失败: $e');
    } finally {
      setState(() => _isCapturing = false);
    }
  }

  // 手动拍照（供外部调用）
  Future<void> takePhoto() async {
    await _takePhoto(isAuto: false);
  }

  Future<void> _initAfterSized() async {
    for (int i = 0; i < 15; i++) {
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
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      try {
        debugPrint('CameraPane: lifecycle=$state -> 停止并释放控制器');
        _stopAutoPhoto();
        _controller?.dispose();
        _controller = null;
        _initialized = false;
      } catch (e) {
        debugPrint('CameraPane: 释放控制器异常: $e');
      }
    } else if (state == AppLifecycleState.resumed) {
      debugPrint('CameraPane: lifecycle=$state -> 尝试重新初始化相机');
      if (!_initializing) {
        _initAfterSized();
      }
    }
  }

  CameraDescription _pickBestCamera() {
    final specific = _cameras.where((c) => c.lensDirection == widget.lensDirection).toList();
    if (specific.isNotEmpty) return specific.first;

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
      setState(() {
        _errorMessage = '未授予相机权限';
        _initializing = false;
      });
      return;
    }

    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() {
          _errorMessage = '设备上未发现摄像头';
          _initializing = false;
        });
        return;
      }
      
      for (final c in _cameras) {
        debugPrint('CameraPane: 可用摄像头 name=${c.name}, lens=${c.lensDirection}');
      }

      CameraDescription cam = _pickBestCamera();
      debugPrint('CameraPane: 选择摄像头=${cam.name}, lens=${cam.lensDirection}');

      if (cam.lensDirection == CameraLensDirection.external) {
        await _tryExternalCameraInit(cam);
      } else {
        await _tryRegularCameraInit(cam);
      }

      // 初始化成功后，如果需要自动拍照，则启动
      if (_initialized && widget.autoPhotoEnabled) {
        _startAutoPhoto();
      }

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('CameraPane: 所有初始化方案均失败: $e');
      setState(() {
        _errorMessage = 'External镜头不支持连续预览';
        _initialized = false;
      });
    } finally {
      _initializing = false;
    }
  }

  Future<void> _tryExternalCameraInit(CameraDescription cam) async {
    final configs = [
      {
        'preset': ResolutionPreset.low,
        'format': ImageFormatGroup.yuv420,
        'delay': 1200,
      },
      {
        'preset': ResolutionPreset.low,
        'format': ImageFormatGroup.yuv420,
        'delay': 1000,
      },
      {
        'preset': ResolutionPreset.low,
        'format': ImageFormatGroup.jpeg,
        'delay': 800,
      },
    ];

    for (final config in configs) {
      try {
        debugPrint('CameraPane: External镜头尝试配置: ${config}');
        _controller?.dispose();
        
        _controller = CameraController(
          cam,
          config['preset'] as ResolutionPreset,
          enableAudio: false,
          imageFormatGroup: config['format'] as ImageFormatGroup,
        );
        
        await Future.delayed(Duration(milliseconds: config['delay'] as int));
        await _controller!.initialize();
        _initialized = true;
        debugPrint('CameraPane: External镜头初始化成功，使用配置: ${config}');
        return;
      } catch (e) {
        debugPrint('CameraPane: External镜头配置${config}失败: $e');
        _controller?.dispose();
        _controller = null;
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }
    
    throw CameraException('external_all_failed', 'External镜头所有配置均失败');
  }

  Future<void> _tryRegularCameraInit(CameraDescription cam) async {
    _controller = CameraController(
      cam,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    
    await Future.delayed(const Duration(milliseconds: 200));
    await _controller!.initialize();
    _initialized = true;
  }

  void _rotateBy(double delta) {
    setState(() {
      _rotation = (_rotation + delta) % 360;
    });
  }

  void _switchCamera() async {
    if (_cameras.isEmpty || _cameras.length < 2) return;
    try {
      _stopAutoPhoto(); // 切换相机时停止自动拍照
      
      final current = _controller?.description;
      final other = _cameras.firstWhere(
        (c) => current == null || c.lensDirection != current.lensDirection,
        orElse: () => current ?? _cameras.first,
      );
      if (current == other) return;

      await _controller?.dispose();
      
      if (other.lensDirection == CameraLensDirection.external) {
        await _tryExternalCameraInit(other);
      } else {
        await _tryRegularCameraInit(other);
      }
      
      // 切换成功后重新启动自动拍照
      if (_initialized && widget.autoPhotoEnabled) {
        _startAutoPhoto();
      }
      
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
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      if (!_initializing && _errorMessage.isNotEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.camera_alt_outlined, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                _errorMessage,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '使用拍照按钮进行识别',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
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
        Center(
          child: Transform.rotate(
            angle: _rotation * math.pi / 180.0,
            child: AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: preview,
            ),
          ),
        ),
        
        // 拍照状态指示器
        if (_isCapturing)
          Positioned.fill(
            child: Container(
              color: Colors.white.withOpacity(0.3),
              child: const Center(
                child: Icon(
                  Icons.camera_alt,
                  size: 64,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          
        // 自动拍照计数显示
        if (widget.autoPhotoEnabled && _photoCount > 0)
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.8),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '自动拍照 $_photoCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
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
                if (_cameras.length > 1)
                  IconButton(
                    icon: const Icon(Icons.cameraswitch, color: Colors.white),
                    onPressed: _switchCamera,
                    tooltip: '切换摄像头',
                  ),
                // 手动拍照按钮
                IconButton(
                  icon: const Icon(Icons.camera_alt, color: Colors.white),
                  onPressed: _takePhoto,
                  tooltip: '手动拍照',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
