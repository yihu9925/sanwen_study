// 雷达图可视化组件 - 布鲁姆分类学六维度
import { RadarData } from '../models/Course';
import { UiStyle, StyleColors } from '../utils/UiStyle';

@Component
export struct RadarChartView {
  @StorageLink('themeMode') themeMode: string = 'auto';
  @StorageLink('uiStyle') uiStyle: string = 'default';

  colors(): StyleColors {
    return UiStyle.getColors(this.uiStyle || 'default', this.themeMode === 'dark');
  }
  @Prop radarData: RadarData = {
    remember: 0,
    understand: 0,
    apply: 0,
    analyze: 0,
    evaluate: 0,
    create: 0
  };
  @Prop forceRedraw: number = 0;
  private canvasSize: number = 340;
  private centerX: number = 170;
  private centerY: number = 170;
  private radius: number = 120;
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  // 六个维度的标签
  private labels: string[] = ['记忆', '理解', '应用', '分析', '评价', '创造'];
  private chartColors: string[] = ['#007DFF', '#52C41A', '#FAAD14', '#F5222D', '#722ED1', '#13C2C2'];

  build() {
    Column() {
      // 标题
      Row() {
        Text('布鲁姆分类学能力图谱')
          .fontSize(18)
          .fontWeight(FontWeight.Bold);
      }
      .width('100%')
      .padding(16);

      // Canvas绑制区域（使用forceRedraw奇偶切换两个Canvas实例强制刷新）
      Canvas(this.context)
          .key('radar_' + this.forceRedraw)
          .width(this.canvasSize)
          .height(this.canvasSize)
          .backgroundColor(this.colors().pageBg)
          .borderRadius(8)
          .onReady(() => {
            this.drawRadarChart();
          });

      // 维度详情（无数据时隐藏）
      if (this.hasData()) {
        this.DimensionDetails();
      }

      // 图例说明
      this.LegendCard();
    }
    .width('100%')
    .backgroundColor(this.colors().cardBg)
    .borderRadius(12);
  }

  @Builder
  DimensionDetails(): void {
    Column() {
      Row() {
        Text('维度详情')
          .fontSize(14)
          .fontWeight(FontWeight.Bold);
      }
      .width('100%');

      Grid() {
        GridItem() {
          this.DimensionItem('记忆', this.radarData.remember, this.chartColors[0], '知识的识记和回忆');
        }
        GridItem() {
          this.DimensionItem('理解', this.radarData.understand, this.chartColors[1], '把握知识间的联系');
        }
        GridItem() {
          this.DimensionItem('应用', this.radarData.apply, this.chartColors[2], '将知识应用于新情境');
        }
        GridItem() {
          this.DimensionItem('分析', this.radarData.analyze, this.chartColors[3], '分解和剖析知识结构');
        }
        GridItem() {
          this.DimensionItem('评价', this.radarData.evaluate, this.chartColors[4], '做出价值判断');
        }
        GridItem() {
          this.DimensionItem('创造', this.radarData.create, this.chartColors[5], '产生新的思想或产品');
        }
      }
      .columnsTemplate('1fr 1fr')
      .rowsTemplate('1fr 1fr 1fr')
      .width('100%')
      .height(180)
      .margin({ top: 12 });
    }
    .width('100%')
    .padding(16);
  }

  @Builder
  DimensionItem(label: string, value: number, color: string, desc: string): void {
    Column() {
      Row() {
        Circle()
          .width(8)
          .height(8)
          .fill(color);
        
        Text(label)
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .margin({ left: 4 });
      }

      Text(`${value}%`)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
        .margin({ top: 4 });

      Text(desc)
        .fontSize(10)
        .fontColor(this.colors().textTertiary)
        .margin({ top: 2 });
    }
    .width('100%')
    .padding(8);
  }

  @Builder
  LegendCard(): void {
    Column() {
      Text('布鲁姆分类学将认知领域分为六个层次，从低到高依次为：记忆、理解、应用、分析、评价、创造。')
        .fontSize(12)
        .fontColor(this.colors().textSecondary);
    }
    .width('100%')
    .padding(16)
    .backgroundColor(this.colors().cardBg)
    .borderRadius(8)
    .margin({ top: 8, left: 16, right: 16, bottom: 16 });
  }

  private hasData(): boolean {
    return this.radarData.remember > 0 || this.radarData.understand > 0 ||
      this.radarData.apply > 0 || this.radarData.analyze > 0 ||
      this.radarData.evaluate > 0 || this.radarData.create > 0;
  }

  private drawRadarChart(): void {
    if (!this.context) {
      return;
    }

    const c = this.colors();

    this.context.clearRect(0, 0, this.canvasSize, this.canvasSize);

    if (!this.hasData()) {
      this.context.fillStyle = c.textTertiary;
      this.context.font = '36px sans-serif';
      this.context.textAlign = 'center';
      this.context.fillText('完成测评后查看能力图谱', this.centerX, this.centerY);
      return;
    }

    const values = [
      this.radarData.remember,
      this.radarData.understand,
      this.radarData.apply,
      this.radarData.analyze,
      this.radarData.evaluate,
      this.radarData.create
    ];

    // 绘制背景网格
    this.drawBackgroundGrid();

    // 绘制数据区域
    this.drawDataArea(values);

    // 绘制标签
    this.drawLabels();
  }

  private drawBackgroundGrid(): void {
    const levels = [20, 40, 60, 80, 100];
    const c = this.colors();
    const gridColor = c.divider;
    
    for (const level of levels) {
      this.context.beginPath();
      this.context.strokeStyle = gridColor;
      this.context.lineWidth = 1;

      for (let i = 0; i < 6; i++) {
        const angle = (Math.PI * 2 * i) / 6 - Math.PI / 2;
        const x = this.centerX + Math.cos(angle) * this.radius * (level / 100);
        const y = this.centerY + Math.sin(angle) * this.radius * (level / 100);

        if (i === 0) {
          this.context.moveTo(x, y);
        } else {
          this.context.lineTo(x, y);
        }
      }

      this.context.closePath();
      this.context.stroke();
    }

    // 绘制轴线
    for (let i = 0; i < 6; i++) {
      const angle = (Math.PI * 2 * i) / 6 - Math.PI / 2;
      const x = this.centerX + Math.cos(angle) * this.radius;
      const y = this.centerY + Math.sin(angle) * this.radius;

      this.context.beginPath();
      this.context.moveTo(this.centerX, this.centerY);
      this.context.lineTo(x, y);
      this.context.strokeStyle = gridColor;
      this.context.stroke();
    }
  }

  private drawDataArea(values: number[]): void {
    this.context.beginPath();
    this.context.fillStyle = 'rgba(0, 125, 255, 0.3)';
    this.context.strokeStyle = '#007DFF';
    this.context.lineWidth = 2;

    for (let i = 0; i < 6; i++) {
      const angle = (Math.PI * 2 * i) / 6 - Math.PI / 2;
      const value = values[i] / 100;
      const x = this.centerX + Math.cos(angle) * this.radius * value;
      const y = this.centerY + Math.sin(angle) * this.radius * value;

      if (i === 0) {
        this.context.moveTo(x, y);
      } else {
        this.context.lineTo(x, y);
      }
    }

    this.context.closePath();
    this.context.fill();
    this.context.stroke();

    // 绘制数据点
    for (let i = 0; i < 6; i++) {
      const angle = (Math.PI * 2 * i) / 6 - Math.PI / 2;
      const value = values[i] / 100;
      const x = this.centerX + Math.cos(angle) * this.radius * value;
      const y = this.centerY + Math.sin(angle) * this.radius * value;

      this.context.beginPath();
      this.context.arc(x, y, 4, 0, 2 * Math.PI);
      this.context.fillStyle = this.chartColors[i];
      this.context.fill();
    }
  }

  private drawLabels(): void {
    const c = this.colors();
    this.context.fillStyle = c.textPrimary;
    this.context.font = 'bold 18px sans-serif';
    this.context.textAlign = 'center';
    this.context.shadowColor = this.themeMode === 'dark' ? '#000000' : '#FFFFFF';
    this.context.shadowBlur = 3;

    for (let i = 0; i < 6; i++) {
      const angle = (Math.PI * 2 * i) / 6 - Math.PI / 2;
      const x = this.centerX + Math.cos(angle) * (this.radius + 28);
      const y = this.centerY + Math.sin(angle) * (this.radius + 28);

      this.context.shadowBlur = 0;
      this.context.fillText(this.labels[i], x, y);
    }
  }
}
