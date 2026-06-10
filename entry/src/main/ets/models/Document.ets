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
