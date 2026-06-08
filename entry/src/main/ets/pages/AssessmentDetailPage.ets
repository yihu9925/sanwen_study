// 测评详情页 - 答题交互
import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { Question } from '../models/Question';
import { AssessmentService } from '../services/AssessmentService';
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
      console.error('Load questions failed:', error);
      promptAction.showToast({ message: '加载题目失败' });
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
      const result = await AssessmentService.submitAnswer(
        'default_user',
        this.courseId,
        question.id,
        this.selectedAnswer
      );

      this.isCorrect = result;
      this.hasSubmitted = true;
    } catch (error) {
      console.error('Submit answer failed:', error);
      promptAction.showToast({ message: '提交失败' });
    }
  }

  nextQuestion(): void {
    if (this.currentIndex < this.questions.length - 1) {
      this.currentIndex++;
      this.selectedAnswer = '';
      this.hasSubmitted = false;
    } else {
      promptAction.showToast({ message: '答题完成！' });
      AppRouter.back();
    }
  }

  build() {
    Column() {
      if (this.isLoading) {
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
      LoadingProgress()
        .width(48)
        .height(48);
      
      Text('加载中...')
        .fontSize(14)
        .fontColor('#999999')
        .margin({ top: 12 });
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center);
  }

  @Builder
  EmptyView(): void {
    Column() {
      Text('暂无题目')
        .fontSize(16)
        .fontColor('#999999');

      Button('返回')
        .margin({ top: 16 })
        .onClick(() => {
          AppRouter.back();
        });
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center);
  }

  @Builder
  QuestionView(): void {
    Column() {
      // 进度指示器
      Row() {
        Text(`题目 ${this.currentIndex + 1} / ${this.questions.length}`)
          .fontSize(14)
          .fontColor('#666666');
      }
      .width('100%')
      .padding(16)
      .backgroundColor(Color.White);

      // 题目内容
      Column() {
        Text(this.questions[this.currentIndex].questionText)
          .fontSize(18)
          .fontWeight(FontWeight.Bold);

        // 选项
        Column() {
          ForEach(this.questions[this.currentIndex].options, (option: string, index: number) => {
            Row() {
              Radio({ value: index.toString(), group: 'question_options' })
                .width(24)
                .height(24)
                .checked(this.selectedAnswer === index.toString())
                .onChange((isChecked: boolean) => {
                  if (isChecked) {
                    this.selectedAnswer = index.toString();
                  }
                });

              Text(option)
                .fontSize(16)
                .margin({ left: 12 });
            }
            .width('100%')
            .padding(12)
            .backgroundColor(this.selectedAnswer === index.toString() ? '#E3F2FD' : Color.White)
            .borderRadius(8)
            .margin({ top: 8 });
          });
        }
        .width('100%')
        .margin({ top: 24 });

        // 答案反馈
        if (this.hasSubmitted) {
          Column() {
            Row() {
              Text(this.isCorrect ? '✓ 正确' : '✗ 错误')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.isCorrect ? '#4CAF50' : '#F44336');
            };
          }
          .width('100%')
          .padding(16)
          .backgroundColor(this.isCorrect ? '#E8F5E9' : '#FFEBEE')
          .borderRadius(8)
          .margin({ top: 24 });
        }
      }
      .width('100%')
      .layoutWeight(1)
      .padding(16);

      // 操作按钮
      Row() {
        if (!this.hasSubmitted) {
          Button('提交答案')
            .width('100%')
            .enabled(this.selectedAnswer !== '')
            .onClick(() => {
              this.submitAnswer();
            });
        } else {
          Button('下一题')
            .width('100%')
            .onClick(() => {
              this.nextQuestion();
            });
        }
      }
      .width('100%')
      .padding(16)
      .backgroundColor(Color.White);
    }
    .width('100%')
    .height('100%');
  }
}
