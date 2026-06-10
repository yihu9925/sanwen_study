// 测评题数据模型（自由答题模式）
export type BloomLevel = 1 | 2 | 3 | 4 | 5 | 6;  // 布鲁姆认知层级

export interface BloomLevelNames {
  one: string;
  two: string;
  three: string;
  four: string;
  five: string;
  six: string;
}

export const BLOOM_LEVELS: BloomLevelNames = {
  one: '\u8bb0\u5fc6',
  two: '\u7406\u89e3',
  three: '\u5e94\u7528',
  four: '\u5206\u6790',
  five: '\u8bc4\u4ef7',
  six: '\u521b\u9020'
};

export type QuestionType = 'choice' | 'open';  // 选择题 / 开放题

export interface Question {
  id: string;
  courseId: string;
  bloomLevel: BloomLevel;
  labels: string[];            // 标签列表（可单可多，如["记忆"]或["理解","应用"]）
  questionText: string;
  options: string[];           // 选项数组（选择题4个选项，开放题可为空）
  correctAnswer: string;       // 参考答案/正确答案
  explanation: string;         // 知识点提示
  difficulty: number;          // 1~5 难度等级
  questionType: QuestionType;  // 题目类型，默认 'open'
}

// LLM评判结果
export interface AiEvaluation {
  score: number;           // 0-100
  comment: string;         // 总体评语
  strengths: string[];     // 优点列表
  weaknesses: string[];    // 不足列表
  improvement: string;     // 改进建议
}

// 学习记录（自由答题模式）
export interface LearningRecord {
  id: string;
  userId: string;
  courseId: string;
  questionId: string;
  bloomLevel: BloomLevel;
  userAnswerText: string;      // 用户自由输入的答案（核心）
  aiEvaluation: AiEvaluation;  // LLM评判结果
  isCorrect: boolean;          // score >= 60
  score: number;               // 0-100
  answeredAt: string;
}

// 评估报告
export interface AssessmentReport {
  courseId: string;
  totalQuestions: number;
  answeredQuestions: number;
  averageScore: number;
  levelStats: LevelStat[];
  answerDetails: AnswerDetail[];
  generatedAt: string;
}

export interface LevelStat {
  level: BloomLevel;
  levelName: string;
  totalQuestions: number;
  answeredQuestions: number;
  averageScore: number;
  weaknesses: string[];
}

export interface AnswerDetail {
  question: Question;
  userAnswerText: string;
  evaluation: AiEvaluation;
  isCorrect: boolean;
  score: number;
}

// 获取布鲁姆层级中文名
export function getBloomLevelName(level: BloomLevel): string {
  const names: BloomLevelNames = BLOOM_LEVELS;
  switch (level) {
    case 1: return names.one;
    case 2: return names.two;
    case 3: return names.three;
    case 4: return names.four;
    case 5: return names.five;
    case 6: return names.six;
    default: return '\u672a\u77e5';
  }
}
