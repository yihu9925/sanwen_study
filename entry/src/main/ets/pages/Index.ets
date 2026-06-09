// 应用主入口 - 底部Tab导航（3个Tab：首页 / 知识库 / 个人中心）
import { HomePage } from './HomePage';
import { PersonalCenter } from './PersonalCenter';
import { KnowledgeHub } from './KnowledgeHub';

@Entry
@Component
struct Index {
  @State currentTabIndex: number = 0;
  @StorageLink('themeMode') themeMode: string = 'auto';

  build() {
    Tabs({ barPosition: BarPosition.End }) {
      TabContent() {
        HomePage();
      }
      .tabBar('\u9996\u9875');

      TabContent() {
        KnowledgeHub();
      }
      .tabBar('\u77E5\u8BC6\u5E93');

      TabContent() {
        PersonalCenter();
      }
      .tabBar('\u4e2a\u4eba');
    }
    .width('100%')
    .height('100%')
    .barBackgroundColor(this.themeMode === 'dark' ? '#333333' : Color.White)
    .onChange((index: number) => {
      this.currentTabIndex = index;
    });
  }
}
