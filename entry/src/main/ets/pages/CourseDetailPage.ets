// 课程详情页 - 三问学习法
import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
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
import { KnowledgeGraphView } from '../components/KnowledgeGraphView';
import { ControversyView } from '../components/ControversyView';
import { RadarChartView } from '../components/RadarChartView';
import { getTimeAgo } from '../utils/DateUtils';
import { parseParagraphs } from '../utils/ContentUtils';

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
  @State contentStatus: CourseContentStatus | null = null;
  @State isFilling: number = 0;  // 0=none, 1=filling Q1, 2=filling Q2, 3=filling Q3
  @State graphKey: number = 0;   // 递增以强制刷新知识图谱组件
  @State radarKey: number = 0;   // 递增以强制刷新雷达图组件
  @State expandedChapterId: string = '';   // 当前展开的章节卡片ID
  @State selectedGraphNodeId: string = ''; // 选中聚焦的图节点ID
  @State selectedDoc: Document | null = null;
  @State showDocSheet: boolean = false;
  @State docParagraphs: string[] = [];
  private loadedOnce: boolean = false;

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string>;
    this.courseId = params?.['courseId'] || '';
    
    if (this.courseId) {
      this.loadCourseData();
      this.setupEventListeners();
    }
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
        await this.loadKnowledgeGraph();
      } else if (part === 2) {
        success = await CourseHealthService.fillQ2Controversies(this.courseId, question);
        await this.loadControversies();
      } else if (part === 3) {
        success = await CourseHealthService.fillQ3Questions(this.courseId, question);
        await this.loadQuestions();
      }

      // 重新加载所有数据
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
      
      // ===== 第一步：AI自动生成资料库内容 =====
      promptAction.showToast({ message: '\u6b63\u5728\u751f\u6210\u5b66\u4e60\u8d44\u6599...' });
      const docCount: number = await KnowledgeBaseService.generateAIDocuments(
        this.courseId, this.course.question
      );

      // ===== 第二步：加载资料库文档，作为三问生成的基础素材 =====
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

      // 生成知识图谱（基于资料库内容）
      await KnowledgeBaseService.generateKnowledgeGraph(
        this.courseId,
        materialContent
      );

      // 生成争议点（基于资料库内容）
      await KnowledgeBaseService.discoverControversies(
        this.courseId,
        materialContent
      );

      // 生成测评题（基于资料库内容）
      await AssessmentService.generateQuestions(
        this.courseId,
        materialContent,
        1,
        5
      );

      // 重新加载所有三问数据（确保UI跟随更新）
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
    .backgroundColor(this.themeMode === 'dark' ? '#222222' : '#F5F5F5')
    .bindSheet($$this.showDocSheet, this.DocSheet(), {
      height: 500,
      backgroundColor: this.themeMode === 'dark' ? '#333333' : Color.White,
      dragBar: true
    });
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
    .backgroundColor(done ? '#E8F5E9' : '#FFF3E0')
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
    .backgroundColor(Color.White);
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
                        .backgroundColor(this.themeMode === 'dark' ? '#1A2A3A' : '#E6F7FF')
                        .borderRadius(4);

                      if (doc.keywords.length > 0) {
                        Text(doc.keywords.slice(0, 3).join(' / '))
                          .fontSize(11)
                          .fontColor(this.themeMode === 'dark' ? '#CCCCCC' : '#999999')
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
                .backgroundColor(this.themeMode === 'dark' ? '#333333' : Color.White)
                .borderRadius(8)
                .onClick(() => {
                  this.selectedDoc = this.documents[index];
                  this.docParagraphs = parseParagraphs(this.documents[index].content || '\u6682\u65E0\u5185\u5BB9');
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

  // 显示上传对话框（上传后自动重新生成三问内容）
  showUploadDialog(): void {
    promptAction.showDialog({
      title: '\u4E0A\u4F20\u5B66\u4E60\u8D44\u6599',
      message: '\u652F\u6301 PDF\u3001Word\u3001Markdown\u3001TXT \u683C\u5F0F\u3002\u8BF7\u5C06\u6587\u4EF6\u653E\u7F6E\u5728\u8BBE\u5907\u7684 Documents \u76EE\u5F55\u4E0B\u3002\n\n\u5F53\u524D\u7248\u672C\u652F\u6301\u901A\u8FC7\u4EE5\u4E0B\u65B9\u5F0F\u6DFB\u52A0\uff1a\n1. \u4F7F\u7528 @kit.FilePicker \u9009\u62E9\u6587\u4EF6\n2. \u8F93\u5165\u6587\u672C\u5185\u5BB9\u76F4\u63A5\u6DFB\u52A0\n\n\u63D0\u793A\uFF1A\u6DFB\u52A0\u8D44\u6599\u540E\u7CFB\u7EDF\u5C06\u81EA\u52A8\u91CD\u65B0\u751F\u6210\u4E09\u95EE\u5185\u5BB9',
      buttons: [
        { text: '\u53D6\u6D88', color: '#999999' },
        { text: '\u6DFB\u52A0\u5E76\u91CD\u751F\u6210', color: '#007DFF' }
      ]
    }).then(async (data: promptAction.ShowDialogSuccessResponse) => {
      if (data.index === 1) {
        // 先添加文档（模拟），再触发重生成
        await KnowledgeBaseService.generateAIDocuments(this.courseId, this.course?.question || '');
        await this.loadDocuments();
        await this.generateContent();
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

        // 课程章节列表（基于知识图谱节点生成）
        if (this.knowledgeGraph.nodes.length > 0) {
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
                    .backgroundColor(this.themeMode === 'dark' ? '#333333' : Color.White)
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
                          Text(node.description)
                            .fontSize(14)
                            .fontColor(this.themeMode === 'dark' ? '#FFFFFF' : '#333333')
                            .lineHeight(22)
                            .width('100%');
                        }

                        if (node.children.length > 0) {
                          Text('\u5173\u8054\u5B50\u6982\u5FF5')
                            .fontSize(13)
                            .fontWeight(FontWeight.Bold)
                            .fontColor(this.themeMode === 'dark' ? '#FFFFFF' : '#333333')
                            .margin({ top: 12, bottom: 6 });

                          ForEach(node.children, (child: GraphNode) => {
                            Row() {
                              Circle().width(6).height(6).fill('#52C41A');
                              Text(child.label)
                                .fontSize(13)
                                .fontColor(this.themeMode === 'dark' ? '#FFFFFF' : '#333333')
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
                            .fontColor(this.themeMode === 'dark' ? '#FFFFFF' : '#333333')
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
                      .backgroundColor(this.themeMode === 'dark' ? '#2A2A2A' : '#FAFAFA')
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
          .backgroundColor(this.themeMode === 'dark' ? '#2A2A2A' : '#FAFAFA')
          .borderRadius(12)
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
                .backgroundColor(this.themeMode === 'dark' ? '#333333' : Color.White)
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
        }
      }
      .width('100%');
    }
    .width('100%')
    .layoutWeight(1)
    .scrollBar(BarState.Auto);
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
              .fontColor(this.themeMode === 'dark' ? '#FFFFFF' : '#1A1A1A')
              .lineHeight(30)
              .width('100%');

            Row() {
              Text(this.selectedDoc.sourceType === 'ai' ? 'AI\u751F\u6210' : '\u7528\u6237\u4E0A\u4F20')
                .fontSize(12)
                .fontColor(this.selectedDoc.sourceType === 'ai' ? '#52C41A' : '#FA8C16')
                .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                .backgroundColor(this.selectedDoc.sourceType === 'ai' ?
                  (this.themeMode === 'dark' ? '#1A2A1A' : '#F6FFED') :
                  (this.themeMode === 'dark' ? '#2A1A0A' : '#FFF7E6'))
                .borderRadius(4);
            }
            .width('100%')
            .margin({ top: 12 });

            if (this.selectedDoc.uploadedAt) {
              Text(getTimeAgo(this.selectedDoc.uploadedAt))
                .fontSize(12)
                .fontColor(this.themeMode === 'dark' ? '#888888' : '#AAAAAA')
                .width('100%')
                .margin({ top: 6 });
            }

            if (this.selectedDoc.keywords.length > 0) {
              Flex({ wrap: FlexWrap.Wrap }) {
                ForEach(this.selectedDoc.keywords, (kw: string) => {
                  Text(kw)
                    .fontSize(12)
                    .fontColor(this.themeMode === 'dark' ? '#BBBBBB' : '#666666')
                    .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                    .backgroundColor(this.themeMode === 'dark' ? '#444444' : '#F0F0F0')
                    .borderRadius(12)
                    .margin({ right: 6, bottom: 6 });
                });
              }
              .width('100%')
              .margin({ top: 12 });
            }

            Divider().margin({ top: 16, bottom: 16 });

            ForEach(this.docParagraphs, (para: string) => {
              Text(para)
                .fontSize(15)
                .fontColor(this.themeMode === 'dark' ? '#CCCCCC' : '#444444')
                .lineHeight(26)
                .width('100%')
                .margin({ bottom: 12 });
            });
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
}
