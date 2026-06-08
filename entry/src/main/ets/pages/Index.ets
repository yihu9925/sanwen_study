// 应用主入口 - 底部Tab导航
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
      .tabBar('首页');

      TabContent() {
        PersonalCenter();
      }
      .tabBar('个人');

      TabContent() {
        DiscussionHub();
      }
      .tabBar('讨论');
    }
    .width('100%')
    .height('100%')
    .barBackgroundColor(Color.White)
    .onChange((index: number) => {
      this.currentTabIndex = index;
    });
  }
}
