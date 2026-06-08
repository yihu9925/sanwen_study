// 个人中心页
import { Course } from '../models/Course';
import { UserProfile } from '../models/UserProfile';
import { CourseService } from '../services/CourseService';
import { AppRouter } from '../AppRouter';

@Component
export struct PersonalCenter {
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
      Scroll() {
        Column() {
          // 用户信息卡片
          this.UserInfoCard();

          // 统计卡片
          this.StatisticsCard();

          // 功能入口
          this.FunctionList();
        }
        .width('100%');
      }
      .layoutWeight(1);
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5');
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
          Text('\u5B66\u4E60\u8005')
            .fontSize(20)
            .fontWeight(FontWeight.Bold);

          Text('\u9AD8\u6548\u5B66\u4E60\uFF0C\u6DF1\u5EA6\u7406\u89E3')
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
      this.StatItem('\u8BFE\u7A0B\u603B\u6570', this.courses.length.toString());
      Divider().vertical(true).height(40);
      this.StatItem('\u5DF2\u5B8C\u6210', this.courses.filter(c => c.status === 'completed').length.toString());
      Divider().vertical(true).height(40);
      this.StatItem('\u5DF2\u5F52\u6863', this.archivedCourses.length.toString());
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
      this.FunctionItem('\uD83D\uDCDA \u5F52\u6863\u7BA1\u7406', '\u67E5\u770B\u5DF2\u5F52\u6863\u7684\u8BFE\u7A0B', () => {
        AppRouter.toArchive();
      });

      Divider();

      this.FunctionItem('\u2699\uFE0F \u8BBE\u7F6E', 'API\u914D\u7F6E\u3001\u6DF1\u8272\u6A21\u5F0F\u3001\u5BFC\u51FA\u6570\u636E', () => {
        AppRouter.toSettings();
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
