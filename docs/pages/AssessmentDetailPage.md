# AssessmentDetailPage - 测评详情页（自由答题模式）

> ⚠ **核心变更**：从选择题（Radio选择）改为**自由文本输入+LLM评判**模式。

## 页面信息

| 项目 | 值 |
|-----|------|
| 页面名称 | AssessmentDetailPage |
| 页面级次 | 三级（从CourseDetailPage跳转） |
| 导航方式 | router.pushUrl |
| 参数 | { courseId: string } |

## 页面目的

用户自由回答每一道测评题，调用LLM评判回答质量，保存对话原始记录，最终生成评估报告。

## 布局结构

```
┌──────────────────────────────────────────┐
│  ← 返回      认知测评 (3/12)              │
├──────────────────────────────────────────┤
│                                          │
│  ┌─ 题目卡片 ─────────────────────────┐  │
│  │  难度: ⭐⭐⭐                       │  │
│  │  层级: 🧠 应用（布鲁姆第3层）        │  │
│  │                                      │  │
│  │  题目：                             │  │
│  │  请解释微积分基本定理如何应用于      │  │
│  │  计算曲线下方的面积？                │  │
│  │                                      │  │
│  │  ┌─ 你的回答 ──────────────────┐    │  │
│  │  │ [多行文本输入框]              │    │  │
│  │  │                               │    │  │
│  │  │                               │    │  │
│  │  └──────────────────────────────┘    │  │
│  │                                      │  │
│  │  [📤 提交回答]                       │  │
│  └──────────────────────────────────────┘  │
│                                            │
│  ┌─ LLM评判结果（提交后显示）───────────┐  │
│  │  📊 评分: 85/100                     │  │
│  │  👍 优点：思路清晰，举例恰当       │  │
│  │  💡 不足：缺少严格的数学推导       │  │
│  │  📝 改进建议：尝试用极限定义推导   │  │
│  │                                      │  │
│  │  [➡️ 下一题]                        │  │
│  └──────────────────────────────────────┘  │
│                                            │
├──────────────────────────────────────────┤
│ 🟢 答题进度: 3/12 已完成                 │
└──────────────────────────────────────────┘
```

## 控件清单

| 控件名称 | 类型 | 功能 | 备注 |
|---------|------|------|------|
| ProgressHeader | Row | 显示当前进度 (x/N) | — |
| QuestionCard | Column | 显示题目+层级+难度 | — |
| FreeTextInput | TextArea | 用户自由输入回答 | 核心控件，多行文本 |
| SubmitButton | Button | 提交回答至LLM评判 | 提交后禁用 |
| EvaluationCard | Column | 显示LLM评判结果 | 含score/comment/strengths/weaknesses |
| NextButton | Button | 下一题/查看报告 | 最后一道题切换为报告按钮 |
| ReportView | Column | 完整评估报告 | 统计+雷达+对话记录 |

## 页面状态

```typescript
@Entry
@Component
struct AssessmentDetailPage {
  @State courseId: string = '';
  @State questions: Question[] = [];
  @State currentIndex: number = 0;
  @State userAnswerText: string = '';       // 用户自由输入的回答
  @State isSubmitting: boolean = false;      // 是否正在提交（等待LLM）
  @State showEvaluation: boolean = false;    // 是否显示评判结果
  @State evaluation: AiEvaluation | null = null;  // LLM评判结果
  @State answerRecords: AnswerRecord[] = []; // 已答记录
  @State showReport: boolean = false;        // 是否显示报告
  @State allScores: number[] = [];           // 所有题目的评分

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string>;
    this.courseId = params?.['courseId'] || '';
    if (this.courseId) {
      this.loadQuestions();
    }
  }

  async loadQuestions(): Promise<void> { ... }

  // 提交自由回答（核心方法）
  async submitFreeAnswer(): Promise<void> {
    if (!this.userAnswerText.trim()) return;
    this.isSubmitting = true;
    try {
      const question = this.questions[this.currentIndex];
      const { isCorrect, score, evaluation } =
        await AssessmentService.submitFreeAnswer(
          'default_user',
          this.courseId,
          question.id,
          this.userAnswerText
        );
      this.evaluation = evaluation;
      this.allScores.push(score);
      this.showEvaluation = true;
    } catch (error) {
      promptAction.showToast({ message: '提交失败，请重试' });
    } finally {
      this.isSubmitting = false;
    }
  }

  // 下一题或查看报告
  nextQuestion(): void {
    if (this.currentIndex < this.questions.length - 1) {
      this.currentIndex++;
      this.userAnswerText = '';
      this.showEvaluation = false;
      this.evaluation = null;
    } else {
      this.showReport = true;
    }
  }

  // 生成评估报告
  async generateReport(): Promise<void> {
    // 由AssessmentService.generateReport(courseId)完成
    // 更新radar_data
  }
}
```

## 用户交互流程

### 答题流程

```
① 页面加载
   ├─ 从路由获取 courseId
   └─ 加载题目列表（按布鲁姆层级排序）

② 答题循环（每道题）
   ├─ 显示题目（含难度、布鲁姆层级标签）
   ├─ 用户在 TextArea 中输入回答（自由撰写）
   ├─ 点击"提交回答"
   │    ├─ isSubmitting = true（按钮显示转圈）
   │    ├─ 调用LLM评判 → 返回评分+评语
   │    ├─ 保存到 learning_record 表
   │    └─ 显示评判结果
   └─ 点击"下一题" → 继续

③ 最后一道题
   └─ 点击"查看报告"
        ├─ 显示完整评估报告
        ├─ 按布鲁姆维度统计
        ├─ 雷达图更新
        └─ 每道题对话原始记录可展开查看

④ 返回
   └─ 点击"返回课程" → router.back()
```

## 评估报告展示

```
┌──────────────────────────────────────────┐
│  📊 评估报告                             │
│                                          │
│  总题数: 12     均分: 68/100            │
│                                          │
│  ┌─ 布鲁姆维度分析 ──────────────────┐  │
│  │  记忆    ██████████░░  85/100  ✅ │  │
│  │  理解    ████████░░░░  72/100  ⚠  │  │
│  │  应用    █████░░░░░░░  45/100  ❌ │  │
│  │  分析    ███████░░░░░  68/100  ⚠  │  │
│  │  评价    █████░░░░░░░  55/100  ❌ │  │
│  │  创造    ███░░░░░░░░░  30/100  ❌ │  │
│  └────────────────────────────────────┘  │
│                                          │
│  ┌─ 对话原始记录（点击展开） ─────────┐ │
│  │  ▼ 第1题 (记忆) — 85分             │ │
│  │    你的回答：xxxxxxxxxxxx           │ │
│  │    AI评语：xxxxxxxx                 │ │
│  │  ─────────────────────────────────  │ │
│  │  ▼ 第2题 (理解) — 72分             │ │
│  └────────────────────────────────────┘ │
│                                          │
│  [📤 导出报告]  [🔙 返回课程]           │
└──────────────────────────────────────────┘
```

## 完成标准

- [ ] 用户可在 TextArea 自由输入回答
- [ ] 提交后正确调用LLM评判
- [ ] 正确保存对话原始记录（user_answer_text + ai_evaluation）
- [ ] 全部答完后生成完整评估报告
- [ ] 每道题可展开查看对话详情
- [ ] 支持导出报告（JSON/Markdown）
