import { router } from '@kit.ArkUI';
import { KnowledgeBaseService, DocWithCourse } from '../services/KnowledgeBaseService';
import { CourseService } from '../services/CourseService';
import { Course } from '../models/Course';
import { getTimeAgo } from '../utils/DateUtils';
import { parseParagraphs } from '../utils/ContentUtils';

@Component
export struct KnowledgeHub {
  @Prop @Watch('onRefreshKeyChange') refreshKey: number = 0;
  @StorageLink('activeTabIndex') activeTabIndex: number = 0;
  @StorageLink('themeMode') themeMode: string = 'auto';

  private userId: string = 'default_user';

  @State searchText: string = '';
  @State activeFilter: string = 'all';
  @State allDocuments: DocWithCourse[] = [];
  @State filteredDocs: DocWithCourse[] = [];
  @State domains: string[] = [];
  @State selectedDoc: DocWithCourse | null = null;
  @State showDocSheet: boolean = false;
  @State contentParagraphs: string[] = [];
  @State isLoading: boolean = true;
  @State errorMsg: string = '';

  aboutToAppear(): void {
    this.loadData();
  }

  onRefreshKeyChange(): void {
    this.loadData();
  }

  async loadData(): Promise<void> {
    this.isLoading = true;
    this.errorMsg = '';
    try {
      const courses: Course[] = await CourseService.getCoursesByUser(this.userId);
      const domainSet: Set<string> = new Set<string>();
      for (const c of courses) {
        if (c.domain) {
          domainSet.add(c.domain);
        }
      }
      this.domains = Array.from(domainSet);

      this.allDocuments = await KnowledgeBaseService.getDocumentsByUser(this.userId);
      this.applyFilters();
    } catch (e) {
      this.errorMsg = '\u52A0\u8F7D\u5931\u8D25';
    } finally {
      this.isLoading = false;
    }
  }

  applyFilters(): void {
    let result: DocWithCourse[] = this.allDocuments;

    if (this.searchText.trim()) {
      const keyword: string = this.searchText.trim().toLowerCase();
      result = result.filter((doc: DocWithCourse): boolean =>
        doc.title.toLowerCase().includes(keyword) ||
        doc.content.toLowerCase().includes(keyword)
      );
    }

    if (this.activeFilter !== 'all') {
      result = result.filter((doc: DocWithCourse): boolean =>
        doc.domain === this.activeFilter
      );
    }

    this.filteredDocs = result;
  }

  onSearchChange(val: string): void {
    this.searchText = val;
    this.applyFilters();
  }

  openDocDetail(doc: DocWithCourse): void {
    this.selectedDoc = doc;
    this.contentParagraphs = parseParagraphs(doc.content || '\u6682\u65E0\u5185\u5BB9');
    this.showDocSheet = true;
  }

  goToCourse(courseId: string): void {
    this.showDocSheet = false;
    router.pushUrl({
      url: 'pages/CourseDetailPage',
      params: { courseId }
    });
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Text('\uD83D\uDCDA \u77E5\u8BC6\u5E93')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.themeMode === 'dark' ? '#FFFFFF' : '#1A1A1A');
      }
      .width('100%')
      .padding(16);

      // 搜索框
      TextInput({ placeholder: '\u641C\u7D22\u8D44\u6599...', text: this.searchText })
        .width('100%')
        .height(40)
        .padding({ left: 12, right: 12 })
        .backgroundColor(this.themeMode === 'dark' ? '#333333' : '#F5F5F5')
        .placeholderColor(this.themeMode === 'dark' ? '#888888' : '#CCCCCC')
        .borderRadius(20)
        .onChange((val: string) => this.onSearchChange(val));

      // 筛选栏 - 按课程分类
      Row() {
        Button('\u5168\u90E8')
          .fontSize(13)
          .fontColor(this.activeFilter === 'all' ? Color.White :
            (this.themeMode === 'dark' ? '#CCCCCC' : '#666666'))
          .backgroundColor(this.activeFilter === 'all' ? '#007DFF' :
            (this.themeMode === 'dark' ? '#444444' : '#F0F0F0'))
          .borderRadius(16)
          .height(32)
          .margin({ right: 8 })
          .onClick(() => {
            this.activeFilter = 'all';
            this.applyFilters();
          });
        ForEach(this.domains, (domain: string) => {
          Button(domain)
            .fontSize(13)
            .fontColor(this.activeFilter === domain ? Color.White :
              (this.themeMode === 'dark' ? '#CCCCCC' : '#666666'))
            .backgroundColor(this.activeFilter === domain ? '#007DFF' :
              (this.themeMode === 'dark' ? '#444444' : '#F0F0F0'))
            .borderRadius(16)
            .height(32)
            .margin({ right: 8 })
            .onClick(() => {
              this.activeFilter = domain;
              this.applyFilters();
            });
        });
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 4 });

      // 内容区
      if (this.isLoading) {
        this.LoadingSkeleton();
      } else if (this.errorMsg) {
        this.ErrorState();
      } else if (this.filteredDocs.length === 0 && this.allDocuments.length === 0) {
        this.EmptyState();
      } else if (this.filteredDocs.length === 0) {
        this.NoMatchState();
      } else {
        this.DocumentList();
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeMode === 'dark' ? '#222222' : '#FFFFFF')
    .bindSheet($$this.showDocSheet, this.DocSheet(), {
      height: 600,
      backgroundColor: this.themeMode === 'dark' ? '#222222' : Color.White,
      dragBar: true
    });
  }

  @Builder
  LoadingSkeleton(): void {
    Column() {
      ForEach([1, 2, 3] as number[], () => {
        Column() {
          Column() {
            Blank().width('70%').height(16).backgroundColor('#333333').borderRadius(4);
            Blank().width('40%').height(12).backgroundColor('#333333').borderRadius(4).margin({ top: 8 });
            Row() {
              Blank().width(50).height(10).backgroundColor('#333333').borderRadius(4);
              Blank().layoutWeight(1);
              Blank().width(40).height(10).backgroundColor('#333333').borderRadius(4);
            }
            .width('100%')
            .margin({ top: 8 });
          }
          .width('100%')
          .padding(16)
          .backgroundColor(this.themeMode === 'dark' ? '#2A2A2A' : '#F5F5F5')
          .borderRadius(10);
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 8 });
      });
    }
    .width('100%')
    .layoutWeight(1);
  }

  @Builder
  ErrorState(): void {
    Column() {
      Text('\u26A0\uFE0F')
        .fontSize(48);
      Text('\u52A0\u8F7D\u5931\u8D25')
        .fontSize(16)
        .fontColor('#999999')
        .margin({ top: 16 });
      Button('\u70B9\u51FB\u91CD\u8BD5')
        .fontSize(14)
        .margin({ top: 12 })
        .onClick(() => this.loadData());
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center);
  }

  @Builder
  EmptyState(): void {
    Column() {
      Text('\uD83D\uDCC2')
        .fontSize(64);
      Text('\u6682\u65E0\u77E5\u8BC6\u5E93\u8D44\u6599')
        .fontSize(16)
        .fontColor(this.themeMode === 'dark' ? '#CCCCCC' : '#999999')
        .margin({ top: 16 });
      Text('\u8BF7\u5148\u521B\u5EFA\u8BFE\u7A0B\uFF0CAI\u4F1A\u81EA\u52A8\u751F\u6210\u5B66\u4E60\u8D44\u6599')
        .fontSize(13)
        .fontColor(this.themeMode === 'dark' ? '#888888' : '#BBBBBB')
        .margin({ top: 8 });
      Button('\u53BB\u521B\u5EFA\u8BFE\u7A0B')
        .fontSize(14)
        .margin({ top: 16 })
        .onClick(() => {
          this.activeTabIndex = 0;
        });
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center);
  }

  @Builder
  NoMatchState(): void {
    Column() {
      Text('\uD83D\uDD0D')
        .fontSize(48);
      Text('\u6CA1\u6709\u5339\u914D\u7684\u8D44\u6599')
        .fontSize(16)
        .fontColor(this.themeMode === 'dark' ? '#CCCCCC' : '#999999')
        .margin({ top: 16 });
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center);
  }

  @Builder
  DocumentList(): void {
    Scroll() {
      Column() {
        ForEach(this.filteredDocs, (doc: DocWithCourse) => {
          Column() {
            Row() {
              Text('\uD83D\uDCC4')
                .fontSize(28)
                .margin({ right: 12 });

              Column() {
                Text(doc.title)
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.themeMode === 'dark' ? '#FFFFFF' : '#1A1A1A')
                  .lineHeight(22)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis });

                Text('\u8BFE\u7A0B\uFF1A' + doc.courseTitle)
                  .fontSize(12)
                  .fontColor(this.themeMode === 'dark' ? '#AAAAAA' : '#888888')
                  .margin({ top: 4 });

                Row() {
                  Text(doc.domain || '\u672A\u5206\u7C7B')
                    .fontSize(11)
                    .fontColor('#007DFF')
                    .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                    .backgroundColor(this.themeMode === 'dark' ? '#1A2A3A' : '#E6F7FF')
                    .borderRadius(4);

                  Text(getTimeAgo(doc.uploadedAt))
                    .fontSize(11)
                    .fontColor(this.themeMode === 'dark' ? '#888888' : '#AAAAAA')
                    .margin({ left: 8 });
                }
                .margin({ top: 4 });
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start);
            }
            .width('100%')
            .padding(16)
            .backgroundColor(this.themeMode === 'dark' ? '#333333' : Color.White)
            .borderRadius(10);
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 8 })
          .onClick(() => this.openDocDetail(doc));
        });
      }
      .width('100%');
    }
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
              Text(this.selectedDoc.domain || '\u672A\u5206\u7C7B')
                .fontSize(12)
                .fontColor('#007DFF')
                .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                .backgroundColor(this.themeMode === 'dark' ? '#1A2A3A' : '#E6F7FF')
                .borderRadius(4);

              Text(this.selectedDoc.sourceType === 'ai' ? 'AI\u751F\u6210' : '\u7528\u6237\u4E0A\u4F20')
                .fontSize(12)
                .fontColor(this.selectedDoc.sourceType === 'ai' ? '#52C41A' : '#FA8C16')
                .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                .backgroundColor(this.selectedDoc.sourceType === 'ai' ?
                  (this.themeMode === 'dark' ? '#1A2A1A' : '#F6FFED') :
                  (this.themeMode === 'dark' ? '#2A1A0A' : '#FFF7E6'))
                .borderRadius(4)
                .margin({ left: 8 });
            }
            .width('100%')
            .margin({ top: 12 });

            Row() {
              Text('\u8BFE\u7A0B\uFF1A' + this.selectedDoc.courseTitle)
                .fontSize(13)
                .fontColor(this.themeMode === 'dark' ? '#AAAAAA' : '#888888');
              Blank();
              Text(getTimeAgo(this.selectedDoc.uploadedAt))
                .fontSize(12)
                .fontColor(this.themeMode === 'dark' ? '#888888' : '#AAAAAA');
            }
            .width('100%')
            .margin({ top: 6 });

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

            ForEach(this.contentParagraphs, (para: string) => {
              Text(para)
                .fontSize(15)
                .fontColor(this.themeMode === 'dark' ? '#CCCCCC' : '#444444')
                .lineHeight(26)
                .width('100%')
                .textIndent(32)
                .margin({ bottom: 12 });
            });
          }
          .width('100%')
          .padding(20);
        }
        .layoutWeight(1)
        .scrollBar(BarState.Auto);

        Button('\u53BB\u8BFE\u7A0B\u8BE6\u60C5')
          .width('90%')
          .height(44)
          .fontSize(16)
          .fontColor(Color.White)
          .backgroundColor('#007DFF')
          .borderRadius(22)
          .margin({ bottom: 20 })
          .onClick(() => this.goToCourse(this.selectedDoc!.courseId));
      }
    }
    .width('100%')
    .height('85%');
  }
}
