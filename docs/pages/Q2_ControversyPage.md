# Q2_ControversyPage - 争议点分析（第二问）

## 页面信息
| 项目 | 值 |
|-----|-----|
| 页面名称 | Q2_ControversyPage |
| 页面级次 | 子Tab页面（CourseDetailPage的Tab2） |

## 页面目的
展示学术分歧点，呈现正反方观点和证据对比，帮助用户深度思考。

## 布局结构

```
┌─────────────────────────────────────────┐
│  争议点选择器（Swiper）                  │
│  [争议1] [争议2] [争议3]               │
│                                         │
│  ┌─ 正方观点 ──┐ ┌─ 反方观点 ──┐      │
│  │ 观点内容    │ │ 观点内容    │       │
│  │             │ │             │       │
│  │ [展开证据]  │ │ [展开证据]  │       │
│  │  证据1...   │ │  证据1...   │       │
│  │  证据2...   │ │  证据2...   │       │
│  └─────────────┘ └─────────────┘       │
│                                         │
│  🤖 AI总结                              │
│  两种观点并不矛盾，它们分别强调了...    │
│                                         │
│  💬 参与讨论  |  [✓ 完成第二问]        │
└─────────────────────────────────────────┘
```

## 控件清单

| 控件名称 | 类型 | 功能 | 事件 |
|---------|------|------|------|
| ControversySelector | Swiper | 争议点切换 | onChange |
| ProColumn | Column | 正方观点 | — |
| ConColumn | Column | 反方观点 | — |
| EvidenceList | List | 证据列表 | onItemClick |
| ConclusionCard | Card | AI总结 | — |
| DiscussionButton | Button | 参与讨论 | onClick |
| CompleteButton | Button | 完成第二问 | onClick |

## 完成标准

- [ ] 争议点切换正常
- [ ] 左右分栏布局正确
- [ ] 证据可展开/收起
- [ ] "参与讨论"跳转正常
- [ ] "完成第二问"更新进度


## 数据流图

```
┌─────────────────────────────────────────────────────┐
│ Q2_ControversyPage (Tab2)                           │
│                                                     │
│  props.courseId → aboutToAppear()                   │
│       │                                             │
│       └──→ KnowledgeBaseService.getControversies()  │
│              └→ RDB knowledgebase.controversies     │
│                                                     │
│  Swiper切换 → activeIndex 更新                      │
│  展开证据 → showPro/showConEvidence 切换            │
│  完成第二问 → 回调父页面更新进度                    │
│                                                     │
│  异步: EventBus.on('controversy_ready')             │
│       → 重新加载争议点                              │
└─────────────────────────────────────────────────────┘
```

## 完整状态设计

| 状态变量 | 类型 | 初始值 | 说明 |
|---------|------|--------|------|
| controversies | Controversy[] | [] | 争议点列表 |
| activeIndex | number | 0 | 当前选中的争议索引 |
| isLoading | boolean | true | — |

### Loading态
左右分栏灰色占位块

### Empty态
"暂无争议点数据" → 如果已生成知识图谱但无争议点，提示"AI正在分析..."

### 只有一个争议点
不显示Swiper指示点
