// 首页 - 课程列表与搜索
import { promptAction } from '@kit.ArkUI';
import { Course } from '../models/Course';
import { CourseService } from '../services/CourseService';
import { LLMService } from '../services/LLMService';
import { CourseHealthService, CourseContentStatus } from '../services/CourseHealthService';
import { AppRouter } from '../AppRouter';
import { getTimeAgo } from '../utils/DateUtils';
import { UiStyle, StyleColors } from '../utils/UiStyle';

@Component
export struct HomePage {
  @State courses: Course[] = [];
  @State searchText: string = '';
  @State isLoading: boolean = false;
  @State pageState: 'loading' | 'content' | 'empty' | 'error' = 'loading';
  private userId: string = 'default_user';
  @StorageLink('themeMode') themeMode: string = 'auto';
  @StorageLink('uiStyle') uiStyle: string = 'default';

  aboutToAppear(): void {
    this.loadCourses();
  }

  // 页面重新可见时刷新课程列表（从CourseDetailPage返回时触发）
  onPageShow(): void {
    this.loadCourses();
  }

  @State courseHealthMap: Record<string, CourseContentStatus> = {};

  async loadCourses(): Promise<void> {
    try {
      this.pageState = 'loading';
      const allCourses = await CourseService.getCoursesByUser(this.userId);
      this.courses = allCourses.filter(c => c.status !== 'archived');
      // 检测每个课程的内容健康状态
      const healthMap: Record<string, CourseContentStatus> = {};
      for (const c of this.courses) {
        try {
          healthMap[c.id] = await CourseHealthService.checkCourseStatus(c.id);
        } catch (e) {
          // skip for individual course
        }
      }
      this.courseHealthMap = healthMap;
      this.pageState = this.courses.length > 0 ? 'content' : 'empty';
    } catch (error) {
      this.pageState = 'error';
      console.error('Load courses failed:', error);
    }
  }

  async handleSearch(): Promise<void> {
    if (!this.searchText.trim()) {
      promptAction.showToast({ message: '请输入学习问题' });
      return;
    }

    try {
      this.isLoading = true;
      
      // 调用LLM识别领域和生成标题
      const domain = await LLMService.identifyDomain(this.searchText);
      const title = await LLMService.generateCourseTitle(this.searchText, domain);
      
      // 创建课程
      const courseId = await CourseService.createCourse(
        this.userId,
        this.searchText,
        title,
        domain
      );

      // 跳转到课程详情页（返回时onPageShow会自动刷新列表）
      AppRouter.toCourseDetail(courseId);
      
      // 清空搜索框
      this.searchText = '';
    } catch (error) {
      promptAction.showToast({ message: '创建课程失败' });
      console.error('Create course failed:', error);
    } finally {
      this.isLoading = false;
    }
  }

  colors(): StyleColors {
    return UiStyle.getColors(this.uiStyle || 'default', this.themeMode === 'dark');
  }

  build() {
    Column() {
      // 顶部搜索栏
      this.SearchBar();

      // 内容区域
      if (this.pageState === 'loading') {
        this.LoadingContent();
      } else if (this.pageState === 'empty') {
        this.EmptyContent();
      } else if (this.pageState === 'error') {
        this.ErrorContent();
      } else {
        // 课程列表（直接嵌入 build，确保 @State 变化时必更新）
        List() {
          ForEach(this.courses, (course: Course) => {
            ListItem() {
              this.CourseCard(course);
            }
            .margin({ bottom: 12 });
          });
        }
        .width('100%')
        .layoutWeight(1)
        .padding(16)
        .listDirection(Axis.Vertical);
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.colors().pageBg)
  }

  @Builder
  SearchBar(): void {
    Column() {
      Row() {
        Text('三问高效学习机')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1);

        Button('刷新')
          .fontSize(14)
          .height(32)
          .onClick(() => {
            this.loadCourses();
          });
      }
      .width('100%')
      .margin({ bottom: 16 });

      Row() {
        TextInput({ placeholder: '提出你的学习问题...', text: this.searchText })
          .layoutWeight(1)
          .height(48)
          .backgroundColor(this.colors().cardBg)
          .borderRadius(24)
          .padding({ left: 16, right: 16 })
          .onChange((value: string) => {
            this.searchText = value;
          })
          .onSubmit(() => {
            this.handleSearch();
          });

        Button(this.isLoading ? '生成中...' : '提问')
          .width(80)
          .height(48)
          .margin({ left: 12 })
          .enabled(!this.isLoading)
          .onClick(() => {
            this.handleSearch();
          });
      }
      .width('100%');
    }
    .width('100%')
    .padding(16)
    .backgroundColor(this.colors().cardBg);
  }

  @Builder
  LoadingContent(): void {
    Column() {
      LoadingProgress()
        .width(48)
        .height(48)
        .color(this.colors().accent);
      
      Text('加载中...')
        .fontSize(14)
        .fontColor(this.colors().textTertiary)
        .margin({ top: 12 });
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center);
  }

  @Builder
  EmptyContent(): void {
    Column() {
      Text('📚')
        .fontSize(64);
      
      Text('提出你的学习问题，开始吧！')
        .fontSize(16)
        .fontColor(this.colors().textTertiary)
        .margin({ top: 16 });
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center);
  }

  @Builder
  ErrorContent(): void {
    Column() {
      Text('❌')
        .fontSize(64);
      
      Text('加载失败，点击重试')
        .fontSize(16)
        .fontColor(this.colors().textTertiary)
        .margin({ top: 16 });

      Button('重试')
        .margin({ top: 12 })
        .onClick(() => {
          this.loadCourses();
        });
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center);
  }

  @Builder
  CourseCard(course: Course): void {
    Column() {
      Row() {
        Column() {
          Text(course.title)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis });

          Text(course.domain)
            .fontSize(14)
            .fontColor(this.colors().textSecondary)
            .margin({ top: 4 });

          Text(course.question)
            .fontSize(12)
            .fontColor(this.colors().textTertiary)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 8 });
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start);

        // 进度 + 状态
        Column() {
          Text(course.progressPercent + '%')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.colors().accent);

          Text(this.getStatusText(course.status))
            .fontSize(12)
            .fontColor(this.colors().textTertiary)
            .margin({ top: 4 });
        }
        .alignItems(HorizontalAlign.Center);
      }
      .width('100%');

      // 进度条
      Row() {
        Row()
          .width(course.progressPercent + '%')
          .height(4)
          .backgroundColor(this.colors().accent)
          .borderRadius(2);
      }
      .width('100%')
      .height(4)
      .backgroundColor(this.colors().divider)
      .borderRadius(2)
      .margin({ top: 12 });

      // 底部操作栏：时间 + 操作按钮
      Row() {
        // 内容健康状态（点击跳转到课程详情自动触发补全）
      if (this.courseHealthMap[course.id]) {
        Row() {
          if (this.courseHealthMap[course.id].allComplete) {
            Text('\u2714\ufe0f').fontSize(10).fontColor('#4CAF50').margin({ right: 2 });
            Text('\u4e09\u95ee\u5b8c\u6574').fontSize(10).fontColor('#4CAF50');
          } else {
            Text('\u26a0\ufe0f').fontSize(10).fontColor('#FF9800').margin({ right: 2 });
            Text('\u7f3a' + this.courseHealthMap[course.id].missingParts.join('\u3001'))
              .fontSize(10).fontColor('#FF9800');
          }
        }
        .margin({ top: 2 })
        .onClick(() => {
          // 点击缺䃍提示直接跳转到课程详情页，详情页会自动检测并提示䃍充
          AppRouter.toCourseDetail(course.id);
        });
      }

      Text(getTimeAgo(course.lastAccessedAt))
          .fontSize(12)
          .fontColor(this.colors().textTertiary)
          .layoutWeight(1);

        // 归档按钮
        if (course.status !== 'archived') {
          Button('\u5f52\u6863')
            .fontSize(11).fontColor(this.colors().textTertiary)
            .height(26).borderRadius(13)
            .backgroundColor(this.colors().divider).margin({ left: 4 })
            .onClick(() => {
              CourseService.updateCourseStatus(course.id, 'archived').then(() => {
                promptAction.showToast({ message: course.title + ' \u5df2\u5f52\u6863' });
                this.loadCourses();
              }).catch(() => {
                promptAction.showToast({ message: '\u5f52\u6863\u5931\u8d25' });
              });
            });
        }

        // 删除按钮（长按菜单触发后展示）
        Button('\u5220\u9664')
          .fontSize(11).fontColor('#FF4D4F')
          .height(26).borderRadius(13)
          .backgroundColor(this.themeMode === 'dark' ? '#3A1A1A' : '#FFF1F0').margin({ left: 4 })
          .onClick(() => {
            promptAction.showDialog({
              title: '\u786e\u8ba4\u5220\u9664',
              message: '\u786e\u5b9a\u8981\u5220\u9664\u300c' + course.title + '\u300d\u5417\uff1f\u64cd\u4f5c\u4e0d\u53ef\u64a4\u9500\u3002',
              buttons: [
                { text: '\u53d6\u6d88', color: '#999999' },
                { text: '\u5220\u9664', color: '#FF4D4F' }
              ]
            }).then(async (data: promptAction.ShowDialogSuccessResponse) => {
              if (data.index === 1) {
                await CourseService.deleteCourse(course.id);
                promptAction.showToast({ message: course.title + ' \u5df2\u5220\u9664' });
                this.loadCourses();
              }
            }).catch(() => {});
          });
      }
      .width('100%').margin({ top: 8 });
    }
    .width('100%')
    .padding(16)
    .backgroundColor(this.colors().cardBg)
    .borderRadius(this.colors().cardRadius)
    .onClick(() => {
      AppRouter.toCourseDetail(course.id);
    });
  }

  private getStatusText(status: string): string {
    const statusMap: Record<string, string> = {
      'created': '已创建',
      'active': '进行中',
      'completed': '已完成',
      'archived': '已归档'
    };
    return statusMap[status] || status;
  }
}
