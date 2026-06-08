# RadarChart - 能力雷达图组件

## 组件目的
使用Canvas绘制六边形能力雷达图，展示用户在6个认知维度的评分。

## 布局结构

```
       记忆
      /    \
   理解    应用
    |   ⬤   |
   分析    评价
      \    /
       创造
```

## 组件属性

```typescript
@Component
export struct RadarChart {
  @Prop data: RadarData;       // 6维数据 0~100
  @Prop size: number = 180;    // 画布尺寸 vp
  @Prop showLabels: boolean = true;
  @Prop animated: boolean = true;  // 是否开启动画

  private canvasWidth: number = 0;
  private canvasHeight: number = 0;
}
```

## 数据类型

```typescript
export interface RadarData {
  remember: number;      // 记忆
  understand: number;    // 理解
  apply: number;         // 应用
  analyze: number;       // 分析
  evaluate: number;      // 评价
  create: number;        // 创造
}
```

## Canvas绘制实现

```typescript
@Component
export struct RadarChart {
  @State currentData: RadarData | null = null;
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D();

  aboutToAppear(): void {
    if (this.animated) {
      this.animateData();
    } else {
      this.currentData = this.data;
    }
  }

  animateData(): void {
    // 从0逐步增加到目标值（使用动画帧）
    let progress = 0;
    const animate = () => {
      progress += 0.05;
      if (progress >= 1) {
        this.currentData = this.data;
        return;
      }
      this.currentData = {
        remember: this.data.remember * progress,
        understand: this.data.understand * progress,
        apply: this.data.apply * progress,
        analyze: this.data.analyze * progress,
        evaluate: this.data.evaluate * progress,
        create: this.data.create * progress,
      };
      setTimeout(animate, 16); // ~60fps
    };
    animate();
  }

  build() {
    Canvas(this.ctx)
      .width(this.size)
      .height(this.size)
      .onReady(() => this.draw())
      .onDraw(() => this.draw());
  }

  draw(): void {
    const ctx = this.ctx;
    const cw = this.size;
    const ch = this.size;
    const cx = cw / 2;
    const cy = ch / 2;
    const radius = Math.min(cx, cy) * 0.7;

    ctx.clearRect(0, 0, cw, ch);

    const dimensions = ['remember', 'understand', 'apply',
      'analyze', 'evaluate', 'create'];
    const labels = ['记忆', '理解', '应用', '分析', '评价', '创造'];
    const angles = dimensions.map((_, i) =>
      (Math.PI * 2 / 6) * i - Math.PI / 2
    );

    // 绘制背景六边形网格（5层）
    for (let level = 1; level <= 5; level++) {
      const r = (radius / 5) * level;
      ctx.beginPath();
      angles.forEach((angle, i) => {
        const x = cx + r * Math.cos(angle);
        const y = cy + r * Math.sin(angle);
        i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y);
      });
      ctx.closePath();
      ctx.strokeStyle = '#E5E7EB';
      ctx.lineWidth = 1;
      ctx.stroke();
    }

    // 绘制对角线
    angles.forEach(angle => {
      ctx.beginPath();
      ctx.moveTo(cx, cy);
      ctx.lineTo(cx + radius * Math.cos(angle), cy + radius * Math.sin(angle));
      ctx.strokeStyle = '#E5E7EB';
      ctx.stroke();
    });

    // 绘制数据区域
    const data = this.currentData || this.data;
    const dataValues: number[] = dimensions.map(d => (data as RadarData)[d as keyof RadarData] || 0);

    // 数据多边形
    ctx.beginPath();
    angles.forEach((angle, i) => {
      const r = (dataValues[i] / 100) * radius;
      const x = cx + r * Math.cos(angle);
      const y = cy + r * Math.sin(angle);
      i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y);
    });
    ctx.closePath();
    ctx.fillStyle = 'rgba(37, 99, 235, 0.2)';
    ctx.fill();
    ctx.strokeStyle = '#2563EB';
    ctx.lineWidth = 2;
    ctx.stroke();

    // 数据点
    angles.forEach((angle, i) => {
      const r = (dataValues[i] / 100) * radius;
      const x = cx + r * Math.cos(angle);
      const y = cy + r * Math.sin(angle);
      ctx.beginPath();
      ctx.arc(x, y, 4, 0, Math.PI * 2);
      ctx.fillStyle = '#2563EB';
      ctx.fill();
    });

    // 标签
    if (this.showLabels) {
      ctx.font = '12px sans-serif';
      ctx.fillStyle = '#6B7280';
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      angles.forEach((angle, i) => {
        const labelR = radius + 20;
        const x = cx + labelR * Math.cos(angle);
        const y = cy + labelR * Math.sin(angle);
        ctx.fillText(labels[i], x, y);
        // 在标签下方显示分值
        ctx.font = '10px sans-serif';
        ctx.fillStyle = '#2563EB';
        ctx.fillText(`${Math.round(dataValues[i])}`, x, y + 14);
        ctx.font = '12px sans-serif';
      });
    }
  }
}
```

## 尺寸适配

| 容器 | size参数 | 用途 |
|------|---------|------|
| 首页课程卡片 | 120vp | 迷你雷达图 |
| 课程详情页 | 200vp | 完整雷达图 |
| 个人中心 | 240vp | 大尺寸展示 |
| 测评报告 | 280vp | 详细报告图 |


## 完整 Props / Events / States 清单

### @Prop 输入属性

| 属性名 | 类型 | 必填 | 默认值 | 说明 |
|-------|------|------|-------|------|
| data | RadarData | 是 | — | 6维能力评分 (0~100) |
| size | number | 否 | 180 | 画布尺寸 (vp) |
| showLabels | boolean | 否 | true | 是否显示维度标签 |
| showValues | boolean | 否 | true | 是否显示分值 |
| animated | boolean | 否 | true | 是否开启动画 |
| fillColor | string | 否 | 'rgba(37,99,235,0.2)' | 数据区域填充色 |
| strokeColor | string | 否 | '#2563EB' | 数据区域边框色 |
| gridColor | string | 否 | '#E5E7EB' | 网格颜色 |
| gridLevels | number | 否 | 5 | 网格层数 |

### 事件回调

| 回调名 | 签名 | 说明 |
|-------|------|------|
| onDimensionClick | `(dimension: string, value: number) => void` | 点击某维度标签 |

### 内部 @State

| 状态变量 | 类型 | 初始值 | 说明 |
|---------|------|--------|------|
| currentData | RadarData \| null | null | 动画过程中当前帧数据 |
| animationProgress | number | 0 | 动画进度 (0~1) |
| isAnimating | boolean | false | 是否正在动画 |

### 边界情况

| 场景 | 表现 |
|------|------|
| 所有维度为0 | 空白六边形，数据线收缩到中心 |
| 某维度 > 100 | 自动截断到100 |
| 某维度 < 0 | 自动修正为0 |
| size < 60 | 不绘制标签（空间不足） |
