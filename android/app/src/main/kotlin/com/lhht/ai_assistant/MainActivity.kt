package com.lhht.ai_assistant

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import com.lhht.ai_assistant.camerax.CameraXRightPreviewFactory

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // 注册 CameraX 平台视图 - 使用 Hybrid Composition
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "camerax/right_preview",
            CameraXRightPreviewFactory(this, flutterEngine.dartExecutor.binaryMessenger)
        )
    }
}
