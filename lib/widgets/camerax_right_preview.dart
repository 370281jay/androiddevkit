import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CameraXBridge {
  static MethodChannel? _channel;

  static void attach(int viewId) {
    _channel = MethodChannel('camerax/right_preview/$viewId');
  }

  static Future<String?> takePicture() async {
    if (_channel == null) return null;
    final res = await _channel!.invokeMethod('takePicture');
    if (res is Map && res['path'] is String) return res['path'] as String;
    if (res is String) return res;
    return null;
  }
}

class CameraXRightPreview extends StatelessWidget {
  final String lensFacing;           // 'back' | 'front' | 'external'
  final String implementationMode;   // 'PERFORMANCE' | 'COMPATIBLE'
  final String scaleType;            // 'FILL_CENTER' | 'FIT_CENTER' 等
  final double? width;               // null 表示占满父布局

  const CameraXRightPreview({
    super.key,
    this.lensFacing = 'back',
    this.implementationMode = 'PERFORMANCE',
    this.scaleType = 'FILL_CENTER',
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    if (!Platform.isAndroid) {
      return const Center(
        child: Text('CameraX 仅支持 Android 平台'),
      );
    }

    // 使用 LayoutBuilder 获取父容器约束，确保摄像头预览不会溢出
    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: width ?? constraints.maxWidth,
          height: constraints.maxHeight,
          child: AndroidView(
            viewType: 'camerax/right_preview',
            creationParams: {
              'lensFacing': lensFacing,
              'implementationMode': implementationMode,
              'scaleType': scaleType,
            },
            creationParamsCodec: const StandardMessageCodec(),
            onPlatformViewCreated: (int viewId) {
              CameraXBridge.attach(viewId);
            },
          ),
        );
      },
    );
  }
}