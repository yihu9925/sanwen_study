# AppearancePage — 外观设置页

## 文件
`entry/src/main/ets/pages/AppearancePage.ets`（@Entry 独立路由）

## 路由
`router.pushUrl({ url: 'pages/AppearancePage' })` — 从 SettingsPage 进入

## 功能

### 1. 深色模式切换
- Toggle Switch 控制 `themeMode: 'auto' | 'light' | 'dark'`
- 应用 `window.getLastWindow().setWindowSystemBarProperties()` 更新状态栏颜色
- 深色模式：#222222背景 + #FFFFFF文字
- 亮色模式：#FFFFFF背景 + #000000文字

### 2. UI主题选择
- 3个选项按钮（默认/暖阳/暗夜）
- 切换 `uiStyle: 'default' | 'warm' | 'midnight'`
- 通过 AppStorage('uiStyle') 全局同步

### 3. 状态存储
```typescript
@StorageLink('themeMode') themeMode: string = 'auto';
@StorageLink('uiStyle') uiStyle: string = 'default';
```

切换时通过 AppStorage.set() 更新并在 Toast 中反馈结果。

## 页面布局

```
+----------------------------------+
| [返回]        外观                |
+----------------------------------+
| 深色模式                         |
| ---------------------------------|
| 深色模式          [Toggle]       |
+----------------------------------+
| UI主题                           |
| ---------------------------------|
| [默认]   [暖阳]   [暗夜]        |
+----------------------------------+
```
