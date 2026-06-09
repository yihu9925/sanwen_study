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

  // 构建测试JSON体
  getTestMessages(): string {
    return '[{"role":"user","content":"Hi"}]';
  }

  async testAIConnection(): Promise<void> {
    this.testStatus = '\u6b63\u5728\u68c0\u6d4b...';
    this.testResult = -1;
    try {
      const config = await ConfigService.getLLMConfig();
      if (!config.apiKey) {
        promptAction.showToast({ message: '\u8bf7\u5148\u914d\u7f6e API Key' });
        this.testStatus = '\u68c0\u6d4bAI\u8fde\u901a\u6027';
        return;
      }
      const httpRequest = http.createHttp();
      const bodyStr: string = '{"model":"' + config.model + '","messages":[{"role":"user","content":"Hi"}],"max_tokens":5}';
      const response = await httpRequest.request(
        config.apiBase + '/chat/completions',
        {
          method: http.RequestMethod.POST,
          header: {
            'Content-Type': 'application/json' as string,
            'Authorization': ('Bearer ' + config.apiKey) as string
          },
          extraData: bodyStr as string,
          expectDataType: http.HttpDataType.OBJECT
        }
      );
      httpRequest.destroy();
      if (response.responseCode === 200) {
        this.testResult = 1;
        this.testStatus = '\u8fde\u901a\u6210\u529f';
        promptAction.showToast({ message: 'AI \u670d\u52a1\u6b63\u5e38\u8fde\u63a5' });
      } else {
        this.testResult = 0;
        this.testStatus = '\u8fde\u901a\u5931\u8d25';
        promptAction.showToast({ message: '\u54cd\u5e94\u7801: ' + response.responseCode });
      }
    } catch (e) {
      this.testResult = 0;
      this.testStatus = '\u8fde\u901a\u5931\u8d25';
      promptAction.showToast({ message: '\u8fde\u63a5\u5f02\u5e38\uff0c\u8bf7\u68c0\u67e5\u7f51\u7edc\u6216API\u5730\u5740' });
    }
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

          // AI连通性检测
          Row() {
            Button(this.testStatus)
              .fontSize(14)
              .height(36)
              .layoutWeight(1)
              .backgroundColor(this.testResult === -1 ? '#007DFF' : (this.testResult === 1 ? '#4CAF50' : '#F44336'))
              .fontColor(Color.White)
              .borderRadius(18)
              .margin({ right: 8 })
              .onClick(async () => {
                await this.testAIConnection();
              });

            if (this.testResult !== -1) {
              Text(this.testResult === 1 ? '\u2713' : '\u2717')
                .fontSize(18)
                .fontColor(this.testResult === 1 ? '#4CAF50' : '#F44336');
            }
          }
          .width('100%')
          .padding(16)
          .backgroundColor(this.isDarkMode ? '#444444' : Color.White)
          .borderRadius(12);

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
