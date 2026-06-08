// 路由配置
import { router } from '@kit.ArkUI';

interface RouteConfig {
  HOME: string;
  COURSE_DETAIL: string;
  ASSESSMENT_DETAIL: string;
  ARCHIVE: string;
  SETTINGS: string;
  DISCUSSION: string;
}

export const ROUTES: RouteConfig = {
  HOME: 'pages/HomePage',
  COURSE_DETAIL: 'pages/CourseDetailPage',
  ASSESSMENT_DETAIL: 'pages/AssessmentDetailPage',
  ARCHIVE: 'pages/ArchiveManagementPage',
  SETTINGS: 'pages/SettingsPage',
  DISCUSSION: 'pages/DiscussionHub',
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

  static toArchive(): void {
    router.pushUrl({ url: ROUTES.ARCHIVE });
  }

  static toSettings(): void {
    router.pushUrl({ url: ROUTES.SETTINGS });
  }

  static toDiscussion(): void {
    router.pushUrl({ url: ROUTES.DISCUSSION });
  }

  static back(): void {
    router.back();
  }
}
