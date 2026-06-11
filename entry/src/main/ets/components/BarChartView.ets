import { UiStyle, StyleColors } from '../utils/UiStyle';

interface BarItem {
  value: number;
  label: string;
}

@Component
export struct BarChartView {
  @StorageLink('themeMode') themeMode: string = 'auto';
  @StorageLink('uiStyle') uiStyle: string = 'default';
  @Prop chartTitle: string = '';
  @Prop data: number[] = [];
  @Prop labels: string[] = [];
  @Prop chartVersion: number = 0;

  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  colors(): StyleColors {
    return UiStyle.getColors(this.uiStyle || 'default', this.themeMode === 'dark');
  }

  build() {
    Column() {
      Text(this.chartTitle)
        .fontSize(14).fontWeight(FontWeight.Bold)
        .width('100%').padding({ left: 4, bottom: 8 });
      Canvas(this.context)
        .key('bar_' + this.chartVersion)
        .width('100%').height(300)
        .onReady(() => { this.drawChart(); });
    }
    .width('100%').padding(16);
  }

  drawChart(): void {
    const el = this.context;
    const elW = el.width;
    const elH = el.height;
    if (elW <= 0 || elH <= 0) return;
    const padTop = 24;
    const padRight = 16;
    const padBottom = 64;
    const padLeft = 70;
    const chartW = elW - padLeft - padRight;
    const chartH = elH - padTop - padBottom;
    const c = this.colors();
    const filteredData: BarItem[] = [];
    for (let i = 0; i < this.data.length; i++) {
      if (this.data[i] > 0) {
        filteredData.push({ value: this.data[i], label: this.labels[i] || '' });
      }
    }
    const count = filteredData.length;
    if (count === 0) return;
    const maxVal = Math.max(...filteredData.map((d) => d.value), 20);
    const yMax = Math.ceil(maxVal / 20) * 20;

    el.clearRect(0, 0, elW, elH);

    el.strokeStyle = c.divider;
    el.lineWidth = 1;
    for (let i = 0; i <= 4; i++) {
      const y = padTop + (chartH / 4) * i;
      el.beginPath();
      el.moveTo(padLeft, y);
      el.lineTo(elW - padRight, y);
      el.stroke();
      el.fillStyle = c.textSecondary;
      el.font = '36px sans-serif';
      el.textAlign = 'right';
      el.fillText(Math.round(yMax - (yMax / 4) * i) + '', padLeft - 12, y + 12);
    }

    const barGap = chartW / count;
    const barW = Math.min(barGap * 0.6, 50);

    for (let i = 0; i < count; i++) {
      const barH = (filteredData[i].value / yMax) * chartH;
      const x = padLeft + barGap * i + (barGap - barW) / 2;
      const y = padTop + chartH - barH;

      el.beginPath();
      const r = 4;
      el.moveTo(x + r, y);
      el.lineTo(x + barW - r, y);
      el.arcTo(x + barW, y, x + barW, y + r, r);
      el.lineTo(x + barW, padTop + chartH);
      el.lineTo(x, padTop + chartH);
      el.lineTo(x, y + r);
      el.arcTo(x, y, x + r, y, r);
      el.closePath();
      el.fillStyle = i === 0 ? c.accent : c.accentLight;
      el.fill();

      el.fillStyle = c.textSecondary;
      el.font = '36px sans-serif';
      el.textAlign = 'center';
      el.fillText(filteredData[i].label, x + barW / 2, elH - 16);
    }
  }
}
