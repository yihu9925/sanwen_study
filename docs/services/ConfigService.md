# ConfigService — API 配置管理

## 文件
`entry/src/main/ets/services/ConfigService.ets`

## 职责
管理 LLM API 的配置信息（API Key、API Base URL、模型名称），基于 `@kit.ArkData` Preferences 持久化。

## 数据结构

```typescript
export interface LLMConfig {
  apiKey: string;
  apiBase: string;  // 默认: https://api.openai.com/v1
  model: string;    // 默认: gpt-4
}
```

## 核心方法

| 方法 | 说明 | 异步 |
|-----|------|------|
| `init(context)` | 初始化 Preferences 存储，在 EntryAbility.onCreate 中调用 | 是 |
| `getLLMConfig()` | 获取完整 API 配置 | 是 |
| `saveApiKey(key)` | 保存 API Key | 是 |
| `saveApiBase(base)` | 保存 API Base URL | 是 |
| `saveModel(model)` | 保存模型名称 | 是 |

## 存储机制
- 使用 `@kit.ArkData.preferences` 存储
- Store 名称: 'app_config'
- 存储 Key: 'llm_api_key', 'llm_api_base', 'llm_model'
- 每次写入后调用 `flush()` 确保持久化

## 初始化流程

```typescript
// EntryAbility.onCreate 中
import { ConfigService } from '../services/ConfigService';
await ConfigService.init(this.context);
```
