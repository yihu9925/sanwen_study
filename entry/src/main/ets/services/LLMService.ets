// LLM服务 - 支持OpenAI兼容API + 模拟数据兜底
import { http } from '@kit.NetworkKit';
import { GraphNode, GraphEdge, KnowledgeGraph } from '../models/KnowledgeGraph';
import { Controversy, Evidence } from '../models/Controversy';
import { Question, BloomLevel, AiEvaluation, getBloomLevelName } from '../models/Question';
import { ConfigService } from './ConfigService';
import { generateUUID } from '../utils/UUID';

interface ChatMessage {
  role: string;
  content: string;
}

interface ChatChoice {
  message: ChatMessage;
}

interface ApiResponse {
  choices: ChatChoice[];
}

// 合并生成三问的结果
interface AllContentResult {
  graph: KnowledgeGraph;
  controversies: Controversy[];
  questions: Question[];
}

// AI生成的学习资料建议
export interface DocSuggestion {
  title: string;
  content: string;
  keywords: string[];
}

export class LLMService {

  private static async callLLM(
    systemPrompt: string,
    userPrompt: string,
    responseFormat?: string
  ): Promise<string> {
    const config = await ConfigService.getLLMConfig();
    if (!config.apiKey) {
      throw new Error('NO_API_KEY');
    }

    const systemMsg: ChatMessage = { role: 'system', content: systemPrompt };
    const userMsg: ChatMessage = { role: 'user', content: userPrompt };
    const messages: ChatMessage[] = [systemMsg, userMsg];

    const requestBody: Record<string, Object> = {};
    requestBody['model'] = config.model;
    requestBody['messages'] = messages;
    requestBody['temperature'] = 0.3;

    if (responseFormat === 'json') {
      const rf: Record<string, string> = {};
      rf['type'] = 'json_object';
      requestBody['response_format'] = rf;
    }

    const httpRequest = http.createHttp();
    try {
      const response = await httpRequest.request(
        config.apiBase + '/chat/completions',
        {
          method: http.RequestMethod.POST,
          header: {
            'Content-Type': 'application/json' as string,
            'Authorization': ('Bearer ' + config.apiKey) as string
          } ,
          extraData: JSON.stringify(requestBody) as string,
          expectDataType: http.HttpDataType.OBJECT ,
        }
      );

      if (response.responseCode !== 200) {
        throw new Error('API Error ' + response.responseCode + ': ' + JSON.stringify(response.result));
      }

      const data = response.result as ApiResponse;
      return data.choices[0].message.content;
    } finally {
      httpRequest.destroy();
    }
  }

  // 增强JSON提取：处理markdown包裹、前后杂文本、截断修复
  private static extractJSON(text: string): string {
    let cleaned: string = text.trim();
    // 移除 ```json ... ``` 包裹
    const jsonBlockMatch: RegExpMatchArray | null = cleaned.match(/```(?:json)?\s*([\s\S]*?)\s*```/);
    if (jsonBlockMatch) {
      cleaned = jsonBlockMatch[1].trim();
    }
    // 找到第一个 { 和最后一个 } 截取
    const firstBrace: number = cleaned.indexOf('{');
    const lastBrace: number = cleaned.lastIndexOf('}');
    if (firstBrace >= 0 && lastBrace > firstBrace) {
      cleaned = cleaned.substring(firstBrace, lastBrace + 1);
    }
    return cleaned;
  }

  static async identifyDomain(question: string): Promise<string> {
    try {
      const result = await LLMService.callLLM(
        'You are a subject classifier. Return ONLY the subject name, no extra text.',
        'Classify the subject domain of this question: ' + question
      );
      return result.trim();
    } catch (e) {
      if ((e as Error).message === 'NO_API_KEY') {
        return LLMService.mockIdentifyDomain(question);
      }
      return 'General Knowledge';
    }
  }

  static async generateCourseTitle(question: string, domain: string): Promise<string> {
    let title = question;
    if (title.length > 25) {
      title = title.substring(0, 25) + '...';
    }
    return domain + ': ' + title;
  }

  static async generateKnowledgeGraph(content: string): Promise<KnowledgeGraph> {
    try {
      let truncatedContent = content;
      if (truncatedContent.length > 3000) {
        truncatedContent = truncatedContent.substring(0, 3000);
      }
      const prompt =
        '\u4f60\u662f\u77e5\u8bc6\u56fe\u8c31\u6784\u5efa\u4e13\u5bb6\u3002\u6839\u636e\u4ee5\u4e0b\u5b66\u4e60\u8d44\u6599\uff0c\u6784\u5efa\u8be6\u7ec6\u7684\u77e5\u8bc6\u56fe\u8c31\u3002' +
        '\u6bcf\u4e2a\u8282\u70b9\u662f\u4e00\u4e2a\u5b66\u4e60\u7ae0\u8282\uff0c\u5176description\u662f\u5bf9\u8be5\u7ae0\u8282\u7684\u8be6\u7ec6\u5b66\u4e60\u5185\u5bb9\uff08\u9002\u5408\u65b0\u624b\u5b66\u4e60\uff0c\u5305\u542b\u5b9a\u4e49\u3001\u539f\u7406\u3001\u793a\u4f8b\uff09\u3002' +
        '\u5982\u679c\u662f\u7f16\u7a0b\u8bed\u8a00\u5b66\u4e60\uff0c\u8bf7\u5305\u542b\u8bed\u6cd5\u3001\u5173\u952e\u8bcd\u3001\u4ee3\u7801\u793a\u4f8b\u7b49\u3002' +
        '\u9664\u4ee3\u7801\u548c\u4e13\u6709\u540d\u8bcd\u5916\uff0c\u6240\u6709\u5185\u5bb9\u5747\u4f7f\u7528\u4e2d\u6587\u3002' +
        '\u8282\u70b9\u6570\u91cf\u4e0d\u505a\u9650\u5236\uff0c\u8d8a\u5168\u9762\u8d8a\u597d\uff0c\u4f46\u6bcf\u4e2a\u8282\u70b9\u7684description\u5fc5\u987b\u6709\u5b9e\u9645\u5b66\u4e60\u4ef7\u503c\u3002\n\n' +
        '\u8fd4\u56de\u7c97\u7cd7JSON\uff08\u4e0d\u8981\u4efb\u4f55markdown\u6807\u8bb0\uff09\uff0c\u7ed3\u6784\u5982\u4e0b\uff1a\n' +
        '{\n' +
        '  "nodes": [\n' +
        '    { "label": "\u7ae0\u8282\u540d\u79f0", "importance": 1-5, "description": "\u8be5\u7ae0\u8282\u7684\u8be6\u7ec6\u5b66\u4e60\u5185\u5bb9...", ' +
        '"children": [ {"label": "\u5b50\u8282\u70b9", "description": "\u8bf4\u660e"} ] }\n' +
        '  ],\n' +
        '  "edges": [\n' +
        '    { "from": 0, "to": 1, "label": "\u5173\u7cfb\u7c7b\u578b" }\n' +
        '  ]\n' +
        '}\n\n' +
        '\u4e25\u683c\u8981\u6c42\uff1a\u5fc5\u987b\u5305\u542bnodes\u548cedges\u5b57\u6bb5\uff0c\u8282\u70b9\u81f3\u5c113\u4e2a\u3002' +
        '\u8d44\u6599\uff1a' + truncatedContent;

      const result = await LLMService.callLLM(
        '\u4f60\u662f\u77e5\u8bc6\u56fe\u8c31\u4e13\u5bb6\u3002\u53ea\u8fd4\u56de\u7eaf\u7cb9JSON\u5bf9\u8c61\uff08\u4e0d\u5e26\u4efb\u4f55markdown\u6807\u8bb0\u6216\u989d\u5916\u8bf4\u660e\uff09\u3002',
        prompt,
        'json'
      );
      const cleanedResult: string = LLMService.extractJSON(result);
      const parsed = JSON.parse(cleanedResult) as Record<string, Object>;
      // 兼容 LLM 将数组包在额外字段里的情况
      let rawNodes: Array<Record<string, Object>> = (parsed['nodes'] || []) as Array<Record<string, Object>>;
      if (rawNodes.length === 0) {
        for (const key of Object.keys(parsed)) {
          const val = parsed[key];
          if (Array.isArray(val)) {
            const arr = val as Array<Record<string, Object>>;
            if (arr.length > 0 && arr[0]['label']) {
              rawNodes = arr;
              break;
            }
          }
        }
      }
      let rawEdges: Array<Record<string, Object>> = (parsed['edges'] || []) as Array<Record<string, Object>>;

      const nodes: GraphNode[] = [];
      for (let i = 0; i < rawNodes.length; i++) {
        const n = rawNodes[i];

        // 解析子概念
        const rawChildren = (n['children'] || []) as Array<Record<string, Object>>;
        const children: GraphNode[] = [];
        for (let c = 0; c < rawChildren.length; c++) {
          const rc = rawChildren[c];
          children.push({
            id: generateUUID(),
            label: (rc['label'] as string) || '',
            x: 0, y: 0, radius: 20,
            importance: 0,
            children: [],
            description: (rc['description'] as string) || '',
            relatedDocs: []
          });
        }

        nodes.push({
          id: generateUUID(),
          label: (n['label'] as string) || 'Concept ' + i,
          x: 150 + i * 80,
          y: 150 + (i % 2) * 80,
          radius: 25 + ((n['importance'] as number || 3) * 5),
          importance: n['importance'] as number || 3,
          children: children,
          description: (n['description'] as string) || '',
          relatedDocs: []
        });
      }

      const edges: GraphEdge[] = [];
      for (let j = 0; j < rawEdges.length; j++) {
        const e = rawEdges[j];
        const fromIdx = e['from'] as number || 0;
        const toIdx = e['to'] as number || 0;
        if (fromIdx < nodes.length && toIdx < nodes.length) {
          edges.push({
            from: nodes[fromIdx].id,
            to: nodes[toIdx].id,
            label: (e['label'] as string) || ''
          });
        }
      }

      return { nodes, edges };
    } catch (e) {
      if ((e as Error).message === 'NO_API_KEY') {
        return LLMService.mockKnowledgeGraph();
      }
      return LLMService.mockKnowledgeGraph();
    }
  }

  static async discoverControversies(content: string): Promise<Controversy[]> {
    try {
      let truncatedContent = content;
      if (truncatedContent.length > 3000) {
        truncatedContent = truncatedContent.substring(0, 3000);
      }
      const prompt = 'Analyze the following learning material for academic controversies.\n' +
        'Return JSON array format: [{"title":"...","proViewpoint":"...","conViewpoint":"...","aiSummary":"..."}]\n' +
        'Content: ' + truncatedContent;

      const result = await LLMService.callLLM(
        'You are an academic analysis assistant. Return ONLY valid JSON array.',
        prompt,
        'json'
      );
      const items = JSON.parse(result) as Array<Record<string, string>>;
      const controversies: Controversy[] = [];
      for (let k = 0; k < items.length; k++) {
        const item = items[k];
        controversies.push({
          id: generateUUID(),
          title: item['title'] || 'Controversy',
          proViewpoint: item['proViewpoint'] || '',
          proEvidence: [],
          conViewpoint: item['conViewpoint'] || '',
          conEvidence: [],
          aiSummary: item['aiSummary'] || ''
        });
      }
      return controversies;
    } catch (e) {
      if ((e as Error).message === 'NO_API_KEY') {
        return LLMService.mockControversies();
      }
      return LLMService.mockControversies();
    }
  }

  static async generateQuestions(
    content: string,
    count: number,
    difficultyHint?: string
  ): Promise<Question[]> {
    try {
      let truncatedContent = content;
      if (truncatedContent.length > 3000) {
        truncatedContent = truncatedContent.substring(0, 3000);
      }
      const prompt = '\u8bf7\u6839\u636e\u4ee5\u4e0b\u8d44\u6599\u751f\u62108\u9053\u4e2d\u6587\u9898\u76ee\u3002' +
        '\u5176\u4e2d5\u9053\u4e3a\u9009\u62e9\u9898\uff084\u4e2a\u9009\u9879\uff09\uff0c3\u9053\u4e3a\u5f00\u653e\u5f0f\u95ee\u7b54\u9898\u3002\n' +
        '\u6bcf\u9053\u9898\u7684\u5e03\u9c81\u59c6\u8ba4\u77e5\u5c42\u7ea7\u5fc5\u987b\u8986\u76d6\u8bb0\u5fc6\u3001\u7406\u89e3\u3001\u5e94\u7528\u3001\u5206\u6790\u3001\u8bc4\u4ef7\u3001\u521b\u9020\u4e2d\u7684\u4e0d\u540c\u5c42\u7ea7\uff0c\u4e0d\u80fd\u5168\u90e8\u662f\u540c\u4e00\u4e2a\u5c42\u7ea7\u3002\n' +
        '\u6bcf\u9053\u9898\u53ef\u4ee5\u6709\u591a\u4e2a\u6807\u7b7e\uff08labels\uff09\uff0c\u5982["\u8bb0\u5fc6"]\u6216["\u7406\u89e3","\u5e94\u7528"]\u3002\n' +
        '\u4ee5JSON\u6570\u7ec4\u683c\u5f0f\u8fd4\u56de\uff1a' +
        '[{"questionText":"...","options":["A. ...","B. ...","C. ...","D. ..."],"correctAnswer":"A","explanation":"...","difficulty":1-5,"bloomLevel":1-6,"labels":["..."],"questionType":"choice"}]\n' +
        '\u5f00\u653e\u5f0f\u9898\u76ee\u7684options\u4e3a\u7a7a\u6570\u7ec4\uff0cquestionType\u4e3a"open"\u3002\n' +
        (difficultyHint ? '\u96be\u5ea6\u8981\u6c42\uff1a' + difficultyHint + '\n' : '') +
        '\u8d44\u6599\uff1a' + truncatedContent;

      const result = await LLMService.callLLM(
        '\u4f60\u662f\u6559\u80b2\u6d4b\u8bc4\u4e13\u5bb6\uff0c\u8bf7\u7528\u4e2d\u6587\u751f\u6210\u5f00\u653e\u5f0f\u9898\u76ee\uff0c\u53ea\u8fd4\u56de\u6709\u6548\u7684JSON\u6570\u7ec4\u3002',
        prompt,
        'json'
      );
      const rawQuestions = JSON.parse(result) as Array<Record<string, Object>>;
      const questions: Question[] = [];
      for (let m = 0; m < rawQuestions.length; m++) {
        const q = rawQuestions[m];
        let perLevel: BloomLevel = 1;
        const rawLevel: number = q['bloomLevel'] as number;
        if (rawLevel >= 1 && rawLevel <= 6) {
          perLevel = rawLevel as BloomLevel;
        } else {
          perLevel = ((m % 6) + 1) as BloomLevel;
        }
        const rawLabels: string[] = q['labels'] as string[];
        const labels: string[] = rawLabels && rawLabels.length > 0 ? rawLabels : [getBloomLevelName(perLevel)];
        const rawType: string = q['questionType'] as string || 'open';
        questions.push({
          id: generateUUID(),
          courseId: '',
          bloomLevel: perLevel,
          labels: labels,
          questionText: (q['questionText'] as string) || 'Question ' + (m + 1),
          options: (q['options'] as string[]) || [],
          correctAnswer: (q['correctAnswer'] as string) || '',
          explanation: (q['explanation'] as string) || '',
          difficulty: q['difficulty'] as number || 3,
          questionType: rawType === 'choice' ? 'choice' : 'open'
        });
      }
      return questions;
    } catch (e) {
      if ((e as Error).message === 'NO_API_KEY') {
        return LLMService.mockQuestions(count);
      }
      return LLMService.mockQuestions(count);
    }
  }

  // ===== 自由答题模式核心方法 =====

  // 评估用户自由回答（需求要求："自己回答自己产品的学习提问" + "不要拿AI生成答案喂AI"）
  static async evaluateUserAnswer(
    question: Question,
    userAnswer: string
  ): Promise<AiEvaluation> {
    try {
      const levelNames: Record<number, string> = {
        1: '\u8bb0\u5fc6', 2: '\u7406\u89e3', 3: '\u5e94\u7528',
        4: '\u5206\u6790', 5: '\u8bc4\u4ef7', 6: '\u521b\u9020'
      };
      const levelStr = levelNames[question.bloomLevel] || '\u672a\u77e5';
      const systemPrompt = `\u4f60\u662f\u4e25\u8c28\u7684\u6559\u80b2\u8bc4\u4f30\u4e13\u5bb6\u3002\u6839\u636e\u5e03\u9c81\u59c6\u8ba4\u77e5\u5c42\u7ea7\u6807\u51c6\u8bc4\u4ef7\u5b66\u751f\u56de\u7b54\u3002`;
      const userPrompt =
        '\u8bf7\u8bc4\u4ef7\u4ee5\u4e0b\u5b66\u751f\u7684\u56de\u7b54\uff1a\n\n' +
        '\u3010\u9898\u76ee\u3011' + question.questionText + '\n' +
        '\u3010\u5e03\u9c81\u59c6\u5c42\u7ea7\u3011' + levelStr + '\uff08\u7b2c' + question.bloomLevel + '\u5c42\uff09\n' +
        '\u3010\u53c2\u8003\u7b54\u6848\u3011' + (question.correctAnswer || '\u65e0') + '\n' +
        '\u3010\u5b66\u751f\u56de\u7b54\u3011' + userAnswer + '\n\n' +
        '\u8bf7\u4ece\u51c6\u786e\u6027\u3001\u6df1\u5ea6\u3001\u903b\u8f91\u6027\u3001\u8868\u8fbe\u56db\u4e2a\u65b9\u9762\u8bc4\u4ef7\u3002' +
        '\u4ee5JSON\u683c\u5f0f\u8fd4\u56de\uff1a{"score": 0-100, "comment": "\u8bc4\u8bed", "strengths": ["\u4f18\u70b9"], "weaknesses": ["\u4e0d\u8db3"], "improvement": "\u6539\u8fdb\u5efa\u8bae"}' +
        '\u8bc4\u5206\u6807\u51c6\uff1a90+\u4f18\u79c0 75-89\u826f\u597d 60-74\u53ca\u683c 0-59\u4e0d\u53ca\u683c';

      const result = await LLMService.callLLM(systemPrompt, userPrompt, 'json');
      const parsed = JSON.parse(result) as Record<string, Object>;
      const evaluation: AiEvaluation = {
        score: Math.max(0, Math.min(100, (parsed['score'] as number || 50))),
        comment: (parsed['comment'] as string) || '\u8bc4\u4ef7\u53d6\u5f97',
        strengths: (parsed['strengths'] as string[]) || [],
        weaknesses: (parsed['weaknesses'] as string[]) || [],
        improvement: (parsed['improvement'] as string) || ''
      };
      return evaluation;
    } catch (e) {
      if ((e as Error).message === 'NO_API_KEY') {
        return LLMService.mockEvaluation();
      }
      return LLMService.mockEvaluation();
    }
  }

  // ===== 合并三问生成（方案A：一次请求全部生成）=====
  static async generateAllContent(content: string): Promise<AllContentResult> {
    const defaultResult: AllContentResult = {
      graph: { nodes: [], edges: [] },
      controversies: [],
      questions: []
    };

    try {
      let truncatedContent = content;
      if (truncatedContent.length > 4000) {
        truncatedContent = truncatedContent.substring(0, 4000);
      }

      const systemPrompt =
        '\u4f60\u662f\u5b66\u79d1\u4e13\u5bb6\u517c\u77e5\u8bc6\u56fe\u8c31\u6784\u5efa\u4e13\u5bb6\u517c\u6559\u80b2\u6d4b\u8bc4\u4e13\u5bb6\u3002' +
        '\u6839\u636e\u63d0\u4f9b\u7684\u5b66\u4e60\u8d44\u6599\uff0c\u540c\u65f6\u5b8c\u6210\u4ee5\u4e0b\u4e09\u4e2a\u4efb\u52a1\uff0c\u53ea\u8fd4\u56de\u6709\u6548\u7684JSON\u3002';

      const userPrompt =
        '\u4ee5\u4e0b\u662f\u5b66\u4e60\u8d44\u6599\uff1a\n' +
        truncatedContent + '\n\n' +
        '---\n' +
        '\u8bf7\u57fa\u4e8e\u4ee5\u4e0a\u8d44\u6599\uff0c\u540c\u65f6\u5b8c\u6210\u4e09\u4e2a\u4efb\u52a1\uff0c\u4ee5JSON\u683c\u5f0f\u8fd4\u56de\uff1a\n\n' +

        '\u3010\u4efb\u52a11\u2014\u2014\u77e5\u8bc6\u56fe\u8c31\u3011\n' +
        '\u63d0\u53d6\u6838\u5fc3\u6982\u5ff5\u53ca\u5176\u5173\u7cfb\uff0c\u8fd4\u56de\uff1a\n' +
        '{\n' +
        '  "nodes": [\n' +
        '    {\n' +
        '      "label": "\u6982\u5ff5\u540d",\n' +
        '      "description": "\u8be5\u6982\u5ff5\u7684\u8be6\u7ec6\u5b9a\u4e49\u548c\u8bf4\u660e\uff0c\u4e0d\u5f97\u5c11\u4e8e80\u5b57",\n' +
        '      "importance": 1-5,\n' +
        '      "children": [\n' +
        '        {"label": "\u5b50\u6982\u5ff5", "description": "\u5b50\u6982\u5ff5\u8bf4\u660e"}\n' +
        '      ]\n' +
        '    }\n' +
        '  ],\n' +
        '  "edges": [\n' +
        '    {"from": 0, "to": 1, "label": "\u5305\u542b/\u4f9d\u8d56/\u5e76\u5217/\u5bf9\u7acb"}\n' +
        '  ]\n' +
        '}\n\n' +

        '\u3010\u4efb\u52a12\u2014\u2014\u5b66\u672f\u4e89\u8bae\u70b9\u3011\n' +
        '\u8bc6\u522b\u8d44\u6599\u4e2d\u7684\u5b66\u672f\u4e89\u8bae\u6216\u4e0d\u540c\u89c2\u70b9\uff0c\u8fd4\u56de\u6570\u7ec4\uff1a\n' +
        '[\n' +
        '  {\n' +
        '    "title": "\u4e89\u8bae\u6807\u9898",\n' +
        '    "proViewpoint": "\u6b63\u65b9\u89c2\u70b9\u53ca\u4f9d\u636e",\n' +
        '    "conViewpoint": "\u53cd\u65b9\u89c2\u70b9\u53ca\u4f9d\u636e",\n' +
        '    "proEvidence": [{"title": "\u8bba\u636e\u6807\u9898", "content": "\u8bba\u636e\u5185\u5bb9", "source": "\u6765\u6e90"}],\n' +
        '    "conEvidence": [{"title": "\u8bba\u636e\u6807\u9898", "content": "\u8bba\u636e\u5185\u5bb9", "source": "\u6765\u6e90"}],\n' +
        '    "aiSummary": "\u7efc\u5408\u8bc4\u8ff0"\n' +
        '  }\n' +
        ']\n\n' +

        '\u3010\u4efb\u52a13\u2014\u2014\u6d4b\u8bc4\u9898\u3011\n' +
        '\u6309\u5e03\u9c81\u59c6\u8ba4\u77e5\u5c42\u7ea7\uff081\u8bb0\u5fc6 2\u7406\u89e3 3\u5e94\u7528 4\u5206\u6790 5\u8bc4\u4ef7 6\u521b\u9020\uff09\u5404\u81f3\u5c111\u9898\uff0c\u8fd4\u56de\u6570\u7ec4\uff1a\n' +
        '[\n' +
        '  {\n' +
        '    "questionText": "\u4e2d\u6587\u9898\u76ee\u5185\u5bb9",\n' +
        '    "bloomLevel": 1-6,\n' +
        '    "difficulty": 1-5,\n' +
        '    "correctAnswer": "\u53c2\u8003\u7b54\u6848",\n' +
        '    "explanation": "\u77e5\u8bc6\u70b9\u89e3\u91ca"\n' +
        '  }\n' +
        ']\n\n' +

        '---\n' +
        '\u8bf7\u4ee5\u4e0b\u7ed3\u6784\u4e00\u5e76\u8fd4\u56de\uff1a\n' +
        '{\n' +
        '  "knowledgeGraph": {\n    "nodes": [...],\n    "edges": [...]\n  },\n' +
        '  "controversies": [...],\n' +
        '  "questions": [...]\n' +
        '}\n\n' +
        '\u8981\u6c42\uff1a\n' +
        '1. \u6240\u6709\u5185\u5bb9\u4f7f\u7528\u4e2d\u6587\n' +
        '2. nodes.description \u5fc5\u987b\u8be6\u7ec6\uff0c\u4e0d\u5f97\u5c11\u4e8e80\u5b57\n' +
        '3. questions \u8986\u76d6\u5168\u90e86\u4e2a\u5e03\u9c81\u59c6\u5c42\u7ea7\uff0c\u6bcf\u5c42\u81f3\u5c111\u9898\n' +
        '4. \u8fb9\u7684 from\u3001to \u5bf9\u5e94 nodes \u6570\u7ec4\u4e2d\u7684\u7d22\u5f15';

      const result = await LLMService.callLLM(systemPrompt, userPrompt, 'json');
      const parsed = JSON.parse(result) as Record<string, Object>;

      // ---- 解析知识图谱 ----
      let graph: KnowledgeGraph = { nodes: [], edges: [] };
      try {
        const kgRaw = parsed['knowledgeGraph'] as Record<string, Object> || {};
        const rawNodes = (kgRaw['nodes'] || []) as Array<Record<string, Object>>;
        const rawEdges = (kgRaw['edges'] || []) as Array<Record<string, Object>>;

        const nodes: GraphNode[] = [];
        for (let i = 0; i < rawNodes.length; i++) {
          const n = rawNodes[i];
          const rawChildren = (n['children'] || []) as Array<Record<string, Object>>;
          const children: GraphNode[] = [];
          for (let c = 0; c < rawChildren.length; c++) {
            const rc = rawChildren[c];
            children.push({
              id: generateUUID(),
              label: (rc['label'] as string) || '',
              x: 0, y: 0, radius: 20,
              importance: 0,
              children: [],
              description: (rc['description'] as string) || '',
              relatedDocs: []
            });
          }
          nodes.push({
            id: generateUUID(),
            label: (n['label'] as string) || 'Concept ' + i,
            x: 150 + i * 80,
            y: 150 + (i % 2) * 80,
            radius: 25 + ((n['importance'] as number || 3) * 5),
            importance: n['importance'] as number || 3,
            children: children,
            description: (n['description'] as string) || '',
            relatedDocs: []
          });
        }

        const edges: GraphEdge[] = [];
        for (let j = 0; j < rawEdges.length; j++) {
          const e = rawEdges[j];
          const fromIdx = e['from'] as number || 0;
          const toIdx = e['to'] as number || 0;
          if (fromIdx < nodes.length && toIdx < nodes.length) {
            edges.push({
              from: nodes[fromIdx].id,
              to: nodes[toIdx].id,
              label: (e['label'] as string) || ''
            });
          }
        }
        graph = { nodes, edges };
      } catch (e) {
        console.error('Parse knowledgeGraph failed: ' + (e as Error).message);
      }

      // ---- 解析争议点 ----
      let controversies: Controversy[] = [];
      try {
        const rawControversies = (parsed['controversies'] || []) as Array<Record<string, Object>>;
        controversies = [];
        for (let k = 0; k < rawControversies.length; k++) {
          const item = rawControversies[k];
          const rawProEvidence = item['proEvidence'];
          const rawConEvidence = item['conEvidence'];
          const toEvidenceArray = (raw: Object): Evidence[] => {
            const arr = raw as Array<Record<string, Object>> || [];
            const result: Evidence[] = [];
            for (let e = 0; e < arr.length; e++) {
              const ev = arr[e];
              if (typeof ev === 'string') {
                result.push({ title: '', content: ev as string, source: '' });
              } else {
                result.push({
                  title: (ev['title'] as string) || '',
                  content: (ev['content'] as string) || '',
                  source: (ev['source'] as string) || ''
                });
              }
            }
            return result;
          };
          controversies.push({
            id: generateUUID(),
            title: item['title'] as string || 'Controversy',
            proViewpoint: item['proViewpoint'] as string || '',
            proEvidence: toEvidenceArray(rawProEvidence),
            conViewpoint: item['conViewpoint'] as string || '',
            conEvidence: toEvidenceArray(rawConEvidence),
            aiSummary: item['aiSummary'] as string || ''
          });
        }
      } catch (e) {
        console.error('Parse controversies failed: ' + (e as Error).message);
      }

      // ---- 解析测评题 ----
      let questions: Question[] = [];
      try {
        const rawQuestions = (parsed['questions'] || []) as Array<Record<string, Object>>;
        questions = [];
        for (let m = 0; m < rawQuestions.length; m++) {
          const q = rawQuestions[m];
          const rawLevel: number = q['bloomLevel'] as number || 1;
          const qLevel: BloomLevel = (rawLevel >= 1 && rawLevel <= 6) ? rawLevel as BloomLevel : 1;
          const rawLabels: string[] = q['labels'] as string[];
          const qLabels: string[] = rawLabels && rawLabels.length > 0 ? rawLabels : [getBloomLevelName(qLevel)];
          const rawType: string = q['questionType'] as string || 'open';
          questions.push({
            id: generateUUID(),
            courseId: '',
            bloomLevel: qLevel,
            labels: qLabels,
            questionText: (q['questionText'] as string) || 'Question ' + (m + 1),
            options: [],
            correctAnswer: (q['correctAnswer'] as string) || '',
            explanation: (q['explanation'] as string) || '',
            difficulty: q['difficulty'] as number || 3,
            questionType: rawType === 'choice' ? 'choice' : 'open'
          });
        }
      } catch (e) {
        console.error('Parse questions failed: ' + (e as Error).message);
      }

      return { graph, controversies, questions };
    } catch (e) {
      if ((e as Error).message === 'NO_API_KEY') {
        const mock: AllContentResult = {
          graph: LLMService.mockKnowledgeGraph(),
          controversies: LLMService.mockControversies(),
          questions: LLMService.mockQuestions(5)
        };
        return mock;
      }
      return defaultResult;
    }
  }

  // ===== 生成学习资料（AI生成多篇，数量由问题复杂度决定）=====
  static async generateDocuments(question: string): Promise<DocSuggestion[]> {
    try {
      const truncatedQuestion: string = question.length > 500 ? question.substring(0, 500) : question;
      const prompt: string =
        '\u6839\u636E\u4EE5\u4E0B\u5B66\u4E60\u95EE\u9898\uFF0C\u751F\u6210\u82E5\u5E72\u7BC7\u5B66\u4E60\u8D44\u6599\u3002' +
        '\u8D44\u6599\u7BC7\u6570\u7531\u95EE\u9898\u590D\u6742\u5EA6\u51B3\u5B9A\uFF0C\u4E0D\u505A\u9650\u5236\uFF0C\u4EE5\u8986\u76D6\u5168\u90E8\u6838\u5FC3\u5185\u5BB9\u4E3A\u51C6\u3002\n\n' +
        '\u6BCF\u7BC7\u8D44\u6599\u5305\u542B\u4EE5\u4E0B\u5B57\u6BB5\uFF1A\n' +
        '- title: \u6807\u9898\uFF08\u7CBE\u7B80\u76F4\u63A5\uFF0C\u53CD\u6620\u5185\u5BB9\uFF09\n' +
        '- content: \u8BE6\u7EC6\u5185\u5BB9\uFF08\u81F3\u5C11300\u5B57\uFF0C\u9002\u5408\u65B0\u624B\u5B66\u4E60\uFF0C\u5305\u542B\u5B9A\u4E49\u3001\u539F\u7406\u3001\u793A\u4F8B\uff0C\u7528\\n\u6362\u884C\u5206\u6BB5\u843D\uFF09\n' +
        '- keywords: \u5173\u952E\u8BCD\u6570\u7EC4\uFF081-3\u4E2A\uFF09\n\n' +
        '\u8981\u6C42\uFF1A\n' +
        '1. \u5982\u679C\u662F\u7F16\u7A0B\u8BED\u8A00\uFF0Ccontent\u5185\u5FC5\u987B\u5305\u542B\u4EE3\u7801\u793A\u4F8B\uFF08\u7528[CODE]...[/CODE]\u5305\u88F9\uFF09\n' +
        '2. \u5185\u5BB9\u8981\u9002\u5408\u65B0\u624B\uFF0C\u4ECE\u7B80\u5355\u5230\u590D\u6742\u5C42\u5C42\u9012\u8FDB\n' +
        '3. \u4F7F\u7528\u4E2D\u6587\n' +
        '4. \u4EE3\u7801\u5FC5\u987B\u7528[CODE]\u548C[/CODE]\u6807\u8BB0\u5305\u88F9\uFF0C\u4FDD\u6301\u7F29\u8FDB\n' +
        '5. \u53EA\u8FD4\u56DE\u7EAF\u7CB9 JSON \u6570\u7EC4\uFF0C\u4E0D\u8981\u4EFB\u4F55markdown\u6807\u8BB0\u6216\u8BF4\u660E\u6587\u5B57\uFF1A[{\"title\": \"...\", \"content\": \"...\", \"keywords\": [\"...\"]}]\n\n' +
        '\u95EE\u9898\uFF1A' + truncatedQuestion;

      const result: string = await LLMService.callLLM(
        '\u4F60\u662F\u6559\u80B2\u5185\u5BB9\u4E13\u5BB6\uFF0C\u53EA\u8FD4\u56DE\u6709\u6548\u7684JSON\u3002',
        prompt,
        'json'
      );
      const items: Array<Record<string, Object>> = JSON.parse(result) as Array<Record<string, Object>>;
      const docs: DocSuggestion[] = [];
      for (let i: number = 0; i < items.length; i++) {
        const item: Record<string, Object> = items[i];
        const title: string = (item['title'] as string) || '';
        const content: string = (item['content'] as string) || '';
        const keywords: string[] = (item['keywords'] as string[]) || [];
        if (title && content) {
          docs.push({ title, content, keywords });
        }
      }
      return docs.length > 0 ? docs : LLMService.mockDocuments(question);
    } catch (e) {
      if ((e as Error).message === 'NO_API_KEY') {
        return LLMService.mockDocuments(question);
      }
      return LLMService.mockDocuments(question);
    }
  }

  // ===== Mock fallback =====
  private static mockIdentifyDomain(question: string): string {
    const q: string = question.toLowerCase();
    if (q.indexOf('learn') >= 0 || q.indexOf('ai') >= 0 || q.indexOf('machine learning') >= 0 ||
        q.indexOf('deep learning') >= 0 || q.indexOf('\u673a\u5668\u5b66\u4e60') >= 0 ||
        q.indexOf('\u4eba\u5de5\u667a\u80fd') >= 0) {
      return 'Artificial Intelligence';
    }
    if (q.indexOf('physics') >= 0 || q.indexOf('\u529b\u5b66') >= 0 || q.indexOf('\u7269\u7406') >= 0) {
      return 'Physics';
    }
    if (q.indexOf('math') >= 0 || q.indexOf('\u5fae\u79ef\u5206') >= 0 || q.indexOf('\u6570\u5b66') >= 0) {
      return 'Mathematics';
    }
    if (q.indexOf('chem') >= 0 || q.indexOf('\u5316\u5b66') >= 0) {
      return 'Chemistry';
    }
    if (q.indexOf('bio') >= 0 || q.indexOf('\u751f\u7269') >= 0) {
      return 'Biology';
    }
    if (q.indexOf('code') >= 0 || q.indexOf('program') >= 0 || q.indexOf('python') >= 0 ||
        q.indexOf('java') >= 0 || q.indexOf('javascript') >= 0 || q.indexOf('swift') >= 0 ||
        q.indexOf('coding') >= 0 || q.indexOf('\u7f16\u7a0b') >= 0 ||
        q.indexOf('\u4ee3\u7801') >= 0 || q.indexOf('\u8f6f\u4ef6') >= 0) {
      return 'Coding';
    }
    if (q.indexOf('\u5e38\u8bc6') >= 0 || q.indexOf('\u751f\u6d3b') >= 0 || q.indexOf('\u65e5\u5e38') >= 0) {
      return '\u5e38\u8bc6';
    }
    if (q.indexOf('history') >= 0 || q.indexOf('\u5386\u53f2') >= 0) {
      return 'History';
    }
    if (q.indexOf('english') >= 0 || q.indexOf('\u82f1\u8bed') >= 0) {
      return 'English';
    }
    if (q.indexOf('chinese') >= 0 || q.indexOf('\u8bed\u6587') >= 0) {
      return '\u8bed\u6587';
    }
    if (q.indexOf('music') >= 0 || q.indexOf('\u97f3\u4e50') >= 0) {
      return 'Music';
    }
    if (q.indexOf('art') >= 0 || q.indexOf('\u7f8e\u672f') >= 0) {
      return 'Art';
    }
    return 'General Knowledge';
  }

  private static mockKnowledgeGraph(): KnowledgeGraph {
    const node1Id = generateUUID();
    const node2Id = generateUUID();
    const node3Id = generateUUID();
    const child1Id = generateUUID();
    const nodes: GraphNode[] = [
      {
        id: node1Id, label: '核心概念', x: 200, y: 200, radius: 40, importance: 5,
        description: '这是该学习主题的核心概念，涵盖了问题的本质定义和基本原理。掌握这个概念是理解整个知识领域的基础，也是连接其他子概念的枢纽。',
        children: [
          { id: child1Id, label: '基础定义', x: 0, y: 0, radius: 20, importance: 0, children: [], description: '核心概念的基本定义和术语解释，包括其历史背景和理论渊源。', relatedDocs: [] }
        ],
        relatedDocs: []
      },
      {
        id: node2Id, label: '子概念1', x: 100, y: 100, radius: 30, importance: 3,
        description: '与核心概念密切相关的一个子领域，包含重要的定理、方法和技术细节。深入学习此概念有助于加深对核心概念的理解。',
        children: [], relatedDocs: []
      },
      {
        id: node3Id, label: '子概念2', x: 300, y: 100, radius: 30, importance: 3,
        description: '另一个重要的子领域，与子概念1形成互补关系。两者结合可以构建完整的知识框架。',
        children: [], relatedDocs: []
      },
    ];
    const edges: GraphEdge[] = [
      { from: node1Id, to: node2Id, label: '包含' },
      { from: node1Id, to: node3Id, label: '包含' },
    ];
    return { nodes, edges };
  }

  private static mockControversies(): Controversy[] {
    return [{
      id: generateUUID(), title: '\u4e3b\u8981\u4e89\u8bae\u70b9',
      proViewpoint: '\u652f\u6301\u65b9\uff1a\u8be5\u7406\u8bba\u6709\u5145\u5206\u8bc1\u636e\u652f\u6301',
      proEvidence: [{ title: '', content: '\u8fd9\u662f\u4e00\u4e2a\u652f\u6301\u8be5\u89c2\u70b9\u7684\u8bba\u636e', source: '' }],
      conViewpoint: '\u53cd\u5bf9\u65b9\uff1a\u8be5\u7406\u8bba\u5b58\u5728\u91cd\u5927\u7f3a\u9677',
      conEvidence: [{ title: '', content: '\u8fd9\u662f\u4e00\u4e2a\u53cd\u5bf9\u8be5\u89c2\u70b9\u7684\u8bba\u636e', source: '' }],
      aiSummary: '\u8fd9\u662f\u4e00\u4e2a\u5177\u6709\u4e89\u8bae\u7684\u8bdd\u9898\uff0c\u53cc\u65b9\u90fd\u6709\u5408\u7406\u4e4b\u5904\u3002'
    }];
  }

  private static mockQuestions(count: number): Question[] {
    const levelNames: string[] = ['\u8bb0\u5fc6', '\u7406\u89e3', '\u5e94\u7528', '\u5206\u6790', '\u8bc4\u4ef7', '\u521b\u9020'];
    const questions: Question[] = [];
    for (let i = 0; i < count; i++) {
      const level: BloomLevel = ((i % 6) + 1) as BloomLevel;
      const isChoice: boolean = i < 5;
      questions.push({
        id: generateUUID(), courseId: '', bloomLevel: level,
        labels: [levelNames[level - 1]],
        questionText: 'Test question ' + (i + 1) + ': What is the main concept?',
        options: isChoice ? ['A. Correct answer', 'B. Option B', 'C. Option C', 'D. Option D'] : [],
        correctAnswer: 'A',
        explanation: 'This is the correct answer because...',
        difficulty: 3,
        questionType: isChoice ? 'choice' : 'open'
      });
    }
    return questions;
  }

  // Mock fallback for evaluation (when no API key)
  private static mockEvaluation(): AiEvaluation {
    return {
      score: 75,
      comment: '\u56de\u7b54\u57fa\u672c\u6b63\u786e\uff0c\u5c55\u793a\u4e86\u5bf9\u6982\u5ff5\u7684\u7406\u89e3\u3002\u5efa\u8bae\u8fdb\u4e00\u6b65\u52a0\u6df1\u5bf9\u6838\u5fc3\u903b\u8f91\u7684\u638c\u63e1\u3002',
      strengths: ['\u601d\u8def\u6e05\u6670', '\u80fd\u591f\u628a\u63e1\u4e3b\u8981\u89c2\u70b9'],
      weaknesses: ['\u7f3a\u4e4f\u5177\u4f53\u4f8b\u8bc1', '\u8bba\u8ff0\u4e0d\u591f\u6df1\u5165'],
      improvement: '\u5efa\u8bae\u591a\u7ed3\u5408\u5b9e\u9645\u6848\u4f8b\u6765\u8bf4\u660e\u4f60\u7684\u89c2\u70b9\uff0c\u5e76\u5c1d\u8bd5\u4ece\u4e0d\u540c\u89d2\u5ea6\u5206\u6790\u95ee\u9898\u3002'
    };
  }

  // Mock documents based on question complexity
  private static mockDocuments(question: string): DocSuggestion[] {
    const shortContent: string = question.length > 15 ? question.substring(0, 15) : (question || '\u901a\u7528\u77e5\u8bc6');
    const q: string = question.toLowerCase();
    const isCodeRelated: boolean = q.indexOf('code') >= 0 || q.indexOf('program') >= 0 ||
      q.indexOf('python') >= 0 || q.indexOf('java') >= 0 || q.indexOf('javascript') >= 0 ||
      q.indexOf('swift') >= 0 || q.indexOf('function') >= 0 || q.indexOf('class') >= 0 ||
      q.indexOf('def ') >= 0 || q.indexOf('\u53d8\u91cf') >= 0 || q.indexOf('\u51fd\u6570') >= 0 ||
      q.indexOf('\u7f16\u7a0b') >= 0 || q.indexOf('\u4ee3\u7801') >= 0 || q.indexOf('\u7b97\u6cd5') >= 0;

    const topics: string[] = isCodeRelated ? [
      shortContent + '\u57fa\u7840\u8bed\u6cd5',
      shortContent + '\u5b9e\u6218\u6848\u4f8b',
      shortContent + '\u5e38\u89c1\u95ee\u9898'
    ] : [
      shortContent + '\u57fa\u7840\u6982\u5ff5\u4ecb\u7ecd',
      shortContent + '\u6df1\u5165\u5206\u6790\u4e0e\u5e94\u7528',
      shortContent + '\u7814\u7a76\u8d8b\u52bf\u4e0e\u524d\u6cbf',
    ];
    const contents: string[] = isCodeRelated ? [
      shortContent + '\u7684\u57fa\u7840\u8bed\u6cd5\u4ecb\u7ecd\uff1a\u4ee5\u4e0b\u662f\u793a\u4f8b\u4ee3\u7801\u3002\n[CODE]\n# \u57fa\u7840\u8bed\u6cd5\u793a\u4f8b\nfor i in range(5):\n    print(i)\n[/CODE]\n\u4ee5\u4e0a\u4ee3\u7801\u5c55\u793a\u4e86\u5faa\u73af\u8bed\u53e5\u7684\u57fa\u672c\u7528\u6cd5\u3002',
      shortContent + '\u7684\u5b9e\u6218\u6848\u4f8b\u5206\u6790\u3002\n[CODE]\ndef calculate(data):\n    result = []\n    for item in data:\n        if item > 0:\n            result.append(item * 2)\n    return result\n[/CODE]\n\u8be5\u6848\u4f8b\u5c55\u793a\u4e86\u5982\u4f55\u5904\u7406\u6570\u636e\u5e76\u8fd4\u56de\u7ed3\u679c\u3002',
      shortContent + '\u7684\u5e38\u89c1\u95ee\u9898\u4e0e\u89e3\u51b3\u3002\n[CODE]\ntry:\n    x = int(input())\n    print(\u8f93\u5165\uff1a\u201d + str(x))\nexcept ValueError:\n    print(\u8f93\u5165\u9519\u8bef\uff01\u201d)\n[/CODE]\n\u4ee5\u4e0a\u4ee3\u7801\u5904\u7406\u4e86\u7c7b\u578b\u8f6c\u6362\u5f02\u5e38\u3002'
    ] : [
      shortContent + '\u7684\u6838\u5fc3\u6982\u5ff5\u57fa\u7840\uff1a\u672c\u8282\u4ecb\u7ecd' + shortContent + '\u7684\u5b9a\u4e49\u3001\u6838\u5fc3\u601d\u60f3\u3001\u57fa\u672c\u539f\u7406\u548c\u5173\u952e\u672f\u8bed\u3002\n\n\u5e2e\u52a9\u5b66\u4e60\u8005\u5feb\u901f\u5efa\u7acb\u77e5\u8bc6\u6846\u67b6\uff0c\u4e3a\u540e\u7eed\u6df1\u5165\u5b66\u4e60\u6253\u4e0b\u57fa\u7840\u3002',
      shortContent + '\u7684\u5e94\u7528\u573a\u666f\u4e0e\u5b9e\u8df5\uff1a\u672c\u8282\u901a\u8fc7\u5177\u4f53\u6848\u4f8b\u8bf4\u660e' + shortContent + '\u5728\u5b9e\u9645\u5de5\u4f5c\u548c\u7814\u7a76\u4e2d\u7684\u5e94\u7528\u65b9\u6cd5\u3002\n\n\u542b\u5e38\u89c1\u95ee\u9898\u89e3\u7b54\u548c\u5b9e\u6218\u6280\u5de7\uff0c\u5e2e\u52a9\u7406\u8bba\u8054\u7cfb\u5b9e\u9645\u3002',
      shortContent + '\u7684\u5b66\u672f\u524d\u6cbf\u4e0e\u5c55\u671b\uff1a\u672c\u8282\u5173\u6ce8' + shortContent + '\u7684\u6700\u65b0\u7814\u7a76\u8fdb\u5c55\u3001\u4e0d\u540c\u5b66\u6d3e\u89c2\u70b9\u4e89\u8bae\u548c\u672a\u6765\u53d1\u5c55\u65b9\u5411\u3002\n\n\u57f9\u517b\u6279\u5224\u6027\u601d\u7ef4\uff0c\u5f00\u62d3\u5b66\u672f\u89c6\u91ce\u3002'
    ];
    const docs: DocSuggestion[] = [];
    for (let i: number = 0; i < topics.length; i++) {
      docs.push({
        title: topics[i],
        content: contents[i],
        keywords: [shortContent, '\u57fa\u7840\u77e5\u8bc6', '\u5b66\u4e60\u8d44\u6599']
      });
    }
    return docs;
  }
}
