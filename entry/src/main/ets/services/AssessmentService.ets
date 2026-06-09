// 测评服务（自由答题模式）
// 核心变更：选择题对比 → 自由输入 + LLM评判
import { relationalStore } from '@kit.ArkData';
import { Question, BloomLevel, AiEvaluation, LearningRecord } from '../models/Question';
import { RadarData } from '../models/Course';
import { RelationalStoreManager } from './RelationalStoreManager';
import { LLMService } from './LLMService';
import { generateUUID } from '../utils/UUID';

// 提交自由答案返回结果
export interface SubmitFreeAnswerResult {
  isCorrect: boolean;
  score: number;
  evaluation: AiEvaluation;
}

// 雷达图数据更新条目
export interface LevelStatItem {
  level: BloomLevel;
  averageScore: number;
}

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

      const valueBucket: relationalStore.ValuesBucket = {};
      valueBucket['id'] = question.id;
      valueBucket['course_id'] = courseId;
      valueBucket['bloom_level'] = question.bloomLevel;
      valueBucket['question_text'] = question.questionText;
      valueBucket['options'] = JSON.stringify(question.options);
      valueBucket['correct_answer'] = question.correctAnswer;
      valueBucket['explanation'] = question.explanation;
      valueBucket['difficulty'] = question.difficulty;
      valueBucket['question_type'] = 'open';
      valueBucket['created_at'] = now;

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
  ): Promise<SubmitFreeAnswerResult> {
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

    const result: SubmitFreeAnswerResult = { isCorrect, score: evaluation.score, evaluation };
    return result;
  }

  // 获取学习记录
  static async getLearningRecords(courseId: string): Promise<LearningRecord[]> {
    const store = RelationalStoreManager.getStore();
    const predicates = new relationalStore.RdbPredicates('learning_record');
    predicates.equalTo('course_id', courseId);
    const rs = await store.query(predicates);
    const records: LearningRecord[] = [];
    while (rs.goToNextRow()) {
      const evalStr = rs.getString(6); // ai_evaluation column
      let evaluation: AiEvaluation = { score: 0, comment: '', strengths: [], weaknesses: [], improvement: '' };
      try {
        if (evalStr && evalStr !== '') {
          const parsed = JSON.parse(evalStr) as Record<string, Object>;
          evaluation = {
            score: (parsed['score'] as number) || 0,
            comment: (parsed['comment'] as string) || '',
            strengths: (parsed['strengths'] as string[]) || [],
            weaknesses: (parsed['weaknesses'] as string[]) || [],
            improvement: (parsed['improvement'] as string) || ''
          };
        }
      } catch (e) {
        // parse failed, use default
      }
      records.push({
        id: rs.getString(0),
        userId: rs.getString(1),
        courseId: rs.getString(2),
        questionId: rs.getString(3),
        bloomLevel: rs.getLong(4) as BloomLevel,
        userAnswerText: rs.getString(6) || '',
        aiEvaluation: evaluation,
        isCorrect: rs.getLong(7) === 1,
        score: rs.getLong(8),
        answeredAt: rs.getString(10)
      });
    }
    rs.close();
    return records;
  }

  // 更新雷达数据（基于测评结果）
  static async updateRadarData(
    courseId: string,
    levelStats: LevelStatItem[]
  ): Promise<void> {
    const store = RelationalStoreManager.getStore();
    const radarData: Record<string, number> = {};
    radarData['remember'] = 0;
    radarData['understand'] = 0;
    radarData['apply'] = 0;
    radarData['analyze'] = 0;
    radarData['evaluate'] = 0;
    radarData['create'] = 0;

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
