// 归档管理页
import { Course } from '../models/Course';
import { CourseService } from '../services/CourseService';
import { AppRouter } from '../AppRouter';
import { promptAction } from '@kit.ArkUI';

@Entry
@Component
struct ArchiveManagementPage {
  @State archivedCourses: Course[] = [];

  aboutToAppear(): void {
    this.loadArchivedCourses();
  }

  async loadArchivedCourses(): Promise<void> {
    const courses = await CourseService.getCoursesByUser('default_user');
    this.archivedCourses = courses.filter(c => c.status === 'archived');
  }

  async restoreCourse(courseId: string): Promise<void> {
    await CourseService.updateCourseStatus(courseId, 'active');
    promptAction.showToast({ message: '已恢复' });
    await this.loadArchivedCourses();
  }

  async deleteCourse(courseId: string): Promise<void> {
    await CourseService.deleteCourse(courseId);
    promptAction.showToast({ message: '已删除' });
    await this.loadArchivedCourses();
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Button('返回')
          .onClick(() => {
            AppRouter.back();
          });

        Text('归档管理')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .textAlign(TextAlign.Center);

        Row().width(60);
      }
      .width('100%')
      .padding(16)
      .backgroundColor(Color.White);

      // 归档列表
      if (this.archivedCourses.length === 0) {
        Column() {
          Text('📦')
            .fontSize(64);

          Text('暂无归档课程')
            .fontSize(16)
            .fontColor('#999999')
            .margin({ top: 16 });
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center);
      } else {
        List() {
          ForEach(this.archivedCourses, (course: Course) => {
            ListItem() {
              Row() {
                Column() {
                  Text(course.title)
                    .fontSize(16)
                    .fontWeight(FontWeight.Bold);

                  Text(course.domain)
                    .fontSize(12)
                    .fontColor('#999999')
                    .margin({ top: 4 });
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start);

                Row() {
                  Button('恢复')
                    .fontSize(12)
                    .onClick(() => {
                      this.restoreCourse(course.id);
                    });

                  Button('删除')
                    .fontSize(12)
                    .backgroundColor('#F44336')
                    .margin({ left: 8 })
                    .onClick(() => {
                      this.deleteCourse(course.id);
                    });
                }
              }
              .width('100%')
              .padding(16)
              .backgroundColor(Color.White)
              .borderRadius(8);
            }
            .margin({ bottom: 8 });
          });
        }
        .width('100%')
        .layoutWeight(1)
        .padding(16);
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5');
  }
}
