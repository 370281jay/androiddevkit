package com.lhht.ai_assistant.camerax

import android.content.Context
import android.os.Environment
import android.util.Log
import android.view.View
import android.view.ViewGroup
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
        val params = args as? Map<*, *> ?: emptyMap<String, Any>()
        return CameraXRightPreviewImpl(activity, viewId, messenger, params)
    }
}

class CameraXRightPreviewImpl(
    private val activity: FlutterActivity,
    viewId: Int,
    messenger: BinaryMessenger,
    params: Map<*, *>
) : PlatformView {

    private val TAG = "CameraXRightPreview"
    
    // 使用 FrameLayout 作为容器，确保 PreviewView 正确约束
    private val container: FrameLayout = FrameLayout(activity).apply {
        layoutParams = ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT
        )
        setBackgroundColor(android.graphics.Color.BLACK)
    }
    
    private val previewView: PreviewView = PreviewView(activity).apply {
        layoutParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        )
        // 设置缩放类型
        scaleType = PreviewView.ScaleType.FILL_CENTER
        implementationMode = PreviewView.ImplementationMode.PERFORMANCE
    }
    
    private val controller: LifecycleCameraController = LifecycleCameraController(activity)
    private val channel: MethodChannel = MethodChannel(messenger, "camerax/right_preview/$viewId")

    init {
        Log.d(TAG, "初始化 CameraXRightPreview, viewId=$viewId, params=$params")
        
        val lensFacing = params["lensFacing"] as? String ?: "back"
        val implMode = params["implementationMode"] as? String ?: "PERFORMANCE"
        val scaleTypeStr = params["scaleType"] as? String ?: "FILL_CENTER"
        val width = params["width"] as? Int
        val height = params["height"] as? Int
        
        Log.d(TAG, "参数: lensFacing=$lensFacing, implMode=$implMode, scaleType=$scaleTypeStr, size=${width}x$height")

        // 设置预览视图的实现模式
        previewView.implementationMode = when (implMode) {
            "COMPATIBLE" -> PreviewView.ImplementationMode.COMPATIBLE
            else -> PreviewView.ImplementationMode.PERFORMANCE
        }

        // 设置缩放类型
        previewView.scaleType = when (scaleTypeStr) {
            "FIT_CENTER" -> PreviewView.ScaleType.FIT_CENTER
            "FIT_START" -> PreviewView.ScaleType.FIT_START
            "FIT_END" -> PreviewView.ScaleType.FIT_END
            else -> PreviewView.ScaleType.FILL_CENTER
        }

        // 选择摄像头
        controller.cameraSelector = when (lensFacing) {
            "front" -> CameraSelector.DEFAULT_FRONT_CAMERA
            "external" -> CameraSelector.Builder()
                .requireLensFacing(CameraSelector.LENS_FACING_EXTERNAL)
                .build()
            else -> CameraSelector.DEFAULT_BACK_CAMERA
        }

        // 开启预览 + 拍照用例
        controller.setEnabledUseCases(CameraController.IMAGE_CAPTURE)
        
        try {
            controller.bindToLifecycle(activity)
            previewView.controller = controller
            Log.d(TAG, "摄像头绑定成功")
        } catch (e: Exception) {
            Log.e(TAG, "摄像头绑定失败: ${e.message}", e)
            // 尝试使用后置摄像头作为备选
            try {
                controller.cameraSelector = CameraSelector.DEFAULT_BACK_CAMERA
                controller.bindToLifecycle(activity)
                previewView.controller = controller
                Log.d(TAG, "使用后置摄像头作为备选")
            } catch (e2: Exception) {
                Log.e(TAG, "后置摄像头也失败: ${e2.message}", e2)
            }
        }

        // 将 PreviewView 添加到容器
        container.addView(previewView)

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
                                    Log.d(TAG, "拍照成功: ${file.absolutePath}")
                                    result.success(mapOf("path" to file.absolutePath))
                                }
                                override fun onError(exception: ImageCaptureException) {
                                    Log.e(TAG, "拍照失败: ${exception.message}", exception)
                                    result.error("capture_error", exception.message ?: "unknown error", null)
                                }
                            }
                        )
                    } catch (t: Throwable) {
                        Log.e(TAG, "拍照异常: ${t.message}", t)
                        result.error("capture_error", t.message ?: "unknown error", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun getView(): View {
        Log.d(TAG, "getView() 被调用, container大小: ${container.width}x${container.height}")
        return container
    }

    override fun dispose() {
        Log.d(TAG, "dispose() 被调用")
        try {
            controller.unbind()
        } catch (t: Throwable) {
            Log.w(TAG, "dispose error", t)
        }
    }
}