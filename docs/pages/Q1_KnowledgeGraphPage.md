# Q1_KnowledgeGraphPage - 知识图谱（第一问）

## 页面信息
| 项目 | 值 |
|-----|-----|
| 页面名称 | Q1_KnowledgeGraphPage |
| 页面级次 | 子Tab页面（CourseDetailPage的Tab1） |

## 页面目的
展示课程的核心心智模型，通过动态知识图谱呈现学科底层逻辑框架。

## 布局结构

```
┌─────────────────────────────────────────┐
│  🔍 搜索知识点...                       │
│                                         │
│  力导向知识图谱（Canvas绘制）            │
│   概念A (重要度5)                       │
│  /       \                              │
│ 概念B    概念C                          │
│  (3)      (4)                           │
│    \     /                              │
│     概念D (2)                           │
│                                         │
│  ┌─ 点击节点弹出详情气泡 ──────────┐   │
│  │ 概念A: 导数                      │   │
│  │ 重要度: ⭐⭐⭐⭐⭐               │   │
│  │ 描述: 微积分核心概念...          │   │
│  │ 关联资料: [论文1] [笔记2]        │   │
│  │ [关闭]                           │   │
│  └──────────────────────────────────┘   │
│                                         │
│  📄 相关资料列表                       │
│  [AI资料] 论文：导数的本质             │
│  [用户资料] 笔记：微积分复习           │
│                                         │
│  [✓ 完成第一问]                        │
└─────────────────────────────────────────┘
```

## 控件清单

| 控件名称 | 类型 | 功能 | 事件 |
|---------|------|------|------|
| SearchField | TextInput | 知识点搜索 | onChange |
| GraphCanvas | Canvas | 图谱绘制 | onReady / onDraw |
| NodeDetail | Popup | 节点信息气泡 | — |
| ResourceList | List | 关联资料 | onItemClick |
| CompleteButton | Button | 完成第一问 | onClick |

## Canvas实现关键点

- 力导向布局算法（见 `components/KnowledgeGraph.md`）
- 节点点击检测（计算点击坐标是否在圆内）
- 搜索高亮（匹配节点变色+连线条目）

## 完成标准

- [ ] 知识图谱正确显示
- [ ] 节点可点击展开详情
- [ ] 搜索功能正常
- [ ] 资料列表可滚动


## 数据流图

```
┌─────────────────────────────────────────────────────┐
│ Q1_KnowledgeGraphPage (Tab1)                        │
│                                                     │
│  props.courseId → aboutToAppear()                   │
│       │                                             │
│       └──→ KnowledgeBaseService.getKnowledgeGraph() │
│              └→ RDB knowledgebase.knowledge_graph   │
│                                                     │
│  搜索 → 本地过滤 highlightedIds                     │
│  点击节点 → selectedNode = node → 显示详情气泡     │
│                                                     │
│  异步: EventBus.on('graph_ready')                   │
│       → 重新加载图谱                                │
└─────────────────────────────────────────────────────┘
```

## 完整状态设计

| 状态变量 | 类型 | 初始值 | 说明 |
|---------|------|--------|------|
| nodes | GraphNode[] | [] | 图谱节点 |
| edges | GraphEdge[] | [] | 图谱边 |
| selectedNode | GraphNode \| null | null | 选中节点 |
| searchKeyword | string | '' | 搜索词 |
| highlightedIds | string[] | [] | 高亮节点ID |
| isGenerating | boolean | false | 是否在生成中 |

### Loading态
Canvas区域显示旋转加载图标 + "知识图谱生成中..."

### Empty态
"暂无知识图谱，AI正在处理..."（带进度提示）

### 生成超时
"知识图谱生成较慢，你可以先查看已有资料" + [手动刷新] 按钮
