// 知识图谱可视化组件
import { KnowledgeGraph, GraphNode, GraphEdge } from '../models/KnowledgeGraph';

@Component
export struct KnowledgeGraphView {
  @Prop graph: KnowledgeGraph = { nodes: [], edges: [] };
  @State selectedNode: GraphNode | null = null;
  private canvasWidth: number = 350;
  private canvasHeight: number = 350;
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  build() {
    Column() {
      // 标题
      Row() {
        Text('知识图谱')
          .fontSize(18)
          .fontWeight(FontWeight.Bold);
        
        Text(`节点: ${this.graph.nodes.length}`)
          .fontSize(12)
          .fontColor('#999999')
          .margin({ left: 8 });
      }
      .width('100%')
      .padding(16);

      // Canvas绑制区域
      Canvas(this.context)
        .width(this.canvasWidth)
        .height(this.canvasHeight)
        .backgroundColor('#FAFAFA')
        .borderRadius(8)
        .onReady(() => {
          this.drawGraph();
        });

      // 选中节点详情
      if (this.selectedNode) {
        this.NodeDetailCard();
      }

      // 图例
      this.LegendCard();
    }
    .width('100%')
    .backgroundColor(Color.White)
    .borderRadius(12);
  }

  @Builder
  NodeDetailCard(): void {
    Column() {
      Row() {
        Text('选中节点')
          .fontSize(14)
          .fontWeight(FontWeight.Bold);
      }
      .width('100%');

      Column() {
        Text(this.selectedNode?.label || '')
          .fontSize(16)
          .fontWeight(FontWeight.Bold);

        Text(this.selectedNode?.description || '暂无描述')
          .fontSize(12)
          .fontColor('#666666')
          .margin({ top: 8 });

        Row() {
          Text(`重要度: ${this.selectedNode?.importance || 0}`)
            .fontSize(12)
            .fontColor('#999999');

          Text(`子节点: ${this.selectedNode?.children?.length || 0}`)
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
    .width('100%')
    .padding(16);
  }

  @Builder
  LegendCard(): void {
    Row() {
      Row() {
        Circle()
          .width(12)
          .height(12)
          .fill('#007DFF');
        Text('核心概念')
          .fontSize(12)
          .margin({ left: 4 });
      }

      Row() {
        Circle()
          .width(12)
          .height(12)
          .fill('#52C41A');
        Text('子概念')
          .fontSize(12)
          .margin({ left: 4 });
      }
      .margin({ left: 16 });

      Row() {
        Circle()
          .width(12)
          .height(12)
          .fill('#FAAD14');
        Text('关联概念')
          .fontSize(12)
          .margin({ left: 4 });
      }
      .margin({ left: 16 });
    }
    .width('100%')
    .padding(16);
  }

  private drawGraph(): void {
    if (!this.context || this.graph.nodes.length === 0) {
      return;
    }

    // 清空画布
    this.context.clearRect(0, 0, this.canvasWidth, this.canvasHeight);

    // 绘制边
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

        // 绘制边标签
        if (edge.label) {
          const midX = (fromNode.x + toNode.x) / 2;
          const midY = (fromNode.y + toNode.y) / 2;
          this.context.fillStyle = '#999999';
          this.context.font = '10px sans-serif';
          this.context.fillText(edge.label, midX, midY);
        }
      }
    }

    // 绘制节点
    for (const node of this.graph.nodes) {
      // 根据重要度选择颜色
      if (node.importance >= 5) {
        this.context.fillStyle = '#007DFF';
      } else if (node.importance >= 3) {
        this.context.fillStyle = '#52C41A';
      } else {
        this.context.fillStyle = '#FAAD14';
      }

      // 绘制圆形节点
      this.context.beginPath();
      this.context.arc(node.x, node.y, node.radius, 0, 2 * Math.PI);
      this.context.fill();

      // 绘制节点标签
      this.context.fillStyle = '#333333';
      this.context.font = '12px sans-serif';
      this.context.textAlign = 'center';
      this.context.fillText(node.label, node.x, node.y + node.radius + 15);
    }
  }
}
