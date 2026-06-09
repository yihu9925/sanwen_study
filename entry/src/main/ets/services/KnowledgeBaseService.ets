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

  // AI生成模拟资料（替代联网爬取）
  // 返回生成的文档数量，失败返回0
  static async generateAIDocuments(courseId: string, content: string): Promise<number> {
    let count = 0;
    try {
      const store: relationalStore.RdbStore = RelationalStoreManager.getStore();
      const now: string = new Date().toISOString();
      const shortContent: string = content.length > 15 ? content.substring(0, 15) : (content || '\u901a\u7528\u77e5\u8bc6');

      const titles: string[] = [
        shortContent + '\u57fa\u7840\u6982\u5ff5\u4ecb\u7ecd',
        shortContent + '\u6df1\u5165\u5206\u6790\u4e0e\u5e94\u7528',
        shortContent + '\u7814\u7a76\u8d8b\u52bf\u4e0e\u524d\u6cbf',
      ];

      const contents: string[] = [
        '\u672c\u6587\u7cfb\u7edf\u4ecb\u7ecd\u4e86' + shortContent + '\u7684\u6838\u5fc3\u6982\u5ff5\u3001\u53d1\u5c55\u5386\u53f2\u548c\u57fa\u7840\u539f\u7406\uff0c\u9002\u5408\u521d\u5b66\u8005\u5feb\u901f\u5165\u95e8\u3002',
        '\u672c\u6587\u5728\u57fa\u7840\u4e4b\u4e0a\u6df1\u5165\u63a2\u8ba8\u4e86' + shortContent + '\u7684\u5e38\u89c1\u5e94\u7528\u573a\u666f\u3001\u5b9e\u6218\u6280\u5de7\u548c\u6ce8\u610f\u4e8b\u9879\u3002',
        '\u672c\u6587\u5153\u6ce8' + shortContent + '\u7684\u6700\u65b0\u7814\u7a76\u6210\u679c\u3001\u5b66\u672f\u524d\u6cbf\u52a8\u6001\u548c\u672a\u6765\u53d1\u5c55\u65b9\u5411\u3002',
      ];

      for (let i = 0; i < titles.length; i++) {
        const docId: string = generateUUID();
        const valueBucket: relationalStore.ValuesBucket = {};
        valueBucket['id'] = docId;
        valueBucket['course_id'] = courseId;
        valueBucket['source_type'] = 'ai';
        valueBucket['title'] = titles[i];
        valueBucket['content'] = contents[i];
        valueBucket['file_path'] = '';
        valueBucket['file_type'] = 'md';
        valueBucket['keywords'] = '[]';
        valueBucket['uploaded_at'] = now;
        const rowId: number = await store.insert('document', valueBucket);
        if (rowId > 0) {
          count++;
        }
      }
    } catch (e) {
      // \u751f\u6210\u5931\u8d25\uff0c\u8fd4\u56de0
      console.error('generateAIDocuments failed: ' + (e as Error).message);
    }
    return count;
  }
}