// 简化的测评服务
import { relationalStore } from '@kit.ArkData';
import { Question, BloomLevel } from '../models/Question';
import { RelationalStoreManager } from './RelationalStoreManager';
import { LLMService } from './LLMService';
import { generateUUID } from '../utils/UUID';

export class AssessmentService {
  // 生成测评题
  static async generateQuestions(
    courseId: string,
    content: string,
    bloomLevel: BloomLevel,
    count: number = 5
  ): Promise<Question[]> {
    const questions = await LLMService.generateQuestions(content, bloomLevel, count);
    
    // 保存到数据库
    const store = RelationalStoreManager.getStore();
    const now = new Date().toISOString();

    for (const question of questions) {
      question.id = generateUUID();
      question.courseId = courseId;

      const valueBucket: relationalStore.ValuesBucket = {
        id: question.id,
        course_id: courseId,
        bloom_level: question.bloomLevel,
        question_text: question.questionText,
        options: JSON.stringify(question.options),
        correct_answer: question.correctAnswer,
        explanation: question.explanation,
        difficulty: question.difficulty,
        created_at: now
      };

      await store.insert('question', valueBucket);
    }

    return questions;
  }

  // 获取课程的测评题
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
        difficulty: resultSet.getLong(7)
      });
    }
    resultSet.close();

    return questions;
  }

  // 提交答案
  static async submitAnswer(
    userId: string,
    courseId: string,
    questionId: string,
    userAnswer: string
  ): Promise<boolean> {
    const store = RelationalStoreManager.getStore();

    // 获取题目
    const predicates = new relationalStore.RdbPredicates('question');
    predicates.equalTo('id', questionId);
    const resultSet = await store.query(predicates);
    
    let correctAnswer = '';
    if (resultSet.goToNextRow()) {
      correctAnswer = resultSet.getString(5);
    }
    resultSet.close();

    const isCorrect = userAnswer === correctAnswer;
    const now = new Date().toISOString();

    // 保存学习记录
    const recordId = generateUUID();
    const recordValueBucket: relationalStore.ValuesBucket = {
      id: recordId,
      user_id: userId,
      course_id: courseId,
      question_id: questionId,
      bloom_level: 1,
      user_answer: userAnswer,
      is_correct: isCorrect ? 1 : 0,
      attempt_count: 1,
      answered_at: now
    };

    await store.insert('learning_record', recordValueBucket);

    return isCorrect;
  }
}
