import '../models/iwate_quiz_question.dart';

const iwateQuizQuestions = <IwateQuizQuestion>[
  IwateQuizQuestion(
    id: 'capital',
    question: '岩手県の県庁所在地はどこ？',
    choices: ['盛岡市', '花巻市', '宮古市', '一関市'],
    correctIndex: 0,
  ),
  IwateQuizQuestion(
    id: 'iwate_name',
    question: '「岩手」という地名の由来に関係するとされる場所はどこ？',
    choices: ['三ツ石神社', '盛岡八幡宮', '中尊寺', '毛越寺'],
    correctIndex: 0,
  ),
  IwateQuizQuestion(
    id: 'chusonji',
    question: '中尊寺金色堂がある市町村はどこ？',
    choices: ['遠野市', '平泉町', '岩泉町', '雫石町'],
    correctIndex: 1,
  ),
  IwateQuizQuestion(
    id: 'ryusendo',
    question: '龍泉洞がある市町村はどこ？',
    choices: ['岩泉町', '岩手町', '西和賀町', '滝沢市'],
    correctIndex: 0,
  ),
  IwateQuizQuestion(
    id: 'tono_monogatari',
    question: '「遠野物語」と特に関係が深い地域はどこ？',
    choices: ['遠野市', '久慈市', '北上市', '八幡平市'],
    correctIndex: 0,
  ),
  IwateQuizQuestion(
    id: 'nanbu_tekki',
    question: '南部鉄器で特に知られる都市はどこ？',
    choices: ['盛岡市', '釜石市', '宮古市', '大船渡市'],
    correctIndex: 0,
  ),
  IwateQuizQuestion(
    id: 'yakehashiri',
    question: '焼走り熔岩流を形成した火山はどれ？',
    choices: ['岩手山', '姫神山', '早池峰山', '栗駒山'],
    correctIndex: 0,
  ),
  IwateQuizQuestion(
    id: 'takuboku',
    question: '石川啄木の故郷として知られる盛岡市内の地域はどこ？',
    choices: ['渋民', '玉山', '繋', '鉈屋町'],
    correctIndex: 0,
  ),
];
