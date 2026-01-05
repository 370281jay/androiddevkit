import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class WebRTCCameraView extends StatefulWidget {
  const WebRTCCameraView({super.key});

  @override
  State<WebRTCCameraView> createState() => _WebRTCCameraViewState();
}

class _WebRTCCameraViewState extends State<WebRTCCameraView> {
  MediaStream? _localStream;
  RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initRenderers();
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _getUserMedia();
  }

  Future<void> _getUserMedia() async {
    try {
      // 尝试获取摄像头流，包括 external 设备
      final Map<String, dynamic> mediaConstraints = {
        'audio': false,
        'video': {
          'mandatory': {
            'minWidth': '640',
            'minHeight': '480',
            'minFrameRate': '15',
          },
          'facingMode': 'environment', // 后置摄像头
          'optional': [],
        }
      };

      MediaStream stream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      _localRenderer.srcObject = stream;
      setState(() {
        _localStream = stream;
        _isInitialized = true;
      });
    } catch (e) {
      debugPrint('WebRTC获取摄像头失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('WebRTC摄像头初始化失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        RTCVideoView(_localRenderer, mirror: false),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            onPressed: () async {
              // 切换摄像头
              await _switchCamera();
            },
            child: const Icon(Icons.cameraswitch),
          ),
        ),
      ],
    );
  }

  Future<void> _switchCamera() async {
    if (_localStream != null) {
      final videoTracks = _localStream!.getVideoTracks();
      if (videoTracks.isNotEmpty) {
        await Helper.switchCamera(videoTracks.first);
      }
    }
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _localStream?.dispose();
    super.dispose();
  }
}