# CourseService - 课程管理服务

## 核心职责
管理课程的生命周期：创建、查询、更新、删除。

## 接口定义

```typescript
import { RelationalStoreManager } from './RelationalStoreManager';
import { LLMService } from './LLMService';

export class CourseService {

  // 创建新课程
  static async createCourse(question: string): Promise<string> {
    // 1. 生成UUID
    const courseId = crypto.randomUUID();

    // 2. LLM识别领域
    const domain: string = await LLMService.identifyDomain(question);

    // 3. 插入数据库
    const now = new Date().toISOString();
    await RelationalStoreManager.insert('course', {
      id: courseId,
      user_id: AppStorage.get<string>('userId') || 'default_user',
      title: question.length > 30 ? question.substring(0, 30) + '...' : question,
      domain: domain,
      question: question,
      status: 'created',
      progress_q1: 0,
      progress_q2: 0,
      progress_q3: 0,
      progress_percent: 0,
      radar_data: JSON.stringify({
        remember: 0, understand: 0, apply: 0,
        analyze: 0, evaluate: 0, create: 0
      }),
      created_at: now,
      updated_at: now,
      last_accessed_at: now
    });

    // 4. 创建知识库记录
    await RelationalStoreManager.insert('knowledgebase', {
      id: crypto.randomUUID(),
      course_id: courseId,
      knowledge_graph: '[]',
      controversies: '[]',
      created_at: now,
      updated_at: now
    });

    // 5. 后台异步生成内容
    this.generateContent(courseId, question);

    return courseId;
  }

  // 后台异步：生成知识图谱等
  private static async generateContent(courseId: string, question: string): Promise<void> {
    try {
      // 获取文档（如有）
      const docs = await RelationalStoreManager.query('document', 'course_id', courseId);
      const docContents: string[] = docs.map(d => (d.content as string) || '');

      // 生成知识图谱
      const graph = await LLMService.generateKnowledgeGraph(question, docContents);
      await RelationalStoreManager.update('knowledgebase',
        { knowledge_graph: JSON.stringify(graph) },
        'course_id', courseId
      );

      // 生成争议点
      const controversies = await LLMService.discoverControversies(question, docContents);
      await RelationalStoreManager.update('knowledgebase',
        { controversies: JSON.stringify(controversies) },
        'course_id', courseId
      );

      // 生成测评题
      const questions = await LLMService.generateQuestions(question, 'all', []);
      for (const q of questions) {
        await RelationalStoreManager.insert('question', {
          id: crypto.randomUUID(),
          course_id: courseId,
          bloom_level: q.bloomLevel,
          question_text: q.questionText,
          options: JSON.stringify(q.options),
          correct_answer: q.correctAnswer,
          explanation: q.explanation,
          difficulty: q.difficulty,
          created_at: new Date().toISOString()
        });
      }
    } catch (error) {
      console.error('Background content generation failed:', error);
    }
  }

  // 获取课程列表
  static async getCourseList(userId: string): Promise<Course[]> {
    const rows = await RelationalStoreManager.query('course', 'user_id', userId);
    return rows
      .filter(r => r.status !== 'archived')
      .sort((a, b) => (b.last_accessed_at as string) > (a.last_accessed_at as string) ? 1 : -1)
      .map(r => this.rowToCourse(r));
  }

  // 获取归档课程
  static async getArchiveList(userId: string): Promise<Course[]> {
    const predicates = new RdbPredicates('course');
    predicates.equalTo('user_id', userId);
    predicates.equalTo('status', 'archived');
    predicates.orderByDesc('updated_at');
    const resultSet = await RelationalStoreManager.query(predicates);
    return resultSet.map(r => this.rowToCourse(r));
  }

  // 获取单个课程
  static async getCourseById(courseId: string): Promise<Course | null> {
    const rows = await RelationalStoreManager.query('course', 'id', courseId);
    return rows.length > 0 ? this.rowToCourse(rows[0]) : null;
  }

  // 更新进度
  static async updateProgress(courseId: string, qNum: number): Promise<void> {
    const qField = `progress_q${qNum}` as string;
    await RelationalStoreManager.update('course',
      { [qField]: 1 },
      'id', courseId
    );
    // 重新计算总进度
    const course = await this.getCourseById(courseId);
    if (course) {
      const total = [course.progressQ1, course.progressQ2, course.progressQ3]
        .filter(v => v === 1).length;
      const percent = Math.round((total / 3) * 100);
      await RelationalStoreManager.update('course',
        { progress_percent: percent, status: percent === 100 ? 'completed' : 'active' },
        'id', courseId
      );
    }
  }

  // 删除课程
  static async deleteCourse(courseId: string): Promise<void> {
    await RelationalStoreManager.delete('course', 'id', courseId);
    // 级联删除相关数据
    await RelationalStoreManager.delete('knowledgebase', 'course_id', courseId);
    await RelationalStoreManager.delete('document', 'course_id', courseId);
    await RelationalStoreManager.delete('question', 'course_id', courseId);
    await RelationalStoreManager.delete('learning_record', 'course_id', courseId);
  }

  // 归档/恢复
  static async archiveCourse(courseId: string): Promise<void> {
    await RelationalStoreManager.update('course',
      { status: 'archived' }, 'id', courseId);
  }

  static async restoreCourse(courseId: string): Promise<void> {
    await RelationalStoreManager.update('course',
      { status: 'created' }, 'id', courseId);
  }

  // 行转Course对象
  private static rowToCourse(row: Record<string, string | number | boolean>): Course {
    return {
      id: row.id as string,
      userId: row.user_id as string,
      title: row.title as string,
      domain: row.domain as string,
      question: row.question as string,
      status: row.status as Course['status'],
      progressQ1: row.progress_q1 as number,
      progressQ2: row.progress_q2 as number,
      progressQ3: row.progress_q3 as number,
      progressPercent: row.progress_percent as number,
      radarData: JSON.parse(row.radar_data as string || '{}'),
      createdAt: row.created_at as string,
      updatedAt: row.updated_at as string,
      lastAccessedAt: row.last_accessed_at as string,
    } as Course;
  }
}
```


## EventBus 集成

CourseService 在异步操作完成后触发事件：

```typescript
// 创建课程完成
EventBus.emit('course_created', {
  courseId: newCourseId,
  title: title
});

// 后台LLM生成完成
// (在 generateContent 内部)
EventBus.emit('graph_ready', { courseId, graphNodes });
EventBus.emit('controversy_ready', { courseId, controversies });
EventBus.emit('questions_ready', { courseId, questionCount });

// 进度更新
EventBus.emit('progress_updated', {
  courseId,
  progressPercent: newPercent,
  radarData: newRadar
});
```

## 端到端数据流

```
HomePage.createCourse(question)
  → CourseService.createCourse()
    ├─ [同步] LLMService.identifyDomain() → domain
    ├─ [同步] INSERT course (同步返回 courseId)
    ├─ [同步] INSERT knowledgebase
    ├─ [同步] 返回 courseId (UI此时跳转详情页)
    │
    └─ [异步] CourseService.generateContent()
         ├─ LLMService.generateKnowledgeGraph()
         │   └→ EventBus.emit('graph_ready')
         ├─ LLMService.discoverControversies()
         │   └→ EventBus.emit('controversy_ready')
         └─ LLMService.generateQuestions()
             └→ EventBus.emit('questions_ready')
```
