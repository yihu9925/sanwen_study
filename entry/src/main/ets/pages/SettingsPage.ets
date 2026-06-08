// 设置页
import { AppRouter } from '../AppRouter';
import { promptAction } from '@kit.ArkUI';

@Entry
@Component
struct SettingsPage {
  @State isDarkMode: boolean = false;
  @State enableNotification: boolean = true;

  build() {
    Column() {
      // 标题栏
      Row() {
        Button('返回')
          .onClick(() => {
            AppRouter.back();
          });

        Text('设置')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .textAlign(TextAlign.Center);

        Row().width(60);
      }
      .width('100%')
      .padding(16)
      .backgroundColor(Color.White);

      // 设置项
      Column() {
        this.SettingItem('深色模式', this.isDarkMode, (value: boolean) => {
          this.isDarkMode = value;
          promptAction.showToast({ message: '深色模式已' + (value ? '开启' : '关闭') });
        });

        Divider();

        this.SettingItem('消息通知', this.enableNotification, (value: boolean) => {
          this.enableNotification = value;
          promptAction.showToast({ message: '消息通知已' + (value ? '开启' : '关闭') });
        });

        Divider();

        this.SettingAction('清除缓存', () => {
          promptAction.showToast({ message: '缓存已清除' });
        });

        Divider();

        this.SettingAction('关于', () => {
          promptAction.showToast({ message: '三问高效学习机 v1.0' });
        });
      }
      .width('100%')
      .backgroundColor(Color.White)
      .margin({ top: 12 });
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5');
  }

  @Builder
  SettingItem(title: string, value: boolean, onChange: (value: boolean) => void): void {
    Row() {
      Text(title)
        .fontSize(16);

      Toggle({ type: ToggleType.Switch, isOn: value })
        .onChange(onChange);
    }
    .width('100%')
    .padding(16)
    .justifyContent(FlexAlign.SpaceBetween);
  }

  @Builder
  SettingAction(title: string, onClick: () => void): void {
    Row() {
      Text(title)
        .fontSize(16);

      Text('>')
        .fontSize(20)
        .fontColor('#CCCCCC');
    }
    .width('100%')
    .padding(16)
    .justifyContent(FlexAlign.SpaceBetween)
    .onClick(onClick);
  }
}
