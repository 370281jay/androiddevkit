import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';

/// Android 原生 CameraX 预览封装
class NativeCameraXPreview extends StatefulWidget {
  final String lensFacing;           // back | front | external
  final double rotationDegrees;      // -90 逆时针
  final String implementationMode;   // PERFORMANCE | COMPATIBLE
  final String scaleType;            // FILL_CENTER | FIT_CENTER | ...

  const NativeCameraXPreview({
    super.key,
    this.lensFacing = 'external',
    this.rotationDegrees = -90,
    this.implementationMode = 'COMPATIBLE',
    this.scaleType = 'FILL_CENTER',
  });

  @override
  State<NativeCameraXPreview> createState() => _NativeCameraXPreviewState();
}

class _NativeCameraXPreviewState extends State<NativeCameraXPreview> {
  int? _viewId;

  @override
  Widget build(BuildContext context) {
    if (!Platform.isAndroid) {
      return const Center(child: Text('CameraX 仅支持 Android'));
    }

    return PlatformViewLink(
      viewType: 'camerax_preview',
      surfaceFactory: (context, controller) {
        return AndroidViewSurface(
          controller: controller as AndroidViewController,
          gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
          hitTestBehavior: PlatformViewHitTestBehavior.opaque,
        );
      },
      onCreatePlatformView: (params) {
        final view = PlatformViewsService.initSurfaceAndroidView(
          id: params.id,
          viewType: 'camerax_preview',
          layoutDirection: TextDirection.ltr,
          creationParams: {
            'lensFacing': widget.lensFacing,
            'rotationDegrees': widget.rotationDegrees,
            'implementationMode': widget.implementationMode,
            'scaleType': widget.scaleType,
          },
          creationParamsCodec: const StandardMessageCodec(),
          onFocus: () => params.onFocusChanged(true),
        );
        view.addOnPlatformViewCreatedListener((id) {
          _viewId = id;
          params.onPlatformViewCreated(id);
        });
        view.create();
        return view;
      },
    );
  }
}
