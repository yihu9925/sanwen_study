# CourseDetailPage - 课程详情页

> ⚠ API 20 版本：Tabs 组件 + 3个子Tab

## 页面信息

| 项目 | 值 |
|-----|-----|
| 页面名称 | CourseDetailPage |
| 页面级次 | 二级（从首页跳转） |
| 导航方式 | router.pushUrl |
| 参数 | { courseId: string } |

## 页面目的
展示单个课程的完整学习空间，内含3个Tab对应三问学习法。

## 布局结构

```
┌────────────────────────────────────┐
│  ← 返回       数学微基础      ⋮  │
├────────────────────────────────────┤
│                                    │
│  [第一问:知识图谱] [第二问:争议] [第三问:测评]   │
│                                    │
│  ┌─ Tab内容区（Swiper切换）─────┐  │
│  │                                │  │
│  │  Tab1: Q1_KnowledgeGraphPage  │  │
│  │  知识图谱绘制区               │  │
│  │                                │  │
│  │  Tab2: Q2_ControversyPage     │  │
│  │  争议点对比                   │  │
│  │                                │  │
│  │  Tab3: Q3_AssessmentPage      │  │
│  │  测评题目列表                 │  │
│  │                                │  │
│  └────────────────────────────────┘  │
│                                    │
│  底部进度: ████████░░ 80%         │
└────────────────────────────────────┘
```

## 控件清单

| 控件名称 | 类型 | 位置 | 功能 | 事件 | 数据绑定 |
|---------|------|------|------|------|---------|
| BackButton | Button | 左上 | 返回首页 | onClick | router.back() |
| CourseTitle | Text | 中上 | 课程标题 | — | courseData.title |
| MoreButton | Button | 右上 | 更多操作 | onClick | 弹窗菜单 |
| TabsView | Tabs | 下方 | Tab切换 | onChange | activeTabIndex |
| GraphCanvas | Custom | Tab1 | 知识图谱 | onNodeClick | knowledgeGraph |
| ResourceList | List | Tab1下 | 资料列表 | onItemClick | documents |
| CompleteQ1Button | Button | 底部 | 完成第一问 | onClick | 更新进度 |
| ControversySwiper | Swiper | Tab2 | 争议点切换 | onChange | controversies |
| ProColumn | Column | Tab2 | 正方观点 | — | controversy.pro |
| ConColumn | Column | Tab2 | 反方观点 | — | controversy.con |
| QuestionList | List | Tab3 | 题目列表 | onItemClick | questions |
| BloomFilter | Row | Tab3顶 | 层级过滤 | onClick | bloomLevel过滤 |
| StartTestButton | Button | Tab3底 | 开始答题 | onClick | 导航到答题页 |
| ProgressBar | Progress | 底部 | 整体进度 | — | progressPercent |

## 页面状态

```typescript
import { router } from '@kit.ArkUI';
import { CourseService } from '../services/CourseService';
import { KnowledgeBaseService } from '../services/KnowledgeBaseService';
import { Course, GraphNode, Controversy, Question } from '../models/types';

@Entry
@Component
struct CourseDetailPage {
  @StorageLink('currentCourseId') currentCourseId: string = '';

  @State courseData: Course | null = null;
  @State activeTabIndex: number = 0;
  @State graphData: GraphNode[] = [];
  // 用 Record 替代 Map（API 20 禁止 Map 用于 @State）
  @State graphEdges: Array<{ from: string; to: string; label: string }> = [];
  @State controversies: Controversy[] = [];
  @State questions: Question[] = [];
  @State documents: Document[] = [];
  @State isLoading: boolean = true;
  @State progressPercent: number = 0;

  // 从路由参数或 AppStorage 获取 courseId
  courseId: string =
    (router.getParams()?.['courseId'] as string) ||
    AppStorage.get<string>('currentCourseId') || '';

  aboutToAppear(): void {
    this.loadAll();
  }

  async loadAll(): Promise<void> {
    this.isLoading = true;
    try {
      const results = await Promise.all([
        CourseService.getCourseById(this.courseId),
        KnowledgeBaseService.getKnowledgeGraph(this.courseId),
        KnowledgeBaseService.getControversies(this.courseId),
        AssessmentService.getQuestions(this.courseId),
        KnowledgeBaseService.getDocuments(this.courseId),
      ]);
      this.courseData = results[0] as Course | null;
      this.graphData = results[1] as GraphNode[];
      this.graphEdges = this.buildEdges(results[1] as GraphNode[]);
      this.controversies = results[2] as Controversy[];
      this.questions = results[3] as Question[];
      this.documents = results[4] as Document[];
      this.courseData = course;
      this.graphData = graph;
      this.graphEdges = this.buildEdges(graph);
      this.controversies = cList;
      this.questions = qList;
      this.documents = docList;
      this.progressPercent = course?.progressPercent || 0;
    } catch (e) {
      console.error('Load failed:', JSON.stringify(e));
    } finally {
      this.isLoading = false;
    }
  }

  buildEdges(nodes: GraphNode[]): Array<{ from: string; to: string; label: string }> {
    const edges: Array<{ from: string; to: string; label: string }> = [];
    for (const node of nodes) {
      for (const child of node.children) {
        edges.push({ from: node.id, to: child.id, label: '包含' });
      }
    }
    return edges;
  }
}
```

## 三个Tab内容说明

### Tab1: Q1_KnowledgeGraphPage
知识图谱展示，点击节点展开详情，查看关联资料，搜索知识点。

### Tab2: Q2_ControversyPage
争议点分析，切换不同争议主题，查看正反方观点和证据。

### Tab3: Q3_AssessmentPage
测评题目，按认知层级过滤，点击开始答题。

## 完成标准

- [ ] 三个Tab切换正常
- [ ] 知识图谱正确渲染
- [ ] 争议点左右分栏
- [ ] 题目列表可过滤
- [ ] 底部进度条动态更新
- [ ] 深色模式适配


## 数据流图

```
┌─────────────────────────────────────────────────────────┐
│ CourseDetailPage                                        │
│                                                         │
│  aboutToAppear()                                        │
│       │                                                 │
│       ├──→ CourseService.getCourseById(courseId)        │
│       │      └→ RDB course 表                           │
│       │                                                 │
│       ├──→ KnowledgeBaseService.getKnowledgeGraph()     │
│       │      └→ RDB knowledgebase.knowledge_graph       │
│       │                                                 │
│       ├──→ KnowledgeBaseService.getControversies()      │
│       │      └→ RDB knowledgebase.controversies         │
│       │                                                 │
│       ├──→ AssessmentService.getQuestions()             │
│       │      └→ RDB question 表                         │
│       │                                                 │
│       └──→ KnowledgeBaseService.getDocuments()          │
│              └→ RDB document 表                         │
│                                                         │
│  EventBus 监听:                                          │
│  ┌─────────────────────────────────────┐                │
│  │ graph_ready      → 刷新图谱Tab      │                │
│  │ controversy_ready→ 刷新争议Tab      │                │
│  │ questions_ready  → 刷新测评Tab      │                │
│  │ progress_updated → 更新底部进度条   │                │
│  │ document_added   → 刷新文档列表     │                │
│  └─────────────────────────────────────┘                │
└─────────────────────────────────────────────────────────┘
```

## 完整状态设计

### 页面@State

| 状态变量 | 类型 | 初始值 | 说明 |
|---------|------|--------|------|
| courseData | Course \| null | null | 课程数据 |
| graphData | GraphNode[] | [] | 知识图谱节点 |
| graphEdges | Edge[] | [] | 图谱连线 |
| controversies | Controversy[] | [] | 争议点 |
| questions | Question[] | [] | 测评题目 |
| documents | Document[] | [] | 文档列表 |
| tabIndex | number | 0 | 当前Tab |
| progressPercent | number | 0 | 底部进度 |
| pageState | PageState | 'loading' | 页面状态 |

### Loading态
全屏居中 Loading + "正在加载课程数据..."

### Empty态（首次创建进入）
- Tab1: "知识图谱正在生成中..." + 转圈
- Tab2: "争议点数据准备中..."
- Tab3: "测评题目生成中..."

### Error态
"课程数据加载失败" + [返回首页] 按钮

### 进度条颜色语义
| 百分比 | 颜色 | 语义 |
|-------|------|------|
| 0% | #D1D5DB (灰) | 未开始 |
| 1-33% | #F59E0B (橙) | 第一问完成 |
| 34-66% | #3B82F6 (蓝) | 第二问完成 |
| 67-99% | #8B5CF6 (紫) | 第三问进行中 |
| 100% | #10B981 (绿) | 全部完成 |
