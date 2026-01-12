import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'dart:async';
import 'package:camera/camera.dart';

class CameraPane extends StatefulWidget {
  final double rotationDegrees;
  final Function(File imageFile)? onPhotoTaken;
  final bool autoPhotoEnabled;
  final Duration? autoPhotoInterval;

  const CameraPane({
    super.key,
    this.rotationDegrees = 0,
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
  
  Timer? _autoPhotoTimer;
  int _photoCount = 0;
  bool _isCapturing = false;
  bool _isDisposed = false;
  
  int _currentCameraIndex = 0;

  @override
  void initState() {
    super.initState();
    _rotation = widget.rotationDegrees;
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void didUpdateWidget(covariant CameraPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    
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
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _stopAutoPhoto();
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }

  Future<void> _initCamera() async {
    if (_initializing || _isDisposed) return;
    
    setState(() {
      _initializing = true;
      _errorMessage = '';
    });

    try {
      // 1. 请求权限
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        throw Exception('相机权限未授予');
      }

      // 2. 获取可用摄像头
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        throw Exception('未检测到可用摄像头');
      }

      debugPrint('CameraPane: 可用摄像头数量: ${_cameras.length}');
      for (int i = 0; i < _cameras.length; i++) {
        debugPrint('CameraPane: 摄像头[$i] - ${_cameras[i].name}, '
            'facing: ${_cameras[i].lensDirection}');
      }

      // 3. 优先选择外置摄像头
      _currentCameraIndex = 0;
      for (int i = 0; i < _cameras.length; i++) {
        if (_cameras[i].lensDirection == CameraLensDirection.external) {
          _currentCameraIndex = i;
          debugPrint('CameraPane: 选择外置摄像头 index=$i');
          break;
        }
      }

      // 4. 初始化摄像头
      await _initCameraController();

      if (mounted) {
        setState(() {
          _initializing = false;
        });
      }

    } catch (e) {
      debugPrint('CameraPane: 初始化失败: $e');
      if (mounted) {
        setState(() {
          _initializing = false;
          _errorMessage = '相机初始化失败\n$e';
        });
      }
    }
  }

  Future<void> _initCameraController() async {
    try {
      // 释放旧控制器
      if (_controller != null) {
        await _controller!.dispose();
        _controller = null;
      }

      if (_currentCameraIndex >= _cameras.length) {
        throw Exception('摄像头索引越界');
      }

      final camera = _cameras[_currentCameraIndex];
      final cameraName = _getCameraName(camera.lensDirection);
      
      debugPrint('CameraPane: 初始化 $cameraName (${camera.name})');

      // 🔥 创建控制器（使用 CameraX 后端）
      _controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      // 初始化
      await _controller!.initialize();
      
      // 等待摄像头稳定
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (!_controller!.value.isInitialized) {
        throw Exception('摄像头初始化失败');
      }

      _initialized = true;
      debugPrint('CameraPane: $cameraName 初始化成功 ✅');
      
      // 启动自动拍照
      if (widget.autoPhotoEnabled) {
        _startAutoPhoto();
      }
      
    } catch (e) {
      debugPrint('CameraPane: CameraX 初始化失败: $e');
      
      // 尝试下一个摄像头
      if (_currentCameraIndex < _cameras.length - 1) {
        debugPrint('CameraPane: 尝试下一个摄像头...');
        _currentCameraIndex++;
        return _initCameraController();
      }
      
      _initialized = false;
      rethrow;
    }
  }

  String _getCameraName(CameraLensDirection direction) {
    switch (direction) {
      case CameraLensDirection.back:
        return '后置摄像头';
      case CameraLensDirection.front:
        return '前置摄像头';
      case CameraLensDirection.external:
        return '外置摄像头';
    }
  }

  void _startAutoPhoto() {
    if (_autoPhotoTimer != null || !_initialized || widget.onPhotoTaken == null) {
      return;
    }
    
    debugPrint('CameraPane: 启动自动拍照，间隔${widget.autoPhotoInterval?.inSeconds}秒');
    
    _autoPhotoTimer = Timer.periodic(widget.autoPhotoInterval!, (timer) async {
      if (!mounted || !_initialized || _isCapturing || _isDisposed) {
        return;
      }
      
      await _takePhoto(isAuto: true);
    });
  }

  void _stopAutoPhoto() {
    _autoPhotoTimer?.cancel();
    _autoPhotoTimer = null;
    if (mounted) setState(() => _photoCount = 0);
    debugPrint('CameraPane: 停止自动拍照');
  }

  Future<void> _takePhoto({bool isAuto = false}) async {
    if (_controller == null || !_initialized || _isCapturing) {
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

      // 拍照
      final XFile photo = await _controller!.takePicture().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw CameraException('timeout', 'Take picture timeout');
        },
      );
      
      final File imageFile = File(photo.path);

      if (widget.onPhotoTaken != null) {
        widget.onPhotoTaken!(imageFile);
      }

      debugPrint('CameraPane: 拍照成功 ✅ 路径: ${photo.path}');

    } on CameraException catch (e) {
      debugPrint('CameraPane: 拍照失败: ${e.code} - ${e.description}');
    } catch (e) {
      debugPrint('CameraPane: 拍照异常: $e');
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }

  void _rotateBy(double delta) {
    setState(() {
      _rotation = (_rotation + delta) % 360;
    });
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    
    try {
      _stopAutoPhoto();
      
      setState(() {
        _initialized = false;
      });

      _currentCameraIndex = (_currentCameraIndex + 1) % _cameras.length;
      
      await _initCameraController();
      
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
    // 错误状态
    if (_errorMessage.isNotEmpty) {
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
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _errorMessage = '';
                  _initialized = false;
                  _currentCameraIndex = 0;
                });
                _initCamera();
              },
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    // 加载状态
    if (!_initialized || _controller == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在初始化摄像头...'),
          ],
        ),
      );
    }

    // 正常预览
    return Stack(
      fit: StackFit.expand,
      children: [
        // 摄像头预览
        Center(
          child: Transform.rotate(
            angle: _rotation * math.pi / 180.0,
            child: AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: CameraPreview(_controller!),
            ),
          ),
        ),
        
        // 拍照中遮罩
        if (_isCapturing)
          Positioned.fill(
            child: Container(
              color: Colors.white.withOpacity(0.3),
              child: const Center(
                child: Icon(Icons.camera_alt, size: 64, color: Colors.white),
              ),
            ),
          ),
          
        // 自动拍照计数
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
          
        // 摄像头信息
        Positioned(
          top: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _getCameraName(_cameras[_currentCameraIndex].lensDirection),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
          
        // 控制按钮
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
