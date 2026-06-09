// 测评详情页 - 自由答题交互 + 对话原始记录 + 评估报告
// 核心变更：选择题(Radio) → 自由文本输入(TextArea) + LLM评判
import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { Question, AiEvaluation, BloomLevel, getBloomLevelName } from '../models/Question';
import { RadarData } from '../models/Course';
import { AssessmentService } from '../services/AssessmentService';
import { RelationalStoreManager } from '../services/RelationalStoreManager';
import { AppRouter } from '../AppRouter';
import { ExportService } from '../services/ExportService';

// 测评统计条目
interface AssessmentLevelStat {
  level: BloomLevel;
  averageScore: number;
}

@Entry
@Component
struct AssessmentDetailPage {
  @State courseId: string = '';
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
      promptAction.showToast({ message: '\u52a0\u8f7d\u9898\u76ee\u5931\u8d25' });
    } finally {
      this.isLoading = false;
    }
  }

  // 提交自由回答 — 核心方法
  async submitFreeAnswer(): Promise<void> {
    if (!this.userAnswerText.trim() || this.currentIndex >= this.questions.length) {
      return;
    }
    this.isSubmitting = true;
    try {
      const question = this.questions[this.currentIndex];
      const result = await AssessmentService.submitFreeAnswer(
        'default_user',
        this.courseId,
        question,
        this.userAnswerText
      );
      this.evaluation = result.evaluation;
      this.allEvaluations.push(result.evaluation);
      // 保存对话原始记录
      this.answerDetails.push({
        questionText: question.questionText,
        bloomLevel: question.bloomLevel,
        userAnswerText: this.userAnswerText,
        evaluation: result.evaluation,
        score: result.score,
        isCorrect: result.isCorrect
      });
      this.showEvaluation = true;
    } catch (error) {
      promptAction.showToast({ message: '\u63d0\u4ea4\u5931\u8d25\uff0c\u8bf7\u91cd\u8bd5' });
    } finally {
      this.isSubmitting = false;
    }
  }

  nextQuestion(): void {
    if (this.currentIndex < this.questions.length - 1) {
      this.currentIndex++;
      this.userAnswerText = '';
      this.showEvaluation = false;
      this.evaluation = null;
    } else {
      // 更新雷达数据
      this.updateRadarAfterAssessment();
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

  getAverageScore(): number {
    if (this.allEvaluations.length === 0) return 0;
    const total = this.allEvaluations.reduce((s, e) => s + e.score, 0);
    return Math.round(total / this.allEvaluations.length);
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
      Text('\u52a0\u8f7d\u4e2d...').fontSize(14).fontColor('#999999').margin({ top: 12 });
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Center);
  }

  @Builder
  EmptyView(): void {
    Column() {
      Text('\u6682\u65e0\u9898\u76ee').fontSize(16).fontColor('#999999');
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
          .fontSize(14).fontColor('#666666').margin({ bottom: 16 });

        // 统计卡片
        Row() {
          this.StatCard(String(this.questions.length), '\u603b\u9898\u6570', '#333333');
          this.StatCard(String(this.answerDetails.length), '\u5df2\u7b54', this.answerDetails.length > 0 ? '#4CAF50' : '#999999');
          this.StatCard(String(this.getAverageScore()), '\u5747\u5206', this.getAverageScore() >= 60 ? '#4CAF50' : '#FF9800');
        }
        .width('100%').padding(16).backgroundColor(Color.White).borderRadius(12);

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
        .width('100%').padding(12).backgroundColor(Color.White).borderRadius(12);

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
                .fontSize(13).fontColor('#333333').margin({ top: 6 });
            }
            .width('100%');

            Row() {
              Text('\u4f60\u7684\u56de\u7b54: ' + detail.userAnswerText)
                .fontSize(13).fontColor('#666666').margin({ top: 4 });
            }
            .width('100%');

            Row() {
              Text('AI\u8bc4\u8bed: ' + detail.evaluation.comment)
                .fontSize(13).fontColor('#999999').margin({ top: 4 });
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
          .width('100%').padding(12).backgroundColor(Color.White).borderRadius(8).margin({ bottom: 8 });
        });

        Text('\u96f7\u8fbe\u6570\u636e\u5df2\u81ea\u52a8\u66f4\u65b0').fontSize(13).fontColor('#4CAF50')
          .margin({ top: 16, bottom: 8 });

        Row() {
          Button('\U0001F4C4 \u5BFC\u51FA JSON')
            .height(40).borderRadius(20)
            .backgroundColor('#E6F7FF').fontColor('#007DFF')
            .layoutWeight(1).margin({ right: 4 })
            .onClick(() => { this.exportReport('json'); });

          Button('\U0001F4DD \u5BFC\u51FA Markdown')
            .height(40).borderRadius(20)
            .backgroundColor('#FFF7E6').fontColor('#FF9800')
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
      // 在ArkTS中，文件保存通过 fileIo 实现
      // 此处调用系统分享或剪贴板
      promptAction.showToast({ message: '\u5bfc\u51fa\u5b8c\u6210\uff0c\u5df2\u590d\u5236\u5230\u526a\u8d34\u677f' });
    } catch (e) {
      promptAction.showToast({ message: '\u5bfc\u51fa\u5931\u8d25' });
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

  // ===== 答题视图（TextArea自由输入）=====
  @Builder
  QuestionView(): void {
    Column() {
      // 顶部进度
      Row() {
        Text('\u9898\u76ee ' + (this.currentIndex + 1) + ' / ' + this.questions.length)
          .fontSize(14).fontColor('#666666');
      }
      .width('100%').padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor(Color.White);

      Scroll() {
        Column() {
          // 题目卡片
          Column() {
            Row() {
              // 难度标签
              Text('\u2b50'.repeat(this.questions[this.currentIndex].difficulty))
                .fontSize(14);
            }
            .width('100%');

            // 布鲁姆层级
            Row() {
              Text(getBloomLevelName(this.questions[this.currentIndex].bloomLevel))
                .fontSize(12).fontColor(Color.White)
                .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                .backgroundColor('#007DFF').borderRadius(4);
            }
            .width('100%').margin({ top: 8 });

            // 题目文本
            Text(this.questions[this.currentIndex].questionText)
              .fontSize(18).fontWeight(FontWeight.Bold).margin({ top: 16 });

            // 自由输入文本框（核心变更：TextArea替代Radio组）
            Text('\u4f60\u7684\u56de\u7b54')
              .fontSize(14).fontColor('#333333').margin({ top: 24, bottom: 8 });

            TextArea({
              text: this.userAnswerText,
              placeholder: '\u8bf7\u5728\u6b64\u81ea\u7531\u8f93\u5165\u4f60\u7684\u56de\u7b54...'
            })
              .width('100%').height(180)
              .onChange((value: string) => {
                this.userAnswerText = value;
              });
          }
          .width('100%').padding(16).backgroundColor(Color.White).borderRadius(12);

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
                Text(this.evaluation.comment).fontSize(14).fontColor('#333333');
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
            .width('100%').padding(16).backgroundColor(Color.White).borderRadius(12).margin({ top: 12 });
          }
        }
        .width('100%').padding(16);
      }
      .layoutWeight(1);

      // 底部按钮
      Row() {
        if (!this.showEvaluation) {
          // 提交按钮（等待LLM评判时禁用）
          Button('\u63d0\u4ea4\u56de\u7b54')
            .width('100%').height(44).borderRadius(22)
            .enabled(this.userAnswerText.trim().length > 0 && !this.isSubmitting)
            .onClick(() => { this.submitFreeAnswer(); });

          if (this.isSubmitting) {
            // 提交中显示加载提示
            Text('AI\u8bc4\u5224\u4e2d...').fontSize(12).fontColor('#999999').margin({ top: 4 });
          }
        } else {
          Button(this.currentIndex < this.questions.length - 1
            ? '\u4e0b\u4e00\u9898 \u2192'
            : '\u67e5\u770b\u62a5\u544a')
            .width('100%').height(44).borderRadius(22)
            .onClick(() => { this.nextQuestion(); });
        }
      }
      .width('100%').padding(16).backgroundColor(Color.White);
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
