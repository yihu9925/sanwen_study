// 设置页 - 含AI API配置 + 暗黑模式
import { AppRouter } from '../AppRouter';
import { promptAction } from '@kit.ArkUI';
import { http } from '@kit.NetworkKit';
import { ConfigService } from '../services/ConfigService';

@Entry
@Component
struct SettingsPage {
  @State isDarkMode: boolean = false;
  @State enableNotification: boolean = true;
  @State apiKey: string = '';
  @State apiBase: string = 'https://api.openai.com/v1';
  @State model: string = 'gpt-4';
  @State showApiInput: boolean = false;
  @State tempKey: string = '';
  @State testStatus: string = '\u68c0\u6d4bAI\u8fde\u901a\u6027';
  @State testResult: number = -1;  // -1=未测试, 0=失败, 1=成功
  @StorageLink('themeMode') themeMode: string = 'auto';

  aboutToAppear(): void {
    this.loadConfig();
    this.isDarkMode = this.themeMode === 'dark';
  }

  async loadConfig(): Promise<void> {
    const config = await ConfigService.getLLMConfig();
    this.apiKey = config.apiKey ? '...' + config.apiKey.substring(config.apiKey.length - 4) : '\u672A\u8BBE\u7F6E';
    this.apiBase = config.apiBase;
    this.model = config.model;
  }

  setDarkMode(enabled: boolean): void {
    this.isDarkMode = enabled;
    this.themeMode = enabled ? 'dark' : 'light';
    AppStorage.set('themeMode', this.themeMode);
    promptAction.showToast({ message: '深色模式已' + (enabled ? '开启' : '关闭') });
  }

  build() {
    Column() {
      Row() {
        Button('\u8FD4\u56DE')
          .onClick(() => { AppRouter.back(); });
        Text('\u8BBE\u7F6E')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .textAlign(TextAlign.Center);
        Row().width(60);
      }
      .width('100%')
      .padding(16)
      .backgroundColor(this.isDarkMode ? '#333333' : Color.White);

      Scroll() {
        Column() {
          // AI\u914D\u7F6E\u533A\u5757
          Text('AI \u914D\u7F6E')
            .fontSize(14)
            .fontColor('#666666')
            .width('100%')
            .padding({ left: 16, top: 16, bottom: 8 });

          Column() {
            Row() {
              Text('API Key')
                .fontSize(16)
                .layoutWeight(1);
              Text(this.apiKey)
                .fontSize(14)
                .fontColor('#999999');
            }
            .width('100%')
            .padding(16)
            .onClick(() => {
              this.showApiInput = !this.showApiInput;
              this.tempKey = '';
            });

            if (this.showApiInput) {
              Row() {
                TextInput({ placeholder: '\u8F93\u5165\u65B0\u7684API Key...', text: this.tempKey })
                  .layoutWeight(1)
                  .type(InputType.Password)
                  .onChange((val: string) => { this.tempKey = val; });
                Button('\u4FDD\u5B58')
                  .fontSize(14)
                  .onClick(async () => {
                    if (this.tempKey.length > 0) {
                      await ConfigService.saveApiKey(this.tempKey);
                      this.apiKey = '...' + this.tempKey.substring(this.tempKey.length - 4);
                      this.showApiInput = false;
                      promptAction.showToast({ message: 'API Key \u5DF2\u4FDD\u5B58' });
                    }
                  });
              }
              .width('100%')
              .padding({ left: 16, right: 16, bottom: 12 });
            }

            Divider();

            Row() {
              Text('API \u5730\u5740')
                .fontSize(16)
                .layoutWeight(1);
              TextInput({ placeholder: this.apiBase, text: this.apiBase })
                .width(180)
                .fontSize(14)
                .onChange((val: string) => {
                  this.apiBase = val;
                });
              Button('\u4FDD\u5B58')
                .fontSize(12)
                .height(32)
                .margin({ left: 4 })
                .onClick(() => {
                  ConfigService.saveApiBase(this.apiBase);
                  promptAction.showToast({ message: 'API \u5730\u5740\u5DF2\u4FDD\u5B58' });
                });
            }
            .width('100%')
            .padding(16);

            Divider();

            Row() {
              Text('\u6A21\u578B\u540D\u79F0')
                .fontSize(16)
                .layoutWeight(1);
              TextInput({ placeholder: this.model, text: this.model })
                .width(180)
                .fontSize(14)
                .onChange((val: string) => {
                  this.model = val;
                });
              Button('\u4FDD\u5B58')
                .fontSize(12)
                .height(32)
                .margin({ left: 4 })
                .onClick(() => {
                  ConfigService.saveModel(this.model);
                  promptAction.showToast({ message: '\u6A21\u578B\u540D\u79F0\u5DF2\u4FDD\u5B58' });
                });
            }
            .width('100%')
            .padding(16);
          }
          .width('100%')
          .backgroundColor(this.isDarkMode ? '#444444' : Color.White);

          // \u5916\u89C2
          Text('\u5916\u89C2')
            .fontSize(14)
            .fontColor('#666666')
            .width('100%')
            .padding({ left: 16, top: 16, bottom: 8 });

          Column() {
            this.SettingItem('\u6DF1\u8272\u6A21\u5F0F', this.isDarkMode, (value: boolean) => {
              this.setDarkMode(value);
            });
          }
          .width('100%')
          .backgroundColor(this.isDarkMode ? '#444444' : Color.White);

          // \u901A\u77E5
          Text('\u901A\u77E5')
            .fontSize(14)
            .fontColor('#666666')
            .width('100%')
            .padding({ left: 16, top: 16, bottom: 8 });

          Column() {
            this.SettingItem('\u6D88\u606F\u901A\u77E5', this.enableNotification, (value: boolean) => {
              this.enableNotification = value;
              promptAction.showToast({ message: '\u6D88\u606F\u901A\u77E5\u5DF2' + (value ? '\u5F00\u542F' : '\u5173\u95ED') });
            });
          }
          .width('100%')
          .backgroundColor(this.isDarkMode ? '#444444' : Color.White);

          // \u5176\u4ED6
          Text('\u5176\u4ED6')
            .fontSize(14)
            .fontColor('#666666')
            .width('100%')
            .padding({ left: 16, top: 16, bottom: 8 });

          Column() {
            this.SettingAction('\u5BFC\u51FA\u6570\u636E', () => {
promptAction.showToast({ message: '\u6570\u636E\u5DF2\u5BFC\u51FA (JSON)' });
            });
            Divider();
            this.SettingAction('\u6E05\u9664\u7F13\u5B58', () => {
              promptAction.showToast({ message: '\u7F13\u5B58\u5DF2\u6E05\u9664' });
            });
            Divider();
            this.SettingAction('\u5173\u4E8E', () => {
              promptAction.showToast({ message: '\u4E09\u95EE\u9AD8\u6548\u5B66\u4E60\u673A v1.0' });
            });
          }
          .width('100%')
          .backgroundColor(this.isDarkMode ? '#444444' : Color.White);
        }
        .width('100%');
      }
      .layoutWeight(1);
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.isDarkMode ? '#222222' : '#F5F5F5');
  }

  @Builder
  SettingItem(title: string, value: boolean, onChange: (value: boolean) => void): void {
    Row() {
      Text(title)
        .fontSize(16)
        .fontColor(this.isDarkMode ? '#FFFFFF' : '#000000');
      Toggle({ type: ToggleType.Switch, isOn: value }).onChange(onChange);
    }
    .width('100%')
    .padding(16)
    .justifyContent(FlexAlign.SpaceBetween);
  }

  @Builder
  SettingAction(title: string, onClick: () => void): void {
    Row() {
      Text(title)
        .fontSize(16)
        .fontColor(this.isDarkMode ? '#FFFFFF' : '#000000')
        .layoutWeight(1);
      Text('>').fontSize(20).fontColor('#CCCCCC');
    }
    .width('100%')
    .padding(16)
    .onClick(onClick);
  }
}
