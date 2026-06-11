// 课程详情页 - 三问学习法
import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { picker } from '@kit.CoreFileKit';
import { fileIo } from '@kit.CoreFileKit';
import { Course } from '../models/Course';
import { KnowledgeGraph, GraphNode } from '../models/KnowledgeGraph';
import { Controversy } from '../models/Controversy';
import { Question, getBloomLevelName } from '../models/Question';
import { Document } from '../models/Document';
import { CourseService } from '../services/CourseService';
import { KnowledgeBaseService } from '../services/KnowledgeBaseService';
import { AssessmentService } from '../services/AssessmentService';
import { LLMService } from '../services/LLMService';
import { relationalStore } from '@kit.ArkData';
import { AppRouter } from '../AppRouter';
import { EventBus, EVENTS } from '../utils/EventBus';
import { CourseHealthService, CourseContentStatus } from '../services/CourseHealthService';
import { ExportService } from '../services/ExportService';
import { KnowledgeGraphView } from '../components/KnowledgeGraphView';
import { ControversyView } from '../components/ControversyView';
import { RadarChartView } from '../components/RadarChartView';
import { getTimeAgo } from '../utils/DateUtils';
import { UiStyle, StyleColors } from '../utils/UiStyle';
import { parseParagraphs, parseContentSegments, ContentSegment } from '../utils/ContentUtils';
import { StudyStatsService } from '../services/StudyStatsService';

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
  @StorageLink('themeMode') themeMode: string = 'auto';
  @StorageLink('uiStyle') uiStyle: string = 'default';
  @State contentStatus: CourseContentStatus | null = null;
  @State isFilling: number = 0;  // 0=none, 1=filling Q1, 2=filling Q2, 3=filling Q3
  @State graphKey: number = 0;   // 递增以强制刷新知识图谱组件
  @State radarKey: number = 0;   // 递增以强制刷新雷达图组件
  @State expandedChapterId: string = '';   // 当前展开的章节卡片ID
  @State selectedGraphNodeId: string = ''; // 选中聚焦的图节点ID
  @State selectedDoc: Document | null = null;
  @State showDocSheet: boolean = false;
  @State hasScrolledControversy: boolean = false;
  @StorageLink('genStep') generationStep: string = '';
  @StorageLink('genProgress') generationProgress: number = 0;
  @State docSegments: ContentSegment[] = [];
  private pollTimer: number = -1;
  private loadedOnce: boolean = false;

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string>;
    this.courseId = params?.['courseId'] || '';
    
    if (this.courseId) {
      this.loadCourseData();
      this.setupEventListeners();
    }
    StudyStatsService.startStudySession();
  }

  // 从AssessmentDetailPage返回时全面刷新
  onPageShow(): void {
    if (this.courseId && this.loadedOnce) {
      this.loadCourseData();
    }
    this.loadedOnce = true;
  }

  aboutToDisappear(): void {
    EventBus.clear();
    if (this.pollTimer > 0) {
      clearInterval(this.pollTimer);
      this.pollTimer = -1;
    }
  }

  colors(): StyleColors {
    return UiStyle.getColors(this.uiStyle, this.themeMode === 'dark');
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
        await Promise.all([
          this.loadKnowledgeGraph(),
          this.loadControversies(),
          this.loadQuestions(),
          this.loadDocuments()
        ]);

        if (this.knowledgeGraph.nodes.length === 0 && this.knowledgeGraph.edges.length === 0) {
          const genCourseId: string = AppStorage.get<string>('genCourseId') || '';
          if (genCourseId === this.courseId) {
            // 后台仍在生成,进入等待模式
            this.startPollingForCompletion();
            this.isLoading = true;
            return;
          }
          // 全新生成
          await this.generateContent();
          return;
        }
      }
      this.isLoading = false;
    } catch (error) {
      console.error('Load course failed:', error);
      promptAction.showToast({ message: '\u52a0\u8f7d\u8bfe\u7a0b\u5931\u8d25' });
      this.isLoading = false;
    }
  }

  private startPollingForCompletion(): void {
    if (this.pollTimer > 0) return;
    this.pollTimer = setInterval(async () => {
      const genCourseId: string = AppStorage.get<string>('genCourseId') || '';
      if (genCourseId !== this.courseId) {
        clearInterval(this.pollTimer);
        this.pollTimer = -1;
        setTimeout(() => {
          this.loadCourseData();
        }, 800);
      }
    }, 2000);
  }

  // 仅重新加载课程数据（不触发内容生成）
  async reloadCourseOnly(): Promise<void> {
    this.course = await CourseService.getCourseById(this.courseId);
  }

  async loadKnowledgeGraph(): Promise<void> {
    this.knowledgeGraph = await KnowledgeBaseService.getKnowledgeGraph(this.courseId);
    this.graphKey++;   // 触发知识图谱Canvas重建
    this.radarKey++;   // 触发雷达图Canvas重建（雷达数据可能一起更新）
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

  // 补全缺失的某一问
  async fillMissingPart(part: number): Promise<void> {
    if (!this.course || this.isFilling > 0) return;
    this.isFilling = part;
    try {
      const question = this.course.question;
      let success = false;
      const labels: Record<number, string> = { 1: '\u77e5\u8bc6\u56fe\u8c31', 2: '\u4e89\u8bae\u70b9\u5206\u6790', 3: '\u6d4b\u8bc4\u9898' };
      promptAction.showToast({ message: '\u6b63\u5728\u751f\u6210' + (labels[part] || '') + '...' });

      if (part === 1) {
        success = await CourseHealthService.fillQ1KnowledgeGraph(this.courseId, question);
      } else if (part === 2) {
        success = await CourseHealthService.fillQ2Controversies(this.courseId, question);
      } else if (part === 3) {
        success = await CourseHealthService.fillQ3Questions(this.courseId, question);
      }

      // 重新加载所有数据并触发 Canvas 重建
      const results = await Promise.all([
        CourseService.getCourseById(this.courseId),
        KnowledgeBaseService.getKnowledgeGraph(this.courseId),
        KnowledgeBaseService.getControversies(this.courseId),
        AssessmentService.getQuestions(this.courseId)
      ]);
      this.course = results[0] as Course | null;
      this.knowledgeGraph = results[1] as KnowledgeGraph;
      this.controversies = results[2] as Controversy[];
      this.questions = results[3] as Question[];
      this.graphKey++;
      this.radarKey++;
      // 重新检测状态
      this.contentStatus = await CourseHealthService.checkCourseStatus(this.courseId);

      if (success) {
        promptAction.showToast({ message: (labels[part] || '') + '\u751f\u6210\u5b8c\u6210\uff01' });
      } else {
        promptAction.showToast({ message: (labels[part] || '') + '\u751f\u6210\u5931\u8d25\uff0c\u8bf7\u68c0\u67e5 API \u914d\u7f6e' });
      }
    } catch (e) {
      const errMsg: string = (e as Error).message || '\u672a\u77e5\u9519\u8bef';
      promptAction.showToast({ message: '\u586b\u8865\u5931\u8d25: ' + errMsg.substring(0, 40) });
    } finally {
      this.isFilling = 0;
    }
  }

  async generateContent(): Promise<void> {
    if (!this.course) {
      return;
    }

    try {
      this.isLoading = true;
      AppStorage.set<string>('genCourseId', this.courseId);
      await CourseService.resetProgress(this.courseId);
      
      // ===== 第一步：AI自动生成资料库内容 =====
      this.generationStep = '\u6b63\u5728\u751f\u6210\u5b66\u4e60\u8d44\u6599...';
      this.generationProgress = 10;
      const docCount: number = await KnowledgeBaseService.generateAIDocuments(
        this.courseId, this.course.question
      );

      // ===== 第二步：加载资料库文档，作为三问生成的基础素材 =====
      this.generationStep = '\u6b63\u5728\u52a0\u8f7d\u8d44\u6599\u5e93...';
      this.generationProgress = 25;
      await this.loadDocuments();
      let materialContent: string = this.course.question;

      // 将资料库中的文档内容追加到提示词中
      if (this.documents.length > 0) {
        let docTexts: string[] = [];
        for (let d = 0; d < this.documents.length; d++) {
          const doc = this.documents[d];
          if (doc.content) {
            const snippet: string = doc.content.length > 500
              ? doc.content.substring(0, 500)
              : doc.content;
            docTexts.push('\u3010' + doc.title + '\u3011' + snippet);
          }
        }
        if (docTexts.length > 0) {
          const combined: string = docTexts.join('\n');
          materialContent = this.course.question + '\n\n---\n\u53c2\u8003\u8d44\u6599\uff1a\n' +
            (combined.length > 5000 ? combined.substring(0, 5000) : combined);
        }
      }

      // 并行生成：知识图谱 + 争议点 + 测评题（互不依赖，都是基于materialContent）
      this.generationStep = '\u6b63\u5728\u751f\u6210\u77e5\u8bc6\u56fe\u8c31\u3001\u4e89\u8bae\u70b9\u53ca\u6d4b\u8bc4\u9898...';
      this.generationProgress = 40;
      const difficultyHint: string = this.documents.length >= 3 || materialContent.length > 2500
        ? '\u5185\u5bb9\u6bd4\u8f83\u4e30\u5bcc\uff0c\u9898\u76ee\u5e94\u7ed3\u5408\u5177\u4f53\u6982\u5ff5\u51fa\u9898\uff0c\u8003\u5bdf\u7406\u89e3\u548c\u5e94\u7528\u80fd\u529b'
        : '\u57fa\u7840\u5185\u5bb9\u4e3a\u4e3b\uff0c\u9898\u76ee\u6ce8\u91cd\u7406\u89e3\u548c\u5e94\u7528\uff0c\u96be\u5ea6\u4e2d\u7b49';
      await Promise.all([
        (async () => {
          this.generationStep = '\u6b63\u5728\u751f\u6210\u77e5\u8bc6\u56fe\u8c31...';
          this.generationProgress = 45;
          try {
            await KnowledgeBaseService.generateKnowledgeGraph(this.courseId, materialContent);
          } catch (kgErr) {
            console.error('Knowledge graph first attempt failed: ' + (kgErr as Error).message);
            this.generationStep = '\u77e5\u8bc6\u56fe\u8c31\u91cd\u8bd5\u4e2d...';
            try {
              await KnowledgeBaseService.generateKnowledgeGraph(this.courseId, materialContent);
            } catch (kgRetryErr) {
              console.error('Knowledge graph retry failed: ' + (kgRetryErr as Error).message);
            }
          }
        })(),
        (async () => {
          this.generationStep = '\u6b63\u5728\u751f\u6210\u4e89\u8bae\u70b9...';
          this.generationProgress = 50;
          await KnowledgeBaseService.discoverControversies(
            this.courseId,
            materialContent
          );
        })(),
        (async () => {
          this.generationStep = '\u6b63\u5728\u751f\u6210\u6d4b\u8bc4\u9898...';
          this.generationProgress = 55;
          await AssessmentService.deleteQuestionsByCourse(this.courseId);
          await AssessmentService.deleteLearningRecordsByCourse(this.courseId);
          await AssessmentService.generateQuestions(
            this.courseId,
            materialContent,
            8,
            difficultyHint
          );
        })()
      ]);

      // 重新加载所有三问数据（确保UI跟随更新）
      this.generationStep = '\u6b63\u5728\u52a0\u8f7d\u751f\u6210\u7ed3\u679c...';
      this.generationProgress = 85;
      const results = await Promise.all([
        CourseService.getCourseById(this.courseId),
        KnowledgeBaseService.getKnowledgeGraph(this.courseId),
        KnowledgeBaseService.getControversies(this.courseId),
        AssessmentService.getQuestions(this.courseId),
        KnowledgeBaseService.getDocuments(this.courseId)
      ]);
      this.course = results[0] as Course | null;
      this.knowledgeGraph = results[1] as KnowledgeGraph;
      this.controversies = results[2] as Controversy[];
      this.questions = results[3] as Question[];
      this.documents = results[4] as Document[];
      // 重新检测内容健康状态
      this.contentStatus = await CourseHealthService.checkCourseStatus(this.courseId);

      const courseTitle: string = this.course?.title || '';
      const docInfo: string = docCount > 0 ? ' \uff08\u8d44\u6599\u5e93' + docCount + '\u7bc7\uff09' : '';
      promptAction.showToast({ message: courseTitle + ' \u751f\u6210\u5b8c\u6bd5' + docInfo });
    } catch (error) {
      const errMsg: string = (error as Error).message || '\u672a\u77e5\u9519\u8bef';
      console.error('Generate content failed:', errMsg);
      promptAction.showToast({ message: '\u751f\u6210\u5931\u8d25: ' + errMsg.substring(0, 50) });
    } finally {
      // 只在内容完整时才清空生成标记，否则保留以便新页面续上等待
      if (this.course && this.knowledgeGraph.nodes.length > 0 && this.knowledgeGraph.nodes[0].label !== '\u6838\u5fc3\u6982\u5ff5') {
        AppStorage.set<string>('genCourseId', '');
      }
      this.isLoading = false;
    }
  }

  async markQ1Complete(): Promise<void> {
    if (!this.courseId || this.course?.progressQ1 === 1) return;
    await CourseService.updateProgress(this.courseId, 1);
    await this.reloadCourseOnly();
    this.currentTab = 1;
  }

  async markQ2Complete(): Promise<void> {
    if (!this.courseId || this.course?.progressQ2 === 1) return;
    await CourseService.updateProgress(this.courseId, 2);
    await this.reloadCourseOnly();
    this.currentTab = 2;
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
    .backgroundColor(this.colors().pageBg)
    .bindSheet($$this.showDocSheet, this.DocSheet(), {
      height: 500,
      backgroundColor: this.colors().cardBg,
      dragBar: true
    });
  }

  @Builder
  LoadingView(): void {
    Column() {
      Row() {
        Text('\u2715')
          .fontSize(22)
          .fontColor('#999999')
          .padding(12)
          .onClick(() => {
            this.isLoading = false;
            promptAction.showToast({ message: '\u5df2\u8fd4\u56de\u4e3b\u9875\uff0c\u540e\u53f0\u7ee7\u7eed\u751f\u6210\u4e2d...' });
            AppRouter.back();
          });
      }
      .width('100%');

      Column() {
        LoadingProgress()
          .width(48)
          .height(48);

        if (this.generationStep.length > 0) {
          Text(this.generationStep)
            .fontSize(15)
            .fontColor('#555555')
            .margin({ top: 16 });

          Row() {
            Row()
              .width(this.generationProgress + '%')
              .height(6)
              .backgroundColor('#007DFF')
              .borderRadius(3);
          }
          .width('80%')
          .height(6)
          .backgroundColor('#E0E0E0')
          .borderRadius(3)
          .margin({ top: 12 });

          Text(String(this.generationProgress) + '%')
            .fontSize(12)
            .fontColor('#999999')
            .margin({ top: 4 });
        } else {
          Text('\u52a0\u8f7d\u4e2d...')
            .fontSize(14)
            .fontColor('#999999')
            .margin({ top: 12 });
        }
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center);
    }
    .width('100%')
    .height('100%');
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

      // 内容健康状态栏
      this.ContentHealthBar();

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
    .backgroundColor(this.colors().pageBg);
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

  // 三问内容健康检测状态栏
  @Builder
  ContentHealthBar(): void {
    Column() {
      if (this.contentStatus) {
        Row() {
          // Q1 状态
          this.HealthChip('\u7b2c\u4e00\u95ee', this.contentStatus.q1KnowledgeGraph, 1);
          // Q2 状态
          this.HealthChip('\u7b2c\u4e8c\u95ee', this.contentStatus.q2Controversies, 2);
          // Q3 状态
          this.HealthChip('\u7b2c\u4e09\u95ee', this.contentStatus.q3Questions, 3);
        }
        .width('100%').justifyContent(FlexAlign.Center).padding({ top: 4, bottom: 4 });

        // 如果缺失，显示提示
        if (!this.contentStatus.allComplete) {
          Row() {
            Text('\u26a0\ufe0f' + this.contentStatus.missingParts.join('\u3001') + '\u5c1a\u672a\u751f\u6210')
              .fontSize(11).fontColor('#FF9800');
          }
          .width('100%').justifyContent(FlexAlign.Center);
        } else {
          Row() {
            Text('\u2714\ufe0f \u4e09\u95ee\u5185\u5bb9\u5df2\u5b8c\u6574')
              .fontSize(11).fontColor('#4CAF50');
          }
          .width('100%').justifyContent(FlexAlign.Center);
        }
      }
    }
    .width('100%').padding({ left: 12, right: 12, top: 2, bottom: 2 });
  }

  // 单个健康状态芯片
  @Builder
  HealthChip(label: string, done: boolean, part: number): void {
    Row() {
      Row()
        .width(8).height(8)
        .backgroundColor(done ? '#4CAF50' : '#FF9800')
        .borderRadius(4);

      Text(label + (done ? ' \u2713' : '!'))
        .fontSize(12).fontColor(done ? '#4CAF50' : '#FF9800')
        .margin({ left: 4 });

      if (!done && this.isFilling !== part) {
        Text('\u586b\u8865')
          .fontSize(10).fontColor(Color.White)
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .backgroundColor('#007DFF').borderRadius(8)
          .margin({ left: 4 })
          .onClick(() => {
            this.fillMissingPart(part);
          });
      }

      if (this.isFilling === part) {
        LoadingProgress().width(12).height(12).margin({ left: 4 });
      }
    }
    .padding({ left: 8, right: 8, top: 4, bottom: 4 })
    .backgroundColor(done ?
      this.colors().pageBg :
      this.colors().pageBg)
    .borderRadius(12)
    .margin({ left: 4, right: 4 });
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
    .backgroundColor(this.colors().pageBg);
  }

  @Builder
  TabBar(): void {
    Row() {
      this.TabItemTwoLine('第一问', '知识图谱', 0);
      this.TabItemTwoLine('第二问', '争议点', 1);
      this.TabItemTwoLine('第三问', '测评', 2);
      this.TabItemTwoLine('资料库', '', 3);
    }
    .width('100%')
    .height(48)
    .backgroundColor(this.colors().pageBg);
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

  // 双行排版Tab项（第一行：三问步骤名，第二行：功能名）
  @Builder
  TabItemTwoLine(line1: string, line2: string, index: number): void {
    Column() {
      if (line2.length > 0) {
        Text(line1)
          .fontSize(11)
          .fontColor(this.currentTab === index ? '#007DFF' : '#666666')
          .fontWeight(this.currentTab === index ? FontWeight.Bold : FontWeight.Normal);
        Text(line2)
          .fontSize(11)
          .fontColor(this.currentTab === index ? '#007DFF' : '#666666')
          .fontWeight(this.currentTab === index ? FontWeight.Bold : FontWeight.Normal)
          .margin({ top: 1 });
      } else {
        Text(line1)
          .fontSize(14)
          .fontColor(this.currentTab === index ? '#007DFF' : '#666666')
          .fontWeight(this.currentTab === index ? FontWeight.Bold : FontWeight.Normal);
      }

      if (this.currentTab === index) {
        Row()
          .width(30)
          .height(2)
          .backgroundColor('#007DFF')
          .margin({ top: 2 });
      }
    }
    .layoutWeight(1)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.currentTab = index;
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
            Text('📚')
              .fontSize(64);
            Text('\u6682\u65E0\u8D44\u6599')
              .fontSize(16)
              .fontColor('#999999')
              .margin({ top: 16 });
            Text('\u70B9\u51FB\u4E0B\u65B9\u6309\u94AE\u4E0A\u4F20\u5B66\u4E60\u8D44\u6599\u6216\u8BA9AI\u81EA\u52A8\u722C\u53D6\u7F51\u7EDC\u8D44\u6E90')
              .fontSize(12)
              .fontColor('#CCCCCC')
              .margin({ top: 8 });
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center);
        } else {
          List() {
            ForEach(this.documents, (doc: Document, index: number) => {
              ListItem() {
                Row() {
                  Column() {
                    Text(doc.sourceType === 'ai' ? '🤖' : '📄')
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
                        .backgroundColor(this.colors().accentLight)
                        .borderRadius(4);

                      if (doc.keywords.length > 0) {
                        Text(doc.keywords.slice(0, 3).join(' / '))
                          .fontSize(11)
                          .fontColor(this.colors().textTertiary)
                          .margin({ left: 8 });
                      }
                    }
                    .margin({ top: 4 });
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)
                  .margin({ left: 8 });
                }
                .width('100%')
                .padding(12)
                .backgroundColor(this.colors().cardBg)
                .borderRadius(8)
                .onClick(() => {
                  this.selectedDoc = this.documents[index];
                  this.docSegments = parseContentSegments(this.documents[index].content || '');
                  this.showDocSheet = true;
                });
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

    // 上传资料按钮
    Row() {
      Button('📄 \u4E0A\u4F20\u6587\u4EF6')
        .height(40).borderRadius(20)
        .backgroundColor('#007DFF').fontColor(Color.White)
        .layoutWeight(1).margin({ right: 6 })
        .onClick(() => {
          this.showUploadDialog();
        });

      Button('🔍 AI\u722C\u53D6\u8D44\u6599')
        .height(40).borderRadius(20)
        .backgroundColor('#E6F7FF').fontColor('#007DFF')
        .layoutWeight(1).margin({ left: 6 })
        .onClick(() => {
          this.showCrawlDialog();
        });
    }
    .width('100%').padding(16);
  }

  // 显示上传对话框 — 确认后打开系统文件选择器
  showUploadDialog(): void {
    promptAction.showDialog({
      title: '\u4E0A\u4F20\u5B66\u4E60\u8D44\u6599',
      message: '\u70B9\u51FB\u201C\u6DFB\u52A0\u5E76\u91CD\u751F\u6210\u201D\u540E\u5C06\u6253\u5F00\u7CFB\u7EDF\u6587\u4EF6\u9009\u62E9\u5668\uFF0C\u652F\u6301 PDF\u3001Word\u3001Markdown\u3001TXT \u683C\u5F0F\u3002',
      buttons: [
        { text: '\u53D6\u6D88', color: '#999999' },
        { text: '\u6DFB\u52A0\u5E76\u91CD\u751F\u6210', color: '#007DFF' }
      ]
    }).then(async (data: promptAction.ShowDialogSuccessResponse) => {
      if (data.index === 1) {
        try {
          const docPicker = new picker.DocumentViewPicker();
          const result: string[] = await docPicker.select();
          if (result.length > 0) {
            const fileUri: string = result[0];
            await KnowledgeBaseService.generateAIDocuments(this.courseId, this.course?.question || '');
            await this.loadDocuments();
            await this.generateContent();
          }
        } catch (e) {
          promptAction.showToast({ message: '\u6587\u4EF6\u9009\u62E9\u5931\u8D25' });
        }
      }
    }).catch(() => {});
  }

  // 显示AI爬取对话框
  showCrawlDialog(): void {
    promptAction.showDialog({
      title: 'AI\u722C\u53D6\u7F51\u7EDC\u8D44\u6E90',
      message: '\u5C06\u81EA\u52A8\u641C\u7D22\u4E0E\u8BFE\u7A0B\u76F8\u5173\u7684\u516C\u5F00\u6587\u6863\u3001\u6559\u7A0B\u548C\u8D44\u6E90\u3002\u8BF7\u786E\u4FDD\u5DF2\u914D\u7F6E API Key\u3002',
      buttons: [
        { text: '\u53D6\u6D88', color: '#999999' },
        { text: '\u5F00\u59CB\u722C\u53D6', color: '#007DFF' }
      ]
    }).then(async (data: promptAction.ShowDialogSuccessResponse) => {
      if (data.index === 1) {
        await this.crawlWebResources();
      }
    }).catch(() => {});
  }

  // 添加文本文档
  async addTextDocument(): Promise<void> {
    promptAction.showDialog({
      title: '\u6DFB\u52A0\u6587\u672C\u5185\u5BB9',
      message: '\u8BF7\u8F93\u5165\u5B66\u4E60\u8D44\u6599\u6807\u9898\u548C\u5185\u5BB9\uff1a',
      buttons: [
        { text: '\u53D6\u6D88', color: '#999999' }
      ]
    }).catch(() => {});
    // TODO: Add TextInput dialog in future iteration
    promptAction.showToast({ message: '\u8BF7\u5728 DevEco Studio \u4E2D\u901A\u8FC7 @kit.FilePicker \u5B9E\u73B0\u6587\u4EF6\u9009\u62E9' });
  }

  // AI爬取网络资源
  async crawlWebResources(): Promise<void> {
    try {
      promptAction.showToast({ message: '\u6B63\u5728\u751F\u6210\u8D44\u6599...' });
      const content: string = this.course ? this.course.question : '';
      const docCount: number = await KnowledgeBaseService.generateAIDocuments(this.courseId, content);
      await this.loadDocuments();
      if (docCount > 0) {
        promptAction.showToast({ message: '\u751F\u6210\u5B8C\u6210\uff0c\u5171\u6DFB\u52A0 ' + docCount + ' \u4E2A\u8D44\u6599' });
      } else {
        promptAction.showToast({ message: '\u751F\u6210\u5931\u8D25\uff0c\u8BF7\u68C0\u67E5\u6570\u636E\u5E93\u72B6\u6001' });
      }
    } catch (e) {
      promptAction.showToast({ message: '\u751F\u6210\u5931\u8D25\uff0c\u8BF7\u7A0D\u540E\u91CD\u8BD5' });
    }
  }

  @Builder
  KnowledgeGraphTab(): void {
    Scroll() {
      Column() {
        // 知识图谱可视化组件
        KnowledgeGraphView({ graph: this.knowledgeGraph, forceRedraw: this.graphKey, focusNodeId: this.selectedGraphNodeId });

        // 检测是否为mock数据（LLM生成失败时的fallback）
        if (this.knowledgeGraph.nodes.length > 0 && this.knowledgeGraph.nodes[0].label === '\u6838\u5fc3\u6982\u5ff5') {
          Column() {
            Text('\u26a0\ufe0f \u77e5\u8bc6\u56fe\u8c31\u751f\u6210\u5931\u8d25\uff0c\u8bf7\u68c0\u67e5 API \u914d\u7f6e')
              .fontSize(14)
              .fontColor('#FF9800')
              .margin({ top: 16 });

            Button('\u91cd\u8bd5\u751f\u6210')
              .fontSize(14)
              .margin({ top: 8 })
              .onClick(() => {
                this.generateContent();
              });
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .padding(16);
        }

        // 课程章节列表（基于知识图谱节点生成）
        if (this.knowledgeGraph.nodes.length > 0) {
          // ...existing chapter list code...
          Column() {
            Row() {
              Text('\u7ae0\u8282\u5bfc\u822a')
                .fontSize(18)
                .fontWeight(FontWeight.Bold);
            }
            .width('100%')
            .padding(16);

            List() {
              ForEach(this.knowledgeGraph.nodes, (node: GraphNode) => {
                ListItem() {
                  Column() {
                    // 卡片头部 - 点击聚焦图谱
                    Row() {
                      Text(node.label)
                        .fontSize(16)
                        .fontWeight(FontWeight.Medium)
                        .layoutWeight(1);

                      Text(this.expandedChapterId === node.id ? '\u25bc' : '\u25b6')
                        .fontSize(12)
                        .fontColor('#CCCCCC');
                    }
                    .width('100%')
                    .padding(12)
                    .backgroundColor(this.colors().cardBg)
                    .borderRadius(this.expandedChapterId === node.id ? { topLeft: 8, topRight: 8 } : 8)
                    .onClick(() => {
                      this.selectedGraphNodeId = node.id;
                      if (this.expandedChapterId === node.id) {
                        this.expandedChapterId = '';
                      } else {
                        this.expandedChapterId = node.id;
                      }
                    });

                    // 展开内容
                    if (this.expandedChapterId === node.id) {
                      Column() {
                        if (node.description) {
                          this.RenderSegments(parseContentSegments(node.description));
                        }

                        if (node.children.length > 0) {
                          Text('\u5173\u8054\u5B50\u6982\u5FF5')
                            .fontSize(13)
                            .fontWeight(FontWeight.Bold)
                            .fontColor(this.colors().textPrimary)
                            .margin({ top: 12, bottom: 6 });

                          ForEach(node.children, (child: GraphNode) => {
                            Row() {
                              Circle().width(6).height(6).fill('#52C41A');
                              Text(child.label)
                                .fontSize(13)
                                .fontColor(this.colors().textPrimary)
                                .margin({ left: 6 });
                            }
                            .width('100%')
                            .margin({ top: 2 });
                          });
                        }

                        if (node.relatedDocs.length > 0) {
                          Text('\u53C2\u8003\u8D44\u6599')
                            .fontSize(13)
                            .fontWeight(FontWeight.Bold)
                            .fontColor(this.colors().textPrimary)
                            .margin({ top: 12, bottom: 6 });

                          ForEach(node.relatedDocs, (docId: string) => {
                            Text('\uD83D\uDCC4 \u8D44\u6599 ' + docId)
                              .fontSize(13)
                              .fontColor('#007DFF')
                              .margin({ top: 2 });
                          });
                        }
                      }
                      .width('100%')
                      .padding({ left: 16, right: 16, bottom: 14, top: 4 })
                      .backgroundColor(this.colors().pageBg)
                      .borderRadius({ bottomLeft: 8, bottomRight: 8 });
                    }
                  }
                  .width('100%')
                  .borderRadius(8);
                }
                .margin({ bottom: 6 });
              });
            }
            .width('100%')
            .divider({ strokeWidth: 0 })
            .padding(16);
          }
          .width('100%')
          .backgroundColor(this.colors().pageBg)
          .borderRadius(12)
          .margin({ top: 16 });
        }

        if (this.course) {
          Button(this.course?.progressQ1 === 1 ? '\u2713 \u5DF2\u5B66\u5B8C' : '\u5B8C\u6210\u5B66\u4E60')
            .width('80%')
            .height(44)
            .backgroundColor(this.course?.progressQ1 === 1 ? '#4CAF50' : '#007DFF')
            .fontColor(Color.White)
            .borderRadius(22)
            .margin({ top: 16, bottom: 24 })
            .enabled(this.course?.progressQ1 !== 1)
            .onClick(() => {
              this.markQ1Complete();
            });
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
        ControversyView({ controversies: this.controversies });

        if (this.course) {
          Button(this.course?.progressQ2 === 1 ? '\u2713 \u5DF2\u5B66\u5B8C' : '\u5B8C\u6210\u5B66\u4E60')
            .width('80%')
            .height(44)
            .backgroundColor(this.course?.progressQ2 === 1 ? '#4CAF50' : '#007DFF')
            .fontColor(Color.White)
            .borderRadius(22)
            .margin({ top: 16, bottom: 24 })
            .enabled(this.course?.progressQ2 !== 1)
            .onClick(() => {
              this.markQ2Complete();
            });
        }
      }
      .width('100%')
      .padding(16);
    }
    .width('100%')
    .layoutWeight(1)
    .scrollBar(BarState.Auto)
    .onScroll(() => {
      this.hasScrolledControversy = true;
    });
  }

  @Builder
  AssessmentTab(): void {
    Scroll() {
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
          List() {
            ForEach(this.questions, (question: Question, index: number) => {
              ListItem() {
                Column() {
                  Text(`题目 ${index + 1}: ${question.questionText}`)
                    .fontSize(16)
                    .fontWeight(FontWeight.Bold);

                  Row() {
                    Text('\u5e03\u9c81\u59c6\u5c42\u7ea7: ' + getBloomLevelName(question.bloomLevel))
                      .fontSize(12).fontColor('#007DFF')
                      .padding({ left: 6, right: 6 }).backgroundColor('#E6F7FF').borderRadius(4);
                    Text('\u2b50'.repeat(question.difficulty))
                      .fontSize(12).margin({ left: 8 });
                    Text('\u5f00\u653e\u5f0f\u56de\u7b54')
                      .fontSize(11).fontColor('#999999').margin({ left: 8 });
                  }
                }
                .width('100%')
                .padding(16)
                .backgroundColor(this.colors().cardBg)
                .borderRadius(8);
              }
              .margin({ bottom: 8 });
            });
          }
          .width('100%')
          .height(300)
          .padding(16);

          if (this.course) {
            RadarChartView({ radarData: this.course.radarData, forceRedraw: this.radarKey })
              .margin({ top: 16 });
          }

          Button('开始答题')
            .width('80%')
            .margin({ top: 16, bottom: 24 })
            .onClick(() => {
              AppRouter.toAssessmentDetail(this.courseId);
            });

          if (this.course && this.course.progressPercent === 100) {
            Row() {
              Button('导出 JSON')
                .height(40).borderRadius(20)
                .fontSize(14)
                .layoutWeight(1).margin({ right: 4 })
                .onClick(() => { this.exportReport('json'); });
              Button('导出 Markdown')
                .height(40).borderRadius(20)
                .fontSize(14)
                .layoutWeight(1).margin({ left: 4 })
                .onClick(() => { this.exportReport('md'); });
            }
            .width('80%')
            .margin({ bottom: 24 });
          }
        }
      }
      .width('100%');
    }
    .width('100%')
    .layoutWeight(1)
    .scrollBar(BarState.Auto);
  }

  @Builder
  RenderSegments(segments: ContentSegment[]): void {
    ForEach(segments, (seg: ContentSegment) => {
      this.SegmentItem(seg);
    });
  }

  @Builder
  SegmentItem(seg: ContentSegment): void {
    if (seg.type === 'code') {
      Column() {
        Text(seg.content)
          .fontSize(14)
          .fontFamily('Courier New')
          .fontColor(this.colors().textPrimary)
          .lineHeight(22)
          .width('100%');
      }
      .width('100%')
      .padding(12)
      .backgroundColor(this.colors().pageBg)
      .borderRadius(8)
      .margin({ bottom: 12 });
    } else {
      Text(seg.content)
        .fontSize(15)
        .fontColor(this.colors().textSecondary)
        .lineHeight(26)
        .width('100%')
        .textIndent(32)
        .margin({ bottom: 12 });
    }
  }

  @Builder
  DocSheet(): void {
    Column() {
      if (this.selectedDoc) {

        Scroll() {
          Column() {
            Text(this.selectedDoc.title)
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.colors().textPrimary)
              .lineHeight(30)
              .width('100%');

            Row() {
              Text(this.selectedDoc.sourceType === 'ai' ? 'AI\u751F\u6210' : '\u7528\u6237\u4E0A\u4F20')
                .fontSize(12)
                .fontColor(this.selectedDoc.sourceType === 'ai' ? '#52C41A' : '#FA8C16')
                .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                .backgroundColor(this.colors().accentLight)
                .borderRadius(4);
            }
            .width('100%')
            .margin({ top: 12 });

            if (this.selectedDoc.uploadedAt) {
              Text(getTimeAgo(this.selectedDoc.uploadedAt))
                .fontSize(12)
                .fontColor(this.colors().textSecondary)
                .width('100%')
                .margin({ top: 6 });
            }

            if (this.selectedDoc.keywords.length > 0) {
              Flex({ wrap: FlexWrap.Wrap }) {
                ForEach(this.selectedDoc.keywords, (kw: string) => {
                  Text(kw)
                    .fontSize(12)
                    .fontColor(this.colors().textSecondary)
                    .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                    .backgroundColor(this.colors().divider)
                    .borderRadius(12)
                    .margin({ right: 6, bottom: 6 });
                });
              }
              .width('100%')
              .margin({ top: 12 });
            }

            Divider().margin({ top: 16, bottom: 16 });

            ForEach(this.docSegments, (seg: ContentSegment) => {
              this.SegmentItem(seg);
            });

            if (this.docSegments.length === 0) {
              Text('\u6682\u65E0\u5185\u5BB9')
                .fontSize(15)
                .fontColor(this.colors().textSecondary)
                .width('100%');
            }
          }
          .width('100%')
          .padding(20);
        }
        .layoutWeight(1)
        .scrollBar(BarState.Auto);
      }
    }
    .width('100%')
    .height('100%');
  }

  async exportReport(format: string): Promise<void> {
    try {
      if (!this.course) return;
      const title = this.course.title;
      let content = '';
      if (format === 'json') {
        content = await ExportService.exportReportAsJSON(this.courseId, title);
      } else {
        content = await ExportService.exportReportAsMarkdown(this.courseId, title);
      }
      if (!content || content.length === 0) {
        promptAction.showToast({ message: '\u6682\u65E0\u6D4B\u8BC4\u6570\u636E\u53EF\u5BFC\u51FA' });
        return;
      }

      const fileName: string = 'assessment_report_' + new Date().getTime() + '.' + format;

      // 尝试系统文件保存对话框
      try {
        const docPicker = new picker.DocumentViewPicker();
        const saveResult: string[] = await docPicker.save({ newFileNames: [fileName] });
        if (saveResult && saveResult.length > 0) {
          const destFile: fileIo.File = fileIo.openSync(saveResult[0], fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY);
          fileIo.writeSync(destFile.fd, content);
          fileIo.closeSync(destFile);
          promptAction.showToast({ message: '\u5BFC\u51FA\u6210\u529F' });
          return;
        }
      } catch {
        // 回退：写入应用沙箱
      }

      const context: Context = getContext(this) as Context;
      const filePath: string = context.filesDir + '/' + fileName;
      const file: fileIo.File = fileIo.openSync(filePath, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY);
      fileIo.writeSync(file.fd, content);
      fileIo.closeSync(file);
      promptAction.showToast({ message: '\u5BFC\u51FA\u6210\u529F\uFF1A' + fileName });
    } catch (e) {
      console.error('Export failed: ' + (e as Error).message);
      promptAction.showToast({ message: '\u5BFC\u51FA\u5931\u8D25' });
    }
  }
}
