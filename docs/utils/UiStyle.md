# UiStyle — UI主题配色系统

## 文件
`entry/src/main/ets/utils/UiStyle.ets`

## 职责
提供统一的主题配色系统，支持 3 套主题 x 深色/亮色模式 = 6 种配色方案。

## 主题列表

| 主题名 | 标签 | 亮色特点 | 深色特点 |
|--------|------|---------|---------|
| default | 默认 | #F5F5F5背景, #007DFF主色 | #222222背景, #007DFF主色 |
| warm | 暖阳 | #F5F0EB背景, #D4894A主色 | #2C2418背景, #E8A85A主色 |
| midnight | 暗夜 | #F0F2F5背景, #D4A843主色 | #0F141E背景, #D4A843主色 |

## 核心函数

| 函数 | 说明 |
|-----|------|
| `UiStyle.getColors(style, isDark)` | 根据主题和模式返回 StyleColors 对象 |
| `UiStyle.getStyleLabel(style)` | 返回主题的中文标签 |

## StyleColors 接口

```typescript
export interface StyleColors {
  pageBg: string;          // 页面背景色
  cardBg: string;          // 卡片背景色
  accent: string;          // 主色调
  accentLight: string;     // 主色调浅色变体
  textPrimary: string;     // 主文本色
  textSecondary: string;   // 次级文本色
  textTertiary: string;    // 第三级文本色
  divider: string;         // 分割线色
  cardRadius: number;      // 卡片圆角(12/16)
  cardShadow: string;      // 卡片阴影（仅 warm 主题亮色模式有值）
}
```

## 使用方式

```typescript
// 在任何 Component 中
import { UiStyle, StyleColors } from '../utils/UiStyle';

@Component
struct MyPage {
  @StorageLink('uiStyle') uiStyle: string = 'default';
  @StorageLink('themeMode') themeMode: string = 'auto';

  colors(): StyleColors {
    return UiStyle.getColors(this.uiStyle || 'default', this.themeMode === 'dark');
  }

  build() {
    Column() {
      Text('内容')
        .fontColor(this.colors().textPrimary);
      // ...
    }
    .backgroundColor(this.colors().pageBg);
  }
}
```

## AppearancePage 调用

```typescript
// 切换主题
this.setStyle('warm');  // 或 'default' / 'midnight'

// 切换深色模式
this.setDarkMode(true);  // 或 false
```

主题变更时自动更新 systemUI 状态栏颜色。
