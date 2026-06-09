// LLM服务 - 支持OpenAI兼容API + 模拟数据兜底
import { http } from '@kit.NetworkKit';
import { GraphNode, GraphEdge, KnowledgeGraph } from '../models/KnowledgeGraph';
import { Controversy } from '../models/Controversy';
import { Question, BloomLevel, AiEvaluation } from '../models/Question';
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
      const prompt = 'Based on the following content, extract core concepts and their relationships.\n' +
        'Return JSON format: {"nodes":[{"label":"name","importance":1-5}],"edges":[{"from":0,"to":1,"label":"relation"}]}\n' +
        'Content: ' + truncatedContent;

      const result = await LLMService.callLLM(
        'You are a knowledge graph expert. Return ONLY valid JSON.',
        prompt,
        'json'
      );
      const parsed = JSON.parse(result) as Record<string, Object>;
      const rawNodes = (parsed['nodes'] || []) as Array<Record<string, Object>>;
      const rawEdges = (parsed['edges'] || []) as Array<Record<string, Object>>;

      const nodes: GraphNode[] = [];
      for (let i = 0; i < rawNodes.length; i++) {
        const n = rawNodes[i];
        nodes.push({
          id: generateUUID(),
          label: (n['label'] as string) || 'Concept ' + i,
          x: 150 + i * 80,
          y: 150 + (i % 2) * 80,
          radius: 25 + ((n['importance'] as number || 3) * 5),
          importance: n['importance'] as number || 3,
          children: [],
          description: '',
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
    bloomLevel: BloomLevel,
    count: number
  ): Promise<Question[]> {
    try {
      let truncatedContent = content;
      if (truncatedContent.length > 3000) {
        truncatedContent = truncatedContent.substring(0, 3000);
      }
      const levelNames: Record<number, string> = {
        0: 'Remember', 1: 'Understand', 2: 'Apply',
        3: 'Analyze', 4: 'Evaluate', 5: 'Create'
      };
      const levelName = levelNames[bloomLevel] || '';
      const prompt = 'Generate ' + count + ' assessment questions at Bloom level: ' + levelName + '.\n' +
        'Return JSON array: [{"questionText":"...","options":["A","B","C","D"],"correctAnswer":"A","explanation":"...","difficulty":1-5}]\n' +
        'Content: ' + truncatedContent;

      const result = await LLMService.callLLM(
        'You are an education assessment expert. Return ONLY valid JSON array.',
        prompt,
        'json'
      );
      const rawQuestions = JSON.parse(result) as Array<Record<string, Object>>;
      const questions: Question[] = [];
      for (let m = 0; m < rawQuestions.length; m++) {
        const q = rawQuestions[m];
        questions.push({
          id: generateUUID(),
          courseId: '',
          bloomLevel: bloomLevel,
          questionText: (q['questionText'] as string) || 'Question ' + (m + 1),
          options: (q['options'] as string[]) || ['A', 'B', 'C', 'D'],
          correctAnswer: (q['correctAnswer'] as string) || 'A',
          explanation: (q['explanation'] as string) || '',
          difficulty: q['difficulty'] as number || 3,
          questionType: 'open'
        });
      }
      return questions;
    } catch (e) {
      if ((e as Error).message === 'NO_API_KEY') {
        return LLMService.mockQuestions(bloomLevel, count);
      }
      return LLMService.mockQuestions(bloomLevel, count);
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

  // ===== Mock fallback =====
  private static mockIdentifyDomain(question: string): string {
    if (question.indexOf('learn') >= 0 || question.indexOf('AI') >= 0) {
      return 'Artificial Intelligence';
    }
    if (question.indexOf('physics') >= 0 || question.indexOf('\u529b\u5b66') >= 0) {
      return 'Physics';
    }
    if (question.indexOf('math') >= 0 || question.indexOf('\u5fae\u79ef\u5206') >= 0) {
      return 'Mathematics';
    }
    if (question.indexOf('chem') >= 0) {
      return 'Chemistry';
    }
    if (question.indexOf('bio') >= 0) {
      return 'Biology';
    }
    return 'General Knowledge';
  }

  private static mockKnowledgeGraph(): KnowledgeGraph {
    const node1Id = generateUUID();
    const node2Id = generateUUID();
    const node3Id = generateUUID();
    const nodes: GraphNode[] = [
      { id: node1Id, label: 'Core Concept', x: 200, y: 200, radius: 40, importance: 5, children: [], description: 'Core concept description', relatedDocs: [] },
      { id: node2Id, label: 'Sub Concept 1', x: 100, y: 100, radius: 30, importance: 3, children: [], description: 'Sub concept description', relatedDocs: [] },
      { id: node3Id, label: 'Sub Concept 2', x: 300, y: 100, radius: 30, importance: 3, children: [], description: 'Sub concept description', relatedDocs: [] },
    ];
    const edges: GraphEdge[] = [
      { from: node1Id, to: node2Id, label: 'Contains' },
      { from: node1Id, to: node3Id, label: 'Contains' },
    ];
    return { nodes, edges };
  }

  private static mockControversies(): Controversy[] {
    return [{
      id: generateUUID(), title: 'Main Controversy',
      proViewpoint: 'Pro: This theory is supported by evidence', proEvidence: [],
      conViewpoint: 'Con: This theory has significant flaws', conEvidence: [],
      aiSummary: 'This is a debated topic with valid arguments on both sides.'
    }];
  }

  private static mockQuestions(bloomLevel: BloomLevel, count: number): Question[] {
    const questions: Question[] = [];
    for (let i = 0; i < count; i++) {
      questions.push({
        id: generateUUID(), courseId: '', bloomLevel: bloomLevel,
        questionText: 'Test question ' + (i + 1) + ': What is the main concept?',
        options: ['A: Correct answer', 'B: Option', 'C: Option', 'D: Option'],
        correctAnswer: 'A',
        explanation: 'This is the correct answer because...',
        difficulty: 3,
        questionType: 'open'
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
}
