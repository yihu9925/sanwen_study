# EventBus — 全局事件总线

## 文件
`entry/src/main/ets/utils/EventBus.ets`

## 职责
提供基于 Map 的发布-订阅模式，实现 Service 到 UI 的解耦通信。

## 核心方法

| 方法 | 说明 |
|-----|------|
| `EventBus.on(event, handler)` | 订阅事件 |
| `EventBus.off(event, handler)` | 取消订阅 |
| `EventBus.emit(event, data)` | 触发事件 |
| `EventBus.clear()` | 清空所有订阅 |
| `EventBus.clearEvent(event)` | 清空特定事件的所有订阅 |

## 事件常量

```typescript
export const EVENTS = {
  GRAPH_READY: 'graph_ready',
  GRAPH_UPDATED: 'graph_updated',
  CONTROVERSY_READY: 'controversy_ready',
  QUESTIONS_READY: 'questions_ready',
  PROGRESS_UPDATED: 'progress_updated',
  COURSE_CREATED: 'course_created',
  DOCUMENT_ADDED: 'document_added',
  THEME_CHANGED: 'theme_changed'
};
```

## 生命周期管理

```typescript
@Component
struct CourseDetailPage {
  // 在 aboutToAppear 中注册
  aboutToAppear(): void {
    this.setupEventListeners();
  }

  setupEventListeners(): void {
    EventBus.on(EVENTS.GRAPH_READY, this.handleGraphReady);
    EventBus.on(EVENTS.PROGRESS_UPDATED, this.handleProgress);
  }

  // 在 aboutToDisappear 中取消注册
  aboutToDisappear(): void {
    EventBus.off(EVENTS.GRAPH_READY, this.handleGraphReady);
    EventBus.off(EVENTS.PROGRESS_UPDATED, this.handleProgress);
  }
}
```

## 与 AppStorage 协同

EventBus 负责"事件通知"，AppStorage 负责"数据共享"：

```
Service 完成异步任务
  -> EventBus.emit('graph_ready', { courseId })
  -> UI 组件中注册的回调执行
  -> 更新 @State 或调用 reload 方法
  -> ArkUI 自动触发重渲染
```
