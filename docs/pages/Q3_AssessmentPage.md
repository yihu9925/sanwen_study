# Q3_AssessmentPage - 认知测评（第三问）

## 页面信息
| 项目 | 值 |
|-----|-----|
| 页面名称 | Q3_AssessmentPage |
| 页面级次 | 子Tab页面（CourseDetailPage的Tab3） |

## 页面目的
根据布鲁姆认知层级，提供自适应测评题，评估用户的理解深度。

## 布局结构

```
┌─────────────────────────────────────────┐
│  认知层级过滤器（Row + Chip）            │
│  [全部] [记忆] [理解] [应用] [分析] [评价] [创造] │
│                                         │
│  题目列表                               │
│  ┌─────────────────────────────────┐   │
│  │ Q1. 什么是导数？               │   │
│  │ 难度: ⭐⭐                     │   │
│  │ [记忆] [简单]                  │   │
│  │ 状态: ✅ 已答                  │   │
│  └─────────────────────────────────┘   │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │ Q2. 如何应用微积分解决...       │   │
│  │ 难度: ⭐⭐⭐                   │   │
│  │ [应用] [中等]                   │   │
│  │ 状态: ❌ 错误                   │   │
│  └─────────────────────────────────┘   │
│                                         │
│  [开始答题 →]        [📊 查看报告]    │
│                                         │
│  答题卡                                │
│  [✓][✓][✗][ ][ ][✓][ ][✗]...          │
│  正确:3 错误:2 未答:5                  │
└─────────────────────────────────────────┘
```

## 控件清单

| 控件名称 | 类型 | 功能 | 事件 |
|---------|------|------|------|
| BloomFilter | Row | 认知层级过滤 | onChipClick |
| QuestionList | List | 题目列表 | onItemClick |
| QuestionItem | Component | 题目卡片 | — |
| DifficultyBadge | Badge | 难度标识 | — |
| BloomBadge | Badge | 层级标签 | — |
| StartTestBtn | Button | 开始答题 | onClick |
| ReportBtn | Button | 查看报告 | onClick |
| AnswerSheet | Grid | 答题卡 | — |
| StatsRow | Row | 正确/错误/未答 | — |

## 页面状态

```typescript
import { AssessmentService } from '../services/AssessmentService';

@Component
export struct Q3_AssessmentPage {
  @State bloomLevel: number = 0;     // 0=全部
  @State questions: Question[] = [];
  @State filteredQuestions: Question[] = [];
  @State correctCount: number = 0;
  @State wrongCount: number = 0;
  @State totalAnswered: number = 0;

  props!: { courseId: string };

  aboutToAppear(): void {
    this.loadQuestions();
    this.loadStats();
  }

  async loadQuestions(): Promise<void> {
    this.questions = await AssessmentService.getQuestions(this.props.courseId);
    this.filterQuestions();
  }

  filterQuestions(): void {
    if (this.bloomLevel === 0) {
      this.filteredQuestions = this.questions;
    } else {
      this.filteredQuestions = this.questions.filter(
        q => q.bloomLevel === this.bloomLevel
      );
    }
  }

  async loadStats(): Promise<void> {
    const report = await AssessmentService.generateReport(this.props.courseId);
    this.correctCount = report.correctCount;
    this.totalAnswered = report.answeredCount;
    this.wrongCount = this.totalAnswered - this.correctCount;
  }

  startTest(): void {
    router.pushUrl({
      url: 'pages/AssessmentDetailPage',
      params: { courseId: this.props.courseId }
    });
  }

  viewReport(): void {
    // 显示弹窗或跳转报告页
  }
}
```

## 完成标准

- [ ] 过滤器能按层级正确过滤
- [ ] 题目列表显示完整
- [ ] 答题卡正确标记状态
- [ ] 统计数字实时更新
- [ ] "开始答题"跳转到答题详情页


## 数据流图

```
┌─────────────────────────────────────────────────────┐
│ Q3_AssessmentPage (Tab3)                            │
│                                                     │
│  props.courseId → aboutToAppear()                   │
│       │                                             │
│       ├──→ AssessmentService.getQuestions()         │
│       │      └→ RDB question 表                     │
│       │                                             │
│       └──→ AssessmentService.generateReport()       │
│              └→ RDB learning_record 统计            │
│                                                     │
│  BloomFilter切换 → 本地过滤 questions               │
│  点击题目 → router.push AssessmentDetailPage        │
│                                                     │
│  异步: EventBus.on('questions_ready')                │
│       → 重新加载题目列表                             │
│  EventBus.on('progress_updated')                    │
│       → 刷新统计数据                                │
└─────────────────────────────────────────────────────┘
```

## 完整状态设计

| 状态变量 | 类型 | 初始值 | 说明 |
|---------|------|--------|------|
| questions | Question[] | [] | 所有题目 |
| filteredQuestions | Question[] | [] | 过滤后题目 |
| bloomLevel | number | 0 | 当前过滤层级 (0=全部) |
| isGenerating | boolean | false | 是否在生成中 |
| stats | { correct: number; wrong: number; total: number } | — | 统计 |

### Loading态
题目列表骨架屏

### Empty态（生成中）
"AI正在为你生成测评题目，请稍候..." + 进度提示

### Empty态（已生成但无题目）
"暂无题目数据"

### 全部答完态
在列表顶部显示绿色横幅 "🎉 全部答完！正确率 X%"
