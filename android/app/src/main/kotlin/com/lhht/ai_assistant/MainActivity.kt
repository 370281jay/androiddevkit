package com.lhht.ai_assistant

import com.lhht.ai_assistant.camerax.CameraXPreviewFactory
import com.lhht.ai_assistant.camerax.CameraXRightPreviewFactory
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 注册 CameraX 原生预览视图
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "camerax_preview",
            CameraXPreviewFactory(flutterEngine.dartExecutor.binaryMessenger, this),
        )

        // 注册右侧 2/3 预览
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "camerax/right_preview",
            CameraXRightPreviewFactory(this, flutterEngine.dartExecutor.binaryMessenger),
        )
    }
}
