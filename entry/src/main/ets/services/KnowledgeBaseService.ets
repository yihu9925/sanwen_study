// 简化的知识库服务
import { relationalStore } from '@kit.ArkData';
import { KnowledgeGraph } from '../models/KnowledgeGraph';
import { Controversy } from '../models/Controversy';
import { Document, DocumentSourceType, DocumentFileType } from '../models/Document';
import { RelationalStoreManager } from './RelationalStoreManager';
import { LLMService, DocSuggestion } from './LLMService';
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

  // AI生成学习资料（调用LLM，篇数由问题复杂度决定）
  // 先删除该课程已有的AI资料，再重新生成，确保不重复
  static async generateAIDocuments(courseId: string, question: string): Promise<number> {
    try {
      const store: relationalStore.RdbStore = RelationalStoreManager.getStore();
      const now: string = new Date().toISOString();

      // 先删除该课程已有的所有AI资料
      const delPredicates = new relationalStore.RdbPredicates('document');
      delPredicates.equalTo('course_id', courseId);
      delPredicates.equalTo('source_type', 'ai');
      await store.delete(delPredicates);

      // 调用LLM生成学习资料（篇数由问题复杂度自动决定）
      const docs: DocSuggestion[] = await LLMService.generateDocuments(question);

      let count: number = 0;
      for (let i: number = 0; i < docs.length; i++) {
        const doc: DocSuggestion = docs[i];
        const docId: string = generateUUID();
        const valueBucket: relationalStore.ValuesBucket = {};
        valueBucket['id'] = docId;
        valueBucket['course_id'] = courseId;
        valueBucket['source_type'] = 'ai';
        valueBucket['title'] = doc.title;
        valueBucket['content'] = doc.content;
        valueBucket['file_path'] = '';
        valueBucket['file_type'] = 'md';
        valueBucket['keywords'] = JSON.stringify(doc.keywords);
        valueBucket['uploaded_at'] = now;
        const rowId: number = await store.insert('document', valueBucket);
        if (rowId > 0) {
          count++;
        }
      }
      return count;
    } catch (e) {
      const errMsg: string = (e as Error).message || '\u672a\u77e5\u9519\u8bef';
      console.error('generateAIDocuments failed: ' + errMsg);
      return 0;
    }
  }

  // 带课程信息的文档
  static async getDocumentsByUser(userId: string): Promise<DocWithCourse[]> {
    const store = RelationalStoreManager.getStore();
    const sql: string = `
      SELECT d.id, d.course_id, d.source_type, d.title, d.content,
             d.file_path, d.file_type, d.keywords, d.uploaded_at,
             c.title as course_title
      FROM document d
      JOIN course c ON d.course_id = c.id
      WHERE c.user_id = ?
      ORDER BY d.uploaded_at DESC
    `;
    const resultSet = await store.querySql(sql, [userId]);
    const docs: DocWithCourse[] = [];

    while (resultSet.goToNextRow()) {
      docs.push({
        id: resultSet.getString(0),
        courseId: resultSet.getString(1),
        sourceType: resultSet.getString(2) as DocumentSourceType,
        title: resultSet.getString(3) || '',
        content: resultSet.getString(4) || '',
        filePath: resultSet.getString(5) || '',
        fileType: resultSet.getString(6) as DocumentFileType || 'txt',
        keywords: JSON.parse(resultSet.getString(7) || '[]'),
        uploadedAt: resultSet.getString(8) || '',
        courseTitle: resultSet.getString(9) || ''
      });
    }
    resultSet.close();
    return docs;
  }
}

// 带课程信息的文档接口
export interface DocWithCourse {
  id: string;
  courseId: string;
  sourceType: DocumentSourceType;
  title: string;
  content: string;
  filePath: string;
  fileType: DocumentFileType;
  keywords: string[];
  uploadedAt: string;
  courseTitle: string;
}