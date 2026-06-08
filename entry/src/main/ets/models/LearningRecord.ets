// 学习记录数据模型
import { BloomLevel } from './Question';

export interface LearningRecord {
  id: string;
  userId: string;
  courseId: string;
  questionId: string;
  bloomLevel: BloomLevel;
  userAnswer: string;
  isCorrect: boolean;
  attemptCount: number;
  answeredAt: string;
}

// 创建学习记录
export function createLearningRecord(
  id: string,
  userId: string,
  courseId: string,
  questionId: string,
  bloomLevel: BloomLevel
): LearningRecord {
  return {
    id: id,
    userId: userId,
    courseId: courseId,
    questionId: questionId,
    bloomLevel: bloomLevel,
    userAnswer: '',
    isCorrect: false,
    attemptCount: 1,
    answeredAt: new Date().toISOString()
  };
}
