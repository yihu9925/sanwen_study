// 课程数据模型
export interface RadarData {
  remember: number;      // 记忆 0~100
  understand: number;    // 理解 0~100
  apply: number;         // 应用 0~100
  analyze: number;       // 分析 0~100
  evaluate: number;      // 评价 0~100
  create: number;        // 创造 0~100
}

export type CourseStatus = 'created' | 'active' | 'completed' | 'archived';

export interface Course {
  id: string;
  userId: string;
  title: string;
  domain: string;
  question: string;
  status: CourseStatus;
  progressQ1: number;      // 第一问进度 0/1
  progressQ2: number;      // 第二问进度 0/1
  progressQ3: number;      // 第三问进度 0/1
  progressPercent: number; // 综合进度 0~100
  radarData: RadarData;
  createdAt: string;
  updatedAt: string;
  lastAccessedAt: string;
}

// 默认雷达数据
export function getDefaultRadarData(): RadarData {
  return {
    remember: 0,
    understand: 0,
    apply: 0,
    analyze: 0,
    evaluate: 0,
    create: 0
  };
}
