# Flutter混淆规则
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# 保留flutter_displaymode相关类
-keep class dev.flutter.plugin.** { *; }

# 保留Kotlin相关类
-keep class kotlin.** { *; }
-keep class kotlinx.** { *; }

# 保留androidx相关类
-keep class androidx.** { *; }
-keep class com.google.android.material.** { *; }

# 移除debug日志
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int d(...);
    public static int i(...);
} 