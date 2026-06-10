// 应用主入口 - 底部Tab导航（3个Tab：首页 / 知识库 / 个人中心）
import { PersonalCenterHost } from './PersonalCenterHost';
import { KnowledgeHubHost } from './KnowledgeHubHost';
import { HomePage } from './HomePage';
import { CourseService } from '../services/CourseService';
import { UiStyle, StyleColors } from '../utils/UiStyle';

@Entry
@Component
struct Index {
  @StorageLink('activeTabIndex') activeTabIndex: number = 0;
  @StorageLink('themeMode') themeMode: string = 'auto';
  @StorageLink('uiStyle') uiStyle: string = 'default';
  @State homePageKey: number = 0;
  @State personalCenterKey: number = 0;
  @State knowledgeHubKey: number = 0;

  aboutToAppear(): void {
    AppStorage.setOrCreate('uiStyle', 'default');
  }

  onPageShow(): void {
    // 从推送页面返回时，强制所有 tab 重建
    CourseService.refreshStatsInStorage('default_user').then(() => {
      this.homePageKey++;
      this.personalCenterKey++;
      this.knowledgeHubKey++;
    });
  }

  colors(): StyleColors {
    return UiStyle.getColors(this.uiStyle || 'default', this.themeMode === 'dark');
  }

  build() {
    Tabs({ barPosition: BarPosition.End, index: this.activeTabIndex }) {
      TabContent() {
        HomePage().key('hp_' + this.homePageKey);
      }
      .tabBar('\u9996\u9875');

      TabContent() {
        KnowledgeHubHost().key('kh_' + this.knowledgeHubKey);
      }
      .tabBar('\u77E5\u8BC6\u5E93');

      TabContent() {
        PersonalCenterHost().key('pc_' + this.personalCenterKey);
      }
      .tabBar('\u4e2a\u4eba');
    }
    .width('100%')
    .height('100%')
    .barBackgroundColor(this.colors().cardBg)
    .onChange((index: number) => {
      this.activeTabIndex = index;
      if (index === 0) {
        this.homePageKey++;
      }
      if (index === 2) {
        CourseService.refreshStatsInStorage('default_user').then(() => {
          this.personalCenterKey++;
        });
      }
      if (index === 1) {
        this.knowledgeHubKey++;
      }
    });
  }
}
