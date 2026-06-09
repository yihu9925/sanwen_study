// 知识图谱可视化组件 - 支持拖动和缩放
import { KnowledgeGraph, GraphNode, GraphEdge } from '../models/KnowledgeGraph';

@Component
export struct KnowledgeGraphView {
  @Prop graph: KnowledgeGraph = { nodes: [], edges: [] };
  @Prop forceRedraw: number = 0;  // 用于检测图谱数据变化
  @State selectedNode: GraphNode | null = null;
  @State zoomScale: number = 1.0;
  @State offsetX: number = 0;
  @State offsetY: number = 0;
  private canvasWidth: number = 350;
  private canvasHeight: number = 350;
  private lastTouchX: number = 0;
  private lastTouchY: number = 0;
  private isDragging: boolean = false;
  private lastPinchDist: number = 0;
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  aboutToAppear(): void {
    this.offsetX = this.canvasWidth / 2;
    this.offsetY = this.canvasHeight / 2;
  }

  build() {
    Column() {
      Row() {
        Text('知识图谱')
          .fontSize(18)
          .fontWeight(FontWeight.Bold);
        Text('节点: ' + this.graph.nodes.length)
          .fontSize(12)
          .fontColor('#999999')
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
        .width(this.canvasWidth)
        .height(this.canvasHeight) {
        Canvas(this.context)
          .key('kg_' + this.forceRedraw)
          .width(this.canvasWidth)
          .height(this.canvasHeight)
          .backgroundColor('#FAFAFA')
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
            Text('-').fontSize(22).fontWeight(FontWeight.Bold).fontColor('#333333');
          }
            .width(40)
            .height(40)
            .borderRadius(20)
            .backgroundColor('#E0E0E0')
            .onClick(() => {
              let newScale = this.zoomScale * 0.7;
              if (newScale < 0.3) { newScale = 0.3; }
              this.zoomScale = newScale;
              this.drawGraph();
            });
        }
        .width(44)
        .alignItems(HorizontalAlign.Center)
        .position({ x: this.canvasWidth - 56, y: this.canvasHeight - 130 });
      }

      if (this.selectedNode) {
        this.NodeDetailCard();
      }
      this.LegendCard();
    }
    .width('100%')
    .backgroundColor(Color.White)
    .borderRadius(12);
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
      if (dist <= node.radius * this.zoomScale + 10) {
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
        .fontColor('#666666')
        .margin({ top: 8 });

      Row() {
        Text('重要度: ' + (this.selectedNode?.importance || 0))
          .fontSize(12)
          .fontColor('#999999');
        Text('子节点: ' + (this.selectedNode?.children?.length || 0))
          .fontSize(12)
          .fontColor('#999999')
          .margin({ left: 16 });
      }
      .margin({ top: 8 });
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(12)
    .backgroundColor('#F5F5F5')
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

    this.context.clearRect(0, 0, this.canvasWidth, this.canvasHeight);
    this.context.save();
    this.context.translate(this.offsetX, this.offsetY);
    this.context.scale(this.zoomScale, this.zoomScale);

    // Draw edges
    this.context.strokeStyle = '#E5E5E5';
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
          this.context.fillStyle = '#999999';
          this.context.font = '10px sans-serif';
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

      this.context.fillStyle = '#333333';
      this.context.font = '12px sans-serif';
      this.context.textAlign = 'center';
      this.context.fillText(node.label, node.x, node.y + node.radius + 15);
    }

    this.context.restore();
  }
}
