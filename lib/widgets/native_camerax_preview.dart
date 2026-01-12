import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Android 原生 CameraX 预览封装
class NativeCameraXPreview extends StatelessWidget {
  final String lensFacing; // back | front | external
  final double rotationDegrees; // 预览旋转角度（Android原生侧应用）

  const NativeCameraXPreview({
    super.key,
    this.lensFacing = 'external',
    this.rotationDegrees = -90, // 默认逆时针90°
  });

  @override
  Widget build(BuildContext context) {
    if (!Platform.isAndroid) {
      return const Center(child: Text('CameraX 预览仅支持 Android'));
    }

    // 去掉 Transform.rotate，改为原生侧旋转
    return AndroidView(
      viewType: 'camerax_preview',
      layoutDirection: TextDirection.ltr,
      creationParams: {
        'lensFacing': lensFacing,
        'rotationDegrees': rotationDegrees,
      },
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: (_) {
        debugPrint('NativeCameraXPreview created (rotation=$rotationDegrees)');
      },
    );
  }
}
