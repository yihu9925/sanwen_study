# AssessmentService - 测评管理服务（自由答题模式）

> ⚠ **核心变更**：需求明确要求"自己回答自己产品的学习提问，并提交评价报告，不要拿AI生成答案喂AI"。
> 因此测评系统由选择题比对改为**自由答题+LLM评判**模式。

## 核心职责
管理测评题目、用户答题、LLM评判结果、评估报告生成。

## 数据模型

```typescript
import { Question, BloomLevel } from '../models/Question';
import { RelationalStoreManager } from './RelationalStoreManager';
import { LLMService } from './LLMService';

// 用户答题记录（自由答题模式使用）
export interface AnswerRecord {
  id?: string;
  userId: string;
  courseId: string;
  questionId: string;
  bloomLevel: BloomLevel;
  userAnswerText: string;      // 用户自由输入的答案文本（核心字段）
  aiEvaluation: AiEvaluation;  // LLM评判结果
  isCorrect: boolean;          // score >= 60 为 true
  score: number;               // 0-100
  answeredAt: string;
}

// LLM评判结果
export interface AiEvaluation {
  score: number;           // 0-100
  comment: string;         // 评语
  strengths: string[];     // 优点
  weaknesses: string[];    // 不足
  improvement: string;     // 改进建议
}

// 评估报告
export interface AssessmentReport {
  courseId: string;
  totalQuestions: number;
  answeredQuestions: number;
  averageScore: number;
  levelStats: LevelStat[];       // 按布鲁姆维度统计
  radarData: RadarData;          // 雷达图数据
  answerDetails: AnswerDetail[]; // 每道题的详情（含对话记录）
  generatedAt: string;
}

export interface LevelStat {
  level: BloomLevel;
  levelName: string;        // '记忆' | '理解' | '应用' | '分析' | '评价' | '创造'
  totalQuestions: number;
  answeredQuestions: number;
  averageScore: number;
  weaknesses: string[];     // 该维度常见不足
}

export interface AnswerDetail {
  question: Question;
  userAnswerText: string;   // 用户回答原文（对话原始记录）
  evaluation: AiEvaluation; // LLM评判
  isCorrect: boolean;
  score: number;
}
```

## 接口定义

```typescript
export class AssessmentService {

  // 1. 获取测评题目
  static async getQuestions(
    courseId: string,
    bloomLevel?: BloomLevel
  ): Promise<Question[]>

  // 2. 提交自由答案 — 调用LLM评判
  static async submitFreeAnswer(
    userId: string,
    courseId: string,
    questionId: string,
    userAnswerText: string
  ): Promise<{ isCorrect: boolean; score: number; evaluation: AiEvaluation }>

  // 3. 获取学习记录
  static async getLearningRecords(
    courseId: string
  ): Promise<AnswerRecord[]>

  // 4. 生成测评报告
  static async generateReport(
    courseId: string
  ): Promise<AssessmentReport>

  // 5. 更新课程雷达数据
  static async updateRadarData(
    courseId: string,
    report: AssessmentReport
  ): Promise<void>
}
```

## 核心流程

### 自由答题流程

```
用户查看题目
  ↓
用户在文本框中自由输入回答
  ↓
用户点击"提交"
  ↓
调用 LLMService.evaluateUserAnswer(question, userAnswer)
  ├─ 构建评判Prompt（含题目、参考答案、布鲁姆层级、评分标准）
  ├─ 调用LLM API
  └─ 返回 AiEvaluation { score, comment, strengths, weaknesses, improvement }
  ↓
保存学习记录到 learning_record 表
  ├─ user_answer_text = 用户输入
  ├─ ai_evaluation = JSON.stringify(evaluation)
  ├─ score = evaluation.score
  └─ is_correct = (score >= 60)
  ↓
显示评判结果给用户（评分、评语、改进建议）
  ↓
下一题 → 回到步骤1
  ↓
全部答完 → 生成 AssessmentReport
  ├─ 计算各维度平均分
  ├─ 更新 radar_data
  └─ 展示完整评估报告
```

### LLM评判Prompt设计

```typescript
private static buildEvaluationPrompt(
  question: Question,
  userAnswer: string
): string {
  const levelNames = ['记忆', '理解', '应用', '分析', '评价', '创造'];
  return `你是教育评估专家。请根据以下信息评价学生的回答。

【题目】
${question.questionText}

【布鲁姆认知层级】
${levelNames[question.bloomLevel - 1]}（第${question.bloomLevel}层）

【参考答案】
${question.correctAnswer}

【学生的回答】
${userAnswer}

请从以下方面评价：
1. 准确性：回答是否正确、完整
2. 深度：是否达到该布鲁姆层级的要求
3. 逻辑性：论证是否清晰、有条理
4. 表达：语言是否准确、规范

请以JSON格式返回评价结果：
{
  "score": <0-100的整数>,
  "comment": "<总体评语>",
  "strengths": ["<优点1>", "<优点2>"],
  "weaknesses": ["<不足1>", "<不足2>"],
  "improvement": "<改进建议>"
}

注意：评分标准——
90-100：优秀，完全正确且有深度
75-89：良好，基本正确但有提升空间
60-74：及格，部分正确但需要加强
0-59：不及格，需要重新学习这个知识点`;
}
```

## 评分报告示例

### 按维度汇总

| 布鲁姆层级 | 题目数 | 均分 | 状态 |
|-----------|--------|------|------|
| 记忆 | 2 | 85 | ✅ 良好 |
| 理解 | 2 | 72 | ⚠️ 需要加强 |
| 应用 | 2 | 45 | ❌ 不及格 |
| 分析 | 2 | 68 | ⚠️ 需要加强 |
| 评价 | 2 | 55 | ❌ 不及格 |
| 创造 | 2 | 30 | ❌ 不及格 |

### 对话原始记录（每道题）

```
题目：请解释微积分基本定理的核心思想
你的回答：微积分基本定理建立了微分和积分之间的联系...
AI评语：回答基本正确，但对于该定理的几何意义阐述不够深入（评分：72/100）
改进建议：建议从牛顿和莱布尼茨的历史背景出发理解该定理...

---
```

## 保存的对话原始记录

每次答题的完整对话保存在 `learning_record` 表中，包含：
- `user_answer_text` — 用户回答的原始文本
- `ai_evaluation` — LLM评判的JSON（含score, comment, strengths, weaknesses, improvement）
- `answered_at` — 回答时间戳

这些数据可以导出为 JSON/Markdown 格式，满足"提交评价报告和对话原始记录"的需求。

## 端到端数据流

```
AssessmentDetailPage
  ├─ aboutToAppear()
  │    └→ AssessmentService.getQuestions(courseId)
  │         └→ RDB question 表
  │
  ├─ 用户输入回答 → submitFreeAnswer()
  │    ├→ LLMService.evaluateUserAnswer(question, text)
  │    ├→ INSERT learning_record (含user_answer_text, ai_evaluation)
  │    └→ 返回评分结果
  │
  └─ 生成报告 → generateReport()
       ├→ SELECT * FROM learning_record WHERE course_id = ?
       ├→ 计算各维度统计
       └→ UPDATE course SET radar_data = ? WHERE id = ?
```
