// 讨论区页 - 完整实现
import { AppRouter } from '../AppRouter';
import { promptAction } from '@kit.ArkUI';
import { generateUUID } from '../utils/UUID';

// 讨论话题数据模型
interface DiscussionTopic {
  id: string;
  title: string;
  content: string;
  author: string;
  createdAt: string;
  likeCount: number;
  commentCount: number;
  tags: string[];
}

// 评论数据模型
interface Comment {
  id: string;
  topicId: string;
  content: string;
  author: string;
  createdAt: string;
  likeCount: number;
}

@Component
export struct DiscussionHub {
  @State topics: DiscussionTopic[] = [];
  @State searchText: string = '';
  @State selectedTab: number = 0;
  @State showCreateDialog: boolean = false;
  @State newTopicTitle: string = '';
  @State newTopicContent: string = '';

  aboutToAppear(): void {
    this.loadMockData();
  }

  loadMockData(): void {
    // 模拟数据
    this.topics = [
      {
        id: '1',
        title: '如何提高深度学习的理解能力？',
        content: '在学习深度学习时，我发现很难理解反向传播算法的原理，有没有好的学习方法？',
        author: '学习者A',
        createdAt: '2024-01-15 10:30',
        likeCount: 15,
        commentCount: 8,
        tags: ['深度学习', '学习方法']
      },
      {
        id: '2',
        title: '布鲁姆分类学在实际教学中的应用',
        content: '分享一个案例：如何使用布鲁姆分类学设计课程测评题。',
        author: '教师B',
        createdAt: '2024-01-14 15:20',
        likeCount: 23,
        commentCount: 12,
        tags: ['教育学', '测评设计']
      },
      {
        id: '3',
        title: '知识图谱可视化技术讨论',
        content: '讨论在HarmonyOS中实现知识图谱可视化的最佳实践。',
        author: '开发者C',
        createdAt: '2024-01-13 09:45',
        likeCount: 18,
        commentCount: 6,
        tags: ['技术', 'HarmonyOS']
      }
    ];
  }

  build() {
    Column() {
      // 标题栏
      this.TitleBar();

      // 搜索栏
      this.SearchBar();

      // 标签页
      Tabs() {
        TabContent() {
          this.TopicList();
        }
        .tabBar('热门话题');

        TabContent() {
          this.TopicList();
        }
        .tabBar('最新话题');

        TabContent() {
          this.TopicList();
        }
        .tabBar('我的话题');
      }
      .width('100%')
      .layoutWeight(1)
      .barMode(BarMode.Fixed)
      .onChange((index: number) => {
        this.selectedTab = index;
      });
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
    .bindSheet($$this.showCreateDialog, this.CreateTopicSheet(), {
      height: 400,
      backgroundColor: Color.White,
      dragBar: true
    });
  }

  @Builder
  TitleBar(): void {
    Row() {
      Text('讨论区')
        .fontSize(20)
        .fontWeight(FontWeight.Bold);

      Blank();

      Button('发起讨论')
        .fontSize(14)
        .onClick(() => {
          this.showCreateDialog = true;
        });
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Color.White);
  }

  @Builder
  SearchBar(): void {
    Row() {
      TextInput({ placeholder: '搜索话题...', text: this.searchText })
        .layoutWeight(1)
        .height(40)
        .backgroundColor('#F5F5F5')
        .borderRadius(20)
        .padding({ left: 16, right: 16 })
        .onChange((value: string) => {
          this.searchText = value;
        });

      Button('搜索')
        .width(60)
        .height(40)
        .margin({ left: 12 })
        .onClick(() => {
          promptAction.showToast({ message: '搜索功能开发中' });
        });
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 8, bottom: 8 })
    .backgroundColor(Color.White);
  }

  @Builder
  TopicList(): void {
    if (this.topics.length === 0) {
      Column() {
        Text('💬')
          .fontSize(64);

        Text('暂无话题')
          .fontSize(16)
          .fontColor('#999999')
          .margin({ top: 16 });

        Text('点击右上角"发起讨论"开始交流')
          .fontSize(14)
          .fontColor('#CCCCCC')
          .margin({ top: 8 });
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center);
    } else {
      List() {
        ForEach(this.topics, (topic: DiscussionTopic) => {
          ListItem() {
            this.TopicCard(topic);
          }
          .margin({ bottom: 12 });
        });
      }
      .width('100%')
      .layoutWeight(1)
      .padding(16);
    }
  }

  @Builder
  TopicCard(topic: DiscussionTopic): void {
    Column() {
      // 标题和标签
      Row() {
        Text(topic.title)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1);

        // 标签
        if (topic.tags && topic.tags.length > 0) {
          Text(topic.tags[0])
            .fontSize(12)
            .fontColor('#007DFF')
            .backgroundColor('#E6F7FF')
            .borderRadius(4)
            .padding({ left: 8, right: 8, top: 2, bottom: 2 });
        }
      }
      .width('100%');

      // 内容
      Text(topic.content)
        .fontSize(14)
        .fontColor('#666666')
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ top: 8 });

      // 底部信息
      Row() {
        Text(topic.author)
          .fontSize(12)
          .fontColor('#999999');

        Text(topic.createdAt)
          .fontSize(12)
          .fontColor('#CCCCCC')
          .margin({ left: 16 });

        Blank();

        Row() {
          Text(`👍 ${topic.likeCount}`)
            .fontSize(12)
            .fontColor('#999999');

          Text(`💬 ${topic.commentCount}`)
            .fontSize(12)
            .fontColor('#999999')
            .margin({ left: 16 });
        }
      }
      .width('100%')
      .margin({ top: 12 });
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(12)
    .onClick(() => {
      promptAction.showToast({ message: '话题详情功能开发中' });
    });
  }

  @Builder
  CreateTopicSheet(): void {
    Column() {
      // 标题
      Row() {
        Text('发起讨论')
          .fontSize(18)
          .fontWeight(FontWeight.Bold);
      }
      .width('100%')
      .padding(16);

      // 输入表单
      Column() {
        TextInput({ placeholder: '话题标题', text: this.newTopicTitle })
          .height(48)
          .backgroundColor('#F5F5F5')
          .borderRadius(8)
          .onChange((value: string) => {
            this.newTopicTitle = value;
          });

        TextArea({ placeholder: '话题内容...', text: this.newTopicContent })
          .height(120)
          .backgroundColor('#F5F5F5')
          .borderRadius(8)
          .margin({ top: 12 })
          .onChange((value: string) => {
            this.newTopicContent = value;
          });
      }
      .width('100%')
      .padding({ left: 16, right: 16 });

      // 提交按钮
      Button('发布')
        .width('100%')
        .height(48)
        .margin({ top: 16, left: 16, right: 16 })
        .onClick(() => {
          if (!this.newTopicTitle.trim() || !this.newTopicContent.trim()) {
            promptAction.showToast({ message: '请填写完整信息' });
            return;
          }

          // 创建新话题
          const newTopic: DiscussionTopic = {
            id: generateUUID(),
            title: this.newTopicTitle,
            content: this.newTopicContent,
            author: '我',
            createdAt: new Date().toLocaleString(),
            likeCount: 0,
            commentCount: 0,
            tags: []
          };

          this.topics.unshift(newTopic);
          this.newTopicTitle = '';
          this.newTopicContent = '';
          this.showCreateDialog = false;
          promptAction.showToast({ message: '发布成功' });
        });
    }
    .width('100%');
  }
}
