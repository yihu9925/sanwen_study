// 应用主入口 - 底部Tab导航
import { HomePage } from './HomePage';
import { PersonalCenter } from './PersonalCenter';

@Entry
@Component
struct Index {
  @State currentTabIndex: number = 0;

  build() {
    Tabs({ barPosition: BarPosition.End }) {
      TabContent() {
        HomePage();
      }
      .tabBar('\u9996\u9875');

      TabContent() {
        PersonalCenter();
      }
      .tabBar('\u4E2A\u4EBA');
    }
    .width('100%')
    .height('100%')
    .barBackgroundColor(Color.White)
    .onChange((index: number) => {
      this.currentTabIndex = index;
    });
  }
}
