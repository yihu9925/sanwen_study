// 全局事件总线 - 使用Map替代索引签名
type EventHandler = (data?: object) => void;

interface EventConstants {
  GRAPH_READY: string;
  GRAPH_UPDATED: string;
  CONTROVERSY_READY: string;
  QUESTIONS_READY: string;
  PROGRESS_UPDATED: string;
  COURSE_CREATED: string;
  DOCUMENT_ADDED: string;
  THEME_CHANGED: string;
}

export class EventBus {
  private static handlers: Map<string, EventHandler[]> = new Map();

  // 订阅事件
  static on(event: string, handler: EventHandler): void {
    let list = EventBus.handlers.get(event);
    if (!list) {
      list = [];
      EventBus.handlers.set(event, list);
    }
    list.push(handler);
  }

  // 取消订阅
  static off(event: string, handler: EventHandler): void {
    const list = EventBus.handlers.get(event);
    if (list) {
      const newList = list.filter(h => h !== handler);
      EventBus.handlers.set(event, newList);
    }
  }

  // 触发事件
  static emit(event: string, data?: object): void {
    const list = EventBus.handlers.get(event);
    if (list) {
      for (const handler of list) {
        handler(data);
      }
    }
  }

  // 清空所有订阅
  static clear(): void {
    EventBus.handlers.clear();
  }

  // 清空特定事件的订阅
  static clearEvent(event: string): void {
    EventBus.handlers.delete(event);
  }
}

// 事件类型常量
export const EVENTS: EventConstants = {
  GRAPH_READY: 'graph_ready',
  GRAPH_UPDATED: 'graph_updated',
  CONTROVERSY_READY: 'controversy_ready',
  QUESTIONS_READY: 'questions_ready',
  PROGRESS_UPDATED: 'progress_updated',
  COURSE_CREATED: 'course_created',
  DOCUMENT_ADDED: 'document_added',
  THEME_CHANGED: 'theme_changed'
};
