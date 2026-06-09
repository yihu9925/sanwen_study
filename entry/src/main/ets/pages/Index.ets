// 应用主入口 - 底部Tab导航（2个Tab：首页 / 个人中心）
import { HomePage } from './HomePage';
import { PersonalCenter } from './PersonalCenter';

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
