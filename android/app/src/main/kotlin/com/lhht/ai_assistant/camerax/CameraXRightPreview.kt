package com.lhht.ai_assistant.camerax

import android.content.Context
import android.os.Environment
import android.util.Log
import android.view.View
import android.widget.FrameLayout
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageCapture
import androidx.camera.core.ImageCaptureException
import androidx.camera.view.PreviewView
import androidx.camera.view.LifecycleCameraController
import androidx.camera.view.CameraController
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import java.io.File

class CameraXRightPreviewFactory(
    private val activity: FlutterActivity,
    private val messenger: BinaryMessenger
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        @Suppress("UNCHECKED_CAST")
        val params = (args as? Map<String, Any?>) ?: emptyMap()
        return CameraXRightPreviewView(activity, messenger, viewId, params)
    }
}

class CameraXRightPreviewView(
    private val activity: FlutterActivity,
    messenger: BinaryMessenger,
    viewId: Int,
    private val params: Map<String, Any?>
) : PlatformView {

    private val container: FrameLayout = FrameLayout(activity)
    private val previewView: PreviewView = PreviewView(activity)
    private val controller: LifecycleCameraController = LifecycleCameraController(activity)
    private val channel = MethodChannel(messenger, "camerax/right_preview/$viewId")

    init {
        container.layoutParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        )

        val implMode = (params["implementationMode"] as? String) ?: "PERFORMANCE"
        previewView.implementationMode =
            if (implMode.equals("COMPATIBLE", true))
                PreviewView.ImplementationMode.COMPATIBLE
            else
                PreviewView.ImplementationMode.PERFORMANCE

        val scaleType = (params["scaleType"] as? String) ?: "FILL_CENTER"
        previewView.scaleType = when (scaleType.uppercase()) {
            "FIT_CENTER" -> PreviewView.ScaleType.FIT_CENTER
            "FIT_START" -> PreviewView.ScaleType.FIT_START
            "FIT_END" -> PreviewView.ScaleType.FIT_END
            "FILL_START" -> PreviewView.ScaleType.FILL_START
            "FILL_END" -> PreviewView.ScaleType.FILL_END
            else -> PreviewView.ScaleType.FILL_CENTER
        }

        val lens = (params["lensFacing"] as? String) ?: "back"
        controller.cameraSelector = when (lens.lowercase()) {
            "front" -> CameraSelector.DEFAULT_FRONT_CAMERA
            "external" -> CameraSelector.Builder()
                .requireLensFacing(CameraSelector.LENS_FACING_EXTERNAL)
                .build()
            else -> CameraSelector.DEFAULT_BACK_CAMERA
        }

        // 开启预览 + 拍照用例
        controller.setEnabledUseCases(CameraController.IMAGE_CAPTURE)
        controller.bindToLifecycle(activity)
        previewView.controller = controller

        container.addView(
            previewView,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
        )

        // 方法通道：拍照
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "takePicture" -> {
                    try {
                        val fileName = "shot_${System.currentTimeMillis()}.jpg"
                        val dir = File(activity.getExternalFilesDir(Environment.DIRECTORY_PICTURES), "camerax")
                        if (!dir.exists()) dir.mkdirs()
                        val file = File(dir, fileName)

                        val output = ImageCapture.OutputFileOptions.Builder(file).build()
                        controller.takePicture(
                            output,
                            ContextCompat.getMainExecutor(activity),
                            object : ImageCapture.OnImageSavedCallback {
                                override fun onImageSaved(outputFileResults: ImageCapture.OutputFileResults) {
                                    result.success(mapOf("path" to file.absolutePath))
                                }
                                override fun onError(exception: ImageCaptureException) {
                                    result.error("capture_error", exception.message ?: "unknown error", null)
                                }
                            }
                        )
                    } catch (t: Throwable) {
                        result.error("capture_error", t.message ?: "unknown error", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun getView(): View = container

    override fun dispose() {
        try {
            controller.unbind()
        } catch (t: Throwable) {
            Log.w("CameraXRightPreview", "dispose error", t)
        }
    }
}