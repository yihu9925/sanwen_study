# Q3_AssessmentPage - 第三问：深度测评（自由答题模式入口）

> ⚠ **核心变更**：从展示选择题列表改为开放题列表 + 答题入口。

## 页面信息

| 项目 | 值 |
|-----|------|
| 页面名称 | Q3_AssessmentPage |
| 页面级次 | 三级（CourseDetailPage Tab3内容 / 或独立页面） |
| 导航方式 | 内嵌Tab或独立页面 |

## 页面目的

展示当前课程的测评题目概览，提供"开始答题"入口，以及已完成的答题记录和报告。

## 布局结构

```
┌──────────────────────────────────────────┐
│  📝 认知测评                             │
│                                          │
│  布鲁姆6维度 | 12道开放题                │
│                                          │
│  ┌─ 维度过滤器 ───────────────────────┐  │
│  │  [全部] [记忆] [理解] [应用] [分析]│  │
│  │  [评价] [创造]                     │  │
│  └────────────────────────────────────┘  │
│                                          │
│  ┌─ 题目列表 ─────────────────────────┐  │
│  │  ❓ 第1题（记忆）什么是xxx？       │  │
│  │    难度: ⭐⭐  状态: 未答          │  │
│  │  ─────────────────────────────────  │  │
│  │  ❓ 第2题（理解）请解释xxx          │  │
│  │    难度: ⭐⭐⭐ 状态: ✅ 已答 85分│  │
│  │  ─────────────────────────────────  │  │
│  │  ❓ 第3题（应用）请用xxx解决...    │  │
│  │    难度: ⭐⭐⭐⭐  状态: ❌ 45分  │  │
│  │  ─────────────────────────────────  │  │
│  │  ...还有9道题未答                  │  │
│  └────────────────────────────────────┘  │
│                                          │
│  [▶ 开始答题]     [📊 查看报告]         │
│                                          │
│  答题进度: ████░░░░ 3/12 (25%)          │
└──────────────────────────────────────────┘
```

## 核心变更说明

| 旧模式（选择题） | 新模式（自由答题） |
|----------------|------------------|
| 题目有4个选项 | 题目无选项，引导用户自由阐述 |
| 用户选择A/B/C/D | 用户在TextArea输入回答 |
| 与预设答案比对判对错 | LLM评判回答质量（0-100分） |
| 仅保存选择结果 | 保存完整对话原始记录 |
| 报告显示正确率 | 报告显示各维度评分+评语+改进建议 |

## 页面状态

```typescript
@Component
export struct Q3_AssessmentPage {
  @State bloomFilter: number = 0;       // 0=全部
  @State questions: Question[] = [];
  @State answeredCount: number = 0;
  @State averageScore: number = 0;
  @State hasReport: boolean = false;     // 是否有已完成报告

  props!: { courseId: string };

  aboutToAppear(): void {
    this.loadQuestions();
    this.loadProgress();
  }

  async loadQuestions(): Promise<void> { ... }
  async loadProgress(): Promise<void> { ... }

  startAssessment(): void {
    router.pushUrl({
      url: 'pages/AssessmentDetailPage',
      params: { courseId: this.props.courseId }
    });
  }

  viewReport(): void {
    // 弹窗或跳转报告页
  }
}
```

## 完成标准

- [ ] 显示所有开放题列表
- [ ] 维度过滤器正确过滤
- [ ] 显示每道题的答题状态（未答/已答评分）
- [ ] 开始答题跳转到 AssessmentDetailPage
- [ ] 查看报告展示完整评估报告
