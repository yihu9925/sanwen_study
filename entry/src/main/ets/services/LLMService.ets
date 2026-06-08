// LLM服务 - 支持OpenAI兼容API + 模拟数据兜底
import { http } from '@kit.NetworkKit';
import { GraphNode, GraphEdge, KnowledgeGraph } from '../models/KnowledgeGraph';
import { Controversy } from '../models/Controversy';
import { Question, BloomLevel } from '../models/Question';
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

    const requestBody: Record<string, Object> = {
      model: config.model,
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: userPrompt }
      ],
      temperature: 0.3,
    };

    if (responseFormat === 'json') {
      requestBody['response_format'] = { type: 'json_object' };
    }

    const httpRequest = http.createHttp();
    try {
      const response = await httpRequest.request(
        config.apiBase + '/chat/completions',
        {
          method: http.RequestMethod.POST,
          header: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ' + config.apiKey
          },
          extraData: JSON.stringify(requestBody),
          expectDataType: http.HttpDataType.OBJECT,
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
          difficulty: q['difficulty'] as number || 3
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
        difficulty: 3
      });
    }
    return questions;
  }
}
