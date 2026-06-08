// 简化的知识库服务
import { relationalStore } from '@kit.ArkData';
import { KnowledgeGraph } from '../models/KnowledgeGraph';
import { Controversy } from '../models/Controversy';
import { Document } from '../models/Document';
import { RelationalStoreManager } from './RelationalStoreManager';
import { LLMService } from './LLMService';
import { generateUUID } from '../utils/UUID';

export class KnowledgeBaseService {
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
}
