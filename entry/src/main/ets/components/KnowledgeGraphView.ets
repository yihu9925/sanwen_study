// 知识图谱可视化组件 - 支持拖动和缩放
import { KnowledgeGraph, GraphNode, GraphEdge } from '../models/KnowledgeGraph';
import { UiStyle, StyleColors } from '../utils/UiStyle';

@Component
export struct KnowledgeGraphView {
  @StorageLink('themeMode') themeMode: string = 'auto';
  @StorageLink('uiStyle') uiStyle: string = 'default';

  colors(): StyleColors {
    return UiStyle.getColors(this.uiStyle || 'default', this.themeMode === 'dark');
  }
  @Prop graph: KnowledgeGraph = { nodes: [], edges: [] };
  @Prop @Watch('onForceRedrawChange') forceRedraw: number = 0;
  @Prop @Watch('onFocusNodeIdChange') focusNodeId: string = '';
  @State selectedNode: GraphNode | null = null;
  @State zoomScale: number = 1.0;
  @State offsetX: number = 0;
  @State offsetY: number = 0;
  @State canvasWidth: number = 360;
  private canvasHeight: number = 400;
  private minCanvasSize: number = 280;
  private lastTouchX: number = 0;
  private lastTouchY: number = 0;
  private isDragging: boolean = false;
  private lastPinchDist: number = 0;
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  aboutToAppear(): void {
    this.centerOnNodes();
  }

  build() {
    Column() {
      Row() {
        Text('知识图谱')
          .fontSize(18)
          .fontWeight(FontWeight.Bold);
        Text('节点: ' + this.graph.nodes.length)
          .fontSize(12)
          .fontColor(this.colors().textTertiary)
          .margin({ left: 8 });
        Text('  |  拖动移动 · 拠缩放大')
          .fontSize(10)
          .fontColor('#CCCCCC')
          .margin({ left: 4 });
      }
      .width('100%')
      .padding(16);

      Stack()
        .hitTestBehavior(HitTestMode.Block)
        .width('100%')
        .height(this.canvasHeight)
        .onAreaChange((oldValue: Area, newValue: Area) => {
          const w: number = newValue.width as number;
          if (w > this.minCanvasSize) {
            this.canvasWidth = w;
          }
        }) {
        Canvas(this.context)
          .key('kg_' + this.forceRedraw)
          .width('100%')
          .height(this.canvasHeight)
          .backgroundColor(this.colors().pageBg)
          .borderRadius(8)
          .onReady(() => {
            this.drawGraph();
          })
          .onTouch((event: TouchEvent) => {
            this.handleTouch(event);
          });

        // 右侧缩放按钮
        Column() {
          Button() {
            Text('+').fontSize(22).fontWeight(FontWeight.Bold).fontColor(Color.White);
          }
            .width(40)
            .height(40)
            .borderRadius(20)
            .backgroundColor('#007DFF')
            .onClick(() => {
              let newScale = this.zoomScale * 1.3;
              if (newScale > 3.0) { newScale = 3.0; }
              this.zoomScale = newScale;
              this.drawGraph();
            });

          Text(Math.round(this.zoomScale * 100) + '%')
            .fontSize(11)
            .fontColor('#007DFF')
            .fontWeight(FontWeight.Bold)
            .width(40)
            .height(20)
            .textAlign(TextAlign.Center);

          Button() {
            Text('-').fontSize(22).fontWeight(FontWeight.Bold).fontColor(this.colors().textPrimary);
          }
            .width(40)
            .height(40)
            .borderRadius(20)
            .backgroundColor(this.colors().divider)
            .onClick(() => {
              let newScale = this.zoomScale * 0.7;
              if (newScale < 0.3) { newScale = 0.3; }
              this.zoomScale = newScale;
              this.drawGraph();
            });
        }
        .width(44)
        .alignItems(HorizontalAlign.Center)
        .position({ x: this.canvasWidth - 64, y: this.canvasHeight - 130 });
      }

      if (this.selectedNode) {
        this.NodeDetailCard();
      }
      this.LegendCard();
    }
    .width('100%')
    .backgroundColor(this.colors().cardBg)
    .borderRadius(12);
  }

  private onForceRedrawChange(): void {
    this.centerOnNodes();
    this.drawGraph();
  }

  private centerOnNodes(): void {
    if (this.graph.nodes.length === 0) {
      this.offsetX = this.canvasWidth / 2;
      this.offsetY = this.canvasHeight / 2;
      return;
    }

    let minX = this.graph.nodes[0].x;
    let maxX = this.graph.nodes[0].x;
    let minY = this.graph.nodes[0].y;
    let maxY = this.graph.nodes[0].y;

    for (let i = 1; i < this.graph.nodes.length; i++) {
      const node = this.graph.nodes[i];
      if (node.x < minX) { minX = node.x; }
      if (node.x > maxX) { maxX = node.x; }
      if (node.y < minY) { minY = node.y; }
      if (node.y > maxY) { maxY = node.y; }
    }

    const centerX = (minX + maxX) / 2;
    const centerY = (minY + maxY) / 2;

    this.offsetX = this.canvasWidth / 2 - centerX * this.zoomScale;
    this.offsetY = this.canvasHeight / 2 - centerY * this.zoomScale;
  }

  private onFocusNodeIdChange(): void {
    if (!this.focusNodeId || this.graph.nodes.length === 0) return;

    const node = this.graph.nodes.find(n => n.id === this.focusNodeId);
    if (!node) return;

    this.offsetX = (this.canvasWidth / 2) - node.x * this.zoomScale;
    this.offsetY = (this.canvasHeight / 2) - node.y * this.zoomScale;
    this.selectedNode = node;
    this.drawGraph();
  }

  private handleTouch(event: TouchEvent): void {
    const touches = event.touches;
    if (touches.length === 1) {
      const touch = touches[0];
      if (event.type === TouchType.Down) {
        this.isDragging = true;
        this.lastTouchX = touch.x;
        this.lastTouchY = touch.y;
      } else if (event.type === TouchType.Move && this.isDragging) {
        const dx = touch.x - this.lastTouchX;
        const dy = touch.y - this.lastTouchY;
        this.offsetX += dx;
        this.offsetY += dy;
        this.lastTouchX = touch.x;
        this.lastTouchY = touch.y;
        this.drawGraph();
      } else if (event.type === TouchType.Up) {
        if (this.isDragging) {
          const clickedNode = this.hitTest(touch.x, touch.y);
          if (clickedNode) {
            this.selectedNode = clickedNode;
          } else {
            this.selectedNode = null;
          }
        }
        this.isDragging = false;
      }
    } else if (touches.length === 2) {
      const t1 = touches[0];
      const t2 = touches[1];
      const dist = Math.sqrt(
        (t2.x - t1.x) * (t2.x - t1.x) + (t2.y - t1.y) * (t2.y - t1.y)
      );
      if (this.lastPinchDist > 0) {
        const factor = dist / this.lastPinchDist;
        let newScale = this.zoomScale * factor;
        if (newScale < 0.3) { newScale = 0.3; }
        if (newScale > 3.0) { newScale = 3.0; }
        this.zoomScale = newScale;
        this.drawGraph();
      }
      this.lastPinchDist = dist;
    }

    if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      this.lastPinchDist = 0;
      this.isDragging = false;
    }
  }

  private hitTest(tx: number, ty: number): GraphNode | null {
    for (const node of this.graph.nodes) {
      const nx = node.x * this.zoomScale + this.offsetX;
      const ny = node.y * this.zoomScale + this.offsetY;
      const dist = Math.sqrt((tx - nx) * (tx - nx) + (ty - ny) * (ty - ny));
      if (dist <= node.radius * this.zoomScale + 20) {
        return node;
      }
    }
    return null;
  }

  @Builder
  NodeDetailCard(): void {
    Column() {
      Text(this.selectedNode?.label || '')
        .fontSize(16)
        .fontWeight(FontWeight.Bold);

      Text(this.selectedNode?.description || '暂无描述')
        .fontSize(12)
        .fontColor(this.colors().textSecondary)
        .margin({ top: 8 });

      Row() {
        Text('重要度: ' + (this.selectedNode?.importance || 0))
          .fontSize(12)
          .fontColor(this.colors().textTertiary);
        Text('子节点: ' + (this.selectedNode?.children?.length || 0))
          .fontSize(12)
          .fontColor(this.colors().textTertiary)
          .margin({ left: 16 });
      }
      .margin({ top: 8 });
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(12)
    .backgroundColor(this.colors().cardBg)
    .borderRadius(8)
    .margin({ top: 8 });
  }

  @Builder
  LegendCard(): void {
    Row() {
      this.LegendItem('#007DFF', '核心概念');
      this.LegendItem('#52C41A', '子概念');
      this.LegendItem('#FAAD14', '关联概念');
    }
    .width('100%')
    .padding(16);
  }

  @Builder
  LegendItem(color: string, label: string): void {
    Row() {
      Circle().width(12).height(12).fill(color);
      Text(label).fontSize(12).margin({ left: 4 });
    }
    .margin({ left: 16 });
  }

  private drawGraph(): void {
    if (!this.context || this.graph.nodes.length === 0) {
      return;
    }

    const c = this.colors();

    this.context.clearRect(0, 0, this.canvasWidth, this.canvasHeight);
    this.context.save();
    this.context.translate(this.offsetX, this.offsetY);
    this.context.scale(this.zoomScale, this.zoomScale);

    // Draw edges
    this.context.strokeStyle = c.divider;
    this.context.lineWidth = 2;
    for (const edge of this.graph.edges) {
      const fromNode = this.graph.nodes.find(n => n.id === edge.from);
      const toNode = this.graph.nodes.find(n => n.id === edge.to);
      if (fromNode && toNode) {
        this.context.beginPath();
        this.context.moveTo(fromNode.x, fromNode.y);
        this.context.lineTo(toNode.x, toNode.y);
        this.context.stroke();

        if (edge.label) {
          const midX = (fromNode.x + toNode.x) / 2;
          const midY = (fromNode.y + toNode.y) / 2;
          this.context.fillStyle = c.textSecondary;
          this.context.font = '16px sans-serif';
          this.context.fillText(edge.label, midX, midY);
        }
      }
    }

    // Draw nodes
    for (const node of this.graph.nodes) {
      if (node.importance >= 5) {
        this.context.fillStyle = '#007DFF';
      } else if (node.importance >= 3) {
        this.context.fillStyle = '#52C41A';
      } else {
        this.context.fillStyle = '#FAAD14';
      }

      this.context.beginPath();
      this.context.arc(node.x, node.y, node.radius, 0, 2 * Math.PI);
      this.context.fill();

      this.context.fillStyle = c.textPrimary;
      this.context.font = 'bold 20px sans-serif';
      this.context.textAlign = 'center';
      this.context.fillText(node.label, node.x, node.y + node.radius + 24);
    }

    this.context.restore();
  }
}
