// 简化的LLM服务 - 使用模拟数据
import { GraphNode, GraphEdge, KnowledgeGraph } from '../models/KnowledgeGraph';
import { Controversy } from '../models/Controversy';
import { Question, BloomLevel } from '../models/Question';
import { generateUUID } from '../utils/UUID';

export class LLMService {
  // 识别领域
  static async identifyDomain(question: string): Promise<string> {
    // 简单的关键词匹配
    if (question.includes('深度学习') || question.includes('机器学习') || question.includes('AI')) {
      return '人工智能';
    } else if (question.includes('物理') || question.includes('力学')) {
      return '物理学';
    } else if (question.includes('数学') || question.includes('微积分')) {
      return '数学';
    } else if (question.includes('化学')) {
      return '化学';
    } else if (question.includes('生物')) {
      return '生物学';
    }
    return '综合知识';
  }

  // 生成课程标题
  static async generateCourseTitle(question: string, domain: string): Promise<string> {
    return `${domain}学习`;
  }

  // 生成知识图谱（模拟）
  static async generateKnowledgeGraph(content: string): Promise<KnowledgeGraph> {
    const nodes: GraphNode[] = [
      {
        id: generateUUID(),
        label: '核心概念',
        x: 200,
        y: 200,
        radius: 40,
        importance: 5,
        children: [],
        description: '这是核心概念',
        relatedDocs: []
      },
      {
        id: generateUUID(),
        label: '子概念1',
        x: 100,
        y: 100,
        radius: 30,
        importance: 3,
        children: [],
        description: '子概念描述',
        relatedDocs: []
      },
      {
        id: generateUUID(),
        label: '子概念2',
        x: 300,
        y: 100,
        radius: 30,
        importance: 3,
        children: [],
        description: '子概念描述',
        relatedDocs: []
      }
    ];

    const edges: GraphEdge[] = [
      {
        from: nodes[0].id,
        to: nodes[1].id,
        label: '包含'
      },
      {
        from: nodes[0].id,
        to: nodes[2].id,
        label: '包含'
      }
    ];

    return { nodes, edges };
  }

  // 挖掘争议点（模拟）
  static async discoverControversies(content: string): Promise<Controversy[]> {
    return [
      {
        id: generateUUID(),
        title: '主要争议点',
        proViewpoint: '正方观点：支持这一理论',
        proEvidence: [],
        conViewpoint: '反方观点：反对这一理论',
        conEvidence: [],
        aiSummary: 'AI总结：这是一个有争议的话题，双方都有合理的论据。'
      }
    ];
  }

  // 生成测评题（模拟）
  static async generateQuestions(
    content: string,
    bloomLevel: BloomLevel,
    count: number = 5
  ): Promise<Question[]> {
    const questions: Question[] = [];
    for (let i = 0; i < count; i++) {
      questions.push({
        id: generateUUID(),
        courseId: '',
        bloomLevel: bloomLevel,
        questionText: `这是第${i + 1}道测试题目？`,
        options: ['选项A', '选项B', '选项C', '选项D'],
        correctAnswer: 'A',
        explanation: '这是答案解析',
        difficulty: 3
      });
    }
    return questions;
  }
}
