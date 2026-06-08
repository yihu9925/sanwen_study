# KnowledgeBaseService - 知识库管理服务

## 核心职责
管理知识库：知识图谱、争议点、文档的增删改查。

## 接口定义

```typescript
import { RelationalStoreManager } from './RelationalStoreManager';
import { LLMService } from './LLMService';

export class KnowledgeBaseService {

  // 创建知识库
  static async createKnowledgeBase(courseId: string): Promise<void> {
    await RelationalStoreManager.insert('knowledgebase', {
      id: crypto.randomUUID(),
      course_id: courseId,
      knowledge_graph: '[]',
      controversies: '[]',
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString()
    });
  }

  // 获取知识图谱
  static async getKnowledgeGraph(courseId: string): Promise<GraphNode[]> {
    const rows = await RelationalStoreManager.query('knowledgebase', 'course_id', courseId);
    if (rows.length === 0) return [];
    const graphStr = rows[0].knowledge_graph as string || '[]';
    return JSON.parse(graphStr) as GraphNode[];
  }

  // 获取争议点
  static async getControversies(courseId: string): Promise<Controversy[]> {
    const rows = await RelationalStoreManager.query('knowledgebase', 'course_id', courseId);
    if (rows.length === 0) return [];
    const cStr = rows[0].controversies as string || '[]';
    return JSON.parse(cStr) as Controversy[];
  }

  // 更新知识图谱
  static async updateKnowledgeGraph(courseId: string, nodes: GraphNode[]): Promise<void> {
    await RelationalStoreManager.update('knowledgebase',
      {
        knowledge_graph: JSON.stringify(nodes),
        updated_at: new Date().toISOString()
      },
      'course_id', courseId
    );
  }

  // 获取文档列表
  static async getDocuments(courseId: string): Promise<Document[]> {
    const rows = await RelationalStoreManager.query('document', 'course_id', courseId);
    return rows.map(r => ({
      id: r.id as string,
      courseId: r.course_id as string,
      sourceType: r.source_type as string,
      title: r.title as string,
      content: r.content as string,
      filePath: r.file_path as string,
      fileType: r.file_type as string,
      keywords: JSON.parse(r.keywords as string || '[]'),
      uploadedAt: r.uploaded_at as string,
    }));
  }

  // 添加文档（用户上传）
  static async addDocument(courseId: string, file: {
    title: string;
    content: string;
    fileType: string;
    filePath: string;
  }): Promise<void> {
    await RelationalStoreManager.insert('document', {
      id: crypto.randomUUID(),
      course_id: courseId,
      source_type: 'user',
      title: file.title,
      content: file.content,
      file_path: file.filePath,
      file_type: file.fileType,
      keywords: '[]',
      uploaded_at: new Date().toISOString()
    });
  }

  // 删除文档
  static async deleteDocument(docId: string): Promise<void> {
    await RelationalStoreManager.delete('document', 'id', docId);
  }
}
```


## EventBus 集成

```typescript
// 添加文档后触发生成
EventBus.emit('document_added', {
  courseId: courseId,
  docTitle: title
});

// 知识图谱更新（重新生成后）
EventBus.emit('graph_updated', {
  courseId: courseId,
  graphNodes: newGraph
});
```

## 端到端数据流

```
用户上传文件
  → KnowledgeBaseService.addDocument()
    ├─ @kit.CoreFileKit.fileIo 读取文件
    ├─ 解析内容、提取关键词
    ├─ INSERT document
    └→ EventBus.emit('document_added')

CourseDetailPage 监听 document_added
  → 刷新文档列表
  → 可选项：重新生成知识图谱
```
