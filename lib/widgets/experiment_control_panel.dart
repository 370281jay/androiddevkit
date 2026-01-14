import 'package:flutter/material.dart';
import 'package:ai_assistant/models/experiment.dart';

class ExperimentControlPanel extends StatelessWidget {
  final Experiment? selectedExperiment;
  final bool isConnected;
  final VoidCallback? onPauseExperiment;
  final VoidCallback? onEndExperiment;
  final VoidCallback? onViewReport;

  const ExperimentControlPanel({
    Key? key,
    required this.selectedExperiment,
    required this.isConnected,
    this.onPauseExperiment,
    this.onEndExperiment,
    this.onViewReport,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (selectedExperiment == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标题
          Row(
            children: [
              Icon(
                Icons.science,
                size: 16,
                color: Colors.blue.shade600,
              ),
              const SizedBox(width: 6),
              Text(
                '实验控制',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          
          // 按钮组
          Row(
            children: [
              // 暂停实验按钮
              Expanded(
                child: _buildControlButton(
                  icon: Icons.pause_circle_outline,
                  label: '暂停实验',
                  color: Colors.orange,
                  onTap: onPauseExperiment,
                  enabled: isConnected,
                ),
              ),
              const SizedBox(width: 6),
              
              // 结束实验按钮
              Expanded(
                child: _buildControlButton(
                  icon: Icons.stop_circle_outlined,
                  label: '结束实验',
                  color: Colors.red,
                  onTap: onEndExperiment,
                  enabled: isConnected,
                ),
              ),
              const SizedBox(width: 6),
              
              // 实验报告按钮
              Expanded(
                child: _buildControlButton(
                  icon: Icons.description_outlined,
                  label: '实验报告',
                  color: Colors.green,
                  onTap: onViewReport,
                  enabled: true, // 报告按钮始终可用
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
    required bool enabled,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: enabled 
                ? color.withOpacity(0.1) 
                : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: enabled 
                  ? color.withOpacity(0.3) 
                  : Colors.grey.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 18,
                color: enabled ? color : Colors.grey,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  color: enabled ? color : Colors.grey,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}