import 'package:flutter/material.dart';
import 'package:ai_assistant/models/experiment.dart';
import 'package:ai_assistant/screens/experiment_report_screen.dart';

class ExperimentDialogs {
  /// 显示暂停实验对话框
  static Future<bool?> showPauseDialog(
    BuildContext context,
    Experiment experiment,
  ) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.pause_circle, color: Colors.orange, size: 28),
            const SizedBox(width: 12),
            const Text('暂停实验'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('实验「${experiment.name}」已暂停'),
            const SizedBox(height: 8),
            Text(
              'WebSocket 连接已断开，您可以随时重新连接继续实验。',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('确定'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('重新连接'),
          ),
        ],
      ),
    );
  }

  /// 显示结束实验对话框
  static Future<bool?> showEndDialog(
    BuildContext context,
    Experiment experiment,
  ) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.red, size: 28),
            const SizedBox(width: 12),
            const Text('结束实验'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('确定要结束当前实验吗？'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '实验：${experiment.name}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '• WebSocket 连接将断开\n• 实验数据将保存\n• 可查看实验报告',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('确定结束'),
          ),
        ],
      ),
    );
  }

  /// 查看实验报告对话框
  static Future<void> showReportDialog(
    BuildContext context,
    Experiment experiment,
  ) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.assessment, color: Colors.green, size: 28),
            const SizedBox(width: 12),
            const Text('实验报告'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('实验「${experiment.name}」的报告'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📄 报告功能包括：',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  SizedBox(height: 8),
                  Text('• PDF格式在线预览', style: TextStyle(fontSize: 13)),
                  SizedBox(height: 2),
                  Text('• DOCX格式邮件发送', style: TextStyle(fontSize: 13)),
                  SizedBox(height: 2),
                  Text('• 实验步骤记录', style: TextStyle(fontSize: 13)),
                  SizedBox(height: 2),
                  Text('• 体征数据分析', style: TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // 导航到新的报告界面
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ExperimentReportScreen(
                    experiment: experiment,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('查看报告'),
          ),
        ],
      ),
    );
  }
}