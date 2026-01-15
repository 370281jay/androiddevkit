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
        instruction:
            '1. 把电机穿进拼装板，通过合适的方式固定电机，再将偏心转盘安装在电机轴上。偏心轮的作用是使电机转动时产生振动，这是机器人能够自转绘画的关键动力来源。',
      ),
      ExperimentStep(
        index: 3,
        name: '电池盒固定与供电就绪',
        instruction:
            '1. 将拼装板的各部分组装好，形成机器人的主体结构。接着用双面胶把电池盒粘贴在拼装板上，保证电池盒位置牢固，不会在机器人运行时脱落。',
      ),
      ExperimentStep(
        index: 4,
        name: '最终检查与运行测试',
        instruction:
            '1. 装入自备电池，将组装好的画画机器人放置在纸上，开启开关。\n'
            '2. 电池供电后，电机带动偏心轮振动，使机器人在纸上自转，画笔随之绘制出图案，直观展现机械振动在创意制作中的应用效果。',
      ),
    ],
  ),
  Experiment(
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
        instruction:
            '1. 认识霍尔感应管的部件特征：两边平。\n'
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
        instruction:
            '1. 用双面胶将快接、电池盒粘在小屋上。\n'
            '2. 装上自备电池，打开开关。\n'
            '3. 测试：当小屋大门打开时，蜂鸣器会发出警报声音，此时防盗报警器功能正常。',
      ),
    ],
  ),
  Experiment(
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
        instruction:
            '1. 红导线接开关中间极脚。\n2. 电池盒黑色导线接开关 “O” 极脚。\n3. 通过开关实现对小车动力电路的通断控制，保障操作安全性。',
      ),
      ExperimentStep(
        index: 3,
        name: '部件拼装板固定',
        instruction:
            '1. 电机牙箱粘双面胶，固定在拼装板上。\n2. 垫片粘在电机牙箱上。\n3. 电池盒用圆形双面胶粘在拼装板上。\n4. 合并拼装板，完成核心部件的集成。',
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
  Experiment(
    id: 'exp_06',
    name: '实验六 亮度感应灯',
    description: '学习如何组装一个能够根据环境亮度自动开关的LED灯',
    steps: [
      ExperimentStep(
        index: 1,
        name: 'LED灯与灯罩组装',
        instruction:
            '1. 将红发红LED灯的灯脚插进LED灯座，注意长脚（正极）插进红色线插口。\n2. 将LED灯座的导线从前面穿进灯罩。',
      ),
      ExperimentStep(
        index: 2,
        name: '导线与吸管、过渡管组装',
        instruction: '1. 将LED灯座导线穿进吸管。\n2. 把过渡管塞进吸管。\n3. 将灯座导线穿出底座小孔。',
      ),
      ExperimentStep(
        index: 3,
        name: '整体配件组装',
        instruction: '1. 用螺丝刀和小螺丝将各配件（包括多孔底板等）组装固定好。',
      ),
      ExperimentStep(
        index: 4,
        name: '实验测试',
        instruction: '1. 装上电池，打开电源开关，分别在照明良好和照明不良的环境下观察LED灯珠是否亮着，以此验证亮度感应功能。',
      ),
    ],
  ),
  Experiment(
    id: 'exp_08',
    name: '实验七 导电的物体',
    description: '学习如何搭建一个电路，通过人体或物体触碰铜片来测试其导电性，并通过LED灯的亮灭显示结果',
    steps: [
      ExperimentStep(
        index: 1,
        name: '固定三极管、电池盒导线与铜片',
        instruction: '1. 使用螺丝刀和小螺丝，将三极管、电池盒导线、铜片依次固定在多孔底板上。',
      ),
      ExperimentStep(
        index: 2,
        name: '固定LED灯、电池盒导线与铜片',
        instruction: '1. 同样用螺丝刀和小螺丝，把LED灯、电池盒导线、铜片固定在多孔底板的合适位置。',
      ),
      ExperimentStep(
        index: 3,
        name: '固定电池盒并测试材料导电性',
        instruction:
            '1. 将电池盒固定在多孔底板上，装上自备电池。\n2. 测试方法一：双手触摸铜片，观察LED灯是否通电发光。\n3. 测试方法二：一只手触摸铜片，另一只手拿不同材料触摸另一个铜片，通过LED灯的亮灭来分辨该材料是否导电。',
      ),
    ],
  ),
  Experiment(
    id: 'exp_09',
    name: '实验八 密电发报机',
    description: '学习如何组装一个简单的发报机模型，通过手动按压铜片来控制电路通断，模拟电报信号的发送',
    steps: [
      ExperimentStep(
        index: 1,
        name: '安装电池盒与正极线路组件',
        instruction:
            '1. 选择多孔底板上适当位置，用1-2颗螺丝将电池盒安装固定。\n2. 将电池盒红线、蜂鸣器红线、固定电阻、LED灯长脚（正极）依次用螺丝拧紧在底板上，完成正极线路的组装。',
      ),
      ExperimentStep(
        index: 2,
        name: '安装负极线路组件',
        instruction:
            '1. 用螺丝将电池盒黑线固定在多孔底板上。\n2. 将LED灯短脚（负极）、蜂鸣器黑线（负极）、铜片依次用螺丝拧紧在底板上，完成负极线路的组装。',
      ),
      ExperimentStep(
        index: 3,
        name: '模拟发报测试',
        instruction: '1. 将自备电池装入电池盒。\n2. 按动铜片，观察LED灯的亮灭，以此模拟发报机发报的电信号传输过程。',
      ),
    ],
  ),
  Experiment(
    id: 'exp_10',
    name: '实验九 遥控电梯',
    description: '学习如何组装一个由电机驱动、可通过遥控开关控制升降的电梯模型',
    steps: [
      ExperimentStep(
        index: 1,
        name: '准备传动棉线与齿轮',
        instruction: '1. 将棉线穿进齿轮。\n2. 剪一小段棉线绑在铁轴上。',
      ),
      ExperimentStep(
        index: 2,
        name: '安装铁轴与多孔轴架',
        instruction: '1. 将铁轴穿进多孔轴架。\n2. 用介子固定多孔轴架。\n3. 将多孔轴架穿进泡沫板。',
      ),
      ExperimentStep(
        index: 3,
        name: '整体器材组装',
        instruction: '1. 将各器材按照结构要求组装起来。',
      ),
      ExperimentStep(
        index: 4,
        name: '安装泡沫板与固定棉线',
        instruction: '1. 将泡沫板穿进红管立柱。\n2. 用软塞把棉线固定在泡沫板小孔。',
      ),
      ExperimentStep(
        index: 5,
        name: '连接电机与导线',
        instruction: '1. 将导线穿进电机快接小孔再从中间孔穿出后拧紧。\n2. 把蜗杆齿接上电机。\n3. 用电机快接扣住电机。',
      ),
      ExperimentStep(
        index: 6,
        name: '最终组装与测试',
        instruction: '1. 把电机插进泡沫板。\n2. 将遥控开关连接上电机。\n3. 装上自备电池，通过按键控制电梯升降。',
      ),
    ],
  ),
  Experiment(
    id: 'exp_11',
    name: '实验十 电动起重机',
    description: '学习如何组装一个由电机驱动、可控制升降的起重机模型',
    steps: [
      ExperimentStep(
        index: 1,
        name: '安装齿轮与多孔轴架',
        instruction:
            '1. 将 20mm 铁轴穿进齿轮。\n2. 把铁轴穿进多孔轴架。\n3. 将多孔轴架穿进拼装板。\n4. 用介子固定铁轴。\n5. 将长线绑住短轴。',
      ),
      ExperimentStep(
        index: 2,
        name: '安装立柱与泡沫板',
        instruction: '1. 将铁轴穿进多孔轴架。\n2. 用介子固定多孔轴架。\n3. 将多孔轴架穿进泡沫板。',
      ),
      ExperimentStep(
        index: 3,
        name: '固定多孔杆和短扁条',
        instruction: '1. 用螺丝固定多孔杆、短扁条。\n2. 用螺母拧紧螺丝。',
      ),
      ExperimentStep(index: 4, name: '安装上滑轮', instruction: '1. 将滑轮安装到指定位置。'),
      ExperimentStep(
        index: 5,
        name: '连接电池盒与电机并安装蜗杆齿',
        instruction: '1. 通过电机快接将按键电池盒连接上电机。\n2. 将蜗杆齿穿进电机轴。',
      ),
      ExperimentStep(
        index: 6,
        name: '安装吊钩与最终测试',
        instruction: '1. 将长线穿过滑轮后绑住大螺母。\n2. 装上自备电池。\n3. 通过开关即可控制起重机的升降。',
      ),
    ],
  ),
  Experiment(
    id: 'exp_12',
    name: '实验十一 迷你清洁机',
    description: '学习如何组装一个由电机驱动风扇产生吸力的小型手持清洁机模型',
    steps: [
      ExperimentStep(
        index: 1,
        name: '连接电机与安装',
        instruction: '1. 将电池盒导线连接上电机。\n2. 把电机穿进电机座。\n3. 撕掉电机座保护膜。',
      ),
      ExperimentStep(
        index: 2,
        name: '安装电机座与六叶扇',
        instruction: '1. 把电机座粘在清洁机泡沫板上。\n2. 把六叶扇插进电机轴。',
      ),
      ExperimentStep(
        index: 3,
        name: '拼装泡沫板为手枪模型',
        instruction: '1. 将清洁机泡沫板拼装出手枪模型。',
      ),
      ExperimentStep(
        index: 4,
        name: '固定电池盒',
        instruction: '1. 用双面胶将电池盒粘牢在合适位置。',
      ),
      ExperimentStep(
        index: 5,
        name: '安装吸尘组件并测试',
        instruction:
            '1. 安装带孔五安杯。\n2. 将管座粘在五安杯上。\n3. 安装吸管。\n4. 装上自备电池。\n5. 将废纸剪碎放在桌面上，用吸管对着碎纸吸收，测试清洁功能。',
      ),
    ],
  ),
  Experiment(
    id: 'exp_13',
    name: '实验十二 地动警示仪',
    description: '学习如何组装一个简易的地震预警模型，当装置摇晃时，闭合电路触发声光报警',
    steps: [
      ExperimentStep(
        index: 1,
        name: '安装支架与导线架',
        instruction: '1. 把长支架、短支架插进底板。\n2. 把上导线架穿进长支架。\n3. 把下导线架穿进短支架。',
      ),
      ExperimentStep(
        index: 2,
        name: '安装警示输出部件',
        instruction: '1. 把蜂鸣器、LED灯插进底板。',
      ),
      ExperimentStep(
        index: 3,
        name: '组装杜邦线与O端子',
        instruction: '1. 将两根短杜邦线和O端子组装好。',
      ),
      ExperimentStep(
        index: 4,
        name: '接感应与电路部件并测试',
        instruction:
            '1. 用铜线缠住长杜邦线一端插进上导线架。\n2. 把铜丝穿过上导线架、O端子。\n3. 绑住大珠。\n4. 把杜邦线另一端插进底板负极“-”。\n5. 装上自备电池，打开开关摇晃装置，测试地动警示功能。',
      ),
    ],
  ),
  Experiment(
    id: 'exp_14',
    name: '实验十三 滑动调速风扇',
    description: '学习如何通过滑动电热丝上的接触点来改变电路电阻，从而实现对风扇电机转速的调节',
    steps: [
      ExperimentStep(
        index: 1,
        name: '搭建结构框架并固定电热丝',
        instruction: '1. 将立柱和扁立柱插进底板。\n2. 用软塞将电热丝分别固定在扁立柱和立柱上。',
      ),
      ExperimentStep(
        index: 2,
        name: '连接电机与杜邦线',
        instruction: '1. 将杜邦线插进快接。\n2. 连接上电机。',
      ),
      ExperimentStep(
        index: 3,
        name: '安装电机与风叶扇',
        instruction: '1. 将电机穿进电机架。\n2. 将风叶扇插进电机轴。\n3. 将电机架插进底板。',
      ),
      ExperimentStep(
        index: 4,
        name: '连接电热丝与杜邦线',
        instruction: '1. 用快接将一根杜邦线和电热丝连接。\n2. 将另一根杜邦线插进底板正极孔。',
      ),
      ExperimentStep(
        index: 5,
        name: '完成电路连接并测试调速',
        instruction:
            '1. 将杜邦线一边插进底板负极。\n2. 将杜邦线另一端在电热丝上滑动。\n3. 装上自备电池。\n4. 通过滑动杜邦线在电热丝上的位置，观察风扇转速的变化，测试滑动调速功能。',
      ),
    ],
  ),
  Experiment(
    id: 'exp_15',
    name: '实验十四 电热分割机',
    description: '学习如何利用电热丝通电发热的特性，对泡沫材料进行热切割',
    steps: [
      ExperimentStep(index: 1, name: '安装立柱构建结构框架', instruction: '1. 将立柱插进底板。'),
      ExperimentStep(
        index: 2,
        name: '安装电热丝与杜邦线',
        instruction:
            '1. 先将一小段电热丝缠住杜邦线。\n2. 将电热丝穿过两根立柱顶孔。\n3. 把绑有电热丝的杜邦线穿进立柱。\n4. 用软塞塞住固定。',
      ),
      ExperimentStep(
        index: 3,
        name: '安装电池并测试分割功能',
        instruction: '1. 装上自备电池。\n2. 打开开关，等待电热丝发热。\n3. 用泡沫球进行分割实验。',
      ),
    ],
  ),
  Experiment(
    id: 'exp_16',
    name: '实验十五 油田磕头机',
    description: '学习如何组装一个模拟油田采油用“磕头机”（游梁式抽油机）的模型，理解其曲柄连杆传动原理',
    steps: [
      ExperimentStep(
        index: 1,
        name: '连接电机与导线',
        instruction: '1. 将导线插进电机快接，然后接在电机上。',
      ),
      ExperimentStep(
        index: 2,
        name: '组装电机支架与偏心传动部件',
        instruction: '1. 把电机支架扣进电机。\n2. 把偏心支架跟偏心轮组装起来。\n3. 用偏心轮最边缘孔穿进电机轴。',
      ),
      ExperimentStep(
        index: 3,
        name: '安装立柱与电机支架',
        instruction: '1. 把立柱插进底板。\n2. 把电机支架穿进立柱。\n3. 将电机导线插进底板对应的接口。',
      ),
      ExperimentStep(
        index: 4,
        name: '连接多孔杆与铁轴',
        instruction: '1. 用短铁轴穿过偏心支架跟多孔杆，然后用介子固定。\n2. 用长铁轴穿过立柱跟多孔杆，然后用介子固定。',
      ),
      ExperimentStep(
        index: 5,
        name: '连接注射器并测试工作',
        instruction:
            '1. 用棉线绑住多孔杆和注射器的推杆。\n2. 装上自备电池。\n3. 手拿着注射器，打开开关，测试磕头机工作状态。',
      ),
    ],
  ),
  Experiment(
    id: 'exp_17',
    name: '实验十六 水位监测器',
    description: '学习如何组装一个简易水位报警装置，当水位升高接触铜线时，电路导通触发声光报警',
    steps: [
      ExperimentStep(
        index: 1,
        name: '安装警示与控制电路部件',
        instruction: '1. 将蜂鸣器、LED灯、三极管、杜邦线插进底板。',
      ),
      ExperimentStep(
        index: 2,
        name: '安装水位感应与连接部件',
        instruction:
            '1. 将剩下的两根杜邦线一端插进底板，另一端用快接夹住。\n2. 快接的另一边夹住铜线。\n3. 用双面胶把快接粘在扁立柱上。\n4. 放置杯子，然后往杯子里倒水。',
      ),
    ],
  ),
];
