// 用户信息数据模型
export interface UserProfile {
  id: string;
  nickname: string;
  avatar: string;
  totalStudyHours: number;
  totalCourses: number;
  avgAccuracy: number;
  createdAt: string;
  updatedAt: string;
}
