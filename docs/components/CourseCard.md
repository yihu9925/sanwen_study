# CourseCard - 课程卡片组件

## 组件目的
在首页网格中展示单个课程摘要信息，支持点击进入详情和长按菜单。

## 布局结构

```
┌─────────────────────────┐
│ 📚                      │
│ 数学微积分              │
│ 进度: 30%               │
│ [████████░░░░░░░░░░░]   │
│ [雷达图 (迷你)]         │
│ 最近学习: 2天前         │
└─────────────────────────┘
```

## 组件属性

```typescript
@Component
export struct CourseCard {
  @Prop course: Course;
  @Prop cardWidth: number = 160;

  // 事件
  onClick?: (courseId: string) => void;
  onLongPress?: (courseId: string) => void;

  build() {
    Column() {
      // 学科图标（Emoji占位，正式使用图标字体）
      Text(this.getDomainEmoji())
        .fontSize(32)
        .margin({ top: 12 });

      // 课程名称
      Text(this.course.title)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .maxLines(2)
        .textOverflow(TextOverflow.Ellipsis)
        .margin({ top: 8 });

      // 进度条
      Progress({ value: this.course.progressPercent, total: 100 })
        .width('90%')
        .height(6)
        .color('#2563EB')
        .backgroundColor('#E5E7EB')
        .margin({ top: 8 });

      // 迷你雷达图
      RadarChart({
        data: this.course.radarData,
        size: 80,
        showLabels: false,
        animated: false
      });

      // 最近学习时间
      Text(`最近: ${this.formatTime(this.course.lastAccessedAt)}`)
        .fontSize(10)
        .fontColor('#9CA3AF')
        .margin({ bottom: 8 });
    }
    .width(this.cardWidth)
    .height(180)
    .backgroundColor(Color.White)
    .borderRadius(12)
    .shadow({ radius: 4, color: '#00000010' })
    .onClick(() => this.onClick?.(this.course.id))
    .onLongPress(() => this.onLongPress?.(this.course.id))
  }

  getDomainEmoji(): string {
    const map: Record<string, string> = {
      '数学': '📐', '物理': '⚛️', '化学': '🧪',
      '生物': '🧬', '计算机': '💻', '哲学': '📖',
      '文学': '📝', '历史': '🏛️', '经济': '📊'
    };
    return map[this.course.domain] || '📚';
  }

  formatTime(time: string): string {
    // 简化为相对时间
    return time ? '刚刚' : '';
  }
}
```

## 交互状态

| 状态 | UI表现 |
|------|--------|
| 默认 | 白色卡片，阴影 |
| 点击 | 缩放动画反馈 |
| 长按 | 震动反馈 + ContextMenu |
| 空数据 | 默认占位emoji + 骨架屏 |


## 完整 Props / Events 清单

### @Prop 输入属性

| 属性名 | 类型 | 必填 | 默认值 | 说明 |
|-------|------|------|-------|------|
| course | Course | 是 | — | 课程数据对象 |
| cardWidth | number | 否 | 160 | 卡片宽度 (vp) |
| showRadar | boolean | 否 | true | 是否显示迷你雷达图 |

### 事件回调

| 回调名 | 签名 | 说明 |
|-------|------|------|
| onClick | `(courseId: string) => void` | 点击卡片，跳转详情页 |
| onLongPress | `(courseId: string) => void` | 长按卡片，弹出ContextMenu |

### 内部 @State

| 状态变量 | 类型 | 初始值 | 说明 |
|---------|------|--------|------|
| iconEmoji | string | '📚' | 学科表情图标 |
| relativeTime | string | '' | 相对时间文本 |

### 边界情况

| 场景 | 表现 |
|------|------|
| course.title 为空 | 显示"未命名课程" |
| course.progressPercent = 0 | 进度条为空 |
| course.radarData 全0 | 雷达图显示空白六边形 |
| course.lastAccessedAt 为空 | 不显示时间 |
