import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { RelationalStoreManager } from '../services/RelationalStoreManager';
import { ConfigService } from '../services/ConfigService';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  async onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): Promise<void> {
    // 初始化全局状态
    if (!AppStorage.has('themeMode')) {
      AppStorage.set('themeMode', 'auto');
    }
    const savedTheme: string = AppStorage.get('themeMode') || 'auto';
    try {
      if (savedTheme === 'dark') {
        this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
      } else if (savedTheme === 'light') {
        this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
      } else {
        this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
      }
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    
    // 初始化数据库
    try {
      await RelationalStoreManager.init(this.context);
      hilog.info(DOMAIN, 'testTag', 'Database initialized successfully');
      await ConfigService.init(this.context);
      hilog.info(DOMAIN, 'testTag', 'Config initialized successfully');
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to initialize database. Cause: %{public}s', JSON.stringify(err));
    }
    
    // 数据库就绪后加载主页面
    this.loadMainPage();
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  private appWindowStage: window.WindowStage | null = null;

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');
    this.appWindowStage = windowStage;
    // loadContent is now triggered from onCreate after DB init completes
  }

  private loadMainPage(): void {
    if (!this.appWindowStage) {
      return;
    }
    this.appWindowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load content. Cause: %{public}s', JSON.stringify(err));
        // 重试一次
        setTimeout(() => {
          this.loadMainPage();
        }, 500);
        return;
      }
      // 设置系统导航栏颜色跟随主题
      this.setSystemBarTheme(AppStorage.get('themeMode') as string || 'auto');
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });
  }

  private async setSystemBarTheme(themeMode: string): Promise<void> {
    if (!this.appWindowStage) {
      return;
    }
    try {
      const mainWindow = await this.appWindowStage.getMainWindow();
      const isDark: boolean = themeMode === 'dark';
      mainWindow.setWindowSystemBarProperties({
        navigationBarColor: isDark ? '#222222' : '#FFFFFF',
        navigationBarContentColor: isDark ? '#FFFFFF' : '#000000',
        statusBarColor: isDark ? '#222222' : '#FFFFFF',
        statusBarContentColor: isDark ? '#FFFFFF' : '#000000'
      });
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set system bar theme. Cause: %{public}s', JSON.stringify(err));
    }
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}