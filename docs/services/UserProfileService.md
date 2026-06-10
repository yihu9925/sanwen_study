# UserProfileService — 用户信息服务

## 文件
`entry/src/main/ets/services/UserProfileService.ets`

## 职责
管理用户基本信息的 CRUD 操作，基于 `user_profile` 数据表。

## 核心方法

| 方法 | 说明 | 异步 |
|-----|------|------|
| `getProfile(userId)` | 获取用户信息，返回 UserProfile 或 null | 是 |
| `initProfile(userId)` | 初始化新用户信息（默认昵称"学习者"） | 是 |
| `updateNickname(userId, nickname)` | 更新昵称 | 是 |
| `updateAvatar(userId, avatar)` | 更新头像 | 是 |

## 数据结构

```typescript
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
```
