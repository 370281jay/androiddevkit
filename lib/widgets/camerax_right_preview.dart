import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';

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

class CameraXRightPreview extends StatefulWidget {
  final String lensFacing;           // 'back' | 'front' | 'external'
  final String implementationMode;   // 'PERFORMANCE' | 'COMPATIBLE'
  final String scaleType;            // 'FILL_CENTER' | 'FIT_CENTER' 等
  final double? width;
  final double? height;

  const CameraXRightPreview({
    super.key,
    this.lensFacing = 'back',
    this.implementationMode = 'PERFORMANCE',
    this.scaleType = 'FILL_CENTER',
    this.width,
    this.height,
  });

  @override
  State<CameraXRightPreview> createState() => _CameraXRightPreviewState();
}

class _CameraXRightPreviewState extends State<CameraXRightPreview> {
  int? _viewId;

  @override
  Widget build(BuildContext context) {
    if (!Platform.isAndroid) {
      return const Center(
        child: Text('CameraX 仅支持 Android 平台'),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final effectiveWidth = widget.width ??
            (constraints.maxWidth.isFinite ? constraints.maxWidth : 400);
        final effectiveHeight = widget.height ??
            (constraints.maxHeight.isFinite ? constraints.maxHeight : 300);

        debugPrint('CameraXRightPreview 尺寸: ${effectiveWidth}x$effectiveHeight');

        // 使用 PlatformViewLink 实现 Hybrid Composition
        return SizedBox(
          width: effectiveWidth,
          height: effectiveHeight,
          child: PlatformViewLink(
            viewType: 'camerax/right_preview',
            surfaceFactory: (context, controller) {
              return AndroidViewSurface(
                controller: controller as AndroidViewController,
                gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
                hitTestBehavior: PlatformViewHitTestBehavior.opaque,
              );
            },
            onCreatePlatformView: (params) {
              debugPrint('CameraXRightPreview: 创建 PlatformView, id=${params.id}');
              return PlatformViewsService.initSurfaceAndroidView(
                id: params.id,
                viewType: 'camerax/right_preview',
                layoutDirection: TextDirection.ltr,
                creationParams: {
                  'lensFacing': widget.lensFacing,
                  'implementationMode': widget.implementationMode,
                  'scaleType': widget.scaleType,
                  'width': effectiveWidth.toInt(),
                  'height': effectiveHeight.toInt(),
                },
                creationParamsCodec: const StandardMessageCodec(),
                onFocus: () {
                  params.onFocusChanged(true);
                },
              )
                ..addOnPlatformViewCreatedListener((viewId) {
                  debugPrint('CameraXRightPreview: PlatformView 创建成功, viewId=$viewId');
                  params.onPlatformViewCreated(viewId);
                  setState(() => _viewId = viewId);
                  CameraXBridge.attach(viewId);
                })
                ..create();
            },
          ),
        );
      },
    );
  }
}