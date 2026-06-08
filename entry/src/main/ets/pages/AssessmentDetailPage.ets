// 测评详情页 - 答题交互 + 测评报告
import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { relationalStore } from '@kit.ArkData';
import { Question } from '../models/Question';
import { RadarData } from '../models/Course';
import { AssessmentService } from '../services/AssessmentService';
import { RelationalStoreManager } from '../services/RelationalStoreManager';
import { AppRouter } from '../AppRouter';

@Entry
@Component
struct AssessmentDetailPage {
  @State courseId: string = '';
  @State questions: Question[] = [];
  @State currentIndex: number = 0;
  @State selectedAnswer: string = '';
  @State hasSubmitted: boolean = false;
  @State isCorrect: boolean = false;
  @State isLoading: boolean = false;
  @State showReport: boolean = false;
  @State answerLevels: number[] = [];
  @State answerResults: boolean[] = [];
  @State correctNum: number = 0;

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string>;
    this.courseId = params?.['courseId'] || '';
    if (this.courseId) {
      this.loadQuestions();
    }
  }

  async loadQuestions(): Promise<void> {
    try {
      this.isLoading = true;
      this.questions = await AssessmentService.getQuestions(this.courseId);
    } catch (error) {
      promptAction.showToast({ message: '\u52A0\u8F7D\u9898\u76EE\u5931\u8D25' });
    } finally {
      this.isLoading = false;
    }
  }

  async submitAnswer(): Promise<void> {
    if (!this.selectedAnswer || this.currentIndex >= this.questions.length) {
      return;
    }
    try {
      const question = this.questions[this.currentIndex];
      const result = await AssessmentService.submitAnswer('default_user', this.courseId, question.id, this.selectedAnswer);
      this.isCorrect = result;
      this.hasSubmitted = true;
      this.answerLevels.push(question.bloomLevel);
      this.answerResults.push(result);
      if (result) {
        this.correctNum++;
      }
    } catch (error) {
      promptAction.showToast({ message: '\u63D0\u4EA4\u5931\u8D25' });
    }
  }

  async updateRadarData(): Promise<void> {
    try {
      const levelCorrect: number[] = [0, 0, 0, 0, 0, 0];
      const levelTotal: number[] = [0, 0, 0, 0, 0, 0];
      for (let i = 0; i < this.answerLevels.length; i++) {
        const level = this.answerLevels[i];
        if (level >= 0 && level < 6) {
          levelTotal[level]++;
          if (this.answerResults[i]) {
            levelCorrect[level]++;
          }
        }
      }
      const radar: RadarData = { remember: 0, understand: 0, apply: 0, analyze: 0, evaluate: 0, create: 0 };
      if (levelTotal[0] > 0) { radar.remember = Math.round(levelCorrect[0] / levelTotal[0] * 100); }
      if (levelTotal[1] > 0) { radar.understand = Math.round(levelCorrect[1] / levelTotal[1] * 100); }
      if (levelTotal[2] > 0) { radar.apply = Math.round(levelCorrect[2] / levelTotal[2] * 100); }
      if (levelTotal[3] > 0) { radar.analyze = Math.round(levelCorrect[3] / levelTotal[3] * 100); }
      if (levelTotal[4] > 0) { radar.evaluate = Math.round(levelCorrect[4] / levelTotal[4] * 100); }
      if (levelTotal[5] > 0) { radar.create = Math.round(levelCorrect[5] / levelTotal[5] * 100); }

      const store = RelationalStoreManager.getStore();
      const predicates = new relationalStore.RdbPredicates('course');
      predicates.equalTo('id', this.courseId);
      const updateVal: relationalStore.ValuesBucket = {
        radar_data: JSON.stringify(radar),
        updated_at: new Date().toISOString()
      };
      await store.update(updateVal, predicates);
    } catch (e) {
      console.error('Radar update failed');
    }
  }

  nextQuestion(): void {
    if (this.currentIndex < this.questions.length - 1) {
      this.currentIndex++;
      this.selectedAnswer = '';
      this.hasSubmitted = false;
    } else {
      this.updateRadarData();
      this.showReport = true;
    }
  }

  build() {
    Column() {
      if (this.showReport) {
        this.ReportView();
      } else if (this.isLoading) {
        this.LoadingView();
      } else if (this.questions.length === 0) {
        this.EmptyView();
      } else {
        this.QuestionView();
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5');
  }

  @Builder
  LoadingView(): void {
    Column() {
      LoadingProgress().width(48).height(48);
      Text('\u52A0\u8F7D\u4E2D...').fontSize(14).fontColor('#999999').margin({ top: 12 });
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Center);
  }

  @Builder
  EmptyView(): void {
    Column() {
      Text('\u6682\u65E0\u9898\u76EE').fontSize(16).fontColor('#999999');
      Button('\u8FD4\u56DE').margin({ top: 16 }).onClick(() => { AppRouter.back(); });
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Center);
  }

  @Builder
  ReportView(): void {
    Scroll() {
      Column() {
        Text('\u8BC4\u4F30\u62A5\u544A').fontSize(22).fontWeight(FontWeight.Bold).margin({ top: 24, bottom: 8 });
        Text('\u606D\u559C\u5B8C\u6210\u4E86\u672C\u6B21\u8BC4\u4F30!').fontSize(14).fontColor('#666666').margin({ bottom: 20 });
        Row() {
          this.StatCard(String(this.questions.length), '\u603B\u9898\u6570', '#333333');
          this.StatCard(String(this.correctNum), '\u6B63\u786E\u6570', '#4CAF50');
          this.StatCard(String(this.getReportRate()) + '%', '\u6B63\u786E\u7387', '#FF9800');
        }
        .width('100%').padding(16).backgroundColor(Color.White).borderRadius(12);

        Text('\u8BA4\u77E5\u5C42\u6B21\u5206\u6790').fontSize(18).fontWeight(FontWeight.Bold).width('100%').margin({ top: 20, bottom: 12 });
        Column() {
          this.ReportRow('\u8BB0\u5FC6', this.getLevelStat(0));
          this.ReportRow('\u7406\u89E3', this.getLevelStat(1));
          this.ReportRow('\u5E94\u7528', this.getLevelStat(2));
          this.ReportRow('\u5206\u6790', this.getLevelStat(3));
          this.ReportRow('\u8BC4\u4EF7', this.getLevelStat(4));
          this.ReportRow('\u521B\u9020', this.getLevelStat(5));
        }
        .width('100%').padding(12).backgroundColor(Color.White).borderRadius(12);

        Text('\u96F7\u8FBE\u6570\u636E\u5DF2\u81EA\u52A8\u66F4\u65B0').fontSize(13).fontColor('#4CAF50').margin({ top: 16, bottom: 20 });
        Button('\u8FD4\u56DE\u8BFE\u7A0B').width('80%').height(44).borderRadius(22).margin({ bottom: 24 }).onClick(() => { AppRouter.back(); });
      }
      .width('100%').padding(16);
    }
    .width('100%').layoutWeight(1);
  }

  reportColor(pct: number): string {
    if (pct >= 80) { return '#4CAF50'; }
    if (pct >= 60) { return '#FF9800'; }
    return '#F44336';
  }

  getReportRate(): number {
    return this.questions.length > 0 ? Math.round(this.correctNum / this.questions.length * 100) : 0;
  }

  getLevelStat(level: number): number {
    let correct = 0;
    let total = 0;
    for (let i = 0; i < this.answerLevels.length; i++) {
      if (this.answerLevels[i] === level) {
        total++;
        if (this.answerResults[i]) {
          correct++;
        }
      }
    }
    return total > 0 ? Math.round(correct / total * 100) : 0;
  }

  @Builder
  StatCard(value: string, label: string, color: string): void {
    Column() {
      Text(value).fontSize(26).fontWeight(FontWeight.Bold).fontColor(color);
      Text(label).fontSize(12).fontColor('#999999').margin({ top: 4 });
    }
    .layoutWeight(1);
  }

  @Builder
  ReportRow(label: string, pct: number): void {
    Row() {
      Text(label).fontSize(14).width(50);
      Row() {
        Row().width(String(pct) + '%').height(14).backgroundColor(this.reportColor(pct)).borderRadius(7);
      }
      .width(120).height(14).backgroundColor('#F0F0F0').borderRadius(7).margin({ left: 8 });
      Text(String(pct) + '%').fontSize(13).fontColor(this.reportColor(pct)).width(40).textAlign(TextAlign.End);
    }
    .width('100%').margin({ top: 6, bottom: 6 });
  }

  @Builder
  QuestionView(): void {
    Column() {
      Row() {
        Text('\u9898\u76EE ' + (this.currentIndex + 1) + ' / ' + this.questions.length)
          .fontSize(14).fontColor('#666666');
      }
      .width('100%').padding(16).backgroundColor(Color.White);

      Column() {
        Text(this.questions[this.currentIndex].questionText)
          .fontSize(18).fontWeight(FontWeight.Bold);

        Column() {
          ForEach(this.questions[this.currentIndex].options, (option: string, index: number) => {
            Row() {
              Radio({ value: String(index), group: 'q_options' })
                .width(24).height(24)
                .checked(this.selectedAnswer === String(index))
                .onChange((isChecked: boolean) => {
                  if (isChecked) {
                    this.selectedAnswer = String(index);
                  }
                });
              Text(option).fontSize(16).margin({ left: 12 });
            }
            .width('100%').padding(12)
            .backgroundColor(this.selectedAnswer === String(index) ? '#E3F2FD' : Color.White)
            .borderRadius(8).margin({ top: 8 });
          });
        }
        .width('100%').margin({ top: 24 });

        if (this.hasSubmitted) {
          Column() {
            Text(this.isCorrect ? '\u2713 \u6B63\u786E' : '\u2717 \u9519\u8BEF')
              .fontSize(16).fontWeight(FontWeight.Bold)
              .fontColor(this.isCorrect ? '#4CAF50' : '#F44336');
          }
          .width('100%').padding(16)
          .backgroundColor(this.isCorrect ? '#E8F5E9' : '#FFEBEE')
          .borderRadius(8).margin({ top: 24 });
        }
      }
      .width('100%').layoutWeight(1).padding(16);

      Row() {
        if (!this.hasSubmitted) {
          Button('\u63D0\u4EA4\u7B54\u6848')
            .width('100%').enabled(this.selectedAnswer !== '')
            .onClick(() => { this.submitAnswer(); });
        } else {
          Button(this.currentIndex < this.questions.length - 1 ? '\u4E0B\u4E00\u9898' : '\u67E5\u770B\u62A5\u544A')
            .width('100%')
            .onClick(() => { this.nextQuestion(); });
        }
      }
      .width('100%').padding(16).backgroundColor(Color.White);
    }
    .width('100%').height('100%');
  }
}
