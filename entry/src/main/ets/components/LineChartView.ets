import { UiStyle, StyleColors } from '../utils/UiStyle';

interface ChartPoint {
  x: number;
  y: number;
  idx: number;
}

@Component
export struct LineChartView {
  @StorageLink('themeMode') themeMode: string = 'auto';
  @StorageLink('uiStyle') uiStyle: string = 'default';
  @Prop chartTitle: string = '';
  @Prop data: number[] = [];
  @Prop chartVersion: number = 0;

  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private dayLabels: string[] = ['一', '二', '三', '四', '五', '六', '日'];

  colors(): StyleColors {
    return UiStyle.getColors(this.uiStyle || 'default', this.themeMode === 'dark');
  }

  build() {
    Column() {
      Text(this.chartTitle)
        .fontSize(14).fontWeight(FontWeight.Bold)
        .width('100%').padding({ left: 4, bottom: 8 });
      Canvas(this.context)
        .key('line_' + this.chartVersion)
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
    const maxVal = Math.max(...this.data, 30);
    const yMax = Math.ceil(maxVal / 30) * 30;

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

    const pts: ChartPoint[] = [];
    for (let i = 0; i < 7; i++) {
      const yVal = this.data[i] || 0;
      if (yVal <= 0) continue;
      const x = padLeft + (chartW / 6) * i;
      const y = padTop + chartH - (yVal / yMax) * chartH;
      pts.push({ x, y, idx: i });
    }
    if (pts.length === 0) return;

    let segStart = 0;
    for (let s = 1; s <= pts.length; s++) {
      const end = s === pts.length;
      const gap = !end && (pts[s].idx - pts[s - 1].idx > 1);
      if (end || gap) {
        const seg = pts.slice(segStart, s);
        if (seg.length >= 2) {
          el.beginPath();
          el.moveTo(seg[0].x, seg[0].y);
          for (let k = 1; k < seg.length; k++) {
            const cp1x = (seg[k - 1].x + seg[k].x) / 2;
            const cp1y = seg[k - 1].y;
            const cp2x = (seg[k - 1].x + seg[k].x) / 2;
            const cp2y = seg[k].y;
            el.bezierCurveTo(cp1x, cp1y, cp2x, cp2y, seg[k].x, seg[k].y);
          }
          el.strokeStyle = c.accent;
          el.lineWidth = 3;
          el.stroke();

          el.lineTo(seg[seg.length - 1].x, padTop + chartH);
          el.lineTo(seg[0].x, padTop + chartH);
          el.closePath();
          const grad = el.createLinearGradient(0, padTop, 0, padTop + chartH);
          grad.addColorStop(0, c.accent + '50');
          grad.addColorStop(1, c.accent + '08');
          el.fillStyle = grad;
          el.fill();
        } else {
          el.beginPath();
          el.arc(seg[0].x, seg[0].y, 5, 0, Math.PI * 2);
          el.fillStyle = c.accent;
          el.fill();
        }
        segStart = s;
      }
    }

    for (const pt of pts) {
      el.beginPath();
      el.arc(pt.x, pt.y, 5, 0, Math.PI * 2);
      el.fillStyle = c.cardBg;
      el.fill();
      el.strokeStyle = c.accent;
      el.lineWidth = 2.5;
      el.stroke();
    }

    for (let i = 0; i < 7; i++) {
      el.fillStyle = c.textSecondary;
      el.font = '39px sans-serif';
      el.textAlign = 'center';
      el.fillText(this.dayLabels[i], padLeft + (chartW / 6) * i, elH - 16);
    }
  }
}
