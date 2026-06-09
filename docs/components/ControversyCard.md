# ControversyCard - 争议点卡片组件

## 组件目的
展示学术争议点的正反方观点对比，支持展开证据和AI总结。

## 布局结构

```
┌──────────────────────────────────────┐
│ 争议主题: 导数的本质是变化率还是...  │
│                                      │
│  ┌─ 正方观点 ──┐ ┌─ 反方观点 ──┐   │
│  │ 变化率是    │ │ 导数应当    │   │
│  │ 最直观的    │ │ 从极限定义  │   │
│  │ 理解方式    │ │ 出发        │   │
│  │             │ │             │   │
│  │ [展开证据]  │ │ [展开证据]  │   │
│  └─────────────┘ └─────────────┘   │
│                                      │
│  🤖 AI总结: 两种观点并不矛盾...     │
│                                      │
│  💬 参与讨论  |  👍 有帮助(23)     │
└──────────────────────────────────────┘
```

## 组件属性

```typescript
@Component
export struct ControversyCard {
  @Prop controversy: Controversy;
  @Prop isActive: boolean = false;

  // 事件
  onDiscuss?: (controversyId: string) => void;

  // 内部状态
  @State showProEvidence: boolean = false;
  @State showConEvidence: boolean = false;
  @State helpfulCount: number = 0;
}
```

## 数据类型

```typescript
export interface Controversy {
  id: string;
  title: string;
  proViewpoint: string;
  proEvidence: Evidence[];
  conViewpoint: string;
  conEvidence: Evidence[];
  aiSummary: string;
}

export interface Evidence {
  title: string;
  content: string;
  source: string;
  sourceUrl?: string;
}
```

## 交互状态

| 状态 | 说明 |
|------|------|
| 收起 | 仅显示标题和观点摘要 |
| 展开证据 | 点击"展开证据"显示详细引用 |
| 点赞 | 计数+1，防止重复点击 |

## 使用示例

```typescript
ControversyCard({
  controversy: currentControversy,
  isActive: index === activeIndex
})
```


## 完整 Props / Events / States 清单

### @Prop 输入属性

| 属性名 | 类型 | 必填 | 默认值 | 说明 |
|-------|------|------|-------|------|
| controversy | Controversy | 是 | — | 争议点数据对象 |
| isActive | boolean | 否 | false | 当前是否选中（高亮） |
| cardWidth | number | 否 | '100%' | 卡片宽度 |
| expanded | boolean | 否 | false | 是否默认展开证据 |

### 事件回调

| 回调名 | 签名 | 说明 |
|-------|------|------|
| onDiscuss | `(controversyId: string) => void` | 点击"参与讨论" |
| onHelpful | `(controversyId: string) => void` | 点击"有帮助" |
| onComplete | `(controversyId: string) => void` | 标记完成 |

### 内部 @State

| 状态变量 | 类型 | 初始值 | 说明 |
|---------|------|--------|------|
| showProEvidence | boolean | false | 正方证据是否展开 |
| showConEvidence | boolean | false | 反方证据是否展开 |
| helpfulCount | number | 0 | 点赞数 |
| isHelpfulClicked | boolean | false | 是否已点赞（防重复） |

### 边界情况

| 场景 | 表现 |
|------|------|
| proEvidence / conEvidence 为空 | 按钮文字改为"暂无证据" (disabled) |
| aiSummary 为空 | 不显示AI总结卡片 |
| 标题超长 | 自动换行，最多2行后省略 |
