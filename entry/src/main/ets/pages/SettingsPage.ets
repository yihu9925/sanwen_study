// 设置页 - 含AI API配置
import { AppRouter } from '../AppRouter';
import { promptAction } from '@kit.ArkUI';
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

  aboutToAppear(): void {
    this.loadConfig();
  }

  async loadConfig(): Promise<void> {
    const config = await ConfigService.getLLMConfig();
    this.apiKey = config.apiKey ? '...' + config.apiKey.substring(config.apiKey.length - 4) : 'unset';
    this.apiBase = config.apiBase;
    this.model = config.model;
  }

  build() {
    Column() {
      Row() {
        Button('Back')
          .onClick(() => { AppRouter.back(); });
        Text('Settings')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .textAlign(TextAlign.Center);
        Row().width(60);
      }
      .width('100%')
      .padding(16)
      .backgroundColor(Color.White);

      Scroll() {
        Column() {
          // AI API Config
          Text('AI Configuration')
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
                TextInput({ placeholder: 'Enter new API Key...', text: this.tempKey })
                  .layoutWeight(1)
                  .type(InputType.Password)
                  .onChange((val: string) => { this.tempKey = val; });
                Button('Save')
                  .fontSize(14)
                  .onClick(async () => {
                    if (this.tempKey.length > 0) {
                      await ConfigService.saveApiKey(this.tempKey);
                      this.apiKey = '...' + this.tempKey.substring(this.tempKey.length - 4);
                      this.showApiInput = false;
                      promptAction.showToast({ message: 'API Key saved' });
                    }
                  });
              }
              .width('100%')
              .padding({ left: 16, right: 16, bottom: 12 });
            }

            Divider();

            Row() {
              Text('API Base URL')
                .fontSize(16)
                .layoutWeight(1);
              TextInput({ placeholder: this.apiBase, text: this.apiBase })
                .width(200)
                .fontSize(14)
                .onChange(async (val: string) => {
                  if (val.length > 0) {
                    await ConfigService.saveApiBase(val);
                    this.apiBase = val;
                  }
                });
            }
            .width('100%')
            .padding(16);

            Divider();

            Row() {
              Text('Model')
                .fontSize(16)
                .layoutWeight(1);
              TextInput({ placeholder: this.model, text: this.model })
                .width(200)
                .fontSize(14)
                .onChange(async (val: string) => {
                  if (val.length > 0) {
                    await ConfigService.saveModel(val);
                    this.model = val;
                  }
                });
            }
            .width('100%')
            .padding(16);
          }
          .width('100%')
          .backgroundColor(Color.White);

          // Appearance
          Text('Appearance')
            .fontSize(14)
            .fontColor('#666666')
            .width('100%')
            .padding({ left: 16, top: 16, bottom: 8 });

          Column() {
            this.SettingItem('Dark Mode', this.isDarkMode, (value: boolean) => {
              this.isDarkMode = value;
              promptAction.showToast({ message: 'Dark mode ' + (value ? 'on' : 'off') });
            });
          }
          .width('100%')
          .backgroundColor(Color.White);

          // Notifications
          Text('Notifications')
            .fontSize(14)
            .fontColor('#666666')
            .width('100%')
            .padding({ left: 16, top: 16, bottom: 8 });

          Column() {
            this.SettingItem('Notifications', this.enableNotification, (value: boolean) => {
              this.enableNotification = value;
              promptAction.showToast({ message: 'Notifications ' + (value ? 'on' : 'off') });
            });
          }
          .width('100%')
          .backgroundColor(Color.White);

          // Other
          Text('Other')
            .fontSize(14)
            .fontColor('#666666')
            .width('100%')
            .padding({ left: 16, top: 16, bottom: 8 });

          Column() {
            this.SettingAction('Clear Cache', () => {
              promptAction.showToast({ message: 'Cache cleared' });
            });
            Divider();
            this.SettingAction('About', () => {
              promptAction.showToast({ message: 'Three-Question Learning Machine v1.0' });
            });
          }
          .width('100%')
          .backgroundColor(Color.White);
        }
        .width('100%');
      }
      .layoutWeight(1);
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5');
  }

  @Builder
  SettingItem(title: string, value: boolean, onChange: (value: boolean) => void): void {
    Row() {
      Text(title).fontSize(16);
      Toggle({ type: ToggleType.Switch, isOn: value }).onChange(onChange);
    }
    .width('100%')
    .padding(16)
    .justifyContent(FlexAlign.SpaceBetween);
  }

  @Builder
  SettingAction(title: string, onClick: () => void): void {
    Row() {
      Text(title).fontSize(16).layoutWeight(1);
      Text('>').fontSize(20).fontColor('#CCCCCC');
    }
    .width('100%')
    .padding(16)
    .onClick(onClick);
  }
}
