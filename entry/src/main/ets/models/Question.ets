// 测评题数据模型
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
  one: '记忆',
  two: '理解',
  three: '应用',
  four: '分析',
  five: '评价',
  six: '创造'
};

export interface Question {
  id: string;
  courseId: string;
  bloomLevel: BloomLevel;
  questionText: string;
  options: string[];        // 选项数组
  correctAnswer: string;    // 正确答案
  explanation: string;      // 解析
  difficulty: number;       // 1~5 难度等级
}

// 创建默认问题
export function createDefaultQuestion(id: string, courseId: string): Question {
  return {
    id: id,
    courseId: courseId,
    bloomLevel: 1,
    questionText: '',
    options: [],
    correctAnswer: '',
    explanation: '',
    difficulty: 1
  };
}
