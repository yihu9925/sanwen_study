// 路由配置（含三问独立页面）
import { router } from '@kit.ArkUI';

interface RouteConfig {
  HOME: string;
  COURSE_DETAIL: string;
  ASSESSMENT_DETAIL: string;
  ARCHIVE: string;
  SETTINGS: string;
  Q1_KNOWLEDGE_GRAPH: string;
  Q2_CONTROVERSY: string;
  Q3_ASSESSMENT: string;
  APPEARANCE: string;
}

export const ROUTES: RouteConfig = {
  HOME: 'pages/HomePage',
  COURSE_DETAIL: 'pages/CourseDetailPage',
  ASSESSMENT_DETAIL: 'pages/AssessmentDetailPage',
  ARCHIVE: 'pages/ArchiveManagementPage',
  SETTINGS: 'pages/SettingsPage',
  Q1_KNOWLEDGE_GRAPH: 'pages/Q1_KnowledgeGraphPage',
  Q2_CONTROVERSY: 'pages/Q2_ControversyPage',
  Q3_ASSESSMENT: 'pages/Q3_AssessmentPage',
  APPEARANCE: 'pages/AppearancePage',
};

// 导航工具类
export class AppRouter {
  static toCourseDetail(courseId: string): void {
    router.pushUrl({
      url: ROUTES.COURSE_DETAIL,
      params: { courseId }
    });
  }

  static toAssessmentDetail(courseId: string): void {
    router.pushUrl({
      url: ROUTES.ASSESSMENT_DETAIL,
      params: { courseId }
    });
  }

  static toQ1KnowledgeGraph(courseId: string): void {
    router.pushUrl({
      url: ROUTES.Q1_KNOWLEDGE_GRAPH,
      params: { courseId }
    });
  }

  static toQ2Controversy(courseId: string): void {
    router.pushUrl({
      url: ROUTES.Q2_CONTROVERSY,
      params: { courseId }
    });
  }

  static toQ3Assessment(courseId: string): void {
    router.pushUrl({
      url: ROUTES.Q3_ASSESSMENT,
      params: { courseId }
    });
  }

  static toArchive(): void {
    router.pushUrl({ url: ROUTES.ARCHIVE });
  }

  static toSettings(): void {
    router.pushUrl({ url: ROUTES.SETTINGS });
  }

  static toAppearance(): void {
    router.pushUrl({ url: ROUTES.APPEARANCE });
  }

  static back(): void {
    router.back();
  }
}
