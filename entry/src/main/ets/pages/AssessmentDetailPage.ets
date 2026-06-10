// 测评详情页 - 自由答题交互 + 对话原始记录 + 评估报告
// 核心变更：选择题(Radio) → 自由文本输入(TextArea) + LLM评判
import { router, promptAction } from '@kit.ArkUI';
import { fileIo } from '@kit.CoreFileKit';
import { Question, AiEvaluation, BloomLevel, getBloomLevelName } from '../models/Question';
import { AssessmentService } from '../services/AssessmentService';
import { CourseService } from '../services/CourseService';
import { AppRouter } from '../AppRouter';
import { ExportService } from '../services/ExportService';
import { UiStyle, StyleColors } from '../utils/UiStyle';

// 测评统计条目
interface AssessmentLevelStat {
  level: BloomLevel;
  averageScore: number;
}

// 薄弱维度分析条目
interface WeaknessItem {
  level: number;
  levelName: string;
  score: number;
  advice: string;
  isWeak: boolean;
}

@Entry
@Component
struct AssessmentDetailPage {
  @State courseId: string = '';
  @StorageLink('themeMode') themeMode: string = 'auto';
  @StorageLink('uiStyle') uiStyle: string = 'default';
  @State questions: Question[] = [];
  @State currentIndex: number = 0;
  @State userAnswerText: string = '';       // 用户自由输入的回答
  @State isSubmitting: boolean = false;      // 是否在等待LLM评判
  @State showEvaluation: boolean = false;    // 是否显示评判结果
  @State evaluation: AiEvaluation | null = null;  // LLM评判结果
  @State allEvaluations: AiEvaluation[] = [];     // 所有评判记录
  @State showReport: boolean = false;        // 是否显示报告
  @State isLoading: boolean = false;
  @State answerDetails: AnswerDetailItem[] = []; // 对话记录
  @State showAnswerCard: boolean = false;          // 答题卡弹窗
  @State selectedChoiceIndex: number = -1;         // 选择题选中的选项索引

  colors(): StyleColors {
    const isDark = this.themeMode === 'dark';
    return UiStyle.getColors(this.uiStyle, isDark);
  }

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string>;
    this.courseId = params?.['courseId'] || '';
    if (this.courseId) {
      this.loadQuestions();
    }
    // 还原之前退出的答题进度
    this.restoreAssessmentProgress();
  }

  aboutToDisappear(): void {
    this.clearAssessmentProgress();
  }

  // 在退出时保存答题进度到 AppStorage（页面销毁后恢复）
  saveAssessmentProgress(): void {
    AppStorage.set<string>('assess_courseId', this.courseId);
    AppStorage.set<number>('assess_currentIndex', this.currentIndex);
    AppStorage.set<string>('assess_answerDetails', JSON.stringify(this.answerDetails));
    AppStorage.set<string>('assess_allEvals', JSON.stringify(this.allEvaluations));
    AppStorage.set<boolean>('assess_showReport', this.showReport);
    AppStorage.set<string>('assess_userAnswer', this.userAnswerText);
  }

  restoreAssessmentProgress(): void {
    const savedCourseId: string = AppStorage.get<string>('assess_courseId') as string;
    if (savedCourseId !== this.courseId) {
      return;
    }
    this.currentIndex = AppStorage.get<number>('assess_currentIndex') as number || 0;
    this.showReport = AppStorage.get<boolean>('assess_showReport') as boolean || false;
    this.userAnswerText = AppStorage.get<string>('assess_userAnswer') as string || '';
    const detailsJson: string = AppStorage.get<string>('assess_answerDetails') as string || '';
    if (detailsJson) {
      this.answerDetails = JSON.parse(detailsJson) as AnswerDetailItem[];
    }
    const evalsJson: string = AppStorage.get<string>('assess_allEvals') as string || '';
    if (evalsJson) {
      this.allEvaluations = JSON.parse(evalsJson) as AiEvaluation[];
    }
    // 如果还原后有当前题的评判记录，显示它
    if (this.currentIndex < this.answerDetails.length) {
      this.evaluation = this.answerDetails[this.currentIndex].evaluation;
      this.showEvaluation = true;
    }
  }

  clearAssessmentProgress(): void {
    AppStorage.delete('assess_courseId');
    AppStorage.delete('assess_currentIndex');
    AppStorage.delete('assess_answerDetails');
    AppStorage.delete('assess_allEvals');
    AppStorage.delete('assess_showReport');
    AppStorage.delete('assess_userAnswer');
  }

  async loadQuestions(): Promise<void> {
    try {
      this.isLoading = true;
      this.questions = await AssessmentService.getQuestions(this.courseId);
    } catch (error) {
      promptAction.showToast({ message: '\u52a0\u8f7d\u9898\u76ee\u5931\u8d25' });
    } finally {
      this.isLoading = false;
    }
  }

  // 提交回答 — 选择题直接判对错，开放题调用LLM评判
  async submitFreeAnswer(): Promise<void> {
    if (this.currentIndex >= this.questions.length) {
      return;
    }
    const question = this.questions[this.currentIndex];
    if (question.questionType === 'choice') {
      if (this.selectedChoiceIndex < 0) { return; }
      this.isSubmitting = true;
      try {
        const selectedText: string = question.options[this.selectedChoiceIndex] || '';
        const isCorrect: boolean = selectedText.startsWith(question.correctAnswer + '.') ||
          selectedText.startsWith(question.correctAnswer + '\u3001') ||
          selectedText.startsWith(question.correctAnswer + ')') ||
          selectedText.startsWith(question.correctAnswer + '\uff09') ||
          selectedText.indexOf(question.correctAnswer) === 0;
        const score: number = isCorrect ? 100 : 0;
        const evalItem: AiEvaluation = {
          score: score,
          comment: isCorrect ? '\u56de\u7b54\u6b63\u786e\uff01' : '\u56de\u7b54\u9519\u8bef\uff0c\u6b63\u786e\u7b54\u6848\u4e3a' + question.correctAnswer,
          strengths: isCorrect ? ['\u9009\u62e9\u6b63\u786e'] : [],
          weaknesses: isCorrect ? [] : ['\u9009\u62e9\u9519\u8bef'],
          improvement: '\u53c2\u8003\u89e3\u91ca\uff1a' + question.explanation
        };
        this.evaluation = evalItem;
        this.allEvaluations.push(evalItem);
        this.answerDetails.push({
          questionText: question.questionText,
          bloomLevel: question.bloomLevel,
          userAnswerText: selectedText,
          evaluation: evalItem,
          score: score,
          isCorrect: isCorrect
        });
        // 保存学习记录到 DB
        await AssessmentService.saveLearningRecord('default_user', this.courseId, question, selectedText, evalItem, score, isCorrect);
        this.showEvaluation = true;
        this.saveAssessmentProgress();
      } catch (e) {
        promptAction.showToast({ message: '\u63d0\u4ea4\u5931\u8d25\uff0c\u8bf7\u91cd\u8bd5' });
      } finally {
        this.isSubmitting = false;
      }
    } else {
      if (!this.userAnswerText.trim()) { return; }
      this.isSubmitting = true;
      try {
        const result = await AssessmentService.submitFreeAnswer(
          'default_user',
          this.courseId,
          question,
          this.userAnswerText
        );
        this.evaluation = result.evaluation;
        this.allEvaluations.push(result.evaluation);
        this.answerDetails.push({
          questionText: question.questionText,
          bloomLevel: question.bloomLevel,
          userAnswerText: this.userAnswerText,
          evaluation: result.evaluation,
          score: result.score,
          isCorrect: result.isCorrect
        });
        this.showEvaluation = true;
        this.saveAssessmentProgress();
      } catch (error) {
        promptAction.showToast({ message: '\u63d0\u4ea4\u5931\u8d25\uff0c\u8bf7\u91cd\u8bd5' });
      } finally {
        this.isSubmitting = false;
      }
    }
  }

  nextQuestion(): void {
    if (this.currentIndex < this.questions.length - 1) {
      this.currentIndex++;
      this.userAnswerText = '';
      this.showEvaluation = false;
      this.evaluation = null;
      this.selectedChoiceIndex = -1;
      this.saveAssessmentProgress();
    } else {
      // 全部答完 -> 标记第三问完成 + 更新雷达数据
      this.updateRadarAfterAssessment();
      CourseService.updateProgress(this.courseId, 3);
      this.clearAssessmentProgress();
      this.showReport = true;
    }
  }

  async updateRadarAfterAssessment(): Promise<void> {
    try {
      // 按布鲁姆维度计算平均分
      const levelScores: Record<number, number[]> = {};
      // Initialize all levels
      for (let lvInit = 1; lvInit <= 6; lvInit++) {
        levelScores[lvInit] = [];
      }
      for (const detail of this.answerDetails) {
        const lv = detail.bloomLevel;
        if (!levelScores[lv]) {
          levelScores[lv] = [];
        }
        levelScores[lv].push(detail.score);
      }
      const levelStats: AssessmentLevelStat[] = [];
      for (let lv = 1; lv <= 6; lv++) {
        const scores = levelScores[lv] || [];
        const avg = scores.length > 0
          ? Math.round(scores.reduce((a, b) => a + b, 0) / scores.length)
          : 0;
        const item: AssessmentLevelStat = { level: lv as BloomLevel, averageScore: avg };
        levelStats.push(item);
      }
      await AssessmentService.updateRadarData(this.courseId, levelStats);
    } catch (e) {
      console.error('Radar update failed');
    }
  }

  // 答题卡：判断某题是否已答
  hasAnswerFor(index: number): boolean {
    if (index >= this.answerDetails.length) {
      return false;
    }
    const q = this.questions[index];
    const detail = this.answerDetails[index];
    return detail !== undefined && detail.questionText === q.questionText;
  }

  // 答题卡：跳转到指定题
  jumpToQuestion(index: number): void {
    this.showAnswerCard = false;
    this.currentIndex = index;
    this.selectedChoiceIndex = -1;
    if (this.hasAnswerFor(index)) {
      const detail = this.answerDetails[index];
      this.evaluation = detail.evaluation;
      this.userAnswerText = detail.userAnswerText;
      this.showEvaluation = true;
    } else {
      this.userAnswerText = '';
      this.showEvaluation = false;
      this.evaluation = null;
    }
  }

  getAverageScore(): number {
    if (this.allEvaluations.length === 0) return 0;
    const total = this.allEvaluations.reduce((s, e) => s + e.score, 0);
    return Math.round(total / this.allEvaluations.length);
  }

  build() {
    Stack() {
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
      .backgroundColor(this.colors().pageBg);

      // 答题卡遮罩
      if (this.showAnswerCard) {
        this.AnswerCardOverlay();
      }
    }
  }

  @Builder
  LoadingView(): void {
    Column() {
      LoadingProgress().width(48).height(48);
      Text('\u52a0\u8f7d\u4e2d...').fontSize(14).fontColor(this.colors().textTertiary).margin({ top: 12 });
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Center);
  }

  @Builder
  EmptyView(): void {
    Column() {
      Text('\u6682\u65e0\u9898\u76ee').fontSize(16).fontColor(this.colors().textTertiary);
      Button('\u8fd4\u56de').margin({ top: 16 }).onClick(() => { AppRouter.back(); });
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Center);
  }

  // ===== 完整评估报告（含对话原始记录）=====
  @Builder
  ReportView(): void {
    Scroll() {
      Column() {
        // 报告标题
        Text('\u8bc4\u4f30\u62a5\u544a').fontSize(22).fontWeight(FontWeight.Bold).margin({ top: 24, bottom: 4 });
        Text('\u5171' + this.questions.length + '\u9898\uff0c\u5df2\u7b54' + this.answerDetails.length + '\u9898')
          .fontSize(14).fontColor(this.colors().textSecondary).margin({ bottom: 16 });

        // 统计卡片
        Row() {
          this.StatCard(String(this.questions.length), '\u603b\u9898\u6570', '#333333');
          this.StatCard(String(this.answerDetails.length), '\u5df2\u7b54', this.answerDetails.length > 0 ? '#4CAF50' : '#999999');
          this.StatCard(String(this.getAverageScore()), '\u5747\u5206', this.getAverageScore() >= 60 ? '#4CAF50' : '#FF9800');
        }
        .width('100%').padding(16).backgroundColor(this.colors().cardBg).borderRadius(12);

        // 布鲁姆维度分析
        Text('\u8ba4\u77e5\u5c42\u6b21\u5206\u6790').fontSize(18).fontWeight(FontWeight.Bold)
          .width('100%').margin({ top: 20, bottom: 12 });
        Column() {
          this.ReportRow('\u8bb0\u5fc6', this.getLevelAvgScore(1));
          this.ReportRow('\u7406\u89e3', this.getLevelAvgScore(2));
          this.ReportRow('\u5e94\u7528', this.getLevelAvgScore(3));
          this.ReportRow('\u5206\u6790', this.getLevelAvgScore(4));
          this.ReportRow('\u8bc4\u4ef7', this.getLevelAvgScore(5));
          this.ReportRow('\u521b\u9020', this.getLevelAvgScore(6));
        }
        .width('100%').padding(12).backgroundColor(this.colors().cardBg).borderRadius(12);

        // 对话原始记录
        Text('\u5bf9\u8bdd\u539f\u59cb\u8bb0\u5f55').fontSize(18).fontWeight(FontWeight.Bold)
          .width('100%').margin({ top: 20, bottom: 12 });

        ForEach(this.answerDetails, (detail: AnswerDetailItem, index: number) => {
          Column() {
            Row() {
              Text('\u7b2c' + (index + 1) + '\u9898: ' + getBloomLevelName(detail.bloomLevel))
                .fontSize(15).fontWeight(FontWeight.Bold).fontColor('#007DFF');
              Text('\u5206\u6570: ' + detail.score)
                .fontSize(14).fontColor(detail.score >= 60 ? '#4CAF50' : '#F44336')
                .margin({ left: 8 });
            }
            .width('100%');

            Row() {
              Text('\u9898\u76ee: ' + detail.questionText)
                .fontSize(13).fontColor(this.colors().textPrimary).margin({ top: 6 });
            }
            .width('100%');

            Row() {
              Text('\u4f60\u7684\u56de\u7b54: ' + detail.userAnswerText)
                .fontSize(13).fontColor(this.colors().textSecondary).margin({ top: 4 });
            }
            .width('100%');

            Row() {
              Text('AI\u8bc4\u8bed: ' + detail.evaluation.comment)
                .fontSize(13).fontColor(this.colors().textTertiary).margin({ top: 4 });
            }
            .width('100%');

            if (detail.evaluation.strengths.length > 0) {
              Row() {
                Text('\u4f18\u70b9: ' + detail.evaluation.strengths.join('\uff1b'))
                  .fontSize(12).fontColor('#4CAF50').margin({ top: 2 });
              }
              .width('100%');
            }

            if (detail.evaluation.weaknesses.length > 0) {
              Row() {
                Text('\u4e0d\u8db3: ' + detail.evaluation.weaknesses.join('\uff1b'))
                  .fontSize(12).fontColor('#F44336').margin({ top: 2 });
              }
              .width('100%');
            }

            Row() {
              Text('\u6539\u8fdb\u5efa\u8bae: ' + detail.evaluation.improvement)
                .fontSize(12).fontColor('#FF9800').margin({ top: 2 });
            }
            .width('100%');
          }
          .width('100%').padding(12).backgroundColor(this.colors().cardBg).borderRadius(8).margin({ bottom: 8 });
        });

        Text('\u96f7\u8fbe\u6570\u636e\u5df2\u81ea\u52a8\u66f4\u65b0').fontSize(13).fontColor('#4CAF50')
          .margin({ top: 16, bottom: 8 });

        Row() {
          Button('📄 \u5BFC\u51FA JSON')
            .height(40).borderRadius(20)
            .backgroundColor(this.colors().accentLight).fontColor('#007DFF')
            .layoutWeight(1).margin({ right: 4 })
            .onClick(() => { this.exportReport('json'); });

          Button('📝 \u5BFC\u51FA Markdown')
            .height(40).borderRadius(20)
            .backgroundColor(this.colors().accentLight).fontColor('#FF9800')
            .layoutWeight(1).margin({ left: 4 })
            .onClick(() => { this.exportReport('md'); });
        }
        .width('80%').margin({ bottom: 12 });

        Button('\u8fd4\u56de\u8bfe\u7a0b').width('80%').height(44).borderRadius(22).margin({ bottom: 24 })
          .onClick(() => { AppRouter.back(); });
      }
      .width('100%').padding(16);
    }
    .width('100%').layoutWeight(1);
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
      // 保存到应用沙箱 filesDir（DevEco Studio 设备文件浏览器可拉取）
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

  // 薄弱维度分析
  getWeaknessAnalysis(): WeaknessItem[] {
    const items: WeaknessItem[] = [];
    const levelNames: string[] = ['\u8bb0\u5fc6', '\u7406\u89e3', '\u5e94\u7528', '\u5206\u6790', '\u8bc4\u4ef7', '\u521b\u9020'];
    const levelAdvice: string[] = [
      '\u5efa\u8bae\u591a\u6b21\u590d\u4e60\u57fa\u7840\u6982\u5ff5\uff0c\u5236\u4f5c\u6982\u5ff5\u5361\u7247\u8fdb\u884c\u8bb0\u5fc6\u953b\u70bc\u3002',
      '\u5efa\u8bae\u7528\u81ea\u5df1\u7684\u8bdd\u590d\u8ff0\u77e5\u8bc6\u70b9\uff0c\u5c1d\u8bd5\u6559\u5b66\u4ed6\u4eba\u3002',
      '\u5efa\u8bae\u591a\u505a\u7ec3\u4e60\u9898\uff0c\u5c06\u77e5\u8bc6\u5e94\u7528\u4e8e\u5b9e\u9645\u573a\u666f\u3002',
      '\u5efa\u8bae\u7ec3\u4e60\u62c6\u89e3\u590d\u6742\u95ee\u9898\uff0c\u5212\u5206\u7ed3\u6784\u56fe\u3002',
      '\u5efa\u8bae\u5bfb\u627e\u4e0d\u540c\u89c2\u70b9\u8fdb\u884c\u6bd4\u8f83\u5206\u6790\uff0c\u57f9\u517b\u6279\u5224\u6027\u601d\u7ef4\u3002',
      '\u5efa\u8bae\u5c1d\u8bd5\u5c06\u77e5\u8bc6\u8f6c\u5316\u4e3a\u81ea\u5df1\u7684\u89e3\u51b3\u65b9\u6848\u6216\u521b\u65b0\u9879\u76ee\u3002'
    ];
    for (let lv = 1; lv <= 6; lv++) {
      const score: number = this.getLevelAvgScore(lv);
      const item: WeaknessItem = {
        level: lv,
        levelName: levelNames[lv - 1],
        score: score,
        advice: score >= 80 ? levelAdvice[lv - 1].replace('\u5efa\u8bae', '\u4fdd\u6301\u5f53\u524d\u6c34\u5e73\uff0c\u53ef') : levelAdvice[lv - 1],
        isWeak: score < 60
      };
      items.push(item);
    }
    return items;
  }

  // 按层级折叠展示对话记录
  @Builder
  CollapsibleAnswers(): void {
    Column() {
      ForEach(this.answerDetails, (detail: AnswerDetailItem, index: number) => {
        Column() {
          Row() {
            Text('\u7b2c' + (index + 1) + '\u9898: ' + getBloomLevelName(detail.bloomLevel))
              .fontSize(14).fontWeight(FontWeight.Bold).fontColor(detail.score >= 60 ? '#4CAF50' : '#F44336');
            Text(detail.score + '/100').fontSize(12).fontColor(detail.score >= 60 ? '#4CAF50' : '#F44336')
              .margin({ left: 8 });
          }
          .width('100%');

          Text('\u9898\u76ee: ' + detail.questionText).fontSize(12).fontColor(this.colors().textPrimary)
            .width('100%').margin({ top: 4 }).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis });
        }
        .padding(8).backgroundColor(this.colors().accentLight).borderRadius(6)
        .width('100%').margin({ top: 4 });
      });
    }
  }

  getLevelAvgScore(level: number): number {
    const items = this.answerDetails.filter(d => d.bloomLevel === level);
    if (items.length === 0) return 0;
    return Math.round(items.reduce((s, d) => s + d.score, 0) / items.length);
  }

  reportColor(pct: number): string {
    if (pct >= 80) { return '#4CAF50'; }
    if (pct >= 60) { return '#FF9800'; }
    return '#F44336';
  }

  @Builder
  StatCard(value: string, label: string, color: string): void {
    Column() {
      Text(value).fontSize(26).fontWeight(FontWeight.Bold).fontColor(color);
      Text(label).fontSize(12).fontColor(this.colors().textTertiary).margin({ top: 4 });
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
      .width(120).height(14).backgroundColor(this.colors().divider).borderRadius(7).margin({ left: 8 });
      Text(String(pct) + '%').fontSize(13).fontColor(this.reportColor(pct)).width(40).textAlign(TextAlign.End);
    }
    .width('100%').margin({ top: 6, bottom: 6 });
  }

  // ===== 答题卡弹窗 =====
  @Builder
  AnswerCardOverlay(): void {
    Column() {
      Column() {
        // 标题行
        Row() {
          Text('\u7b54\u9898\u5361').fontSize(18).fontWeight(FontWeight.Bold);
          Blank();
          Button() {
            Text('\u2716').fontSize(16).fontColor('#999999');
          }
          .width(32).height(32).backgroundColor(Color.Transparent)
          .onClick(() => { this.showAnswerCard = false; });
        }
        .width('100%').margin({ bottom: 16 });

        // 统计
        Row() {
          Text('\u603b' + this.questions.length + '\u9898')
            .fontSize(13).fontColor(this.colors().textSecondary);
          Text('\u5df2\u7b54' + this.answerDetails.length + '\u9898')
            .fontSize(13).fontColor('#4CAF50').margin({ left: 12 });
        }
        .width('100%').margin({ bottom: 16 });

        // 题号网格
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
          ForEach(this.questions, (q: Question, idx: number) => {
            Column() {
              Button(String(idx + 1))
                .width(44).height(44)
                .borderRadius(8)
                .backgroundColor(
                  idx === this.currentIndex ? '#007DFF' :
                  this.hasAnswerFor(idx) ? '#4CAF50' :
                  (this.colors().divider)
                )
                .fontColor(
                  idx === this.currentIndex ? Color.White :
                  this.hasAnswerFor(idx) ? Color.White :
                  (this.colors().textPrimary)
                )
                .fontSize(16).fontWeight(FontWeight.Bold)
                .onClick(() => { this.jumpToQuestion(idx); });
            }
            .margin(4);
          });
        }
        .width('100%');
      }
      .width('85%').padding(20)
      .backgroundColor(this.colors().cardBg)
      .borderRadius(16);
    }
    .width('100%').height('100%')
    .backgroundColor('#80000000')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .onClick(() => { this.showAnswerCard = false; });
  }

  // ===== 答题视图（TextArea自由输入）=====
  @Builder
  QuestionView(): void {
    Column() {
      // 顶部栏：退出 + 进度
      Row() {
        Button() {
          Text('\u2190').fontSize(18).fontColor(this.colors().textPrimary);
        }
        .width(36).height(36).backgroundColor(Color.Transparent)
        .onClick(() => {
          this.saveAssessmentProgress();
          AppRouter.back();
        });
        Blank();
        Text('\u9898\u76ee ' + (this.currentIndex + 1) + ' / ' + this.questions.length)
          .fontSize(14).fontColor(this.colors().textSecondary);
        Blank();
        Button() {
          Text('\u7b54\u9898\u5361').fontSize(13).fontColor('#007DFF');
        }
        .height(32).borderRadius(16).backgroundColor(this.colors().accentLight)
        .onClick(() => { this.showAnswerCard = !this.showAnswerCard; });
      }
      .width('100%').padding({ left: 8, right: 16, top: 8, bottom: 8 })
      .backgroundColor(this.colors().cardBg);

      Scroll() {
        Column() {
          // 题目卡片
          Column() {
            Row() {
              Text('\u2b50'.repeat(this.questions[this.currentIndex].difficulty))
                .fontSize(14);
            }
            .width('100%');

            // 标签（可多个）
            Row() {
              ForEach(this.questions[this.currentIndex].labels, (label: string) => {
                Text(label)
                  .fontSize(12).fontColor(Color.White)
                  .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                  .backgroundColor('#007DFF').borderRadius(4).margin({ right: 6 });
              });
            }
            .width('100%').margin({ top: 8 });

            // 题目文本
            Text(this.questions[this.currentIndex].questionText)
              .fontSize(18).fontWeight(FontWeight.Bold).margin({ top: 16 });

            // 根据题型显示：选择题→Radio组，开放题→TextArea
            if (this.questions[this.currentIndex].questionType === 'choice') {
              Text('\u8bf7\u9009\u62e9\u7b54\u6848')
                .fontSize(14).fontColor(this.colors().textPrimary).margin({ top: 24, bottom: 8 });
              Column() {
                ForEach(this.questions[this.currentIndex].options, (opt: string, optIdx: number) => {
                  Row() {
                    Radio({ value: String(optIdx), group: 'q' + this.currentIndex })
                      .onChange(() => {
                        this.selectedChoiceIndex = optIdx;
                        this.userAnswerText = opt;
                      });
                    Text(opt).fontSize(15).fontColor(this.colors().textPrimary).margin({ left: 8 });
                  }
                  .width('100%').margin({ top: 8 });
                });
              }
              .width('100%');
            } else {
              Text('\u4f60\u7684\u56de\u7b54')
                .fontSize(14).fontColor(this.colors().textPrimary).margin({ top: 24, bottom: 8 });
              TextArea({
                text: this.userAnswerText,
                placeholder: '\u8bf7\u5728\u6b64\u81ea\u7531\u8f93\u5165\u4f60\u7684\u56de\u7b54...'
              })
                .width('100%').height(180)
                .onChange((value: string) => {
                  this.userAnswerText = value;
                });
            }
          }
      .width('100%').padding(16).backgroundColor(this.colors().cardBg).borderRadius(12);
 
          // LLM评判结果展示（提交后显示）
          if (this.showEvaluation && this.evaluation) {
            Column() {
              Row() {
                Text('\u8bc4\u5206: ' + this.evaluation.score + '/100')
                  .fontSize(20).fontWeight(FontWeight.Bold)
                  .fontColor(this.evaluation.score >= 60 ? '#4CAF50' : '#F44336');
              }
              .width('100%');

              Row() {
                Text(this.evaluation.comment).fontSize(14).fontColor(this.colors().textPrimary);
              }
              .width('100%').margin({ top: 8 });

              if (this.evaluation.strengths.length > 0) {
                Row() {
                  Text('\u2713 \u4f18\u70b9: ' + this.evaluation.strengths.join('\uff1b'))
                    .fontSize(13).fontColor('#4CAF50');
                }
                .width('100%').margin({ top: 4 });
              }

              if (this.evaluation.weaknesses.length > 0) {
                Row() {
                  Text('\u2717 \u4e0d\u8db3: ' + this.evaluation.weaknesses.join('\uff1b'))
                    .fontSize(13).fontColor('#F44336');
                }
                .width('100%').margin({ top: 4 });
              }

              Row() {
                Text('\u2b06 \u6539\u8fdb\u5efa\u8bae: ' + this.evaluation.improvement)
                  .fontSize(13).fontColor('#FF9800');
              }
              .width('100%').margin({ top: 4 });
            }
            .width('100%').padding(16).backgroundColor(this.colors().cardBg).borderRadius(12).margin({ top: 12 });
          }
        }
        .width('100%').padding(16);
      }
      .layoutWeight(1);

      // 底部按钮
      Row() {
        if (!this.showEvaluation) {
          Button('\u7b54\u9898\u5361')
            .height(44).borderRadius(22)
            .backgroundColor(this.colors().divider).fontColor(this.colors().textPrimary)
            .margin({ right: 8 })
            .onClick(() => { this.showAnswerCard = !this.showAnswerCard; });
          Button('\u63d0\u4ea4\u56de\u7b54')
            .layoutWeight(1).height(44).borderRadius(22)
            .enabled((this.questions[this.currentIndex].questionType === 'choice' ? this.selectedChoiceIndex >= 0 : this.userAnswerText.trim().length > 0) && !this.isSubmitting)
            .onClick(() => { this.submitFreeAnswer(); });

          if (this.isSubmitting) {
            // 提交中显示加载提示
            Text('AI\u8bc4\u5224\u4e2d...').fontSize(12).fontColor(this.colors().textTertiary).margin({ top: 4 });
          }
        } else {
          Button('\u7b54\u9898\u5361')
            .height(44).borderRadius(22)
            .backgroundColor(this.colors().divider).fontColor(this.colors().textPrimary)
            .margin({ right: 8 })
            .onClick(() => { this.showAnswerCard = !this.showAnswerCard; });
          Button(this.currentIndex < this.questions.length - 1
            ? '\u4e0b\u4e00\u9898 \u2192'
            : '\u67e5\u770b\u62a5\u544a')
            .layoutWeight(1).height(44).borderRadius(22)
            .onClick(() => { this.nextQuestion(); });
        }
      }
      .width('100%').padding(16).backgroundColor(this.colors().cardBg);
    }
    .width('100%').height('100%');
  }
}

// 对话记录条目接口
interface AnswerDetailItem {
  questionText: string;
  bloomLevel: BloomLevel;
  userAnswerText: string;
  evaluation: AiEvaluation;
  score: number;
  isCorrect: boolean;
}
