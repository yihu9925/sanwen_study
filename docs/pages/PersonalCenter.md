# PersonalCenter - 个人中心

## 页面信息

| 项目 | 值 |
|-----|-----|
| 页面名称 | PersonalCenter |
| 页面级次 | 一级（底部Tab第2个） |
| 父页面 | MainLayout |
| 导航方式 | Tab切换 |

## 页面目的
展示用户学习数据总览、课程管理、设置入口。

## 布局结构

```
┌────────────────────────────────────┐
│  用户头像 + 用户名                 │
│  学习等级 / 编辑资料按钮           │
├────────────────────────────────────┤
│  ┌─ 学习数据总览 ──────────────┐  │
│  │ 总学习时长: 45小时          │  │
│  │ 已创建课程: 5门             │  │
│  │ 平均正确率: 78%             │  │
│  │ 今日学习: 2小时             │  │
│  └──────────────────────────────┘  │
│                                    │
│  学习趋势（周数据）                │
│  [柱状图统计]                      │
│                                    │
│  课程归档 (3)          [查看全部]  │
│  • 高等数学（已完成）             │
│  • 物理学基础（已完成）          │
│                                    │
│  ⚙️ 设置                          │
│  • 通知提醒                       │
│  • 深色模式                       │
│  • 数据管理                       │
│  • 关于应用                       │
├────────────────────────────────────┤
│ [首页] [个人] [讨论]              │
└────────────────────────────────────┘
```

## 控件清单

| 控件名称 | 类型 | 位置 | 功能 | 事件 | 数据绑定 |
|---------|------|------|------|------|---------|
| UserAvatar | Image | 头部左侧 | 显示头像 | — | userProfile.avatar |
| UserName | Text | 头部中上 | 显示昵称 | — | userProfile.nickname |
| EditProfileBtn | Button | 头部右侧 | 编辑资料 | onClick | 编辑弹窗 |
| StatsCard | Column | 数据区 | 统计汇总 | — | statsData |
| StudyHours | Text | 统计卡内 | 总时长 | — | userProfile.totalStudyHours |
| CourseCount | Text | 统计卡内 | 总课程数 | — | userProfile.totalCourses |
| AvgAccuracy | Text | 统计卡内 | 平均正确率 | — | userProfile.avgAccuracy |
| TrendChart | CustomPanel | 趋势区 | 周数据图 | — | 7天数据 |
| ArchiveSection | Column | 归档区 | 归档课程 | onClick | 跳转归档页 |
| ArchiveBadge | Badge | 归档标题旁 | 归档数量 | — | archiveCount |
| SeeAllBtn | Button | 归档行尾 | 查看全部 | onClick | router跳转 |
| SettingsList | List | 设置区 | 设置项列表 | onItemClick | menuItems |
| NotificationItem | ListItem | 设置列表 | 通知提醒 | onClick | toggle |
| ThemeItem | ListItem | 设置列表 | 深色模式 | onClick | toggle |
| DataManageItem | ListItem | 设置列表 | 数据管理 | onClick | 导出/清理 |
| AboutItem | ListItem | 设置列表 | 关于应用 | onClick | 弹窗 |

## 页面状态

```typescript
@Entry
@Component
struct PersonalCenter {
  // 全局状态
  @StorageLink('userId') userId: string = '';

  // 页面状态
  @State userProfile: UserProfile | null = null;
  @State archiveCourses: Course[] = [];
  @State weeklyStats: number[] = [];     // 7天学习时长
  @State isLoading: boolean = true;

  aboutToAppear(): void {
    this.loadProfile();
    this.loadArchiveCourses();
    this.loadWeeklyStats();
  }

  async loadProfile(): Promise<void> {
    this.isLoading = true;
    this.userProfile = await UserService.getProfile(this.userId);
    this.isLoading = false;
  }

  async loadArchiveCourses(): Promise<void> {
    this.archiveCourses =
      await CourseService.getArchiveList(this.userId);
  }

  async loadWeeklyStats(): Promise<void> {
    this.weeklyStats =
      await AnalyticsService.getWeeklyStudyHours(this.userId);
  }
}
```

## 用户交互流程

### 查看归档
```
点击"查看全部" → router.pushUrl('pages/ArchiveManagementPage')
```

### 修改设置
```
点击某个设置项 → 切换开关 / 弹出子菜单 / 跳转子页面
```

### 编辑资料
```
点击编辑头像/名称 → 弹出编辑弹窗 → 保存到Preferences
```

## 数据库交互

```typescript
// 获取用户信息
const profile = await this.rdbStore.query(
  new RdbPredicates('user_profile').equalTo('id', userId)
);

// 获取归档课程
const archives = await this.rdbStore.query(
  new RdbPredicates('course')
    .equalTo('user_id', userId)
    .equalTo('status', 'archived')
    .orderByDesc('updated_at')
);
```

## 完成标准

- [ ] 用户头像和昵称正确显示
- [ ] 统计数据与数据库一致
- [ ] 归档课程列表可点击查看全部
- [ ] 设置项功能正常
- [ ] 加载时有骨架屏
- [ ] 深色模式适配


## 数据流图

```
┌─────────────────────────────────────────────────────┐
│ PersonalCenter                                      │
│                                                     │
│  aboutToAppear()                                    │
│       │                                             │
│       ├──→ UserService.getProfile(userId)           │
│       │      └→ RDB user_profile 表                 │
│       │                                             │
│       ├──→ CourseService.getArchiveList(userId)     │
│       │      └→ RDB course (status=archived)        │
│       │                                             │
│       └──→ AnalyticsService.getWeeklyStats(userId)  │
│              └→ RDB learning_record (近7天)         │
│                                                     │
│  点击"归档" → router.push → ArchiveManagementPage  │
│  点击"设置" → router.push → SettingsPage            │
└─────────────────────────────────────────────────────┘
```

## 完整状态设计

| 状态变量 | 类型 | 初始值 | 说明 |
|---------|------|--------|------|
| userProfile | UserProfile \| null | null | 用户信息 |
| archiveCourses | Course[] | [] | 归档课程 |
| weeklyStats | number[] | [] | 周数据 |
| pageState | 'loading'\|'content'\|'error' | 'loading' | — |

### Loading态
```
┌──────────────────────────┐
│  ○ 头像占位              │
│  ──── 文字占位           │
│  ┌──────────────────┐   │
│  │ ████████████████  │   │  ← 灰色占位块
│  │ ████████████████  │   │
│  └──────────────────┘   │
└──────────────────────────┘
```

### Error态
"数据加载失败" + [重试] 按钮

### 空数据
统计数据为0时显示 "开始学习吧！"
