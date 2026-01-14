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
    name: '实验一 会爬的蠕虫',
    description: '学习如何组装一个能够爬行的蠕虫机器人',
    steps: [
      ExperimentStep(
        index: 1,
        name: '连接电池盒与电机',
        instruction: '1. 先把电池盒导线穿进电机快接，再把电机快接扣住电机。',
      ),
      ExperimentStep(index: 2, name: '放置电机到泡沫板', instruction: '1. 把电机放在泡沫板上。'),
      ExperimentStep(
        index: 3,
        name: '组装铁轴与齿轮部件',
        instruction: '1. 长轴穿进齿轮，短轴穿 3 个介子，再用两块拼装板夹住长轴、短轴。',
      ),
      ExperimentStep(index: 4, name: '组装泡沫板', instruction: '1. 按图组装好泡沫板。'),
      ExperimentStep(
        index: 5,
        name: '安装偏心轮与偏心支架',
        instruction: '1. 将偏心轮固定在电机上，再将长轴穿进偏心支架，最后用介子固定长轴。',
      ),
      ExperimentStep(
        index: 6,
        name: '粘贴卡纸',
        instruction: '1. 用双面胶把卡纸粘在尾盘合适的位置。',
      ),
    ],
  ),
  Experiment(
    id: 'exp_02',
    name: '实验二 煽动的翅膀',
    description: '学习如何组装一个能够煽动翅膀的机械装置',
    steps: [
      ExperimentStep(
        index: 1,
        name: '电机与电池盒连接',
        instruction: '1. 将杜邦线公母电池盒的导线穿入电机快接，然后把电机快接扣住黄色双轴电机，确保连接稳固，为后续供电做好准备。',
      ),
      ExperimentStep(
        index: 2,
        name: '泡沫板与电机初固定',
        instruction: '1. 轻晃泡沫板，检查电机是否松动，确保电机轴与板面垂直，避免偏心造成高速抖动。',
      ),
      ExperimentStep(
        index: 3,
        name: '电池盒固定与供电就绪',
        instruction:
            '1. 用双面胶将电池盒固定在泡沫板上，确保电池盒与泡沫板紧密结合，防止松脱。\n'
            '2. 装入自备电池，打开开关，观察电机是否瞬时启动，验证供电回路是否畅通。\n'
            '3. 通过调整电池盒的位置，确保整个装置的重心平衡，为后续运行提供稳定基础。',
      ),
      ExperimentStep(
        index: 4,
        name: '铁轴传动与介子锁固',
        instruction:
            '1. 将多孔棉绳缠绕在电机轴上，确保绳体与轴紧密贴合，为传动提供基础。\n'
            '2. 用介子固定铁轴，防止绳体在电机轴上滑动，确保传动稳定。\n'
            '3. 手动旋转电机轴，观察棉绳是否同步收紧并带动泡沫板微幅振动，确保传动正常。',
      ),
      ExperimentStep(
        index: 5,
        name: '连杆机构与翅膀最终组装',
        instruction:
            '1. 在泡沫板前端插入钉扣，将连杆小端套入钉扣，大端套入电机轴，形成曲柄连杆机构。\n'
            '2. 用介子固定连杆，将黄色翼柄插入连杆扁槽，确保翅膀能够随连杆上下煽动，完成最终组装。',
      ),
      ExperimentStep(
        index: 6,
        name: '最终检查与运行测试',
        instruction: '1. 检查所有部件是否安装牢固，通电测试翅膀煽动效果，确保实验装置运行正常，完成整个实验。',
      ),
    ],
  ),
  Experiment(
  id: 'exp_03',
  name: '实验三 机器人自转画',
  description: '学习如何组装一个能够通过偏心轮振动、在纸上自转绘画的机器人',
  steps: [
    ExperimentStep(
      index: 1,
      name: '电机与电池盒连接',
      instruction: '1. 将电池盒的导线穿入电机快接中，然后用电机快接扣紧电机，确保电路连接稳定，为电机供电做好准备。',
    ),
    ExperimentStep(
      index: 2,
      name: '电机与偏心轮安装',
      instruction: '1. 把电机穿进拼装板，通过合适的方式固定电机，再将偏心转盘安装在电机轴上。偏心轮的作用是使电机转动时产生振动，这是机器人能够自转绘画的关键动力来源。',
    ),
    ExperimentStep(
      index: 3,
      name: '电池盒固定与供电就绪',
      instruction: '1. 将拼装板的各部分组装好，形成机器人的主体结构。接着用双面胶把电池盒粘贴在拼装板上，保证电池盒位置牢固，不会在机器人运行时脱落。',
    ),
    ExperimentStep(
      index: 4,
      name: '最终检查与运行测试',
      instruction: '1. 装入自备电池，将组装好的画画机器人放置在纸上，开启开关。\n'
          '2. 电池供电后，电机带动偏心轮振动，使机器人在纸上自转，画笔随之绘制出图案，直观展现机械振动在创意制作中的应用效果。',
    ),
  ],
),Experiment(
  id: 'exp_04',
  name: '实验四 防盗报警器',
  description: '学习如何利用霍尔感应管和磁铁组装一个简单的防盗报警装置',
  steps: [
    ExperimentStep(
      index: 1,
      name: '组装泡沫小屋',
      instruction: '1. 按照图示将泡沫板组装成小屋结构，这是防盗报警器的 “载体外壳”',
    ),
    ExperimentStep(
      index: 2,
      name: '认识霍尔感应管',
      instruction: '1. 认识霍尔感应管的部件特征：两边平。\n'
          '2. 对比三极管特征：一边平一边凸。\n'
          '3. 作用说明：霍尔感应管是此防盗报警器的 “感应核心”，用于感知磁铁的位置变化。',
    ),
    ExperimentStep(
      index: 3,
      name: '电路连接',
      instruction: '1. 将霍尔感应管、电池盒导线、蜂鸣器依次接入快接，完成电路的初步连接，这是实现 “报警功能” 的电路基础。',
    ),
    ExperimentStep(
      index: 4,
      name: '安装与测试',
      instruction: '1. 用双面胶将快接、电池盒粘在小屋上。\n'
          '2. 装上自备电池，打开开关。\n'
          '3. 测试：当小屋大门打开时，蜂鸣器会发出警报声音，此时防盗报警器功能正常。',
    ),
  ],
),Experiment(
  id: 'exp_05',
  name: '实验五 环境感知车',
  description: '学习如何组装一个基础移动小车，并连接简单的电源开关控制电路',
  steps: [
    ExperimentStep(
      index: 1,
      name: '电机电路初连接',
      instruction: '1. 将电池盒导线与电源线连接到电机上，为小车动力系统搭建电路基础。',
    ),
    ExperimentStep(
      index: 2,
      name: '开关电路精准接',
      instruction: '1. 红导线接开关中间极脚。\n2. 电池盒黑色导线接开关 “O” 极脚。\n3. 通过开关实现对小车动力电路的通断控制，保障操作安全性。',
    ),
    ExperimentStep(
      index: 3,
      name: '部件拼装板固定',
      instruction: '1. 电机牙箱粘双面胶，固定在拼装板上。\n2. 垫片粘在电机牙箱上。\n3. 电池盒用圆形双面胶粘在拼装板上。\n4. 合并拼装板，完成核心部件的集成。',
    ),
    ExperimentStep(
      index: 4,
      name: '车轮与轴架安装',
      instruction: '1. 将多孔轴架插入拼装板，再装上车轮，完成小车的机械传动与行走结构搭建。',
    ),
    ExperimentStep(
      index: 5,
      name: '最终检查与运行测试',
      instruction: '1. 检查所有部件是否安装牢固，确保实验装置运行正常，完成整个实验。',
    ),
  ],
),
];
