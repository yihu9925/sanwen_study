# LLMService - AI大模型服务

## 核心职责
调用外部LLM API实现AI功能，支持OpenAI兼容接口。

## 导入方式（API 20）

```typescript
import { fetch } from '@kit.NetworkKit';  // API 20 推荐
// 旧方式: import { http } from '@ohos.net.http';
```

## 接口定义

```typescript
export class LLMService {
  private static readonly API_BASE = 'https://api.openai.com/v1';
  private static readonly API_KEY = ''; // 从配置读取

  // 设置API Key
  static setApiKey(key: string): void {
    // 可以存储在Preferences中
  }

  // 通用LLM调用
  private static async callLLM(
    systemPrompt: string,
    userPrompt: string,
    model: string = 'gpt-4'
  ): Promise<string> {
    const response = await fetch.fetch({
      url: `${this.API_BASE}/chat/completions`,
      method: 'POST',
      header: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${this.API_KEY}`
      },
      body: JSON.stringify({
        model: model,
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: userPrompt }
        ],
        temperature: 0.3
      })
    });

    const jsonStr = await response.text();
    const data = JSON.parse(jsonStr) as ChatCompletionResponse;
    return data.choices[0].message.content;
  }

  // 识别问题的学科领域
  static async identifyDomain(question: string): Promise<string> {
    const prompt = `请判断以下问题的学科领域，只返回学科名称（如"微积分"、"生物学"、"哲学"等）：\n${question}`;
    return await this.callLLM('你是一个学科分类助手。', prompt);
  }

  // 生成知识图谱
  static async generateKnowledgeGraph(
    question: string,
    documents: string[]
  ): Promise<GraphNode[]> {
    const prompt = `基于以下学习问题和资料，提取核心概念及其关系，以JSON数组形式返回。`;
    const result = await this.callLLM('你是知识图谱专家。', prompt);
    return JSON.parse(result) as GraphNode[];
  }

  // 挖掘争议点
  static async discoverControversies(
    question: string,
    documents: string[]
  ): Promise<Controversy[]> {
    const prompt = `分析以下资料中的学术争议点...`;
    const result = await this.callLLM('你是学术分析助手。', prompt);
    return JSON.parse(result) as Controversy[];
  }

  // 生成测评题
  static async generateQuestions(
    question: string,
    bloomLevel: string,
    knowledgeNodes: string[]
  ): Promise<Question[]> {
    const prompt = `为以下知识点生成${bloomLevel}层级的测评题目...`;
    const result = await this.callLLM('你是教育测评专家。', prompt);
    return JSON.parse(result) as Question[];
  }

  // 评估答案
  static async evaluateAnswer(
    question: string,
    userAnswer: string,
    correctAnswer: string
  ): Promise<{ isCorrect: boolean; explanation: string }> {
    const prompt = `判断以下答案是否正确并给出解析...`;
    const result = await this.callLLM('你是评分助手。', prompt);
    return JSON.parse(result) as { isCorrect: boolean; explanation: string };
  }
}

// 响应类型
interface ChatCompletionResponse {
  choices: Array<{
    message: {
      content: string;
    };
  }>;
}
```

## 数据流

```
用户提问 → LLMService.identifyDomain()
   → 返回学科领域
   → 触发课程创建

课程创建后 → LLMService.generateKnowledgeGraph()
   → 返回 GraphNode[]
   → 存入 knowledgebase.knowledge_graph

LLMService.discoverControversies()
   → 返回 Controversy[]
   → 存入 knowledgebase.controversies

LLMService.generateQuestions()
   → 返回 Question[]
   → 存入 question 表

用户作答 → LLMService.evaluateAnswer()
   → 返回 { isCorrect, explanation }
   → 存入 learning_record
```


## 数据流

```
LLMService.callLLM(systemPrompt, userPrompt)
  → fetch POST https://api.openai.com/v1/chat/completions
    ├─ Header: Authorization, Content-Type
    ├─ Body: { model, messages, temperature }
    └→ Response: { choices: [{ message: { content } }] }

调用方（其他Service）:
  CourseService.generateContent ← 调用 LLMService
    ├─ identifyDomain() → 返回 string
    ├─ generateKnowledgeGraph() → 返回 GraphNode[]
    ├─ discoverControversies() → 返回 Controversy[]
    └─ generateQuestions() → 返回 Question[]
```

## 错误处理

```typescript
// 网络超时
try {
  const result = await fetch.fetch({ url, method, ... });
} catch (error) {
  // 区分网络错误和API错误
  if (error.message?.includes('timeout')) {
    throw new Error('LLM请求超时，请检查网络');
  } else if (error.response?.status === 401) {
    throw new Error('API Key 无效，请在设置中配置');
  } else if (error.response?.status === 429) {
    throw new Error('请求过于频繁，请稍后重试');
  } else {
    throw new Error('AI服务异常：' + error.message);
  }
}
```
