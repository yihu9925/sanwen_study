// 个人中心页
import { Course } from '../models/Course';
import { UserProfile } from '../models/UserProfile';
import { CourseService } from '../services/CourseService';
import { AppRouter } from '../AppRouter';
import { RadarData } from '../models/Course';

@Component
export struct PersonalCenter {
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private weeklyCtx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private subjectCtx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  @State courses: Course[] = [];
  @State archivedCourses: Course[] = [];

  aboutToAppear(): void {
    this.loadData();
  }

  async loadData(): Promise<void> {
    this.courses = await CourseService.getCoursesByUser('default_user');
    this.archivedCourses = this.courses.filter(c => c.status === 'archived');
  }

  build() {
    Column() {
      // 用户信息卡片
      this.UserInfoCard();

      // 统计卡片
      this.StatisticsCard();

      // 图表区域
      Column() {
        Canvas(this.weeklyCtx)
          .width('100%')
          .height(180)
          .backgroundColor(Color.White)
          .borderRadius(12)
          .margin({ top: 12 })
          .onReady(() => { this.drawWeeklyChart(); });
      }
      .width('100%')
      .padding({ left: 16, right: 16 });

      Column() {
        Canvas(this.subjectCtx)
          .width('100%')
          .height(200)
          .backgroundColor(Color.White)
          .borderRadius(12)
          .margin({ top: 12 })
          .onReady(() => { this.drawSubjectChart(); });
      }
      .width('100%')
      .padding({ left: 16, right: 16 });

      // 功能入口
      this.FunctionList();
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5');
  }

  onPageShow(): void {
    this.drawWeeklyChart();
    this.drawSubjectChart();
  }

  drawWeeklyChart(): void {
    const ctx = this.weeklyCtx;
    ctx.clearRect(0, 0, 350, 180);
    const days: string[] = ['\u5468\u4E00', '\u5468\u4E8C', '\u5468\u4E09', '\u5468\u56DB', '\u5468\u4E94', '\u5468\u516D', '\u5468\u65E5'];
    const hours: number[] = [2.0, 1.5, 3.0, 2.5, 1.8, 4.2, 3.5];
    let maxH = 1;
    for (let i = 0; i < hours.length; i++) { if (hours[i] > maxH) { maxH = hours[i]; } }
    const barW = 30;
    const gap = 14;
    const startX = 25;
    const bottomY = 160;
    const topY = 30;
    const chartH = bottomY - topY;

    // Grid
    ctx.strokeStyle = '#F0F0F0';
    ctx.lineWidth = 1;
    for (let g = 0; g <= 4; g++) {
      const y = topY + (chartH / 4) * g;
      ctx.beginPath();
      ctx.moveTo(startX, y);
      ctx.lineTo(startX + 7 * (barW + gap), y);
      ctx.stroke();
      ctx.fillStyle = '#999';
      ctx.font = '10px sans-serif';
      ctx.textAlign = 'right';
      ctx.fillText((maxH - (maxH / 4) * g).toFixed(1), startX - 4, y + 4);
    }

    // Bars
    for (let i = 0; i < days.length; i++) {
      const x = startX + i * (barW + gap);
      const h = (hours[i] / maxH) * chartH;
      const y = bottomY - h;
      ctx.fillStyle = '#4CAF50';
      ctx.fillRect(x, y, barW, h);
      ctx.fillStyle = '#666';
      ctx.font = '10px sans-serif';
      ctx.textAlign = 'center';
      ctx.fillText(days[i], x + barW / 2, bottomY + 16);
    }

    ctx.fillStyle = '#333';
    ctx.font = '12px sans-serif';
    ctx.textAlign = 'left';
    ctx.fillText('\u672C\u5468\u5B66\u4E60\u65F6\u95F4 (\u5C0F\u65F6)', startX, 14);
  }

  drawSubjectChart(): void {
    const ctx = this.subjectCtx;
    ctx.clearRect(0, 0, 350, 200);
    const subjects: string[] = ['\u6563\u6587', '\u8BED\u8BCD', '\u5C0F\u8BF4', '\u6587\u8A00\u6587'];
    const scores: number[] = [75, 82, 68, 70];
    const startX = 70;
    const barH = 24;
    const gap = 16;
    const startY = 30;
    const colors: string[] = ['#4CAF50', '#2196F3', '#FF9800', '#9C27B0'];

    for (let i = 0; i < subjects.length; i++) {
      const y = startY + i * (barH + gap);
      const w = (scores[i] / 100) * 250;

      ctx.fillStyle = '#333';
      ctx.font = '14px sans-serif';
      ctx.textAlign = 'right';
      ctx.fillText(subjects[i], startX - 8, y + barH / 2 + 4);

      ctx.fillStyle = colors[i];
      ctx.fillRect(startX, y, w, barH);

      ctx.fillStyle = '#FFF';
      ctx.font = '12px sans-serif';
      ctx.textAlign = 'left';
      if (w > 40) { ctx.fillText(scores[i].toString(), startX + 4, y + barH / 2 + 4); }
    }

    ctx.fillStyle = '#333';
    ctx.font = '12px sans-serif';
    ctx.textAlign = 'left';
    ctx.fillText('\u5404\u9886\u57DF\u638C\u63E1\u5EA6\u8BC4\u5206', startX, 14);
  }

  @Builder
  UserInfoCard(): void {
    Column() {
      Row() {
        Circle()
          .width(64)
          .height(64)
          .fill('#E5E5E5');

        Column() {
          Text('学习者')
            .fontSize(20)
            .fontWeight(FontWeight.Bold);

          Text('高效学习，深度理解')
            .fontSize(14)
            .fontColor('#999999')
            .margin({ top: 4 });
        }
        .alignItems(HorizontalAlign.Start)
        .margin({ left: 16 });
      }
      .width('100%');
    }
    .width('100%')
    .padding(24)
    .backgroundColor(Color.White);
  }

  @Builder
  StatisticsCard(): void {
    Row() {
      this.StatItem('课程总数', this.courses.length.toString());
      Divider().vertical(true).height(40);
      this.StatItem('已完成', this.courses.filter(c => c.status === 'completed').length.toString());
      Divider().vertical(true).height(40);
      this.StatItem('已归档', this.archivedCourses.length.toString());
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Color.White)
    .margin({ top: 12 });
  }

  @Builder
  StatItem(label: string, value: string): void {
    Column() {
      Text(value)
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor('#007DFF');

      Text(label)
        .fontSize(12)
        .fontColor('#999999')
        .margin({ top: 4 });
    }
    .layoutWeight(1);
  }

  @Builder
  FunctionList(): void {
    Column() {
      this.FunctionItem('📚 归档管理', '查看已归档的课程', () => {
        AppRouter.toArchive();
      });

      Divider();

      this.FunctionItem('⚙️ 设置', '主题、语言、通知设置', () => {
        AppRouter.toSettings();
      });

      Divider();

      this.FunctionItem('💬 讨论区', '参与话题讨论', () => {
        AppRouter.toDiscussion();
      });
    }
    .width('100%')
    .backgroundColor(Color.White)
    .margin({ top: 12 });
  }

  @Builder
  FunctionItem(title: string, desc: string, onClick: () => void): void {
    Row() {
      Column() {
        Text(title)
          .fontSize(16)
          .fontWeight(FontWeight.Bold);

        Text(desc)
          .fontSize(12)
          .fontColor('#999999')
          .margin({ top: 4 });
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start);

      Text('>')
        .fontSize(20)
        .fontColor('#CCCCCC');
    }
    .width('100%')
    .padding(16)
    .onClick(onClick);
  }
}
