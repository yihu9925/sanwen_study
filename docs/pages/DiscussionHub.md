# DiscussionHub - 讨论区

## 页面信息

| 项目 | 值 |
|-----|-----|
| 页面名称 | DiscussionHub |
| 页面级次 | 一级（底部Tab第3个） |
| 父页面 | MainLayout |
| 导航方式 | Tab切换 |

## 页面目的
提供学术讨论平台，按争议点组织讨论话题，用户可以发表观点、查看热门讨论、与AI助手互动。

## 布局结构

```
┌────────────────────────────────────┐
│  🔍 搜索讨论话题...                │
├────────────────────────────────────┤
│  热门标签:                         │
│  [数学] [物理] [AI] [哲学] [更多] │
├────────────────────────────────────┤
│                                    │
│  讨论话题列表                      │
│                                    │
│  ┌─────────────────────────────┐   │
│  │ 📌 导数的几何意义           │   │
│  │    参与讨论: 45人           │   │
│  │    最新回复: 2小时前        │   │
│  │    ⭐⭐⭐⭐⭐ 热度          │   │
│  │    [标签: 微积分]           │   │
│  └─────────────────────────────┘   │
│                                    │
│  ┌─────────────────────────────┐   │
│  │ 💡 量子力学诠释之争        │   │
│  │    参与讨论: 32人           │   │
│  │    最新回复: 5小时前        │   │
│  │    ⭐⭐⭐⭐ 热度           │   │
│  │    [标签: 物理学]           │   │
│  └─────────────────────────────┘   │
│                                    │
│  ┌─────────────────────────────┐   │
│  │ 🤖 AI助手: 热门争议汇总    │   │
│  │    本周最受关注的3个争议点   │   │
│  └─────────────────────────────┘   │
│                                    │
│  [+ 发表观点] 悬浮按钮             │
├────────────────────────────────────┤
│ [首页] [个人] [讨论]              │
└────────────────────────────────────┘
```

## 控件清单

| 控件名称 | 类型 | 位置 | 功能 | 事件 | 数据绑定 |
|---------|------|------|------|------|---------|
| SearchBox | TextInput | 顶部 | 搜索讨论话题 | onInput | searchText |
| SearchClearBtn | Button | 搜索框内 | 清除搜索 | onClick | '' |
| TagRow | Row | 标签区 | 热门标签过滤 | onTagClick | activeTag |
| TagChip | Chip | 标签行内 | 单个标签 | onClick | tag.name |
| TopicList | List | 主内容区 | 讨论话题列表 | onItemClick | topics |
| TopicCard | Card | 列表项 | 展示话题摘要 | onLongPress | topic |
| TopicTitle | Text | 卡片标题 | 话题名称 | — | topic.title |
| ParticipantCount | Text | 卡片 | 参与人数 | — | topic.participantCount |
| LastReplyTime | Text | 卡片 | 最新回复时间 | — | topic.lastReplyAt |
| HotRating | Row | 卡片 | 热度评级 | — | topic.hotLevel |
| TopicTag | Text | 卡片 | 学科标签 | — | topic.tag |
| AIHighlight | Card | 列表顶部 | AI精选 | onClick | aiSummary |
| NewPostBtn | Button | 悬浮底部 | 发表观点 | onClick | 弹窗 |
| FAB | Button | 右下 | 快速发表 | onClick | 模态框 |

## 页面状态

```typescript
@Entry
@Component
struct DiscussionHub {
  @State searchText: string = '';
  @State activeTag: string = '';
  @State topics: DiscussionTopic[] = [];
  @State filteredTopics: DiscussionTopic[] = [];
  @State isLoading: boolean = true;
  @State aiSummary: string = '';

  allTags: string[] = ['数学', '物理', 'AI', '哲学', '文学', '化学', '生物'];

  aboutToAppear(): void {
    this.loadTopics();
    this.loadAISummary();
  }

  async loadTopics(): Promise<void> {
    this.isLoading = true;
    this.topics = await DiscussionService.getHotTopics();
    this.filterTopics();
    this.isLoading = false;
  }

  filterTopics(): void {
    let result = this.topics;
    if (this.activeTag) {
      result = result.filter(t => t.tag === this.activeTag);
    }
    if (this.searchText) {
      result = result.filter(t =>
        t.title.includes(this.searchText)
      );
    }
    this.filteredTopics = result;
  }

  async loadAISummary(): Promise<void> {
    this.aiSummary =
      await DiscussionService.getWeeklyControversySummary();
  }
}
```

## 用户交互流程

### 搜索讨论
```
用户输入关键词 → onInput触发 → 实时过滤话题列表
```

### 按标签过滤
```
点击标签 → activeTag更新 → 重新过滤列表 → 高亮选中标签
```

### 进入讨论详情
```
点击话题卡片 → 展开话题详情面板
→ 显示所有评论 → 支持回复和点赞
```

### 发表观点
```
点击悬浮按钮 → 弹出模态框
→ 选择关联课程/争议点 → 输入内容 → 提交
```

## 数据类型

```typescript
export interface DiscussionTopic {
  id: string;
  title: string;
  tag: string;
  participantCount: number;
  lastReplyAt: string;
  hotLevel: number;      // 1~5
  isPinned: boolean;     // 是否置顶
}
```

## 数据库交互

```typescript
// 获取热门话题
SELECT * FROM discussion_topics ORDER BY hot_level DESC, last_reply_at DESC LIMIT 20;

// 搜索话题
SELECT * FROM discussion_topics WHERE title LIKE '%keyword%';

// 按标签过滤
SELECT * FROM discussion_topics WHERE tag = '数学';
```

## 完成标准

- [ ] 搜索框实时过滤
- [ ] 标签点击切换正确
- [ ] 话题列表支持滚动
- [ ] 悬浮发表按钮正常工作
- [ ] AI精选卡片显示最新争议
- [ ] 深色模式适配
- [ ] 列表下拉刷新


## 数据流图

```
┌─────────────────────────────────────────────────────┐
│ DiscussionHub                                       │
│                                                     │
│  aboutToAppear()                                    │
│       │                                             │
│       ├──→ DiscussionService.getHotTopics()         │
│       │      └→ RDB discussion_topics 表            │
│       │                                             │
│       └──→ DiscussionService.getWeeklySummary()     │
│              └→ LLMService 汇总热门争议             │
│                                                     │
│  用户搜索 → filterTopics() = 本地过滤               │
│  点击标签 → activeTag → filterTopics()              │
│  发表观点 → NewPostDialog → INSERT                  │
└─────────────────────────────────────────────────────┘
```

## 完整状态设计

| 状态变量 | 类型 | 初始值 | 说明 |
|---------|------|--------|------|
| searchText | string | '' | 搜索关键词 |
| activeTag | string | '' | 当前选中标签 |
| topics | DiscussionTopic[] | [] | 所有话题 |
| filteredTopics | DiscussionTopic[] | [] | 过滤后话题 |
| isLoading | boolean | true | — |
| pageState | PageState | 'loading' | — |

### Loading态
话题列表骨架屏（5行灰色占位）

### Empty态
"暂无讨论话题" / "没有匹配的讨论"

### Error态
"加载失败" + [重试]

### 搜索无结果
"没有找到相关话题，试试其他关键词"
