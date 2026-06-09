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
        radarData: CourseService.parseRadarData(resultSet.getString(10)),
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
        radarData: CourseService.parseRadarData(resultSet.getString(10)),
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

      // 添加AI资料到知识库
      const store2 = RelationalStoreManager.getStore();
      const now2 = new Date().toISOString();
      const docId2 = generateUUID();
      const docBucket: relationalStore.ValuesBucket = {
        id: docId2,
        course_id: courseId,
        source_type: 'ai',
        title: 'AI\u81EA\u52A8\u751F\u6210\u7684\u77E5\u8BC6\u56FE\u8C31\u8D44\u6599',
        content: '\u57FA\u4E8E\u63D0\u95EE\"' + question + '\"\u81EA\u52A8\u751F\u6210\u7684\u5B66\u79D1\u77E5\u8BC6\u56FE\u8C31\uFF0C\u5305\u542B' + graph.nodes.length + '\u4E2A\u6838\u5FC3\u6982\u5FF5\u548C' + graph.edges.length + '\u6761\u903B\u8F91\u5173\u7CFB\u3002',
        file_path: '',
        file_type: 'txt',
        keywords: '["\u77E5\u8BC6\u56FE\u8C31","AI\u8865\u5145","' + question.substring(0, 20) + '"]',
        uploaded_at: now2
      };
      await store2.insert('document', docBucket);

      // 2. 挖掘争议点
      const controversies = await LLMService.discoverControversies(question);
      await KnowledgeBaseService.updateControversies(courseId, controversies);
      const contraEvent: Record<string, string> = {};
      contraEvent['courseId'] = courseId;
      EventBus.emit(EVENTS.CONTROVERSY_READY, contraEvent);

      // 添加争议点资料
      const store3 = RelationalStoreManager.getStore();
      const now3 = new Date().toISOString();
      const docId3 = generateUUID();
      const contraDocBucket: relationalStore.ValuesBucket = {
        id: docId3,
        course_id: courseId,
        source_type: 'ai',
        title: 'AI\u81EA\u52A8\u6316\u6398\u7684\u5B66\u672F\u4E89\u8BAE\u70B9',
        content: '\u57FA\u4E8E\u63D0\u95EE\"' + question + '\"\u81EA\u52A8\u6316\u6398\u7684' + controversies.length + '\u4E2A\u4E89\u8BAE\u70B9\uFF0C\u5305\u542B\u6B63\u53CD\u65B9\u89C2\u70B9\u53CA\u8BC1\u636E\u3002',
        file_path: '',
        file_type: 'txt',
        keywords: '["\u5B66\u672F\u4E89\u8BAE","\u6B63\u53CD\u65B9\u89C2\u70B9","AI\u5206\u6790"]',
        uploaded_at: now3
      };
      await store3.insert('document', contraDocBucket);

      // 3. 生成测评题
      await AssessmentService.generateQuestions(courseId, question, 1, 5);
      const qEvent: Record<string, string> = {};
      qEvent['courseId'] = courseId;
      EventBus.emit(EVENTS.QUESTIONS_READY, qEvent);

      // 添加测评题资料
      const store4 = RelationalStoreManager.getStore();
      const now4 = new Date().toISOString();
      const totalQ = 5;
      const docId4 = generateUUID();
      const qDocBucket: relationalStore.ValuesBucket = {
        id: docId4,
        course_id: courseId,
        source_type: 'ai',
        title: 'AI\u81EA\u52A8\u751F\u6210\u7684\u8BC4\u6D4B\u9898',
        content: '\u57FA\u4E8E\u5E03\u9C81\u59C6\u8BA4\u77E5\u5C42\u7EA7\u81EA\u52A8\u751F\u6210\u4E86' + totalQ + '\u9053\u6D4B\u8BC4\u9898\uFF0C\u6DB5\u76D6\u8BB0\u5FC6\u3001\u7406\u89E3\u3001\u5E94\u7528\u7B49\u591A\u4E2A\u7EF4\u5EA6\u3002',
        file_path: '',
        file_type: 'txt',
        keywords: '["\u8BC4\u6D4B\u9898","\u5E03\u9C81\u59C6\u5206\u7C7B\u5B66","AI\u751F\u6210"]',
        uploaded_at: now4
      };
      await store4.insert('document', qDocBucket);

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

  // 解析雷达数据JSON
  static parseRadarData(jsonStr: string): RadarData {
    if (!jsonStr || jsonStr === '{}' || jsonStr.length === 0) {
      return getDefaultRadarData();
    }
    try {
      const parsed = JSON.parse(jsonStr) as Record<string, number>;
      return {
        remember: parsed['remember'] || 0,
        understand: parsed['understand'] || 0,
        apply: parsed['apply'] || 0,
        analyze: parsed['analyze'] || 0,
        evaluate: parsed['evaluate'] || 0,
        create: parsed['create'] || 0
      };
    } catch (e) {
      return getDefaultRadarData();
    }
  }


  // 更新单问进度
  static async updateProgress(courseId: string, qNum: number): Promise<void> {
    const predicates = new relationalStore.RdbPredicates('course');
    predicates.equalTo('id', courseId);
    const store = RelationalStoreManager.getStore();

    // 读取当前进度
    const qField = 'progress_q' + qNum;
    const updateBucket: relationalStore.ValuesBucket = {};
    updateBucket[qField] = 1;

    // 重新计算总进度
    const allPredicates = new relationalStore.RdbPredicates('course');
    allPredicates.equalTo('id', courseId);
    const rs = await store.query(allPredicates);
    let p1 = 0; let p2 = 0; let p3 = 0;
    if (rs.goToNextRow()) {
      p1 = rs.getLong(5);  // progress_q1
      p2 = rs.getLong(6);  // progress_q2
      p3 = rs.getLong(7);  // progress_q3
    }
    rs.close();

    if (qNum === 1) p1 = 1;
    else if (qNum === 2) p2 = 1;
    else if (qNum === 3) p3 = 1;

    const total = p1 + p2 + p3;
    const percent = Math.round((total / 3) * 100);
    updateBucket['progress_percent'] = percent;
    updateBucket['status'] = (percent === 100 ? 'completed' : 'active');
    updateBucket['updated_at'] = new Date().toISOString();

    await store.update(updateBucket, predicates);
  }
}