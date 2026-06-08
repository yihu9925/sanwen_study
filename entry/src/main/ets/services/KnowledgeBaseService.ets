// 简化的知识库服务
import { relationalStore } from '@kit.ArkData';
import { KnowledgeGraph } from '../models/KnowledgeGraph';
import { Controversy } from '../models/Controversy';
import { Document, DocumentSourceType, DocumentFileType } from '../models/Document';
import { RelationalStoreManager } from './RelationalStoreManager';
import { LLMService } from './LLMService';
import { generateUUID } from '../utils/UUID';

export class KnowledgeBaseService {
  // 创建知识库记录
  static async createKnowledgeBase(courseId: string): Promise<void> {
    const store = RelationalStoreManager.getStore();
    const now = new Date().toISOString();
    const valueBucket: relationalStore.ValuesBucket = {
      id: generateUUID(),
      course_id: courseId,
      knowledge_graph: '[]',
      controversies: '[]',
      created_at: now,
      updated_at: now
    };
    await store.insert('knowledgebase', valueBucket);
  }

  // 获取知识图谱
  static async getKnowledgeGraph(courseId: string): Promise<KnowledgeGraph> {
    const store = RelationalStoreManager.getStore();
    const predicates = new relationalStore.RdbPredicates('knowledgebase');
    predicates.equalTo('course_id', courseId);

    const resultSet = await store.query(predicates);
    let graph: KnowledgeGraph = { nodes: [], edges: [] };

    if (resultSet.goToNextRow()) {
      const graphStr = resultSet.getString(2);
      if (graphStr && graphStr !== '[]') {
        graph = JSON.parse(graphStr) as KnowledgeGraph;
      }
    }
    resultSet.close();

    return graph;
  }

  // 更新知识图谱
  static async updateKnowledgeGraph(courseId: string, graph: KnowledgeGraph): Promise<void> {
    const store = RelationalStoreManager.getStore();
    const now = new Date().toISOString();

    const valueBucket: relationalStore.ValuesBucket = {
      knowledge_graph: JSON.stringify(graph),
      updated_at: now
    };

    const predicates = new relationalStore.RdbPredicates('knowledgebase');
    predicates.equalTo('course_id', courseId);

    await store.update(valueBucket, predicates);
  }

  // 生成知识图谱（调用LLM）
  static async generateKnowledgeGraph(courseId: string, content: string): Promise<void> {
    const graph = await LLMService.generateKnowledgeGraph(content);
    await KnowledgeBaseService.updateKnowledgeGraph(courseId, graph);
  }

  // 获取争议点
  static async getControversies(courseId: string): Promise<Controversy[]> {
    const store = RelationalStoreManager.getStore();
    const predicates = new relationalStore.RdbPredicates('knowledgebase');
    predicates.equalTo('course_id', courseId);

    const resultSet = await store.query(predicates);
    let controversies: Controversy[] = [];

    if (resultSet.goToNextRow()) {
      const str = resultSet.getString(3);
      if (str && str !== '[]') {
        controversies = JSON.parse(str) as Controversy[];
      }
    }
    resultSet.close();

    return controversies;
  }

  // 更新争议点
  static async updateControversies(courseId: string, controversies: Controversy[]): Promise<void> {
    const store = RelationalStoreManager.getStore();
    const now = new Date().toISOString();

    const valueBucket: relationalStore.ValuesBucket = {
      controversies: JSON.stringify(controversies),
      updated_at: now
    };

    const predicates = new relationalStore.RdbPredicates('knowledgebase');
    predicates.equalTo('course_id', courseId);

    await store.update(valueBucket, predicates);
  }

  // 挖掘争议点（调用LLM）
  static async discoverControversies(courseId: string, content: string): Promise<void> {
    const controversies = await LLMService.discoverControversies(content);
    await KnowledgeBaseService.updateControversies(courseId, controversies);
  }

  // 获取课程的文档列表
  static async getDocuments(courseId: string): Promise<Document[]> {
    const store = RelationalStoreManager.getStore();
    const predicates = new relationalStore.RdbPredicates('document');
    predicates.equalTo('course_id', courseId);
    predicates.orderByDesc('uploaded_at');

    const resultSet = await store.query(predicates);
    const documents: Document[] = [];

    while (resultSet.goToNextRow()) {
      documents.push({
        id: resultSet.getString(0),
        courseId: resultSet.getString(1),
        sourceType: resultSet.getString(2) as DocumentSourceType,
        title: resultSet.getString(3) || '',
        content: resultSet.getString(4) || '',
        filePath: resultSet.getString(5) || '',
        fileType: resultSet.getString(6) as DocumentFileType || 'txt',
        keywords: JSON.parse(resultSet.getString(7) || '[]'),
        uploadedAt: resultSet.getString(8) || ''
      });
    }
    resultSet.close();
    return documents;
  }
}
