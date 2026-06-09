// 课程详情页 - 三问学习法
import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { Course } from '../models/Course';
import { KnowledgeGraph, GraphNode } from '../models/KnowledgeGraph';
import { Controversy } from '../models/Controversy';
import { Question } from '../models/Question';
import { Document } from '../models/Document';
import { CourseService } from '../services/CourseService';
import { KnowledgeBaseService } from '../services/KnowledgeBaseService';
import { AssessmentService } from '../services/AssessmentService';
import { LLMService } from '../services/LLMService';
import { relationalStore } from '@kit.ArkData';
import { AppRouter } from '../AppRouter';
import { EventBus, EVENTS } from '../utils/EventBus';
import { KnowledgeGraphView } from '../components/KnowledgeGraphView';
import { ControversyView } from '../components/ControversyView';
import { RadarChartView } from '../components/RadarChartView';

@Entry
@Component
struct CourseDetailPage {
  @State courseId: string = '';
  @State course: Course | null = null;
  @State currentTab: number = 0;
  @State knowledgeGraph: KnowledgeGraph = { nodes: [], edges: [] };
  @State controversies: Controversy[] = [];
  @State questions: Question[] = [];
  @State documents: Document[] = [];
  @State isLoading: boolean = false;

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string>;
    this.courseId = params?.['courseId'] || '';
    
    if (this.courseId) {
      this.loadCourseData();
      this.setupEventListeners();
    }
  }

  aboutToDisappear(): void {
    EventBus.clear();
  }

  setupEventListeners(): void {
    EventBus.on(EVENTS.GRAPH_READY, (data) => {
      const eventData = data as Record<string, Object>;
      if (eventData?.['courseId'] === this.courseId) {
        this.loadKnowledgeGraph();
        this.reloadCourseOnly();
      }
    });

    EventBus.on(EVENTS.CONTROVERSY_READY, (data) => {
      const eventData = data as Record<string, Object>;
      if (eventData?.['courseId'] === this.courseId) {
        this.loadControversies();
        this.reloadCourseOnly();
      }
    });

    EventBus.on(EVENTS.QUESTIONS_READY, (data) => {
      const eventData = data as Record<string, Object>;
      if (eventData?.['courseId'] === this.courseId) {
        this.loadQuestions();
        this.reloadCourseOnly();
      }
    });
  }

  async loadCourseData(): Promise<void> {
    try {
      this.isLoading = true;
      this.course = await CourseService.getCourseById(this.courseId);
      
      if (this.course) {
        // 加载三问数据
        await Promise.all([
          this.loadKnowledgeGraph(),
          this.loadControversies(),
          this.loadQuestions(),
          this.loadDocuments()
        ]);

        // 如果内容为空（新创建的课程），自动触发生成
        if (this.knowledgeGraph.nodes.length === 0 && this.knowledgeGraph.edges.length === 0) {
          this.generateContent();
        }
      }
    } catch (error) {
      console.error('Load course failed:', error);
      promptAction.showToast({ message: '加载课程失败' });
    } finally {
      this.isLoading = false;
    }
  }

  // 仅重新加载课程数据（不触发内容生成）
  async reloadCourseOnly(): Promise<void> {
    this.course = await CourseService.getCourseById(this.courseId);
  }

  async loadKnowledgeGraph(): Promise<void> {
    this.knowledgeGraph = await KnowledgeBaseService.getKnowledgeGraph(this.courseId);
  }

  async loadControversies(): Promise<void> {
    this.controversies = await KnowledgeBaseService.getControversies(this.courseId);
  }

  async loadQuestions(): Promise<void> {
    this.questions = await AssessmentService.getQuestions(this.courseId);
  }

  async loadDocuments(): Promise<void> {
    this.documents = await KnowledgeBaseService.getDocuments(this.courseId);
  }

  async generateContent(): Promise<void> {
    if (!this.course) {
      return;
    }

    try {
      this.isLoading = true;
      
      // 生成知识图谱
      await KnowledgeBaseService.generateKnowledgeGraph(
        this.courseId,
        this.course.question
      );

      // 生成争议点
      await KnowledgeBaseService.discoverControversies(
        this.courseId,
        this.course.question
      );

      // 生成测评题
      await AssessmentService.generateQuestions(
        this.courseId,
        this.course.question,
        1,
        5
      );

      const courseTitle: string = this.course?.title || '';
      // 重新加载课程数据
      this.course = await CourseService.getCourseById(this.courseId);

      promptAction.showToast({ message: courseTitle + ' 生成完毕' });
    } catch (error) {
      console.error('Generate content failed:', error);
      promptAction.showToast({ message: '内容生成失败' });
    } finally {
      this.isLoading = false;
    }
  }

  build() {
    Column() {
      if (this.isLoading) {
        this.LoadingView();
      } else if (this.course) {
        this.ContentView();
      } else {
        this.ErrorView();
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
  ErrorView(): void {
    Column() {
      Text('课程加载失败')
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
  ContentView(): void {
    Column() {
      // 顶部标题栏
      this.HeaderBar();

      // Tab栏
      this.TabBar();

      // 内容区域
      this.TabContent();

      // 底部进度条
      this.ProgressBar();
    }
    .width('100%')
    .height('100%');
  }

  @Builder
  ProgressBar(): void {
    Row() {
      Column() {
        Row() {
          Text('\u5b66\u4e60\u8fdb\u5ea6')
            .fontSize(12).fontColor('#666666');
          Text(String(this.course?.progressPercent || 0) + '%')
            .fontSize(12).fontWeight(FontWeight.Bold)
            .fontColor('#007DFF').margin({ left: 8 });
        }
        .width('100%');

        Row() {
          // 进度条
          Row() {
            Row()
              .width(String(this.course?.progressPercent || 0) + '%')
              .height(6)
              .backgroundColor('#007DFF')
              .borderRadius(3);
          }
          .width('100%').height(6).backgroundColor('#E0E0E0').borderRadius(3);
        }
        .width('100%').margin({ top: 4 });

        // 三问步骤状态
        Row() {
          this.StepDot(1, '\u7b2c\u4e00\u95ee', (this.course?.progressQ1 || 0) === 1);
          this.StepDot(2, '\u7b2c\u4e8c\u95ee', (this.course?.progressQ2 || 0) === 1);
          this.StepDot(3, '\u7b2c\u4e09\u95ee', (this.course?.progressQ3 || 0) === 1);
        }
        .width('100%').margin({ top: 6 });
      }
      .layoutWeight(1);
    }
    .width('100%').padding({ left: 16, right: 16, top: 8, bottom: 12 })
    .backgroundColor(Color.White);
  }

  @Builder
  StepDot(step: number, label: string, done: boolean): void {
    Row() {
      Row()
        .width(10).height(10)
        .backgroundColor(done ? '#4CAF50' : '#D1D5DB')
        .borderRadius(5);
      Text(label)
        .fontSize(11).fontColor(done ? '#4CAF50' : '#999999')
        .margin({ left: 4 });
    }
    .layoutWeight(1).justifyContent(FlexAlign.Center);
  }

  @Builder
  HeaderBar(): void {
    Row() {
      Button('返回')
        .onClick(() => {
          AppRouter.back();
        });

      Column() {
        Text(this.course?.title || '')
          .fontSize(18)
          .fontWeight(FontWeight.Bold);

        Text(this.course?.domain || '')
          .fontSize(12)
          .fontColor('#999999');
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center);

      Button('生成')
        .onClick(() => {
          this.generateContent();
        });
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Color.White);
  }

  @Builder
  TabBar(): void {
    Row() {
      this.TabItem('第一问：知识图谱', 0);
      this.TabItem('第二问：争议点', 1);
      this.TabItem('第三问：测评', 2);
      this.TabItem('资料库', 3);
    }
    .width('100%')
    .height(48)
    .backgroundColor(Color.White);
  }

  @Builder
  TabItem(title: string, index: number): void {
    Column() {
      Text(title)
        .fontSize(14)
        .fontColor(this.currentTab === index ? '#007DFF' : '#666666')
        .fontWeight(this.currentTab === index ? FontWeight.Bold : FontWeight.Normal);

      if (this.currentTab === index) {
        Row()
          .width(40)
          .height(2)
          .backgroundColor('#007DFF')
          .margin({ top: 4 });
      }
    }
    .layoutWeight(1)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.currentTab = index;
      // 长按可跳转到独立页面
    });
  }

  // 跳转到独立的三问页面
  @Builder
  IndependentPageLink(pageType: string): void {
    Row() {
      Text('\u5c55\u5f00 >')
        .fontSize(10).fontColor('#007DFF');
    }
    .padding({ left: 6, right: 6, top: 2, bottom: 2 })
    .backgroundColor('#E6F7FF').borderRadius(4)
    .margin({ left: 8 })
    .onClick(() => {
      if (!this.courseId) return;
      if (pageType === 'q1') {
        AppRouter.toQ1KnowledgeGraph(this.courseId);
      } else if (pageType === 'q2') {
        AppRouter.toQ2Controversy(this.courseId);
      } else if (pageType === 'q3') {
        AppRouter.toQ3Assessment(this.courseId);
      }
    });
  }

  @Builder
  TabContent(): void {
    Column() {
      if (this.currentTab === 0) {
        this.KnowledgeGraphTab();
      } else if (this.currentTab === 1) {
        this.ControversyTab();
      } else if (this.currentTab === 3) {
        this.MaterialsTab();
      } else {
        this.AssessmentTab();
      }
    }
    .width('100%')
    .layoutWeight(1);
  }

  @Builder
  MaterialsTab(): void {
    Scroll() {
      Column() {
        if (this.documents.length === 0) {
          Column() {
            Text('\U0001F4DA')
              .fontSize(48);
            Text('\u6682\u65E0\u8D44\u6599')
              .fontSize(16)
              .fontColor('#999999')
              .margin({ top: 16 });
            Text('AI\u81EA\u52A8\u722C\u53D6\u7684\u8D44\u6599\u548C\u7528\u6237\u4E0A\u4F20\u7684\u6587\u6863\u5C06\u663E\u793A\u5728\u8FD9\u91CC')
              .fontSize(12)
              .fontColor('#CCCCCC')
              .margin({ top: 8 });
          }
          .width('100%')
          .height(200)
          .justifyContent(FlexAlign.Center);
        } else {
          List() {
            ForEach(this.documents, (doc: Document) => {
              ListItem() {
                Row() {
                  Column() {
                    Text(doc.sourceType === 'ai' ? '\U0001F916' : '\U0001F4C4')
                      .fontSize(24);
                  }
                  .width(40)
                  .height(40)
                  .justifyContent(FlexAlign.Center);

                  Column() {
                    Text(doc.title || '\u672A\u547D\u540D\u6587\u6863')
                      .fontSize(15)
                      .fontWeight(FontWeight.Medium)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis });

                    Row() {
                      Text(doc.sourceType === 'ai' ? 'AI\u8865\u5145' : '\u7528\u6237\u4E0A\u4F20')
                        .fontSize(11)
                        .fontColor('#007DFF')
                        .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                        .backgroundColor('#E6F7FF')
                        .borderRadius(4);

                      if (doc.keywords.length > 0) {
                        Text(doc.keywords.slice(0, 3).join(' / '))
                          .fontSize(11)
                          .fontColor('#999999')
                          .margin({ left: 8 });
                      }
                    }
                    .margin({ top: 4 });
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)
                  .margin({ left: 8 });

                  Text('>')
                    .fontSize(16)
                    .fontColor('#CCCCCC');
                }
                .width('100%')
                .padding(12)
                .backgroundColor(Color.White)
                .borderRadius(8);
              }
              .margin({ bottom: 8 });
            });
          }
          .width('100%')
          .layoutWeight(1);
        }
      }
      .width('100%')
      .padding(16);
    }
    .width('100%')
    .layoutWeight(1);
  }

  @Builder
  KnowledgeGraphTab(): void {
    Scroll() {
      Column() {
        // 知识图谱可视化组件
        KnowledgeGraphView({ graph: this.knowledgeGraph });
        
        // 雷达图展示
        if (this.course) {
          RadarChartView({ radarData: this.course.radarData })
            .margin({ top: 16 });
        }
      }
      .width('100%')
      .padding(16);
    }
    .width('100%')
    .layoutWeight(1)
    .scrollBar(BarState.Auto);
  }

  @Builder
  ControversyTab(): void {
    Scroll() {
      Column() {
        // 争议点可视化组件
        ControversyView({ controversies: this.controversies });
      }
      .width('100%')
      .padding(16);
    }
    .width('100%')
    .layoutWeight(1)
    .scrollBar(BarState.Auto);
  }

  @Builder
  AssessmentTab(): void {
    Column() {
      if (this.questions.length === 0) {
        Column() {
          Text('📝')
            .fontSize(64);
          
          Text('AI正在生成测评题...')
            .fontSize(16)
            .fontColor('#999999')
            .margin({ top: 16 });

          Button('重新生成')
            .fontSize(14)
            .margin({ top: 12 })
            .onClick(() => {
              this.generateContent();
            });
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center);
      } else {
        Column() {
          List() {
            ForEach(this.questions, (question: Question, index: number) => {
              ListItem() {
                Column() {
                  Text(`题目 ${index + 1}: ${question.questionText}`)
                    .fontSize(16)
                    .fontWeight(FontWeight.Bold);

                  ForEach(question.options, (option: string, optIndex: number) => {
                    Row() {
                      Radio({ value: optIndex.toString(), group: question.id })
                        .width(20)
                        .height(20);

                      Text(option)
                        .fontSize(14)
                        .margin({ left: 8 });
                    }
                    .width('100%')
                    .margin({ top: 8 });
                  });
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

          Button('开始答题')
            .width('80%')
            .margin({ bottom: 16 })
            .onClick(() => {
              AppRouter.toAssessmentDetail(this.courseId);
            });
        }
        .width('100%')
        .layoutWeight(1);
      }
    }
    .width('100%')
    .layoutWeight(1);
  }
}
