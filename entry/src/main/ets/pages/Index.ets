// 应用主入口 - 底部Tab导航
import { HomePage } from './HomePage';
import { DiscussionHub } from './DiscussionHub';
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
      .tabBar('首页');

      TabContent() {
        DiscussionHub();
      }
      .tabBar('讨论');

      TabContent() {
        PersonalCenter();
      }
      .tabBar('个人');
    }
    .width('100%')
    .height('100%')
    .barBackgroundColor(Color.White)
    .onChange((index: number) => {
      this.currentTabIndex = index;
    });
  }
}
