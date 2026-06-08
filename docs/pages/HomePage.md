# HomePage - 首页

> ⚠ API 20 版本：导入使用 @kit.ArkUI，严格类型

## 页面信息

| 项目 | 值 |
|-----|-----|
| 页面名称 | HomePage |
| 页面级次 | 一级（主导航第1个Tab） |
| 父页面 | MainLayout |
| 导航方式 | Tab切换 |

## 页面目的

展示所有已创建的课程，支持新课程创建（通过搜索框提问）。是整个应用的核心入口。

## 布局结构

```
┌────────────────────────────────────┐
│  StatusBar                         │
├────────────────────────────────────┤
│  搜索框输入区                      │
│  提示: "提出你的学习问题..."        │
├────────────────────────────────────┤
│                                    │
│  课程卡片网格（2列-手机，3列-平板） │
│  ┌──────────────┐ ┌──────────────┐│
│  │ 📚 数学微积分 │ │ 🧬 生物学基础││
│  │ 进度: 30%    │ │ 进度: 60%    ││
│  │ [雷达图]     │ │ [雷达图]     ││
│  │ 最近: 2天前  │ │ 最近: 1小时前││
│  └──────────────┘ └──────────────┘│
│                                    │
│  [无课程时]                         │
│  👈 提出你的学习问题，开始吧！      │
│                                    │
├────────────────────────────────────┤
│ [首页] [个人] [讨论]  ← 底部Tab   │
└────────────────────────────────────┘
```

## 控件清单

| 控件名称 | 类型 | 位置 | 功能 | 事件 | 数据绑定 |
|---------|------|------|------|------|---------|
| SearchBox | TextInput | 顶部 | 输入提问 | onSubmit | searchText |
| SearchButton | Button | 右侧 | 触发搜索 | onClick | 调用创建课程 |
| CourseGrid | Grid | 中部 | 展示卡片 | — | courseList |
| CourseCard | Card | Grid内 | 单个卡片 | onLongPress | course对象 |
| CardTitle | Text | 卡片顶 | 课程名称 | — | course.title |
| CardProgress | Progress | 卡片中 | 进度条 | — | progress_percent |
| RadarChart | Custom | 卡片中 | 能力图 | onClick | radarData |
| CardTouchArea | Blank | 卡片 | 点击区 | onClick | 跳转详情 |
| ContextMenu | Menu | 卡片上 | 长按菜单 | onSelect | 上传/导出/归档 |
| EmptyPrompt | Column | 中部 | 无课程提示 | — | 条件显示 |
| BottomNavBar | Tabs | 底部 | 导航 | onChange | currentTabIndex |

## 页面状态

```typescript
import { router } from '@kit.ArkUI';
import { CourseService } from '../services/CourseService';
import { Course } from '../models/Course';

@Entry
@Component
struct HomePage {
  // 全局状态
  @StorageLink('userId') userId: string = '';
  @StorageLink('courseList') courseList: object[] = [];

  // 页面状态
  @State searchText: string = '';
  @State courses: Course[] = [];
  @State isLoading: boolean = false;
  @State errorMsg: string = '';

  aboutToAppear(): void {
    this.loadCourses();
  }

  async loadCourses(): Promise<void> {
    this.isLoading = true;
    try {
      this.courses = await CourseService.getCourseList(this.userId);
      AppStorage.set<object[]>('courseList', this.courses);
    } catch (e) {
      this.errorMsg = '加载课程失败';
    } finally {
      this.isLoading = false;
    }
  }

  async createCourse(): Promise<void> {
    if (!this.searchText.trim()) return;
    this.isLoading = true;
    try {
      const courseId = await CourseService.createCourse(this.searchText.trim());
      this.searchText = '';
      await this.loadCourses();
      router.pushUrl({
        url: 'pages/CourseDetailPage',
        params: { courseId }
      });
    } catch (e) {
      this.errorMsg = '创建课程失败';
    } finally {
      this.isLoading = false;
    }
  }

  openCourse(courseId: string): void {
    router.pushUrl({
      url: 'pages/CourseDetailPage',
      params: { courseId }
    });
  }
}
```

## 用户交互流程

### 场景1: 创建新课程
```
用户在搜索框输入 → 点击搜索/Enter
→ CourseService.createCourse()
→ Loading动画
→ 跳转CourseDetailPage
→ 后台异步生成知识图谱
```

### 场景2: 点击已有课程
```
点击课程卡片 → AppStorage.set('currentCourseId')
→ router.pushUrl → CourseDetailPage
```

### 场景3: 长按菜单
```
长按卡片 → ContextMenu弹出（上传/导出/归档/删除）
→ 选择操作 → Dialog确认 → 执行
```

## 完成标准

- [ ] 搜索框能正确捕获用户输入
- [ ] 创建课程请求有Loading态
- [ ] 课程卡片正确显示进度和雷达图
- [ ] 长按菜单能正常弹出
- [ ] 点击卡片能跳转到详情页
- [ ] 无课程时显示引导语
- [ ] 深色模式下颜色适配正确


## 数据流图

```
┌─────────────────────────────────────────────────────┐
│ HomePage                                            │
│                                                     │
│  ┌──────────────┐                                   │
│  │ 搜索框输入    │                                   │
│  │ 提问文本      │──→ onSubmit()                     │
│  └──────────────┘     │                              │
│                       ▼                              │
│  ┌──────────────┐  ┌────────────────────┐           │
│  │ 课程卡片网格   │←─│ CourseService      │           │
│  │ 2列/3列      │  │ .createCourse()     │           │
│  │              │  │ .getCourseList()    │           │
│  └──────────────┘  └────────┬───────────┘           │
│                             │                        │
│  ┌──────────────┐          ▼                        │
│  │ 长按Context   │  ┌────────────────────┐           │
│  │ Menu         │──│ KnowledgeBaseSvc   │           │
│  │ 上传/导出    │  │ .addDocument()     │           │
│  └──────────────┘  └────────────────────┘           │
│                                                     │
│  ┌──────────────┐                                   │
│  │ 底部Tab导航   │──→ Tab切换 → Personal/Discuss    │
│  └──────────────┘                                   │
└─────────────────────────────────────────────────────┘
```

## 完整状态设计

### 页面@State

| 状态变量 | 类型 | 初始值 | 更新时机 |
|---------|------|--------|---------|
| searchText | string | '' | 用户输入 |
| courses | Course[] | [] | aboutToAppear / 下拉刷新 |
| isLoading | boolean | false | 加载开始/结束 |
| errorMsg | string | '' | 加载失败时 |
| pageState | 'loading'\|'content'\|'empty'\|'error' | 'loading' | 生命周期 |

### Loading态

```
┌──────────────────────────────┐
│  [■■■■■■■■□□] (骨架卡片x4)  │
│  [■■■■■■■■□□]              │
│  [■■■■■■■■□□]              │
│  [■■■■■■■■□□]              │
└──────────────────────────────┘
```
- 首次进入显示完整骨架屏（4个灰色卡片占位）
- 创建课程时搜索按钮显示转圈

### Empty态

```
┌──────────────────────────────┐
│                              │
│        📚                     │
│                              │
│  提出你的学习问题，开始吧！   │
│                              │
│  在搜索框输入课程名称或       │
│  学科关键词即可开始学习       │
│                              │
└──────────────────────────────┘
```

### Error态

```
┌──────────────────────────────┐
│        ⚠️                    │
│                              │
│  加载失败，请检查网络连接      │
│                              │
│  [点击重试]                   │
│                              │
└──────────────────────────────┘
```

### 下拉刷新

```typescript
@State isRefreshing: boolean = false;

build() {
  Scroll() {
    // 内容...
  }
  .onScrollToBottom(() => this.loadMore())
}

// 或使用 Refresh 组件
Refresh({ refreshing: $$this.isRefreshing }) {
  // 内容
}
.onRefresh(() => {
  this.isRefreshing = true;
  this.loadCourses().then(() => this.isRefreshing = false);
})
```
