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

// 创建默认用户
export function createDefaultUserProfile(id: string): UserProfile {
  return {
    id: id,
    nickname: '学习者',
    avatar: '',
    totalStudyHours: 0,
    totalCourses: 0,
    avgAccuracy: 0,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString()
  };
}
