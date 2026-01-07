import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';

const _tag = 'INFLUX';

void logInflux(String message) {
  // 三路输出，减少被某一路吞掉的概率
  print('[$_tag] $message');
  debugPrint('[$_tag] $message');
  dev.log(message, name: _tag);
}

// 小分片 + 异步调度，避免 debugPrint 节流与 logcat 丢行
Future<void> logInfluxLargeAsync(String message, {int chunk = 180}) async {
  for (var i = 0; i < message.length; i += chunk) {
    final end = (i + chunk < message.length) ? i + chunk : message.length;
    final part = message.substring(i, end);
    // 异步调度每片，给日志系统“喘息”时间
    await Future<void>.delayed(const Duration(milliseconds: 1));
    print('[$_tag][$i] $part');
    debugPrint('[$_tag][$i] $part');
    dev.log(part, name: _tag, sequenceNumber: i);
  }
}