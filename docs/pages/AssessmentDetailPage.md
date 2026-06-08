# AssessmentDetailPage - 答题详情页

## 页面信息

| 项目 | 值 |
|-----|-----|
| 页面名称 | AssessmentDetailPage |
| 页面级次 | 二级（从CourseDetailPage Tab3跳转） |
| 参数 | { courseId: string } |

## 页面目的
提供题目作答、即时反馈、答案解析功能。

## 布局结构

```
┌────────────────────────────────────┐
│  ← 第三问 · 认知测评              │
│  进度: 3/30                        │
├────────────────────────────────────┤
│                                    │
│  认知层级: [记忆] ████████░░ 80%  │
│                                    │
│  ┌─ 题目 ────────────────────┐    │
│  │ Q3. 微积分基本定理的       │    │
│  │ 核心思想是什么？           │    │
│  │                            │    │
│  │ 难度: ⭐⭐⭐               │    │
│  │                            │    │
│  │ A. 微分与积分互为逆运算   │    │
│  │ B. 微分是积分的特例       │    │
│  │ C. 积分是微分的推广       │    │
│  │ D. 两者无关               │    │
│  └────────────────────────────┘    │
│                                    │
│  [上一题]      [下一题 →]        │
│                                    │
│  ┌─ 答题卡 ──────────────────┐    │
│  │ [✓] [✓] [✗] [ ] [ ] ... │    │
│  │ 正确:2 错误:1 未答:27    │    │
│  └────────────────────────────┘    │
└────────────────────────────────────┘
```

## 控件清单

| 控件名称 | 类型 | 功能 | 事件 |
|---------|------|------|------|
| BackButton | Button | 返回课程详情 | onClick |
| ProgressInfo | Row | 显示进度 X/30 | — |
| BloomLevelBar | Progress | 各层级完成度 | — |
| QuestionCard | Card | 题目展示区 | — |
| QuestionText | Text | 题目内容 | — |
| DifficultyBadge | Badge | 难度标识 | — |
| OptionRow | Row | 选项A/B/C/D | onClick |
| OptionRadio | Radio | 单选按钮 | onChange |
| PrevBtn | Button | 上一题 | onClick |
| NextBtn | Button | 下一题 | onClick |
| AnswerCard | Column | 答题后显示解析 | — |
| ResultIcon | Image | 正确/错误图标 | — |
| Explanation | Text | 答案解析文本 | — |
| AnswerSheet | Grid | 答题卡网格 | onItemClick |
| StatsRow | Row | 正确/错误/未答统计 | — |

## 页面状态

```typescript
@Entry
@Component
struct AssessmentDetailPage {
  @State courseId: string =
    (router.getParams()?.['courseId'] as string) || '';
  @State questions: Question[] = [];
  @State currentIndex: number = 0;
  @State selectedAnswer: string = '';
  @State hasSubmitted: boolean = false;
  @State isCorrect: boolean = false;
  @State userAnswers: Record<string, string> = {};
  @State correctCount: number = 0;
  @State wrongCount: number = 0;

  aboutToAppear(): void {
    this.loadQuestions();
  }

  async loadQuestions(): Promise<void> {
    this.questions =
      await AssessmentService.getQuestions(this.courseId);
  }

  get currentQuestion(): Question | null {
    return this.questions[this.currentIndex] || null;
  }

  selectAnswer(option: string): void {
    if (this.hasSubmitted) return;
    this.selectedAnswer = option;
  }

  async submitAnswer(): Promise<void> {
    if (!this.selectedAnswer) return;
    this.hasSubmitted = true;
    this.isCorrect =
      this.selectedAnswer === this.currentQuestion?.correctAnswer;
    if (this.isCorrect) this.correctCount++;
    else this.wrongCount++;
    // 保存到学习记录
    await AssessmentService.submitAnswer(
      this.courseId,
      this.currentQuestion!.id,
      this.selectedAnswer
    );
  }

  nextQuestion(): void {
    if (this.currentIndex < this.questions.length - 1) {
      this.currentIndex++;
      this.hasSubmitted = false;
      this.selectedAnswer = '';
    }
  }
}
```

## 完成标准

- [ ] 题目顺序显示正确
- [ ] 选择答案后即时反馈
- [ ] 正确答案展示+解析
- [ ] 上一题/下一题正常
- [ ] 答题卡标记正确/错误/未答
- [ ] 统计数字实时更新
- [ ] 返回课程详情后进度刷新


## 数据流图

```
┌─────────────────────────────────────────────────────┐
│ AssessmentDetailPage                                │
│                                                     │
│  aboutToAppear()                                    │
│       │                                             │
│       └──→ AssessmentService.getQuestions()         │
│              └→ RDB question 表                      │
│                                                     │
│  用户选择答案 → submitAnswer()                      │
│       │                                             │
│       └──→ AssessmentService.submitAnswer()          │
│              ├→ INSERT learning_record              │
│              ├→ 返回 { isCorrect, explanation }     │
│              └→ EventBus.emit('progress_updated')   │
│                                                     │
│  [查看报告] → generateReport()                      │
│       │                                             │
│       └──→ AssessmentService.generateReport()       │
│              └→ 统计 learning_record                │
│              └→ 返回 AssessmentReport               │
└─────────────────────────────────────────────────────┘
```

## 完整状态设计

### 页面@State

| 状态变量 | 类型 | 初始值 | 说明 |
|---------|------|--------|------|
| questions | Question[] | [] | 题目列表 |
| currentIndex | number | 0 | 当前题目索引 |
| selectedAnswer | string | '' | 用户选择的答案 |
| hasSubmitted | boolean | false | 是否已提交 |
| isCorrect | boolean | false | 答案是否正确 |
| correctCount | number | 0 | 正确计数 |
| wrongCount | number | 0 | 错误计数 |
| userAnswers | Record<string, string> | {} | 所有答案记录 |
| isFinished | boolean | false | 是否全部答完 |
| pageState | PageState | 'loading' | 页面状态 |

### Loading态
全屏 "加载题目中..."

### 无题目的Empty态
"暂无测评题目，请等待AI生成" + [返回] 按钮

### 全部答完态
```
🎉 恭喜完成所有题目！
正确: 8 / 错误: 2 / 正确率: 80%
[查看详细报告]
[返回课程]
```

### 边界情况
- 所有题目答完但未满分 → 提示薄弱维度
- 某维度题目全对 → 显示"💪 掌握扎实"
- 某维度题目全错 → 显示"📖 建议复习"
