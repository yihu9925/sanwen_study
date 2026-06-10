import { relationalStore } from '@kit.ArkData';
import { UserProfile } from '../models/UserProfile';
import { RelationalStoreManager } from './RelationalStoreManager';

export class UserProfileService {
  static async getProfile(userId: string): Promise<UserProfile | null> {
    const store = RelationalStoreManager.getStore();
    const sql: string = 'SELECT id, nickname, avatar, total_study_hours, total_courses, avg_accuracy, created_at, updated_at FROM user_profile WHERE id = ?';
    const resultSet = await store.querySql(sql, [userId]);
    if (resultSet.goToNextRow()) {
      const profile: UserProfile = {
        id: resultSet.getString(0),
        nickname: resultSet.getString(1) || '\u5B66\u4E60\u8005',
        avatar: resultSet.getString(2) || '',
        totalStudyHours: resultSet.getDouble(3),
        totalCourses: resultSet.getDouble(4),
        avgAccuracy: resultSet.getDouble(5),
        createdAt: resultSet.getString(6) || '',
        updatedAt: resultSet.getString(7) || ''
      };
      resultSet.close();
      return profile;
    }
    resultSet.close();
    return null;
  }

  static async initProfile(userId: string): Promise<void> {
    const store = RelationalStoreManager.getStore();
    const now: string = new Date().toISOString();
    await store.insert('user_profile', {
      id: userId,
      nickname: '\u5B66\u4E60\u8005',
      avatar: '',
      total_study_hours: 0,
      total_courses: 0,
      avg_accuracy: 0,
      created_at: now,
      updated_at: now
    });
  }

  static async updateNickname(userId: string, nickname: string): Promise<void> {
    const store = RelationalStoreManager.getStore();
    const now: string = new Date().toISOString();
    const predicates = new relationalStore.RdbPredicates('user_profile');
    predicates.equalTo('id', userId);
    await store.update({ nickname, updated_at: now }, predicates);
  }

  static async updateAvatar(userId: string, avatar: string): Promise<void> {
    const store = RelationalStoreManager.getStore();
    const now: string = new Date().toISOString();
    const predicates = new relationalStore.RdbPredicates('user_profile');
    predicates.equalTo('id', userId);
    await store.update({ avatar, updated_at: now }, predicates);
  }
}
