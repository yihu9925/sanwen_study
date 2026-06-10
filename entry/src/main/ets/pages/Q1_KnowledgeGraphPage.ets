// 第一问：知识图谱展示（独立页面）
import { router } from '@kit.ArkUI';
import { KnowledgeGraph } from '../models/KnowledgeGraph';
import { KnowledgeBaseService } from '../services/KnowledgeBaseService';
import { KnowledgeGraphView } from '../components/KnowledgeGraphView';
import { UiStyle, StyleColors } from '../utils/UiStyle';

@Entry
@Component
struct Q1_KnowledgeGraphPage {
  @State courseId: string = '';
  @State knowledgeGraph: KnowledgeGraph = { nodes: [], edges: [] };
  @State isLoading: boolean = false;
  @StorageLink('themeMode') themeMode: string = 'auto';
  @StorageLink('uiStyle') uiStyle: string = 'default';

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string>;
    this.courseId = params?.['courseId'] || '';
    if (this.courseId) {
      this.loadGraph();
    }
  }

  async loadGraph(): Promise<void> {
    try {
      this.isLoading = true;
      this.knowledgeGraph = await KnowledgeBaseService.getKnowledgeGraph(this.courseId);
    } catch (e) {
      console.error('Load graph failed');
    } finally {
      this.isLoading = false;
    }
  }

  colors(): StyleColors { return UiStyle.getColors(this.uiStyle || 'default', this.themeMode === 'dark'); }

  build() {
    Column() {
      Row() {
        Button('\u8fd4\u56de').onClick(() => { router.back(); });
        Text('\u7b2c\u4e00\u95ee\uff1a\u77e5\u8bc6\u56fe\u8c31')
          .fontSize(18).fontWeight(FontWeight.Bold).layoutWeight(1).textAlign(TextAlign.Center);
        Button('\u5237\u65b0').onClick(() => { this.loadGraph(); });
      }
      .width('100%').padding(16).backgroundColor(this.colors().cardBg);

      if (this.isLoading) {
        Column() {
          LoadingProgress().width(48).height(48);
          Text('\u52a0\u8f7d\u4e2d...').fontSize(14).fontColor(this.colors().textTertiary).margin({ top: 12 });
        }
        .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center);
      } else {
        KnowledgeGraphView({ graph: this.knowledgeGraph })
          .width('100%').layoutWeight(1);
      }
    }
    .width('100%').height('100%').backgroundColor(this.colors().pageBg);
  }
}
