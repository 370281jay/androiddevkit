package com.lhht.ai_assistant.camerax

import android.content.Context
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.camera.core.CameraSelector
import androidx.camera.view.CameraController
import androidx.camera.view.LifecycleCameraController
import androidx.camera.view.PreviewView
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class CameraXPreviewFactory(
    private val messenger: BinaryMessenger,
    private val activity: FlutterActivity,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val params = args as? Map<*, *> ?: emptyMap<String, Any>()
        return CameraXPreviewImpl(activity, params)
    }
}

class CameraXPreviewImpl(
    private val activity: FlutterActivity,
    params: Map<*, *>,
) : PlatformView {

    private val container = FrameLayout(activity).apply {
        layoutParams = ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT
        )
        setBackgroundColor(android.graphics.Color.BLACK)
    }

    private val previewView = PreviewView(activity).apply {
        layoutParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        )
    }

    private val controller = LifecycleCameraController(activity)

    init {
        val lensFacing = params["lensFacing"] as? String ?: "back"
        val implMode = (params["implementationMode"] as? String) ?: "COMPATIBLE"
        val scaleTypeStr = (params["scaleType"] as? String) ?: "FILL_CENTER"
        val rotationDeg = (params["rotationDegrees"] as? Number)?.toFloat() ?: -90f

        // 使用 TextureView，避免遮挡并支持旋转
        previewView.implementationMode = when (implMode.uppercase()) {
            "COMPATIBLE" -> PreviewView.ImplementationMode.COMPATIBLE
            else -> PreviewView.ImplementationMode.PERFORMANCE
        }
        previewView.scaleType = when (scaleTypeStr.uppercase()) {
            "FIT_CENTER" -> PreviewView.ScaleType.FIT_CENTER
            "FIT_START" -> PreviewView.ScaleType.FIT_START
            "FIT_END" -> PreviewView.ScaleType.FIT_END
            else -> PreviewView.ScaleType.FILL_CENTER
        }

        // 在 TextureView 模式下旋转预览
        try { previewView.rotation = rotationDeg } catch (_: Throwable) {}

        controller.cameraSelector = when (lensFacing) {
            "front" -> CameraSelector.DEFAULT_FRONT_CAMERA
            "external" -> CameraSelector.Builder()
                .requireLensFacing(CameraSelector.LENS_FACING_EXTERNAL)
                .build()
            else -> CameraSelector.DEFAULT_BACK_CAMERA
        }
        controller.setEnabledUseCases(CameraController.IMAGE_CAPTURE)

        try {
            controller.bindToLifecycle(activity)
            previewView.controller = controller
        } catch (_: Exception) {
            controller.cameraSelector = CameraSelector.DEFAULT_BACK_CAMERA
            controller.bindToLifecycle(activity)
            previewView.controller = controller
        }

        container.addView(previewView)
    }

    override fun getView(): View = container

    override fun dispose() {
        try { controller.unbind() } catch (_: Throwable) {}
    }
}
