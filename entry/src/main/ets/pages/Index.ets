// 应用主入口 - 底部Tab导航（3个Tab：首页 / 讨论区 / 个人中心）
import { HomePage } from './HomePage';
import { PersonalCenter } from './PersonalCenter';
import { DiscussionHub } from './DiscussionHub';

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
        DiscussionHub();
      }
      .tabBar('\u8ba8\u8bba');

      TabContent() {
        PersonalCenter();
      }
      .tabBar('\u4e2a\u4eba');
    }
    .width('100%')
    .height('100%')
    .barBackgroundColor(Color.White)
    .onChange((index: number) => {
      this.currentTabIndex = index;
    });
  }
}
