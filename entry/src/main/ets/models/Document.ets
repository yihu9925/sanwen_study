// 文档数据模型
export type DocumentSourceType = 'ai' | 'user' | 'reference';
export type DocumentFileType = 'pdf' | 'md' | 'txt' | 'docx';

export interface Document {
  id: string;
  courseId: string;
  sourceType: DocumentSourceType;
  title: string;
  content: string;
  filePath: string;
  fileType: DocumentFileType;
  keywords: string[];
  uploadedAt: string;
}

// 创建默认文档
export function createDefaultDocument(id: string, courseId: string): Document {
  return {
    id: id,
    courseId: courseId,
    sourceType: 'ai',
    title: '',
    content: '',
    filePath: '',
    fileType: 'txt',
    keywords: [],
    uploadedAt: new Date().toISOString()
  };
}
