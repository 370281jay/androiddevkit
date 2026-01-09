package com.lhht.ai_assistant

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import com.lhht.ai_assistant.camerax.CameraXRightPreviewFactory

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.platformViewsController.registry
            .registerViewFactory(
                "camerax/right_preview",
                CameraXRightPreviewFactory(this, flutterEngine.dartExecutor.binaryMessenger)
            )
    }
}
