# ArchiveManagementPage - 归档管理

## 页面信息

| 项目 | 值 |
|-----|-----|
| 页面名称 | ArchiveManagementPage |
| 页面级次 | 二级（从个人中心跳转） |
| 导航方式 | router.pushUrl |

## 页面目的
管理已归档的课程，支持恢复、永久删除等操作。

## 布局结构

```
┌────────────────────────────────────┐
│  ← 课程归档                        │
├────────────────────────────────────┤
│  [全部] [本周] [更早]  ↗排序      │
│                                    │
│  归档课程列表（空状态提示）         │
│                                    │
│  ┌─────────────────────────────┐   │
│  │ 📚 高等数学                 │   │
│  │ 已完成 · 2个月前归档        │   │
│  │ 学习时长: 12小时            │   │
│  │ [恢复] [永久删除]           │   │
│  └─────────────────────────────┘   │
│                                    │
│  ┌─────────────────────────────┐   │
│  │ 🧬 生物学基础              │   │
│  │ 已完成 · 1个月前归档        │   │
│  │ 学习时长: 8小时             │   │
│  │ [恢复] [永久删除]           │   │
│  └─────────────────────────────┘   │
└────────────────────────────────────┘
```

## 控件清单

| 控件名称 | 类型 | 位置 | 功能 | 事件 |
|---------|------|------|------|------|
| BackButton | Button | 左上 | 返回个人中心 | onClick |
| FilterTabs | Tabs | 顶部 | 时间过滤 | onChange |
| SortButton | Button | 右上 | 排序切换 | onClick |
| ArchiveList | List | 主内容区 | 归档列表 | onItemClick |
| ArchiveCard | Card | 列表项 | 课程摘要 | onLongPress |
| RestoreBtn | Button | 卡片右 | 恢复课程 | onClick |
| DeleteBtn | Button | 卡片右 | 永久删除 | onClick |
| EmptyPrompt | Column | 列表空态 | 无归档提示 | — |

## 页面状态

```typescript
@Entry
@Component
struct ArchiveManagementPage {
  @StorageLink('userId') userId: string = '';
  @State archivedCourses: Course[] = [];
  @State filterType: 'all' | 'week' | 'earlier' = 'all';
  @State isLoading: boolean = true;

  async loadArchives(): Promise<void> {
    this.isLoading = true;
    this.archivedCourses =
      await CourseService.getArchiveList(this.userId);
    this.isLoading = false;
  }

  async restoreCourse(courseId: string): Promise<void> {
    await CourseService.restoreCourse(courseId);
    this.loadArchives();  // 刷新
  }

  async permanentlyDelete(courseId: string): Promise<void> {
    await CourseService.deleteCourse(courseId);
    this.loadArchives();
  }
}
```

## 完成标准

- [ ] 归档课程列表正确显示
- [ ] 时间过滤功能正常
- [ ] 恢复课程后回到首页可见
- [ ] 永久删除有二次确认
- [ ] 空状态显示引导文案


## 数据流图

```
┌─────────────────────────────────────────────────────┐
│ ArchiveManagementPage                               │
│                                                     │
│  aboutToAppear()                                    │
│       │                                             │
│       └──→ CourseService.getArchiveList(userId)     │
│              └→ RDB course (status='archived')      │
│                                                     │
│  点击"恢复" → CourseService.restoreCourse(id)       │
│       │      └→ UPDATE status = 'created'           │
│       └──→ 重新加载列表                             │
│                                                     │
│  点击"永久删除" → CourseService.deleteCourse(id)    │
│       │      └→ DELETE CASCADE                      │
│       └──→ 重新加载列表                             │
└─────────────────────────────────────────────────────┘
```

## 完整状态设计

| 状态变量 | 类型 | 初始值 | 说明 |
|---------|------|--------|------|
| archivedCourses | Course[] | [] | 归档课程 |
| filterType | 'all'\|'week'\|'earlier' | 'all' | 过滤 |
| isLoading | boolean | true | — |
| pageState | PageState | 'loading' | — |

### Loading态
列表骨架屏

### Empty态
"暂无归档课程" + [去学习] 按钮跳转首页

### 删除确认弹窗
"确定要永久删除「课程名」吗？此操作不可恢复。"
[取消] [确认删除]
