# KnowledgeGraph - 知识图谱组件

## 组件目的
使用Canvas绘制交互式知识图谱，展示学科核心概念及其逻辑关系。

## 布局结构

```
┌─────────────────────────────────────┐
│  🔍 搜索知识点...                    │
│                                     │
│       概念A (重要度5)               │
│      /      \                      │
│ 概念B (3)  概念C (4)               │
│     \       /                      │
│      概念D (2)                     │
│                                     │
│  点击节点弹出详情气泡               │
└─────────────────────────────────────┘
```

## 组件属性

```typescript
@Component
export struct KnowledgeGraph {
  @Prop nodes: GraphNode[];
  @Prop edges: GraphEdge[];
  @Prop width: number = 360;
  @Prop height: number = 400;

  @State selectedNode: GraphNode | null = null;
  @State searchKeyword: string = '';
  @State highlightedNodes: Set<string> = new Set();

  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D();
  private scale: number = 1;
  private offsetX: number = 0;
  private offsetY: number = 0;
}
```

## 绘制实现

```typescript
@Component
export struct KnowledgeGraph {
  build() {
    Column() {
      // 搜索栏
      Row() {
        TextInput({ placeholder: '搜索知识点...' })
          .onChange((val: string) => this.searchNode(val));
      }
      .padding(8)
      .width('100%')

      // 图谱画布
      Stack() {
        Canvas(this.ctx)
          .width(this.width)
          .height(this.height)
          .onReady(() => this.drawGraph())
          .onDraw(() => this.drawGraph())
          .onClick((event: ClickEvent) => this.handleClick(event));

        // 选中节点的详情气泡
        if (this.selectedNode) {
          NodeDetailPopup({
            node: this.selectedNode,
            onClose: () => this.selectedNode = null
          });
        }
      }
    }
  }

  drawGraph(): void {
    const ctx = this.ctx;
    const cw = this.width;
    const ch = this.height;
    ctx.clearRect(0, 0, cw, ch);

    // 1. 绘制连线
    this.edges.forEach(edge => {
      const from = this.nodes.find(n => n.id === edge.from);
      const to = this.nodes.find(n => n.id === edge.to);
      if (!from || !to) return;

      ctx.beginPath();
      ctx.moveTo(from.x, from.y);
      ctx.lineTo(to.x, to.y);
      ctx.strokeStyle = this.isHighlighted(edge) ? '#2563EB' : '#D1D5DB';
      ctx.lineWidth = this.isHighlighted(edge) ? 2.5 : 1.5;
      ctx.stroke();

      // 关系标签
      const mx = (from.x + to.x) / 2;
      const my = (from.y + to.y) / 2;
      ctx.font = '10px sans-serif';
      ctx.fillStyle = '#6B7280';
      ctx.textAlign = 'center';
      ctx.fillText(edge.label, mx, my - 4);
    });

    // 2. 绘制节点
    this.nodes.forEach(node => {
      const isHighlighted = this.highlightedNodes.has(node.id);
      const isSelected = this.selectedNode?.id === node.id;

      ctx.beginPath();
      ctx.arc(node.x, node.y, node.radius, 0, Math.PI * 2);
      ctx.fillStyle = isHighlighted ? '#2563EB' :
                      isSelected ? '#F59E0B' : '#3B82F6';
      ctx.fill();

      // 节点标签
      ctx.fillStyle = '#FFFFFF';
      ctx.font = `${Math.max(10, node.radius * 0.5)}px sans-serif`;
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText(node.label, node.x, node.y);
    });
  }

  isHighlighted(edge: GraphEdge): boolean {
    return this.highlightedNodes.has(edge.from) ||
           this.highlightedNodes.has(edge.to);
  }

  handleClick(event: ClickEvent): void {
    const x = event.x;
    const y = event.y;
    // 检测点击是否落在某个节点上
    for (const node of this.nodes) {
      const dx = x - node.x;
      const dy = y - node.y;
      if (dx * dx + dy * dy < node.radius * node.radius) {
        this.selectedNode = node;
        return;
      }
    }
    this.selectedNode = null;
  }

  searchNode(keyword: string): void {
    this.searchKeyword = keyword;
    this.highlightedNodes.clear();
    if (!keyword) {
      this.drawGraph();
      return;
    }
    this.nodes.forEach(node => {
      if (node.label.includes(keyword) ||
          node.description.includes(keyword)) {
        this.highlightedNodes.add(node.id);
      }
    });
    this.drawGraph();
  }
}
```

## 布局算法（力导向）

```typescript
// 简单力导向布局，初始未定位时使用
export function layoutGraph(nodes: GraphNode[], edges: GraphEdge[],
  width: number, height: number): void {

  const centerX = width / 2;
  const centerY = height / 2;
  const iterations = 100;

  // 初始化位置
  nodes.forEach((node, i) => {
    const angle = (2 * Math.PI * i) / nodes.length;
    node.x = centerX + 150 * Math.cos(angle);
    node.y = centerY + 150 * Math.sin(angle);
  });

  // 迭代计算
  for (let iter = 0; iter < iterations; iter++) {
    // 排斥力 (库伦定律)
    nodes.forEach((a, i) => {
      nodes.forEach((b, j) => {
        if (i >= j) return;
        const dx = b.x - a.x;
        const dy = b.y - a.y;
        const dist = Math.max(1, Math.sqrt(dx * dx + dy * dy));
        const force = 5000 / (dist * dist);
        a.x -= (force * dx) / dist;
        a.y -= (force * dy) / dist;
        b.x += (force * dx) / dist;
        b.y += (force * dy) / dist;
      });
    });

    // 吸引力 (胡克定律) - 沿边
    edges.forEach(edge => {
      const from = nodes.find(n => n.id === edge.from);
      const to = nodes.find(n => n.id === edge.to);
      if (!from || !to) return;
      const dx = to.x - from.x;
      const dy = to.y - from.y;
      const dist = Math.sqrt(dx * dx + dy * dy);
      const force = (dist - 120) * 0.01;  // 期望距离120
      from.x += (force * dx) / dist;
      from.y += (force * dy) / dist;
      to.x -= (force * dx) / dist;
      to.y -= (force * dy) / dist;
    });

    // 中心引力
    nodes.forEach(node => {
      node.x += (centerX - node.x) * 0.01;
      node.y += (centerY - node.y) * 0.01;
    });
  }
}
```

## 完成标准

- [ ] 节点和连线正确绘制
- [ ] 点击节点弹出详情
- [ ] 搜索功能高亮匹配节点
- [ ] 力导向布局算法工作
- [ ] 支持手势缩放/平移（可选）


## 完整 Props / Events 清单

### @Prop 输入属性

| 属性名 | 类型 | 必填 | 默认值 | 说明 |
|-------|------|------|-------|------|
| nodes | GraphNode[] | 是 | [] | 图谱节点数组 |
| edges | GraphEdge[] | 是 | [] | 图谱边数组 |
| width | number | 否 | 360 | 画布宽度 (vp) |
| height | number | 否 | 400 | 画布高度 (vp) |
| nodeColor | string | 否 | '#3B82F6' | 节点默认颜色 |
| highlightColor | string | 否 | '#2563EB' | 搜索高亮颜色 |
| showSearch | boolean | 否 | true | 是否显示搜索栏 |
| animated | boolean | 否 | true | 是否开启动画 |

### 事件回调

| 回调名 | 签名 | 说明 |
|-------|------|------|
| onNodeClick | `(node: GraphNode) => void` | 点击节点 |
| onNodeDoubleClick | `(node: GraphNode) => void` | 双击节点（可选） |
| onSearch | `(keyword: string) => void` | 搜索回调 |

### 内部 @State

| 状态变量 | 类型 | 初始值 | 说明 |
|---------|------|--------|------|
| selectedNode | GraphNode \| null | null | 当前选中节点 |
| highlightedIds | string[] | [] | 高亮节点ID |
| searchKeyword | string | '' | 搜索关键词 |
| scale | number | 1.0 | 缩放比例 |
| isDragging | boolean | false | 是否拖拽中 |

### 边界情况

| 场景 | 表现 |
|------|------|
| nodes 为空数组 | 显示"暂无知识图谱数据"占位 |
| nodes 只有一个节点 | 居中显示 |
| edges 为空 | 只画节点，无连线 |
| 搜索无匹配 | 所有节点半透明 |
| Canvas onReady 失败 | 显示"图谱绘制失败"提示 |
