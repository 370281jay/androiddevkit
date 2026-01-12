// 简单的中文/英文关键词匹配，尽量保守避免误触发
class VoiceCommands {
  static final List<String> _cameraKeywords = <String>[
    '拍照', '拍个照', '照相', '打开摄像头', '打开相机', '摄像头', '相机',
    'take a photo', 'take photo', 'camera', 'snapshot',
  ];

  // “看看”仅在同时提到“摄像头/相机/camera”时有效
  static bool containsCameraTrigger(String text) {
    final t = text.toLowerCase().trim();
    if (t.isEmpty) return false;

    final hitDirect = _cameraKeywords.any((k) => t.contains(k));
    final hitLook = t.contains('看看') &&
        (t.contains('摄像头') || t.contains('相机') || t.contains('camera'));

    return hitDirect || hitLook;
  }
}