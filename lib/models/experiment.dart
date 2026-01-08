class Experiment {
  final String id;
  final String name;
  final String description;
  final List<ExperimentStep> steps;

  Experiment({
    required this.id,
    required this.name,
    required this.description,
    required this.steps,
  });
}

class ExperimentStep {
  final int index;
  final String name;
  final String instruction;

  ExperimentStep({
    required this.index,
    required this.name,
    required this.instruction,
  });
}

// 实验数据定义
final List<Experiment> experiments = [
  Experiment(
    id: 'exp_01',
    name: '温度采集实验',
    description: '学习如何通过传感器采集环境温度数据',
    steps: [
      ExperimentStep(
        index: 1,
        name: '连接传感器',
        instruction: '1. 检查DHT11温度传感器连接\n',
      ),
      ExperimentStep(
        index: 2,
        name: '初始化配置',
        instruction: '1. 打开配置界面\n'
            '2. 设置采样频率为1Hz\n'
            '3. 配置InfluxDB数据库连接\n'
            '4. 点击"保存配置"',
      ),
      ExperimentStep(
        index: 3,
        name: '开始采集',
        instruction: '1. 在聊天界面输入 /start temp\n'
            '2. 等待"采集开始"提示\n'
            '3. 观察温度数据实时更新\n'
            '4. 可输入 /query temp 查询数据',
      ),
      ExperimentStep(
        index: 4,
        name: '开始采集',
        instruction: '1. 在聊天界面输入 /start temp\n',
            
      ),
    ],
  ),
  Experiment(
    id: 'exp_02',
    name: '心率监测实验',
    description: '实时监测和分析心率数据',
    steps: [
      ExperimentStep(
        index: 1,
        name: '设备配对',
        instruction: '1. 打开蓝牙设置\n'
            '2. 搜索设备 "Xiaozhi-Monitor"\n'
            '3. 输入配对码: 123456\n'
            '4. 点击连接',
      ),
      ExperimentStep(
        index: 2,
        name: '校准传感器',
        instruction: '1. 佩戴心率手环或贴片\n'
            '2. 保持静坐5分钟\n'
            '3. 在设置中选择"传感器校准"\n'
            '4. 等待校准完成',
      ),
      ExperimentStep(
        index: 3,
        name: '数据监测',
        instruction: '1. 点击右上角"语音通话"按钮\n'
            '2. 实时查看心率波形\n'
            '3. 可进行活动测试观察数据变化\n'
            '4. 输入 /export 导出数据',
      ),
    ],
  ),
];