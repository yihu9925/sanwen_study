// 简化的课程服务 - 避免ArkTS严格模式错误
import { relationalStore } from '@kit.ArkData';
import { Course, RadarData, getDefaultRadarData, CourseStatus } from '../models/Course';
import { RelationalStoreManager } from './RelationalStoreManager';
import { KnowledgeBaseService } from './KnowledgeBaseService';
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

    // 刷新统计数据到AppStorage
    await CourseService.refreshStatsInStorage(userId);

    return courseId;
  }

  // 将课程统计数据写入AppStorage（供PersonalCenter @StorageLink读取）
  static async refreshStatsInStorage(userId: string): Promise<void> {
    try {
      const courses: Course[] = await CourseService.getCoursesByUser(userId);
      const nonArchived: Course[] = courses.filter(c => c.status !== 'archived');
      const total: number = nonArchived.length;
      const completed: number = nonArchived.filter(c => c.progressPercent === 100).length;
      const archived: number = courses.filter(c => c.status === 'archived').length;
      AppStorage.set<number>('statTotal', total);
      AppStorage.set<number>('statCompleted', completed);
      AppStorage.set<number>('statArchived', archived);
    } catch (e) {
      console.error('refreshStatsInStorage failed: ' + (e as Error).message);
    }
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

    // 更新统计
    const c = await CourseService.getCourseById(courseId);
    if (c) {
      await CourseService.refreshStatsInStorage(c.userId);
    }
  }

  // 删除课程
  static async deleteCourse(courseId: string): Promise<void> {
    const store = RelationalStoreManager.getStore();
    const c = await CourseService.getCourseById(courseId);
    const predicates = new relationalStore.RdbPredicates('course');
    predicates.equalTo('id', courseId);

    await store.delete(predicates);

    // 更新统计
    if (c) {
      await CourseService.refreshStatsInStorage(c.userId);
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
      p1 = rs.getLong(6);  // progress_q1
      p2 = rs.getLong(7);  // progress_q2
      p3 = rs.getLong(8);  // progress_q3
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

    // 刷新 AppStorage 统计数据，确保 PersonalCenter 即时更新
    const course = await CourseService.getCourseById(courseId);
    if (course) {
      await CourseService.refreshStatsInStorage(course.userId);
    }
  }

  // 重置学习进度为0（重新生成时调用）
  static async resetProgress(courseId: string): Promise<void> {
    const store = RelationalStoreManager.getStore();
    const predicates = new relationalStore.RdbPredicates('course');
    predicates.equalTo('id', courseId);
    const valueBucket: relationalStore.ValuesBucket = {
      'progress_q1': 0,
      'progress_q2': 0,
      'progress_q3': 0,
      'progress_percent': 0,
      'status': 'active',
      'updated_at': new Date().toISOString()
    };
    await store.update(valueBucket, predicates);
    const course = await CourseService.getCourseById(courseId);
    if (course) {
      await CourseService.refreshStatsInStorage(course.userId);
    }
  }

  // 重置雷达数据为初始空状态
  static async resetRadarData(courseId: string): Promise<void> {
    const store = RelationalStoreManager.getStore();
    const predicates = new relationalStore.RdbPredicates('course');
    predicates.equalTo('id', courseId);
    const valueBucket: relationalStore.ValuesBucket = {
      'radar_data': '{}',
      'updated_at': new Date().toISOString()
    };
    await store.update(valueBucket, predicates);
  }
}