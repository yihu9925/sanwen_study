// 第二问：争议点分析（独立页面）
import { router } from '@kit.ArkUI';
import { Controversy } from '../models/Controversy';
import { KnowledgeBaseService } from '../services/KnowledgeBaseService';
import { ControversyView } from '../components/ControversyView';
import { UiStyle, StyleColors } from '../utils/UiStyle';

@Entry
@Component
struct Q2_ControversyPage {
  @State courseId: string = '';
  @State controversies: Controversy[] = [];
  @State isLoading: boolean = false;
  @StorageLink('themeMode') themeMode: string = 'auto';
  @StorageLink('uiStyle') uiStyle: string = 'default';

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string>;
    this.courseId = params?.['courseId'] || '';
    if (this.courseId) {
      this.loadControversies();
    }
  }

  async loadControversies(): Promise<void> {
    try {
      this.isLoading = true;
      this.controversies = await KnowledgeBaseService.getControversies(this.courseId);
    } catch (e) {
      console.error('Load controversies failed');
    } finally {
      this.isLoading = false;
    }
  }

  colors(): StyleColors { return UiStyle.getColors(this.uiStyle || 'default', this.themeMode === 'dark'); }

  build() {
    Column() {
      Row() {
        Button('\u8fd4\u56de').onClick(() => { router.back(); });
        Text('\u7b2c\u4e8c\u95ee\uff1a\u5b66\u672f\u5206\u6b67\u70b9')
          .fontSize(18).fontWeight(FontWeight.Bold).layoutWeight(1).textAlign(TextAlign.Center);
        Button('\u5237\u65b0').onClick(() => { this.loadControversies(); });
      }
      .width('100%').padding(16).backgroundColor(this.colors().cardBg);

      if (this.isLoading) {
        Column() {
          LoadingProgress().width(48).height(48);
          Text('\u52a0\u8f7d\u4e2d...').fontSize(14).fontColor(this.colors().textTertiary).margin({ top: 12 });
        }
        .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center);
      } else {
        ControversyView({ controversies: this.controversies })
          .width('100%').layoutWeight(1);
      }
    }
    .width('100%').height('100%').backgroundColor(this.colors().pageBg);
  }
}
