# AssessmentService - 测评管理服务

## 核心职责
管理测评题目和学习记录。

## 接口定义

```typescript
import { RelationalStoreManager } from './RelationalStoreManager';

export class AssessmentService {

  // 获取测评题目
  static async getQuestions(
    courseId: string,
    bloomLevel?: number
  ): Promise<Question[]> {
    let rows;
    if (bloomLevel) {
      const predicates = new RdbPredicates('question');
      predicates.equalTo('course_id', courseId);
      predicates.equalTo('bloom_level', bloomLevel);
      rows = await RelationalStoreManager.query(predicates);
    } else {
      rows = await RelationalStoreManager.query('question', 'course_id', courseId);
    }
    return rows.map(r => ({
      id: r.id as string,
      courseId: r.course_id as string,
      bloomLevel: r.bloom_level as number,
      questionText: r.question_text as string,
      options: JSON.parse(r.options as string || '[]'),
      correctAnswer: r.correct_answer as string,
      explanation: r.explanation as string,
      difficulty: r.difficulty as number,
    } as Question));
  }

  // 提交答案
  static async submitAnswer(
    courseId: string,
    questionId: string,
    userAnswer: string,
    isCorrect: boolean
  ): Promise<void> {
    // 获取题目信息（含bloom_level）
    const qRows = await RelationalStoreManager.query('question', 'id', questionId);
    const bloomLevel = qRows.length > 0 ? (qRows[0].bloom_level as number) : 0;

    await RelationalStoreManager.insert('learning_record', {
      id: crypto.randomUUID(),
      user_id: AppStorage.get<string>('userId') || 'default_user',
      course_id: courseId,
      question_id: questionId,
      bloom_level: bloomLevel,
      user_answer: userAnswer,
      is_correct: isCorrect ? 1 : 0,
      attempt_count: 1,
      answered_at: new Date().toISOString()
    });
  }

  // 获取学习记录
  static async getLearningRecords(courseId: string): Promise<LearningRecord[]> {
    const rows = await RelationalStoreManager.query('learning_record', 'course_id', courseId);
    return rows.map(r => ({
      id: r.id as string,
      userId: r.user_id as string,
      courseId: r.course_id as string,
      questionId: r.question_id as string,
      bloomLevel: r.bloom_level as number,
      userAnswer: r.user_answer as string,
      isCorrect: (r.is_correct as number) === 1,
      attemptCount: r.attempt_count as number,
      answeredAt: r.answered_at as string,
    } as LearningRecord));
  }

  // 生成测评报告
  static async generateReport(courseId: string): Promise<AssessmentReport> {
    const records = await this.getLearningRecords(courseId);
    const questions = await this.getQuestions(courseId);

    const totalCount = records.length;
    const correctCount = records.filter(r => r.isCorrect).length;
    const wrongRecords = records.filter(r => !r.isCorrect);

    // 各维度统计
    const levelStats: Record<number, { total: number; correct: number }> = {};
    for (let l = 1; l <= 6; l++) {
      const levelRecords = records.filter(r => r.bloomLevel === l);
      levelStats[l] = {
        total: levelRecords.length,
        correct: levelRecords.filter(r => r.isCorrect).length,
      };
    }

    return {
      courseId,
      totalQuestions: questions.length,
      answeredCount: totalCount,
      correctCount,
      accuracy: totalCount > 0 ? Math.round((correctCount / totalCount) * 100) : 0,
      levelStats,
      wrongQuestions: wrongRecords.map(r => ({
        questionId: r.questionId,
        userAnswer: r.userAnswer,
      })),
    } as AssessmentReport;
  }
}

export interface AssessmentReport {
  courseId: string;
  totalQuestions: number;
  answeredCount: number;
  correctCount: number;
  accuracy: number;
  levelStats: Record<number, { total: number; correct: number }>;
  wrongQuestions: Array<{ questionId: string; userAnswer: string }>;
}
```


## EventBus 集成

```typescript
// 提交答案后更新进度
EventBus.emit('progress_updated', {
  courseId,
  progressPercent: newPercent,
  radarData: newRadar
});
```

## 端到端数据流

```
用户选择答案 → submitAnswer()
  ├─ 对比正确答案
  ├─ INSERT learning_record
  ├─ 返回 { isCorrect, explanation }
  └→ EventBus.emit('progress_updated')

CourseDetailPage 监听 progress_updated
  → 更新底部 ProgressBar
  → 更新 Q3_AssessmentPage 答题卡

HomePage 监听 progress_updated（如可见）
  → 更新课程卡片进度
```
