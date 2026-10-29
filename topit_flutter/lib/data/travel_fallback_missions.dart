import '../models/mission.dart';

const travelFallbackMissions = <Mission>[
  Mission(
    title: '旅先の名前を探そう',
    hint: '地名や地域名が書かれたものを見つけて撮ろう',
    shootingTip: '文字だけでなく周囲の景色も一緒に入れよう',
    difficulty: 1,
    estimatedMinutes: 5,
  ),
  Mission(
    title: '足元の発見',
    hint: '模様や形が気になった地面、石、マンホールを撮ろう',
    shootingTip: '安全な場所で立ち止まり、真上から撮ろう',
    difficulty: 1,
    estimatedMinutes: 5,
  ),
  Mission(
    title: '旅先の色',
    hint: '今日の旅を表していると思う色を一つ見つけよう',
    shootingTip: '同じ色が複数入る構図を探そう',
    difficulty: 1,
    estimatedMinutes: 5,
  ),
  Mission(
    title: '移動を残そう',
    hint: '景色や影など、移動していることが伝わるものを撮ろう',
    shootingTip: '安全な場所で立ち止まって撮影しよう',
    difficulty: 1,
    estimatedMinutes: 5,
  ),
  Mission(
    title: '旅先の質感',
    hint: '触った感覚を想像できるものを撮ろう',
    shootingTip: '表面に近づき、模様や凹凸が分かるように撮ろう',
    difficulty: 2,
    estimatedMinutes: 10,
  ),
];
