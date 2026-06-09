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
        shortContent + '\u7684\u6838\u5fc3\u6982\u5ff5\u57fa\u7840\uff1a\u672c\u8282\u4ecb\u7ecd' + shortContent + '\u7684\u5b9a\u4e49\u3001\u6838\u5fc3\u601d\u60f3\u3001\u57fa\u672c\u539f\u7406\u548c\u5173\u952e\u672f\u8bed\uff0c\u5e2e\u52a9\u5b66\u4e60\u8005\u5feb\u901f\u5efa\u7acb\u77e5\u8bc6\u6846\u67b6\u3002',
        shortContent + '\u7684\u5e94\u7528\u573a\u666f\u4e0e\u5b9e\u8df5\uff1a\u672c\u8282\u901a\u8fc7\u5177\u4f53\u6848\u4f8b\u8bf4\u660e' + shortContent + '\u5728\u5b9e\u9645\u5de5\u4f5c\u548c\u7814\u7a76\u4e2d\u7684\u5e94\u7528\u65b9\u6cd5\uff0c\u542b\u5e38\u89c1\u95ee\u9898\u89e3\u7b54\u3002',
        shortContent + '\u7684\u5b66\u672f\u524d\u6cbf\u4e0e\u5c55\u671b\uff1a\u672c\u8282\u5173\u6ce8' + shortContent + '\u7684\u6700\u65b0\u7814\u7a76\u8fdb\u5c55\u3001\u4e0d\u540c\u5b66\u6d3e\u89c2\u70b9\u4e89\u8bae\u548c\u672a\u6765\u53d1\u5c55\u65b9\u5411\uff0c\u57f9\u517b\u6279\u5224\u6027\u601d\u7ef4\u3002',
      ];

      // 检查已存在的文档标题，避免重复生成
      const existPredicates = new relationalStore.RdbPredicates('document');
      existPredicates.equalTo('course_id', courseId);
      const existRs = await store.query(existPredicates);
      const existTitles: string[] = [];
      while (existRs.goToNextRow()) {
        existTitles.push(existRs.getString(3));
      }
      existRs.close();

      // 检查标题是否已存在（模拟Set去重）
      for (let i = 0; i < titles.length; i++) {
        let isDuplicate: boolean = false;
        for (let t = 0; t < existTitles.length; t++) {
          if (existTitles[t] === titles[i]) {
            isDuplicate = true;
            break;
          }
        }
        if (isDuplicate) {
          continue;
        }
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
      const errMsg: string = (e as Error).message || '\u672a\u77e5\u9519\u8bef';
      console.error('generateAIDocuments failed: ' + errMsg);
    }
    return count;
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