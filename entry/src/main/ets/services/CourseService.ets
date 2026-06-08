// 简化的课程服务 - 避免ArkTS严格模式错误
import { relationalStore } from '@kit.ArkData';
import { Course, RadarData, getDefaultRadarData, CourseStatus } from '../models/Course';
import { RelationalStoreManager } from './RelationalStoreManager';
import { KnowledgeBaseService } from './KnowledgeBaseService';
import { AssessmentService } from './AssessmentService';
import { LLMService } from './LLMService';
import { EventBus, EVENTS } from '../utils/EventBus';
import { generateUUID } from '../utils/UUID';

export class CourseService {
  // 创建课程
  static async createCourse(userId: string, question: string, title: string, domain: string): Promise<string> {
    const store = RelationalStoreManager.getStore();
    const courseId = generateUUID();
    const now = new Date().toISOString();

    const valueBucket: relationalStore.ValuesBucket = {
      id: courseId,
      user_id: userId,
      title: title,
      domain: domain,
      question: question,
      status: 'created',
      progress_q1: 0,
      progress_q2: 0,
      progress_q3: 0,
      progress_percent: 0,
      radar_data: '{}',
      created_at: now,
      updated_at: now,
      last_accessed_at: now
    };

    await store.insert('course', valueBucket);

    // 自动创建知识库记录
    await KnowledgeBaseService.createKnowledgeBase(courseId);

    // 后台异步生成内容（不阻塞用户跳转）
    CourseService.generateCourseContent(courseId, question);

    return courseId;
  }

  // 获取用户的所有课程
  static async getCoursesByUser(userId: string): Promise<Course[]> {
    const store = RelationalStoreManager.getStore();
    const predicates = new relationalStore.RdbPredicates('course');
    predicates.equalTo('user_id', userId);
    predicates.orderByDesc('last_accessed_at');

    const resultSet = await store.query(predicates);
    const courses: Course[] = [];

    while (resultSet.goToNextRow()) {
      const course: Course = {
        id: resultSet.getString(0),
        userId: resultSet.getString(1),
        title: resultSet.getString(2),
        domain: resultSet.getString(3),
        question: resultSet.getString(4),
        status: resultSet.getString(5) as CourseStatus,
        progressQ1: resultSet.getLong(6),
        progressQ2: resultSet.getLong(7),
        progressQ3: resultSet.getLong(8),
        progressPercent: resultSet.getLong(9),
        radarData: getDefaultRadarData(),
        createdAt: resultSet.getString(11),
        updatedAt: resultSet.getString(12),
        lastAccessedAt: resultSet.getString(13)
      };
      courses.push(course);
    }
    resultSet.close();

    return courses;
  }

  // 获取单个课程
  static async getCourseById(courseId: string): Promise<Course | null> {
    const store = RelationalStoreManager.getStore();
    const predicates = new relationalStore.RdbPredicates('course');
    predicates.equalTo('id', courseId);

    const resultSet = await store.query(predicates);
    let course: Course | null = null;

    if (resultSet.goToNextRow()) {
      course = {
        id: resultSet.getString(0),
        userId: resultSet.getString(1),
        title: resultSet.getString(2),
        domain: resultSet.getString(3),
        question: resultSet.getString(4),
        status: resultSet.getString(5) as CourseStatus,
        progressQ1: resultSet.getLong(6),
        progressQ2: resultSet.getLong(7),
        progressQ3: resultSet.getLong(8),
        progressPercent: resultSet.getLong(9),
        radarData: getDefaultRadarData(),
        createdAt: resultSet.getString(11),
        updatedAt: resultSet.getString(12),
        lastAccessedAt: resultSet.getString(13)
      };
    }
    resultSet.close();

    return course;
  }

  // 更新课程状态
  static async updateCourseStatus(courseId: string, status: CourseStatus): Promise<void> {
    const store = RelationalStoreManager.getStore();
    const now = new Date().toISOString();

    const valueBucket: relationalStore.ValuesBucket = {
      status: status,
      updated_at: now
    };

    const predicates = new relationalStore.RdbPredicates('course');
    predicates.equalTo('id', courseId);

    await store.update(valueBucket, predicates);
  }

  // 删除课程
  static async deleteCourse(courseId: string): Promise<void> {
    const store = RelationalStoreManager.getStore();
    const predicates = new relationalStore.RdbPredicates('course');
    predicates.equalTo('id', courseId);

    await store.delete(predicates);
  }

  // 后台异步生成课程内容（知识图谱+争议点+测评题）
  static async generateCourseContent(courseId: string, question: string): Promise<void> {
    try {
      // 1. 生成知识图谱
      const graph = await LLMService.generateKnowledgeGraph(question);
      await KnowledgeBaseService.updateKnowledgeGraph(courseId, graph);
      const graphEvent: Record<string, string> = {};
      graphEvent['courseId'] = courseId;
      EventBus.emit(EVENTS.GRAPH_READY, graphEvent);

      // 2. 挖掘争议点
      const controversies = await LLMService.discoverControversies(question);
      await KnowledgeBaseService.updateControversies(courseId, controversies);
      const contraEvent: Record<string, string> = {};
      contraEvent['courseId'] = courseId;
      EventBus.emit(EVENTS.CONTROVERSY_READY, contraEvent);

      // 3. 生成测评题
      await AssessmentService.generateQuestions(courseId, question, 1, 5);
      const qEvent: Record<string, string> = {};
      qEvent['courseId'] = courseId;
      EventBus.emit(EVENTS.QUESTIONS_READY, qEvent);

      // 4. 更新课程状态为active
      const store = RelationalStoreManager.getStore();
      const predicates = new relationalStore.RdbPredicates('course');
      predicates.equalTo('id', courseId);
      const updateValues: relationalStore.ValuesBucket = {
        status: 'active',
        updated_at: new Date().toISOString()
      };
      await store.update(updateValues, predicates);
    } catch (error) {
      console.error('Content generation failed:', JSON.stringify(error));
    }
  }
}
