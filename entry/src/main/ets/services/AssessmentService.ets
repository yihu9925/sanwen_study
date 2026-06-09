// 测评服务（自由答题模式）
// 核心变更：选择题对比 → 自由输入 + LLM评判
import { relationalStore } from '@kit.ArkData';
import { Question, BloomLevel, AiEvaluation } from '../models/Question';
import { RelationalStoreManager } from './RelationalStoreManager';
import { LLMService } from './LLMService';
import { generateUUID } from '../utils/UUID';

export class AssessmentService {
  // 生成测评题（开放题模式）
  static async generateQuestions(
    courseId: string,
    content: string,
    bloomLevel: BloomLevel,
    count: number
  ): Promise<Question[]> {
    const questions = await LLMService.generateQuestions(content, bloomLevel, count);

    // 保存到数据库
    const store = RelationalStoreManager.getStore();
    const now = new Date().toISOString();

    for (const question of questions) {
      question.id = generateUUID();
      question.courseId = courseId;
      question.questionType = 'open';

      const valueBucket: relationalStore.ValuesBucket = {
        'id': question.id,
        'course_id': courseId,
        'bloom_level': question.bloomLevel,
        'question_text': question.questionText,
        'options': JSON.stringify(question.options),
        'correct_answer': question.correctAnswer,
        'explanation': question.explanation,
        'difficulty': question.difficulty,
        'question_type': 'open',
        'created_at': now
      };

      await store.insert('question', valueBucket);
    }

    return questions;
  }

  // 获取测评题
  static async getQuestions(courseId: string): Promise<Question[]> {
    const store = RelationalStoreManager.getStore();
    const predicates = new relationalStore.RdbPredicates('question');
    predicates.equalTo('course_id', courseId);

    const resultSet = await store.query(predicates);
    const questions: Question[] = [];

    while (resultSet.goToNextRow()) {
      questions.push({
        id: resultSet.getString(0),
        courseId: resultSet.getString(1),
        bloomLevel: resultSet.getLong(2) as BloomLevel,
        questionText: resultSet.getString(3),
        options: JSON.parse(resultSet.getString(4)),
        correctAnswer: resultSet.getString(5),
        explanation: resultSet.getString(6),
        difficulty: resultSet.getLong(7),
        questionType: 'open'
      });
    }
    resultSet.close();

    return questions;
  }

  // 提交自由答案 — 核心方法（自由答题模式）
  static async submitFreeAnswer(
    userId: string,
    courseId: string,
    question: Question,
    userAnswerText: string
  ): Promise<{ isCorrect: boolean; score: number; evaluation: AiEvaluation }> {
    // 1. 获取LLM评判
    const evaluation = await LLMService.evaluateUserAnswer(question, userAnswerText);
    const isCorrect = evaluation.score >= 60;
    const now = new Date().toISOString();

    // 2. 保存学习记录（含对话原始记录）
    const store = RelationalStoreManager.getStore();
    const recordId = generateUUID();
    const recordValueBucket: relationalStore.ValuesBucket = {
      'id': recordId,
      'user_id': userId,
      'course_id': courseId,
      'question_id': question.id,
      'bloom_level': question.bloomLevel,
      'user_answer': '',  // 旧字段留空
      'user_answer_text': userAnswerText,   // 核心：用户回答原文
      'ai_evaluation': JSON.stringify(evaluation), // LLM评判JSON
      'is_correct': isCorrect ? 1 : 0,
      'score': evaluation.score,
      'attempt_count': 1,
      'answered_at': now
    };
    await store.insert('learning_record', recordValueBucket);

    return { isCorrect, score: evaluation.score, evaluation };
  }

  // 更新雷达数据（基于测评结果）
  static async updateRadarData(
    courseId: string,
    levelStats: Array<{ level: BloomLevel; averageScore: number }>
  ): Promise<void> {
    const store = RelationalStoreManager.getStore();
    const radarData: Record<string, number> = {
      remember: 0, understand: 0, apply: 0,
      analyze: 0, evaluate: 0, create: 0
    };

    for (const stat of levelStats) {
      const key = AssessmentService.getRadarKey(stat.level);
      radarData[key] = stat.averageScore;
    }

    const predicates = new relationalStore.RdbPredicates('course');
    predicates.equalTo('id', courseId);
    const updateVal: relationalStore.ValuesBucket = {
      'radar_data': JSON.stringify(radarData),
      'updated_at': new Date().toISOString()
    };
    await store.update(updateVal, predicates);
  }

  // 布鲁姆层级映射到雷达图字段名
  private static getRadarKey(level: BloomLevel): string {
    const keys: Record<number, string> = {
      1: 'remember', 2: 'understand', 3: 'apply',
      4: 'analyze', 5: 'evaluate', 6: 'create'
    };
    return keys[level] || 'remember';
  }
}
