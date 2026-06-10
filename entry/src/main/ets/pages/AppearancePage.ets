import { AppRouter } from '../AppRouter';
import { promptAction, window } from '@kit.ArkUI';
import { UiStyle, StyleColors } from '../utils/UiStyle';

@Entry
@Component
struct AppearancePage {
  @StorageLink('themeMode') themeMode: string = 'auto';
  @StorageLink('uiStyle') uiStyle: string = 'default';

  aboutToAppear(): void {
    AppStorage.setOrCreate('uiStyle', this.uiStyle);
  }

  setDarkMode(enabled: boolean): void {
    this.themeMode = enabled ? 'dark' : 'light';
    AppStorage.set('themeMode', this.themeMode);
    this.setSystemBarTheme(this.themeMode);
    promptAction.showToast({ message: '深色模式已' + (enabled ? '开启' : '关闭') });
  }

  setStyle(style: string): void {
    this.uiStyle = style;
    AppStorage.set('uiStyle', style);
    promptAction.showToast({ message: 'UI主题已切换为「' + UiStyle.getStyleLabel(style) + '」' });
  }

  private async setSystemBarTheme(theme: string): Promise<void> {
    try {
      window.getLastWindow(getContext(this)).then((win: window.Window) => {
        const isDark: boolean = theme === 'dark';
        win.setWindowSystemBarProperties({
          navigationBarColor: isDark ? '#222222' : '#FFFFFF',
          navigationBarContentColor: isDark ? '#FFFFFF' : '#000000',
          statusBarColor: isDark ? '#222222' : '#FFFFFF',
          statusBarContentColor: isDark ? '#FFFFFF' : '#000000'
        });
      });
    } catch (err) {
      console.error('Failed to set system bar theme: ' + JSON.stringify(err));
    }
  }

  colors(): StyleColors {
    return UiStyle.getColors(this.uiStyle || 'default', this.themeMode === 'dark');
  }

  build() {
    Column() {
      Row() {
        Button('返回')
          .onClick(() => { AppRouter.back(); });
        Text('外观')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .textAlign(TextAlign.Center);
        Row().width(60);
      }
      .width('100%')
      .padding(16)
      .backgroundColor(this.colors().cardBg);

      Scroll() {
        Column() {
          Text('深色模式')
            .fontSize(14)
            .fontColor(this.colors().textSecondary)
            .width('100%')
            .padding({ left: 16, top: 16, bottom: 8 });

          Column() {
            Row() {
              Text('深色模式')
                .fontSize(16)
                .fontColor(this.colors().textPrimary)
                .layoutWeight(1);
              Toggle({ type: ToggleType.Switch, isOn: this.themeMode === 'dark' })
                .onChange((val: boolean) => { this.setDarkMode(val); });
            }
            .width('100%')
            .padding(16)
            .justifyContent(FlexAlign.SpaceBetween);
          }
          .width('100%')
          .backgroundColor(this.colors().cardBg)
          .borderRadius(this.colors().cardRadius);

          Text('UI主题')
            .fontSize(14)
            .fontColor(this.colors().textSecondary)
            .width('100%')
            .padding({ left: 16, top: 20, bottom: 8 });

          Column() {
            this.StyleOption('默认', 'default',
              '#F5F5F5', '#FFFFFF', '#007DFF');
            Divider().height(1).color(this.colors().divider);
            this.StyleOption('暖阳', 'warm',
              '#F5F0EB', '#FFFDF5', '#D4894A');
            Divider().height(1).color(this.colors().divider);
            this.StyleOption('极夜', 'midnight',
              '#F0F2F5', '#FFFFFF', '#D4A843');
            Divider().height(1).color(this.colors().divider);
            this.StyleOption('森林', 'forest',
              '#F0F7F0', '#FFFFFF', '#2E7D4E');
            Divider().height(1).color(this.colors().divider);
            this.StyleOption('樱花', 'sakura',
              '#FFF5F7', '#FFFFFF', '#D4617A');
            Divider().height(1).color(this.colors().divider);
            this.StyleOption('墨水', 'ink',
              '#F5F0E8', '#FCF8F0', '#C43838');
          }
          .width('100%')
          .backgroundColor(this.colors().cardBg)
          .borderRadius(this.colors().cardRadius);
        }
        .width('100%');
      }
      .layoutWeight(1);
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.colors().pageBg);
  }

  @Builder
  StyleOption(label: string, styleKey: string,
    previewBg: string, previewCard: string, previewAccent: string): void {
    Row() {
      Column() {
        Row() {
          Column() {
            Text('A').fontSize(16).fontWeight(FontWeight.Bold).fontColor(previewAccent);
            Text('a').fontSize(10).fontColor(this.colors().textSecondary).margin({ top: 2 });
          }
          .padding(8)
          .backgroundColor(previewCard)
          .borderRadius(8);
        }
        .width(60).height(44)
        .backgroundColor(previewBg)
        .borderRadius(10)
        .justifyContent(FlexAlign.Center);
      }
      .width(72).height(56)
      .backgroundColor(previewBg)
      .borderRadius(12)
      .justifyContent(FlexAlign.Center);

      Text(label)
        .fontSize(16)
        .fontColor(this.colors().textPrimary)
        .layoutWeight(1)
        .margin({ left: 16 });

      if (this.uiStyle === styleKey) {
        Circle()
          .width(22).height(22)
          .fill(this.colors().accent);
        Circle()
          .width(8).height(8)
          .fill(Color.White);
      } else {
        Circle()
          .width(22).height(22)
          .fill(Color.Transparent)
          .stroke(this.colors().textTertiary)
          .strokeWidth(2);
      }
    }
    .width('100%')
    .padding(16)
    .onClick(() => { this.setStyle(styleKey); });
  }
}
