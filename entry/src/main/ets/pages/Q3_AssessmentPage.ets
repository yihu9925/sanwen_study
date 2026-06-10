// 第三问：深度测评（独立页面 - 题目概览+答题入口）
import { router, promptAction } from '@kit.ArkUI';
import { fileIo } from '@kit.CoreFileKit';
import { relationalStore } from '@kit.ArkData';
import { Question, BloomLevel, getBloomLevelName } from '../models/Question';
import { AssessmentService } from '../services/AssessmentService';
import { ExportService } from '../services/ExportService';
import { RelationalStoreManager } from '../services/RelationalStoreManager';
import { UiStyle, StyleColors } from '../utils/UiStyle';

@Entry
@Component
struct Q3_AssessmentPage {
  @State courseId: string = '';
  @State questions: Question[] = [];
  @State bloomFilter: number = 0;
  @State isLoading: boolean = false;
  @State answeredCount: number = 0;
  @State averageScore: number = 0;
  @StorageLink('themeMode') themeMode: string = 'auto';
  @StorageLink('uiStyle') uiStyle: string = 'default';

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string>;
    this.courseId = params?.['courseId'] || '';
    if (this.courseId) {
      this.loadData();
    }
  }

  async loadData(): Promise<void> {
    try {
      this.isLoading = true;
      this.questions = await AssessmentService.getQuestions(this.courseId);
      await this.loadProgress();
    } catch (e) {
      console.error('Load assessment data failed');
    } finally {
      this.isLoading = false;
    }
  }

  async loadProgress(): Promise<void> {
    try {
      const store = RelationalStoreManager.getStore();
      const predicates = new relationalStore.RdbPredicates('learning_record');
      predicates.equalTo('course_id', this.courseId);
      const rs = await store.query(predicates);
      let count = 0;
      let totalScore = 0;
      while (rs.goToNextRow()) {
        count++;
        totalScore += rs.getLong(8);  // score column
      }
      rs.close();
      this.answeredCount = count;
      this.averageScore = count > 0 ? Math.round(totalScore / count) : 0;
    } catch (e) {
      console.error('Load progress failed');
    }
  }

  getFilteredQuestions(): Question[] {
    if (this.bloomFilter === 0) return this.questions;
    return this.questions.filter(q => q.bloomLevel === this.bloomFilter);
  }

  startAssessment(): void {
    router.pushUrl({
      url: 'pages/AssessmentDetailPage',
      params: { courseId: this.courseId }
    });
  }

  async exportReport(format: string): Promise<void> {
    try {
      let content = '';
      const title = '\u4e09\u95ee\u9ad8\u6548\u5b66\u4e60\u673a';
      if (format === 'json') {
        content = await ExportService.exportReportAsJSON(this.courseId, title);
      } else {
        content = await ExportService.exportReportAsMarkdown(this.courseId, title);
      }
      const context: Context = getContext(this) as Context;
      const dir: string = context.filesDir;
      const timestamp: string = new Date().getTime().toString();
      const fileName: string = 'report_' + timestamp + (format === 'json' ? '.json' : '.md');
      const filePath: string = dir + '/' + fileName;
      const file: fileIo.File = fileIo.openSync(filePath, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY);
      fileIo.writeSync(file.fd, content);
      fileIo.closeSync(file);
      promptAction.showToast({ message: '\u5bfc\u51fa\u6210\u529f\uff1a' + fileName });
    } catch (e) {
      console.error('Export failed: ' + (e as Error).message);
      promptAction.showToast({ message: '\u5bfc\u51fa\u5931\u8d25' });
    }
  }

  colors(): StyleColors { return UiStyle.getColors(this.uiStyle || 'default', this.themeMode === 'dark'); }

  build() {
    Column() {
      Row() {
        Button('\u8fd4\u56de').onClick(() => { router.back(); });
        Text('\u7b2c\u4e09\u95ee\uff1a\u8ba4\u77e5\u6d4b\u8bc4')
          .fontSize(18).fontWeight(FontWeight.Bold).layoutWeight(1).textAlign(TextAlign.Center);
      }
      .width('100%').padding(16).backgroundColor(this.colors().cardBg);

      // 进度概览
      Row() {
        Column() {
          Text(String(this.questions.length)).fontSize(20).fontWeight(FontWeight.Bold).fontColor('#007DFF');
          Text('\u603B\u9898\u6570').fontSize(12).fontColor(this.colors().textTertiary);
        }
        .layoutWeight(1).alignItems(HorizontalAlign.Center);

        Column() {
          Text(String(this.answeredCount)).fontSize(20).fontWeight(FontWeight.Bold).fontColor('#4CAF50');
          Text('\u5DF2\u7B54').fontSize(12).fontColor(this.colors().textTertiary);
        }
        .layoutWeight(1).alignItems(HorizontalAlign.Center);

        Column() {
          Text(String(this.averageScore)).fontSize(20).fontWeight(FontWeight.Bold)
            .fontColor(this.averageScore >= 60 ? '#4CAF50' : '#FF9800');
          Text('\u5747\u5206').fontSize(12).fontColor(this.colors().textTertiary);
        }
        .layoutWeight(1).alignItems(HorizontalAlign.Center);
      }
      .width('100%').padding(16).backgroundColor(this.colors().cardBg).margin({ top: 1 });

      // 维度过滤器
      Row() {
        this.FilterChip('\u5168\u90e8', 0);
        this.FilterChip('\u8bb0\u5fc6', 1);
        this.FilterChip('\u7406\u89e3', 2);
        this.FilterChip('\u5e94\u7528', 3);
        this.FilterChip('\u5206\u6790', 4);
      }
      .width('100%').padding({ left: 16, right: 16, top: 8, bottom: 8 });

      Row() {
        this.FilterChip('\u8bc4\u4ef7', 5);
        this.FilterChip('\u521b\u9020', 6);
      }
      .width('100%').padding({ left: 16, right: 16, top: 0, bottom: 8 });

      // 题目列表
      if (this.isLoading) {
        Column() {
          LoadingProgress().width(48).height(48);
        }
        .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center);
      } else {
        List() {
          ForEach(this.getFilteredQuestions(), (q: Question, index: number) => {
            ListItem() {
              Row() {
                Text('\u2753').fontSize(18).margin({ right: 8 });
                Column() {
                  Text(q.questionText).fontSize(14).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis });
                  Row() {
                    Text(getBloomLevelName(q.bloomLevel))
                      .fontSize(11).fontColor('#007DFF').padding({ left: 4, right: 4 }).backgroundColor(this.colors().accentLight).borderRadius(4);
                    Text('\u2b50'.repeat(q.difficulty)).fontSize(11).margin({ left: 8 });
                  }
                  .margin({ top: 4 });
                }
                .layoutWeight(1).alignItems(HorizontalAlign.Start);
              }
              .width('100%').padding(12).backgroundColor(this.colors().cardBg).borderRadius(8);
            }
            .margin({ bottom: 6 });
          });
        }
        .width('100%').layoutWeight(1).padding(16);
      }

      // 开始答题按钮
      Button('\u25b6 \u5f00\u59cb\u7b54\u9898')
        .width('80%').height(44).borderRadius(22).margin({ bottom: this.answeredCount > 0 ? 8 : 16 })
        .onClick(() => { this.startAssessment(); });

      // 导出按钮（答完题后可导出报告）
      if (this.answeredCount > 0) {
        Row() {
          Button('\u5bfc\u51fa JSON')
            .height(40).borderRadius(20)
            .backgroundColor(this.colors().accentLight).fontColor('#007DFF')
            .layoutWeight(1).margin({ right: 4 })
            .onClick(() => { this.exportReport('json'); });

          Button('\u5bfc\u51fa Markdown')
            .height(40).borderRadius(20)
            .backgroundColor(this.colors().cardBg).fontColor('#FF9800')
            .layoutWeight(1).margin({ left: 4 })
            .onClick(() => { this.exportReport('md'); });
        }
        .width('80%').margin({ bottom: 16 });
      }
    }
    .width('100%').height('100%').backgroundColor(this.colors().pageBg);
  }

  @Builder
  FilterChip(label: string, level: number): void {
    Row() {
      Text(label).fontSize(12).fontColor(this.bloomFilter === level ? Color.White : this.colors().textSecondary);
    }
    .padding({ left: 10, right: 10, top: 4, bottom: 4 })
    .backgroundColor(this.bloomFilter === level ? '#007DFF' : this.colors().divider)
    .borderRadius(12).margin({ right: 6 })
    .onClick(() => { this.bloomFilter = level; });
  }
}
