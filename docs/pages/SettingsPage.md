# SettingsPage - 设置

## 页面信息

| 项目 | 值 |
|-----|-----|
| 页面名称 | SettingsPage |
| 页面级次 | 二级（从个人中心跳转） |
| 导航方式 | router.pushUrl |

## 页面目的
提供应用偏好设置，包括主题、语言、通知、数据管理等。

## 布局结构

```
┌────────────────────────────────────┐
│  ← 设置                            │
├────────────────────────────────────┤
│  ┌─ 外观 ─────────────────────┐   │
│  │ 🌙 深色模式                │   │
│  │     [自动] [浅色] [深色]   │   │
│  └────────────────────────────┘   │
│                                    │
│  ┌─ 语言 ─────────────────────┐   │
│  │ 🌐 应用语言                │   │
│  │     中文 ▼                 │   │
│  └────────────────────────────┘   │
│                                    │
│  ┌─ 通知 ─────────────────────┐   │
│  │ 🔔 学习提醒                │   │
│  │     [开关] 开启            │   │
│  └────────────────────────────┘   │
│                                    │
│  ┌─ 数据管理 ────────────────┐   │
│  │ 💾 清除缓存  当前: 12MB  │   │
│  │ 📤 导出学习数据           │   │
│  │ 📥 导入学习数据           │   │
│  └────────────────────────────┘   │
│                                    │
│  ┌─ 关于 ─────────────────────┐   │
│  │ ℹ️ 版本: 1.0.0            │   │
│  │ 📄 开源许可                │   │
│  └────────────────────────────┘   │
└────────────────────────────────────┘
```

## 控件清单

| 控件名称 | 类型 | 位置 | 功能 | 事件 | 数据绑定 |
|---------|------|------|------|------|---------|
| BackButton | Button | 左上 | 返回个人中心 | onClick | router.back() |
| PageTitle | Text | 顶部 | "设置"标题 | — | — |
| ThemeSection | Column | 外观区 | 主题配置 | — | preferences |
| ThemeModeRow | Row | 深色模式 | 模式选择 | onChange | themeMode |
| ThemeAuto | Radio | 行内 | 自动模式 | onChange | 'auto' |
| ThemeLight | Radio | 行内 | 浅色模式 | onChange | 'light' |
| ThemeDark | Radio | 行内 | 深色模式 | onChange | 'dark' |
| LangSection | Column | 语言区 | 语言配置 | — | — |
| LangSelect | Select | 行内 | 下拉选择 | onSelect | lang |
| NotifySection | Column | 通知区 | 通知配置 | — | — |
| NotifyToggle | Toggle | 行内右 | 开关 | onChange | notifyEnabled |
| DataSection | Column | 数据区 | 管理选项 | — | — |
| ClearCacheBtn | Button | 清理项 | 清除缓存 | onClick | 弹窗确认 |
| CacheSize | Text | 清理项右 | 当前缓存大小 | — | cacheSize |
| ExportBtn | Button | 导出项 | 导出JSON | onClick | 分享弹窗 |
| ImportBtn | Button | 导入项 | 导入数据 | onClick | 文件选择器 |
| AboutSection | Column | 关于区 | 应用信息 | — | — |
| VersionText | Text | 版本行 | 版本号 | — | appVersion |
| LicenseBtn | Button | 许可行 | 开源许可 | onClick | 弹窗 |

## 页面状态

```typescript
@Entry
@Component
struct SettingsPage {
  // 从 AppStorage 读取/写入
  @StorageLink('themeMode') themeMode: string = 'auto';
  @StorageLink('notificationEnabled') notifyEnabled: boolean = true;

  @State currentLang: string = 'zh';
  @State cacheSize: string = '计算中...';
  @State appVersion: string = '1.0.0';

  aboutToAppear(): void {
    this.loadSettings();
  }

  async loadSettings(): Promise<void> {
    this.currentLang =
      await PreferencesManager.getLanguage();
    this.cacheSize =
      await CacheManager.getCacheSize();
  }

  async setTheme(mode: 'auto' | 'light' | 'dark'): Promise<void> {
    this.themeMode = mode;
    await PreferencesManager.setTheme(mode);
  }

  async setLanguage(lang: string): Promise<void> {
    this.currentLang = lang;
    await PreferencesManager.setLanguage(lang);
  }

  async toggleNotification(): Promise<void> {
    await PreferencesManager.setNotificationEnabled(this.notifyEnabled);
  }

  async clearCache(): Promise<void> {
    await CacheManager.clearAll();
    this.cacheSize = '0MB';
  }

  async exportData(): Promise<void> {
    const data = await DataExportService.exportAll();
    // 调用系统分享
  }
}
```

## 用户交互流程

### 更改主题
```
选择"深色" → themeMode更新 → AppStorage同步 → Preferences持久化
→ 应用全局主题变化（通过 @Consume('themeMode') 传播）
```

### 清除缓存
```
点击"清除缓存" → 弹出确认框 → 确认 → 执行清理 → 更新缓存大小显示
```

## 设置状态持久化

```typescript
// 使用 @kit.ArkData Preferences
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

export class SettingsManager {
  private static prefs: preferences.Preferences | null = null;

  static async init(context: common.UIAbilityContext): Promise<void> {
    this.prefs = await preferences.getPreferences(context, 'settings');
  }

  static async get(key: string, defaultValue: string): Promise<string> {
    return (await this.prefs?.get(key, defaultValue)) as string || defaultValue;
  }

  static async set(key: string, value: string): Promise<void> {
    await this.prefs?.put(key, value);
    await this.prefs?.flush();
  }
}
```

## 完成标准

- [ ] 主题模式切换实时生效
- [ ] 语言设置保存到Preferences
- [ ] 通知开关可正常切换
- [ ] 清除缓存有确认弹窗
- [ ] 导出数据可唤起系统分享
- [ ] 返回按钮正常


## 数据流图

```
┌─────────────────────────────────────────────────────┐
│ SettingsPage                                        │
│                                                     │
│  aboutToAppear() → PreferencesManager.getAll()      │
│       │                                             │
│  用户操作 → 立即写入 Preferences                     │
│       │                                             │
│  ├─ 主题切换 → AppStorage.set('themeMode')          │
│  │      → EventBus.emit('theme_changed')            │
│  │      → Preferences.set('theme', newValue)         │
│  │                                                   │
│  ├─ 语言选择 → Preferences.set('language', lang)    │
│  │                                                   │
│  ├─ 通知开关 → Preferences.set('notify', bool)      │
│  │                                                   │
│  ├─ 清除缓存 → CacheManager.clearAll()              │
│  │                                                   │
│  └─ 导出数据 → DataExportService.exportAll()        │
│         → 生成JSON文件 → 系统分享                   │
└─────────────────────────────────────────────────────┘
```

## 完整状态设计

| 状态变量 | 类型 | 初始值 | 说明 |
|---------|------|--------|------|
| themeMode | string | 'auto' | 来自AppStorage |
| notifyEnabled | boolean | true | 来自AppStorage |
| currentLang | string | 'zh' | 来自Preferences |
| cacheSize | string | '计算中...' | 来自CacheManager |

SettingsPage 没有 loading/empty/error 态（因为是纯本地操作）
但清除缓存和导出数据应有确认弹窗和Toast反馈。
