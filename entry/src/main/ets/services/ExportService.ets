// 数据导出服务（JSON/Markdown 格式）
import { Question, AiEvaluation, BloomLevel } from '../models/Question';
import { AssessmentService } from './AssessmentService';

export class ExportService {

  // 导出测评报告为 JSON 字符串
  static async exportReportAsJSON(
    courseId: string,
    courseTitle: string
  ): Promise<string> {
    const questions = await AssessmentService.getQuestions(courseId);
    const records = await AssessmentService.getLearningRecords(courseId);

    const report: Record<string, Object> = {};
    report['courseTitle'] = courseTitle;
    report['courseId'] = courseId;
    report['exportedAt'] = new Date().toISOString();
    report['totalQuestions'] = questions.length;
    report['answeredQuestions'] = records.length;
    report['details'] = [];

    const details: Object[] = [];
    for (const rec of records) {
      const q = questions.find(item => item.id === rec.questionId);
      const detail: Record<string, Object> = {};
      detail['question'] = q?.questionText || '';
      detail['bloomLevel'] = rec.bloomLevel;
      detail['userAnswer'] = rec.userAnswerText;
      detail['aiEvaluation'] = rec.aiEvaluation;
      detail['score'] = rec.score;
      detail['isCorrect'] = rec.isCorrect;
      detail['answeredAt'] = rec.answeredAt;
      details.push(detail);
    }
    report['details'] = details;

    return JSON.stringify(report, null, 2);
  }

  // 导出测评报告为 Markdown 格式
  static async exportReportAsMarkdown(
    courseId: string,
    courseTitle: string
  ): Promise<string> {
    const questions = await AssessmentService.getQuestions(courseId);
    const records = await AssessmentService.getLearningRecords(courseId);

    let md = '# \u8BC4\u4F30\u62A5\u544A\n\n';
    md += '**\u8BFE\u7A0B**\uff1a' + courseTitle + '\n';
    md += '**\u5BFC\u51FA\u65F6\u95F4**\uff1a' + new Date().toLocaleString() + '\n\n';
    md += '## \u6982\u89C8\n\n';
    md += '- \u603B\u9898\u6570\uff1a' + questions.length + '\n';
    md += '- \u5DF2\u7B54\uff1a' + records.length + '\n';
    md += '- \u672A\u7B54\uff1a' + (questions.length - records.length) + '\n\n';

    if (records.length > 0) {
      const avgScore = Math.round(records.reduce((s, r) => s + r.score, 0) / records.length);
      md += '## \u5F97\u5206\u6982\u89C8\n\n';
      md += '| \u9898\u53F7 | \u5E03\u9C81\u59C6\u5C42\u7EA7 | \u5F97\u5206 | \u6B63\u786E\u5426 |\n';
      md += '|------|----------------|------|--------|\n';

      const levelNames = ['\u8BB0\u5FC6', '\u7406\u89E3', '\u5E94\u7528', '\u5206\u6790', '\u8BC4\u4EF7', '\u521B\u9020'];
      for (let i = 0; i < records.length; i++) {
        const rec = records[i];
        const levelName = levelNames[rec.bloomLevel - 1] || '\u672A\u77E5';
        md += '| ' + (i + 1) + ' | ' + levelName + ' | ' + rec.score + ' | ' + (rec.isCorrect ? '\u2713' : '\u2717') + ' |\n';
      }
      md += '\n**\u5E73\u5747\u5206**\uff1a' + avgScore + '/100\n\n';

      md += '## \u5BF9\u8BDD\u539F\u59CB\u8BB0\u5F55\n\n';
      for (let i = 0; i < records.length; i++) {
        const rec = records[i];
        const q = questions.find(item => item.id === rec.questionId);
        md += '### \u9898\u76EE ' + (i + 1) + '\n\n';
        md += '**\u9898\u76EE**\uff1a' + (q?.questionText || '') + '\n\n';
        md += '**\u4F60\u7684\u56DE\u7B54**\uff1a\n\n' + rec.userAnswerText + '\n\n';
        md += '**AI\u8BC4\u8BED**\uff1a\n\n';
        md += '- \u5F97\u5206\uff1a' + rec.score + '/100\n';
        md += '- \u8BC4\u8BED\uff1a' + (rec.aiEvaluation?.comment || '') + '\n';
        if (rec.aiEvaluation?.strengths?.length) {
          md += '- \u4F18\u70B9\uff1a' + rec.aiEvaluation.strengths.join('\u3001') + '\n';
        }
        if (rec.aiEvaluation?.weaknesses?.length) {
          md += '- \u4E0D\u8DB3\uff1a' + rec.aiEvaluation.weaknesses.join('\u3001') + '\n';
        }
        md += '\n---\n\n';
      }
    }

    return md;
  }
}
