# 三问高效学习机 — 功能开发与修复报告

## 目录

1. [UI 主题系统](#1-ui-主题系统)
2. [全页面主题适配](#2-全页面主题适配)
3. [主题扩展（4套新风格）](#3-主题扩展4套新风格)
4. [个人中心重构](#4-个人中心重构)
5. [数据可视化（折线图 + 柱状图）](#5-数据可视化折线图--柱状图)
6. [Q3 测评题生成修复](#6-q3-测评题生成修复)
7. [学习计时器](#7-学习计时器)
8. [硬编码测试数据](#8-硬编码测试数据)

---

## 1. UI 主题系统

### 新增文件
| 文件 | 说明 |
|------|------|
| `utils/UiStyle.ets` | 主题系统核心，定义 `StyleColors` 接口和 `UiStyle` 工具类 |

### StyleColors 接口
```typescript
interface StyleColors {
  pageBg: string;       // 页面背景色
  cardBg: string;       // 卡片背景色
  accent: string;       // 主题强调色
  accentLight: string;  // 主题淡色
  textPrimary: string;  // 主文字色
  textSecondary: string;// 次要文字色
  textTertiary: string; // 辅助文字色
  divider: string;      // 分割线色
  cardRadius: number;   // 卡片圆角
  cardShadow: string;   // 卡片阴影
}
```

### 初始两套主题

| 主题 | Light pageBg | Light accent | Dark pageBg | Dark accent |
|------|-------------|-------------|-------------|-------------|
| 默认 | `#F5F5F5` | `#007DFF` (科技蓝) | `#222222` | `#007DFF` |
| 暖阳 | `#F5F0EB` | `#D4894A` (琥珀) | `#2C2418` | `#E8A85A` |

### 修复的 ArkTS 编译/运行时 Bug

| Bug | 原因 | 修复 |
|-----|------|------|
| `get colors()` 报错 | ArkTS @Component 不支持 ECMAScript `get` 访问器 | 改为普通方法 `colors(): StyleColors` |
| `let c = ...` 编译失败 | ArkTS `build()` 根节点前不允许变量声明 | 将逻辑移至 `colors()` 方法中 |
| `AppStorage('uiStyle')` 为 undefined | 未初始化 `@StorageLink` 键 | 在 `Index.aboutToAppear()` 中调用 `AppStorage.setOrCreate('uiStyle', 'default')` |
| `pushUrl` 静默失败 | 路由页面未注册到 `main_pages.json` | 检查 `entry/src/main/resources/base/profile/main_pages.json`，确保所有目标页面已添加 |

### 修改文件
- `pages/AppearancePage.ets` — 新增外观设置页（深色模式开关 + 主题选择器）
- `pages/PersonalCenter.ets` — 添加「外观」入口
- `AppRouter.ets` — 新增 `APPEARANCE` 路由
- `main_pages.json` — 注册 `AppearancePage`

---

## 2. 全页面主题适配

将 `UiStyle` 集成到所有 15 个页面/组件中，替换原有的 `this.themeMode === 'dark'` 硬编码颜色判断。

### 已适配文件清单

| 文件 | 类型 |
|------|------|
| `pages/Index.ets` | 主入口 Tab 导航 |
| `pages/HomePage.ets` | 首页 |
| `pages/PersonalCenter.ets` | 个人中心 |
| `pages/SettingsPage.ets` | 设置页 |
| `pages/ArchiveManagementPage.ets` | 归档管理 |
| `pages/AppearancePage.ets` | 外观设置 |
| `pages/KnowledgeHub.ets` | 知识库 |
| `pages/CourseDetailPage.ets` | 课程详情 |
| `pages/AssessmentDetailPage.ets` | 测评答题 |
| `pages/Q1_KnowledgeGraphPage.ets` | 第一问 |
| `pages/Q2_ControversyPage.ets` | 第二问 |
| `pages/Q3_AssessmentPage.ets` | 第三问 |
| `components/KnowledgeGraphView.ets` | 知识图谱组件 |
| `components/RadarChartView.ets` | 雷达图组件 |
| `components/ControversyView.ets` | 争议点组件 |

### 颜色映射规则

| 原代码 | 替换为 |
|--------|--------|
| `themeMode === 'dark' ? '#333333' : Color.White` | `this.colors().cardBg` |
| `themeMode === 'dark' ? '#222222' : '#F5F5F5'` | `this.colors().pageBg` |
| `themeMode === 'dark' ? '#CCCCCC' : '#999999'` | `this.colors().textTertiary` |
| `themeMode === 'dark' ? '#AAAAAA' : '#666666'` | `this.colors().textSecondary` |
| `themeMode === 'dark' ? '#FFFFFF' : '#333333'` | `this.colors().textPrimary` |
| `themeMode === 'dark' ? '#444444' : '#E5E5E5'` | `this.colors().divider` |
| `themeMode === 'dark' ? '#555555' : '#E0E0E0'` | `this.colors().divider` |

### 特别注意：语义色保留
红/绿/蓝底色的语义标签（如删除按钮红色背景、正反方观点绿色/红色背景、AI 总结蓝色背景）保持原有颜色，不纳入主题系统。

### 修复的 Bug

**`RadarChartView.ets` — 命名冲突**
- 原有 `private colors: string[]`（色板数组）与新加的 `colors()` 方法冲突
- 修复：色板数组重命名为 `chartColors`

---

## 3. 主题扩展（4套新风格）

### 新增主题

| 主题名 | 风格 | 主色(Light) | 适用场景 |
|--------|------|-------------|----------|
| `midnight` (极夜) | 深海军蓝 + 琥珀金 | `#D4A843` | 沉稳高级 |
| `forest` (森林) | 自然墨绿 | `#2E7D4E` | 护眼静谧 |
| `sakura` (樱花) | 粉玫瑰 | `#D4617A` | 柔和甜美 |
| `ink` (墨水) | 宣纸 + 朱砂红 | `#C43838` | 国风古韵 |

### 修改文件
- `utils/UiStyle.ets` — 新增 4 对 light/dark 调色板，扩展 `getColors()` 和 `getStyleLabel()`
- `pages/AppearancePage.ets` — 添加 4 个 `StyleOption` 预览卡片

---

## 4. 个人中心重构

### 界面结构调整

```
┌─ 用户信息卡（头像 + 昵称）─────────┐
├─ 学习统计数据（总数 / 已完成 / 已归档）┤
├─ 学习数据总览 ──────────────────────┤
│  ├─ 📈 周学习时长变化（折线图）      │
│  └─ 📊 学科能力对比（柱状图）       │
├─ 📚 归档管理                        │
├─ 📁 资料上传历史 → 知识库           │
├─ 🎨 外观                           │
└─ ⚙️ 设置                           │
```

### 统计数据卡片迁移
- 从 `HomePage.ets` 移除课程总数/已完成/已归档统计行
- 移至 `PersonalCenter.ets`，通过 `AppStorage` (`statTotal` / `statCompleted` / `statArchived`) 自动同步
- 移除 `HomePage` 中不再需要的 `@Watch('recalcStats')` 和 `@State statArchived`

### 布局优化
- 移除原有的 `justifyContent(FlexAlign.Center)` 居中布局
- 改用 `Scroll` 包裹全部内容，避免内容溢出

---

## 5. 数据可视化（折线图 + 柱状图）

### 新增文件

| 文件 | 说明 |
|------|------|
| `components/LineChartView.ets` | Canvas 折线图组件 |
| `components/BarChartView.ets` | Canvas 柱状图组件 |
| `services/StudyStatsService.ets` | 学习数据统计服务 |

### 图表特性

| 特性 | 折线图 | 柱状图 |
|------|--------|--------|
| 渲染引擎 | Canvas 2D | Canvas 2D |
| 曲线类型 | 贝塞尔平滑曲线 | 圆角矩形柱 |
| 渐变填充 | 有（半透明渐变） | 无 |
| 数据点 | 圆点（带描边） | — |
| 空缺处理 | 跳过 0 值日，连线断开 | 跳过 0 分学科 |
| 字体大小 | Y 轴 36px, X 轴 39px | 36px |
| 画布高度 | 300px | 300px |

### Canvas 异步渲染问题与修复

**问题**：`loadChartData()` 是异步方法，Canvas 的 `onReady` 在数据返回前就已触发，且 `@Prop` 更新后 Canvas 不会自动重绘。

**修复方案**：添加 `chartVersion` 计数器 + `.key()` 标识
```typescript
// PersonalCenter.ets
@State chartVersion: number = 0;

async loadChartData(): Promise<void> {
  // ... 加载数据 ...
  this.chartVersion++;  // 递增版本号
}

// LineChartView.ets
@Prop chartVersion: number = 0;
Canvas(this.context)
  .key('line_' + this.chartVersion)  // key 变化时 Canvas 销毁重建
  .onReady(() => { this.drawChart(); });
```

### 数据来源
- 折线图：硬编码 `[0, 0, 20, 30, 0, 0, 0]`（周三 20 分钟，周四 30 分钟）
- 柱状图：硬编码 数学=90, Java=75

### 修改文件
- `pages/PersonalCenter.ets` — 集成图表组件，添加 `onPageShow` 刷新
- `AppRouter.ets` — 新增 `KNOWLEDGE_HUB` 路由

---

## 6. Q3 测评题生成修复

### 问题 1：重新生成后能力图谱仍有旧数据

**原因**：`CourseService.resetProgress()` 重置了进度标志但未清空 `radar_data` 字段；`AssessmentService.generateQuestions()` 只插入新题不删除旧题。

**修复**：
- `CourseService.resetProgress()` 增加 `radar_data: '{}'` 重置
- 新增 `AssessmentService.deleteQuestionsByCourse(courseId)` — 删除旧测评题
- 新增 `AssessmentService.deleteLearningRecordsByCourse(courseId)` — 删除旧答题记录
- `CourseDetailPage.generateContent()` 在生成新题前先调用清理方法

### 问题 2：题目数量不一致

**原因**：调用方传 `count=5`，LLM 提示词硬编码"生成8道题目"，`count` 参数未被使用。

**修复**：
- 调用方统一改为 `count=8`
- LLM 提示词改为 `${count}` 动态拼接
- 按 5:3 比例分配选择题和开放题

### 修改文件
- `services/CourseService.ets` — `resetProgress()` 增加 `radar_data`
- `services/AssessmentService.ets` — 新增 `deleteQuestionsByCourse()` 和 `deleteLearningRecordsByCourse()`
- `pages/CourseDetailPage.ets` — 生成前清理旧数据，`count=8`
- `services/CourseHealthService.ets` — 补全 Q3 时清理并 `count=8`
- `services/LLMService.ets` — 提示词动态化

---

## 7. 学习计时器

### 实现方案

使用 `AppStorage` 跨组件通信，实现进入/离开课程详情页的计时：

```
流程：
1. CourseDetailPage.aboutToAppear()
   → StudyStatsService.startStudySession()
   → AppStorage.set('studySessionStart', Date.now())

2. Index.onPageShow()  (返回主页时)
   → StudyStatsService.endStudySession()
   → 计算耗时（分钟）
   → 写入 studyWeeklyData (JSON: { weekStart, minutes[7] })
```

### 存储格式
```json
{
  "weekStart": "2024-01-15",
  "minutes": [0, 0, 20, 30, 0, 0, 0]
}
```

- 按周一起始日存储，跨周自动重置
- 仅记录当日数据（通过 `getDayIndex()` 定位）

### 修改文件
- `services/StudyStatsService.ets` — 新增 `startStudySession()` / `endStudySession()`
- `pages/CourseDetailPage.ets` — 引入 `StudyStatsService`，`aboutToAppear()` 中开始计时
- `pages/Index.ets` — 引入 `StudyStatsService`，`onPageShow()` 中结束计时

---

## 8. 硬编码测试数据

由于数据库暂无真实学习数据，图表当前使用硬编码数据展示：

### 折线图
```
周一  周二  周三  周四  周五  周六  周日
 0     0    20    30    0     0     0
```

### 柱状图
| 学科 | 能力分 |
|------|--------|
| 数学 | 90 |
| Java | 75 |

### 修改文件
- `pages/PersonalCenter.ets` — `@State` 初始值改为硬编码数据，移除 `StudyStatsService` 依赖

---

## 附录：完整文件变更清单

### 新增文件（4 个）
- `utils/UiStyle.ets`
- `components/LineChartView.ets`
- `components/BarChartView.ets`
- `services/StudyStatsService.ets`

### 修改文件（18 个）
- `pages/PersonalCenter.ets`
- `pages/HomePage.ets`
- `pages/AppearancePage.ets`
- `pages/Index.ets`
- `pages/CourseDetailPage.ets`
- `pages/KnowledgeHub.ets`
- `pages/SettingsPage.ets`
- `pages/ArchiveManagementPage.ets`
- `pages/AssessmentDetailPage.ets`
- `pages/Q1_KnowledgeGraphPage.ets`
- `pages/Q2_ControversyPage.ets`
- `pages/Q3_AssessmentPage.ets`
- `components/KnowledgeGraphView.ets`
- `components/RadarChartView.ets`
- `components/ControversyView.ets`
- `services/CourseService.ets`
- `services/AssessmentService.ets`
- `services/LLMService.ets`
- `services/CourseHealthService.ets`
- `AppRouter.ets`
- `entry/src/main/resources/base/profile/main_pages.json`
