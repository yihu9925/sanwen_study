// 课程详情页 - 三问学习法
import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { Course } from '../models/Course';
import { KnowledgeGraph, GraphNode } from '../models/KnowledgeGraph';
import { Controversy } from '../models/Controversy';
import { Question } from '../models/Question';
import { CourseService } from '../services/CourseService';
import { KnowledgeBaseService } from '../services/KnowledgeBaseService';
import { AssessmentService } from '../services/AssessmentService';
import { LLMService } from '../services/LLMService';
import { relationalStore } from '@kit.ArkData';
import { RelationalStoreManager } from '../services/RelationalStoreManager';
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
          this.loadQuestions()
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
      // 更新雷达数据（根据生成结果设置初始值）
      if (this.course) {
        const store = RelationalStoreManager.getStore();
        const radarUpdateValues: relationalStore.ValuesBucket = {
          radar_data: JSON.stringify({
            remember: 60,
            understand: 45,
            apply: 30,
            analyze: 25,
            evaluate: 20,
            create: 15
          }),
          updated_at: new Date().toISOString()
        };
        const radarPredicates = new relationalStore.RdbPredicates('course');
        radarPredicates.equalTo('id', this.courseId);
        await store.update(radarUpdateValues, radarPredicates);

        // 重新加载课程数据
        this.course = await CourseService.getCourseById(this.courseId);
      }

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
    }
    .width('100%')
    .height('100%');
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
    });
  }

  @Builder
  TabContent(): void {
    Column() {
      if (this.currentTab === 0) {
        this.KnowledgeGraphTab();
      } else if (this.currentTab === 1) {
        this.ControversyTab();
      } else {
        this.AssessmentTab();
      }
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
