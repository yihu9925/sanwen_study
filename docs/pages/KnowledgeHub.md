# KnowledgeHub - 知识库总览

## 页面信息

| 项目 | 值 |
|-----|-----|
| 页面名称 | KnowledgeHub |
| 页面级次 | 一级（底部Tab第2个，首页与个人中心之间） |
| 父页面 | MainLayout (Index.ets) |
| 导航方式 | Tab切换 |

## 页面目的

跨课程聚合所有AI生成和用户上传的资料文档，支持全文搜索、按来源/课程筛选，提供全局资料浏览入口。解决原"资料库"深埋在CourseDetailPage内部、无法跨课程查看的问题。

## 布局结构

```
┌─────────────────────────────────────┐
│  📚 知识库                          │
│  ┌─ [搜索资料...] ──────────────┐  │
│  └────────────────────────────────┘  │
├─────────────────────────────────────┤
│  [全部] [AI资料] [用户上传] [按课程▼]│
├─────────────────────────────────────┤
│                                     │
│  ┌───────────────────────────────┐  │
│  │ 📄 数学微积分 - 基础概念介绍  │  │
│  │ 课程：数学微积分              │  │
│  │ [AI资料] 2天前                │  │
│  └───────────────────────────────┘  │
│  ┌───────────────────────────────┐  │
│  │ 📄 生物学 - 前沿研究趋势      │  │
│  │ 课程：生物学基础              │  │
│  │ [用户上传] 5天前              │  │
│  └───────────────────────────────┘  │
│  ┌───────────────────────────────┐  │
│  │ 📄 机器学习 - 算法比较       │  │
│  │ 课程：AI基础                  │  │
│  │ [AI资料] 1周前                │  │
│  └───────────────────────────────┘  │
│                                     │
│  [无文档时]                         │
│  📂 暂无知识库资料                  │
│  请先创建课程，AI会自动生成学习资料  │
│                                     │
├─────────────────────────────────────┤
│  [首页] [知识库] [个人]  ← 底部Tab │
└─────────────────────────────────────┘
```

## 控件清单

| 控件名称 | 类型 | 位置 | 功能 | 事件 | 数据绑定 |
|---------|------|------|------|------|---------|
| PageTitle | Text | 顶部 | 标题"知识库" | — | — |
| SearchBox | TextInput | 顶部 | 按关键词搜索标题/内容 | onInput | searchText |
| FilterPills | Row | 搜索下方 | 来源筛选 | onClick | activeFilter |
| FilterAll | Button | 筛选行 | 全部文档 | onClick | activeFilter='all' |
| FilterAI | Button | 筛选行 | AI生成 | onClick | activeFilter='ai' |
| FilterUser | Button | 筛选行 | 用户上传 | onClick | activeFilter='user' |
| CourseFilter | Select | 筛选行 | 按课程筛选 | onSelect | selectedCourseId |
| DocumentList | List | 主内容区 | 文档列表 | — | filteredDocs |
| DocumentCard | ListItem | 列表内 | 单个文档 | onClick | doc对象 |
| DocTitle | Text | 卡片内 | 文档标题 | — | doc.title |
| DocCourse | Text | 卡片内 | 所属课程 | — | courseTitle |
| SourceBadge | Text | 卡片内 | AI/用户标识 | — | doc.sourceType |
| DocDate | Text | 卡片内 | 时间 | — | relativeTime |
| DocSheet | bindSheet | 列表项 | 底部详情弹窗 | onClick | selectedDoc |
| EmptyPrompt | Column | 列表为空时 | 引导创建课程 | — | — |
| BottomNavBar | Tabs | 底部 | 导航 | onChange | currentTabIndex |

## 页面状态

```typescript
@Entry
@Component
struct KnowledgeHub {
  // 全局状态
  @StorageLink('userId') userId: string = '';
  @StorageLink('themeMode') themeMode: string = 'auto';

  // 页面状态
  @State searchText: string = '';
  @State activeFilter: string = 'all';          // 'all' | 'ai' | 'user'
  @State selectedCourseId: string = '';          // 按课程筛选
  @State allDocuments: DocWithCourse[] = [];
  @State filteredDocs: DocWithCourse[] = [];
  @State userCourses: Course[] = [];
  @State selectedDoc: DocWithCourse | null = null;
  @State showDocSheet: boolean = false;
  @State isLoading: boolean = true;
  @State errorMsg: string = '';

  aboutToAppear(): void {
    this.loadData();
  }

  async loadData(): Promise<void> {
    this.isLoading = true;
    try {
      this.userCourses = await CourseService.getCoursesByUser(this.userId);
      this.allDocuments = await KnowledgeBaseService.getDocumentsByUser(this.userId);
      this.applyFilters();
    } catch (e) {
      this.errorMsg = '加载知识库失败';
    } finally {
      this.isLoading = false;
    }
  }

  applyFilters(): void {
    let result = this.allDocuments;

    // 搜索过滤
    if (this.searchText.trim()) {
      const keyword = this.searchText.trim().toLowerCase();
      result = result.filter(doc =>
        doc.title.toLowerCase().includes(keyword) ||
        doc.content.toLowerCase().includes(keyword)
      );
    }

    // 来源过滤
    if (this.activeFilter !== 'all') {
      result = result.filter(doc => doc.sourceType === this.activeFilter);
    }

    // 课程过滤
    if (this.selectedCourseId) {
      result = result.filter(doc => doc.courseId === this.selectedCourseId);
    }

    this.filteredDocs = result;
  }
}

// 带课程信息的文档
interface DocWithCourse {
  id: string;
  courseId: string;
  courseTitle: string;
  sourceType: DocumentSourceType;
  title: string;
  content: string;
  filePath: string;
  fileType: DocumentFileType;
  keywords: string[];
  uploadedAt: string;
}
```

## 用户交互流程

### 场景1: 浏览全部文档
```
切换到知识库Tab → aboutToAppear加载数据
→ 显示跨所有课程的文档列表（按时间倒序）
→ 点击任意文档 → bindSheet弹出底部详情弹窗
```

### 场景2: 搜索文档
```
在搜索框输入关键词 → onInput实时过滤
→ 匹配标题和内容的文档实时显示
→ 清空搜索框 → 恢复全部列表
```

### 场景3: 按来源/课程筛选
```
点击"AI资料" → activeFilter='ai' → 仅显示AI生成
点击"用户上传" → activeFilter='user' → 仅显示用户上传
点击课程选择器 → selectedCourseId → 仅显示该课程
```

### 场景4: 查看文档详情
```
点击文档卡片 → bindSheet弹出
→ 显示标题、来源标签、完整内容
→ 点击"去课程" → router导航到CourseDetailPage(courseId)
→ 下拉关闭Sheet
```

## 数据流图

```
┌─────────────────────────────────────────────────────────────┐
│ KnowledgeHub                                                │
│                                                             │
│  aboutToAppear()                                            │
│       │                                                     │
│       ├──→ CourseService.getCoursesByUser(userId)           │
│       │      └→ RDB course (user_id=?)                     │
│       │                                                     │
│       └──→ KnowledgeBaseService.getDocumentsByUser(userId)  │
│              └→ RDB document JOIN course (user_id=?)       │
│                                                             │
│  搜索/筛选 → applyFilters() → filteredDocs 更新             │
│                                                             │
│  点击文档 → bindSheet → 查看详情                            │
│  点击"去课程" → router.push → CourseDetailPage(courseId)    │
│                                                             │
│  底部Tab → [首页] [知识库] [个人]                           │
└─────────────────────────────────────────────────────────────┘
```

## 完整状态设计

### 页面@State

| 状态变量 | 类型 | 初始值 | 更新时机 |
|---------|------|--------|---------|
| searchText | string | '' | 用户输入 |
| activeFilter | string | 'all' | 点击筛选按钮 |
| selectedCourseId | string | '' | 课程选择器 |
| allDocuments | DocWithCourse[] | [] | aboutToAppear |
| filteredDocs | DocWithCourse[] | [] | 筛选/搜索变化 |
| userCourses | Course[] | [] | aboutToAppear |
| selectedDoc | DocWithCourse \| null | null | 点击卡片 |
| showDocSheet | boolean | false | 点击/关闭卡片 |
| isLoading | boolean | true | 加载开始/完成 |
| errorMsg | string | '' | 加载失败 |

### Loading态

```
┌──────────────────────────────────┐
│  [🔍 ───────────] 搜索框占位     │
│                                   │
│  [全部] [AI资料] [用户上传]       │
│                                   │
│  ┌──────────────────────────┐    │
│  │ ████████████████████████ │    │  ← 骨架卡片 x3
│  │ ██████                   │    │
│  └──────────────────────────┘    │
│  ┌──────────────────────────┐    │
│  │ ████████████████████████ │    │
│  │ ██████                   │    │
│  └──────────────────────────┘    │
│  ┌──────────────────────────┐    │
│  │ ████████████████████████ │    │
│  │ ██████                   │    │
│  └──────────────────────────┘    │
└──────────────────────────────────┘
```

### Empty态

```
┌──────────────────────────────────┐
│                                  │
│         📂                       │
│                                  │
│    暂无知识库资料                 │
│                                  │
│  请先创建课程，AI会自动生成       │
│  学习资料                         │
│                                  │
│  [去创建课程] → 跳转首页         │
│                                  │
└──────────────────────────────────┘
```

### Error态

```
┌──────────────────────────────────┐
│         ⚠️                       │
│                                  │
│    加载失败，请检查网络           │
│                                  │
│  [点击重试]                       │
│                                  │
└──────────────────────────────────┘
```

## 数据库交互

```typescript
// 新增：跨课程查询文档
// 在 KnowledgeBaseService 中新增

static async getDocumentsByUser(userId: string): Promise<DocWithCourse[]> {
  const store = RelationalStoreManager.getStore();
  const sql = `
    SELECT d.*, c.title as course_title
    FROM document d
    JOIN course c ON d.course_id = c.id
    WHERE c.user_id = ?
    ORDER BY d.uploaded_at DESC
  `;

  const resultSet = await store.querySql(sql, [userId]);
  const docs: DocWithCourse[] = [];

  while (resultSet.goToNextRow()) {
    docs.push({
      id: resultSet.getString(0),
      courseId: resultSet.getString(1),
      sourceType: resultSet.getString(2) as DocumentSourceType,
      title: resultSet.getString(3),
      content: resultSet.getString(4),
      filePath: resultSet.getString(5),
      fileType: resultSet.getString(6) as DocumentFileType,
      keywords: JSON.parse(resultSet.getString(7) || '[]'),
      uploadedAt: resultSet.getString(8),
      courseTitle: resultSet.getString(9)
    });
  }
  resultSet.close();
  return docs;
}
```

## 与其他页面的数据联通

| 页面/组件 | 数据关系 |
|----------|---------|
| **CourseDetailPage (MaterialsTab)** | MaterialsTab只显示当前课程文档；KnowledgeHub聚合所有课程文档 |
| **HomePage** | HomePage创建课程时自动生成AI资料 → KnowledgeHub即刻可见 |
| **PersonalCenter** | 统计"总资料数"需从KnowledgeHub数据源获取 |
| **KnowledgeBaseService** | 新增 getDocumentsByUser() 跨课程查询 |
| **CourseService** | 用于获取用户课程列表（填充课程筛选器） |

## 完成标准

- [ ] 正确加载所有课程的文档列表
- [ ] 搜索功能实时过滤标题和内容
- [ ] 来源筛选（全部/AI/用户）正常工作
- [ ] 课程筛选器显示用户所有课程
- [ ] 点击文档卡片弹出底部详情弹窗
- [ ] 弹窗内"去课程"按钮导航正确
- [ ] 加载时有骨架屏
- [ ] 无文档时显示引导页面
- [ ] 深色模式颜色适配正确
- [ ] 下拉刷新支持
