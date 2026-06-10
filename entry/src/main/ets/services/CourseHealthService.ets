// 课程内容健康检测服务
// 检测三问中哪些部分缺失，并支持逐个补全
import { relationalStore } from '@kit.ArkData';
import { Document } from '../models/Document';
import { RelationalStoreManager } from './RelationalStoreManager';
import { KnowledgeBaseService } from './KnowledgeBaseService';
import { AssessmentService } from './AssessmentService';
import { CourseService } from './CourseService';

// 三问完成状态
export interface CourseContentStatus {
  courseId: string;
  q1KnowledgeGraph: boolean;   // 知识图谱是否已生成
  q2Controversies: boolean;    // 争议点是否已生成
  q3Questions: boolean;        // 测评题是否已生成
  allComplete: boolean;        // 全部完成
  missingParts: string[];      // 缺失的部分名称
  progressPercent: number;     // 综合进度 0-100
}

export class CourseHealthService {

  // 检测单个课程的内容完成状态
  static async checkCourseStatus(courseId: string): Promise<CourseContentStatus> {
    const store = RelationalStoreManager.getStore();
    const missingParts: string[] = [];
    let q1Done = false;
    let q2Done = false;
    let q3Done = false;

    // 检测 Q1: 知识图谱
    try {
      const kbPredicates = new relationalStore.RdbPredicates('knowledgebase');
      kbPredicates.equalTo('course_id', courseId);
      const kbRs = await store.query(kbPredicates);
      if (kbRs.goToNextRow()) {
        const graphStr: string = kbRs.getString(2) || '[]';
        try {
          const parsed: Record<string, Object> = JSON.parse(graphStr) as Record<string, Object>;
          const nodes: Object = parsed['nodes'] || [];
          const nodesArr: Object[] = nodes as Object[];
          q1Done = nodesArr.length > 0;
          // 如果节点全是mock数据（"核心概念"是mock的特征），视为未完成
          if (q1Done) {
            for (let ni = 0; ni < nodesArr.length; ni++) {
              const nd = nodesArr[ni] as Record<string, string>;
              if (nd['label'] && nd['label'].indexOf('\u6838\u5fc3\u6982\u5ff5') >= 0) {
                q1Done = false;
                break;
              }
            }
          }
        } catch (e) {
          q1Done = false;
        }
      }
      kbRs.close();
    } catch (e) {
      q1Done = false;
    }
    if (!q1Done) {
      missingParts.push('\u77e5\u8bc6\u56fe\u8c31');
    }

    // 检测 Q2: 争议点
    try {
      const kbPredicates2 = new relationalStore.RdbPredicates('knowledgebase');
      kbPredicates2.equalTo('course_id', courseId);
      const kbRs2 = await store.query(kbPredicates2);
      if (kbRs2.goToNextRow()) {
        const contStr: string = kbRs2.getString(3) || '[]';
        try {
          const parsed: Record<string, Object> = JSON.parse(contStr) as Record<string, Object>;
          const cont: Object = parsed['controversies'] || parsed;
          const contArr: Object[] = cont as Object[];
          q2Done = contArr.length > 0;
        } catch (e) {
          q2Done = false;
        }
      }
      kbRs2.close();
    } catch (e) {
      q2Done = false;
    }
    if (!q2Done) {
      missingParts.push('\u4e89\u8bae\u70b9\u5206\u6790');
    }

    // 检测 Q3: 测评题
    try {
      const qPredicates = new relationalStore.RdbPredicates('question');
      qPredicates.equalTo('course_id', courseId);
      const qRs = await store.query(qPredicates);
      if (qRs.goToNextRow()) {
        q3Done = true;
      }
      qRs.close();
    } catch (e) {
      q3Done = false;
    }
    if (!q3Done) {
      missingParts.push('\u6d4b\u8bc4\u9898');
    }

    const doneCount = (q1Done ? 1 : 0) + (q2Done ? 1 : 0) + (q3Done ? 1 : 0);

    return {
      courseId: courseId,
      q1KnowledgeGraph: q1Done,
      q2Controversies: q2Done,
      q3Questions: q3Done,
      allComplete: q1Done && q2Done && q3Done,
      missingParts: missingParts,
      progressPercent: Math.round((doneCount / 3) * 100)
    };
  }

  // 获取课程资料库内容（合并所有文档内容到LLM提示词）
  private static async getMaterialContent(courseId: string, question: string): Promise<string> {
    try {
      const docs: Document[] = await KnowledgeBaseService.getDocuments(courseId);
      if (docs.length === 0) {
        return question;
      }
      let docTexts: string[] = [];
      for (let d = 0; d < docs.length; d++) {
        const doc: Document = docs[d];
        if (doc.content) {
          const snippet: string = doc.content.length > 500
            ? doc.content.substring(0, 500)
            : doc.content;
          docTexts.push('\u3010' + doc.title + '\u3011' + snippet);
        }
      }
      if (docTexts.length === 0) {
        return question;
      }
      const combined: string = docTexts.join('\n');
      return question + '\n\n---\n\u53c2\u8003\u8d44\u6599\uff1a\n' +
        (combined.length > 5000 ? combined.substring(0, 5000) : combined);
    } catch (e) {
      return question;
    }
  }

  // 补全缺失的 Q1（知识图谱）
  static async fillQ1KnowledgeGraph(courseId: string, question: string): Promise<boolean> {
    try {
      const material: string = await CourseHealthService.getMaterialContent(courseId, question);
      await KnowledgeBaseService.generateKnowledgeGraph(courseId, material);
      await CourseService.updateProgress(courseId, 1);
      return true;
    } catch (e) {
      return false;
    }
  }

  // 补全缺失的 Q2（争议点）
  static async fillQ2Controversies(courseId: string, question: string): Promise<boolean> {
    try {
      const material: string = await CourseHealthService.getMaterialContent(courseId, question);
      await KnowledgeBaseService.discoverControversies(courseId, material);
      await CourseService.updateProgress(courseId, 2);
      return true;
    } catch (e) {
      return false;
    }
  }

  // 补全缺失的 Q3（测评题）
  static async fillQ3Questions(courseId: string, content: string): Promise<boolean> {
    try {
      const material: string = await CourseHealthService.getMaterialContent(courseId, content);
      await AssessmentService.generateQuestions(courseId, material, 5);
      await CourseService.updateProgress(courseId, 3);
      return true;
    } catch (e) {
      return false;
    }
    }
  }

