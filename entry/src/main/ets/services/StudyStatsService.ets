import { Course } from '../models/Course';
import { CourseService } from './CourseService';

export interface SubjectScore {
  subject: string;
  score: number;
}

interface WeeklyStudyStore {
  weekStart: string;
  minutes: number[];
}

function getMonday(): string {
  const now = new Date();
  const day = now.getDay();
  const mon = new Date(now);
  mon.setDate(now.getDate() - (day === 0 ? 6 : day - 1));
  const y = mon.getFullYear();
  const m = (mon.getMonth() + 1).toString().padStart(2, '0');
  const d = mon.getDate().toString().padStart(2, '0');
  return y + '-' + m + '-' + d;
}

function getDayIndex(): number {
  const day = new Date().getDay();
  return day === 0 ? 6 : day - 1;
}

export class StudyStatsService {
  static startStudySession(): void {
    AppStorage.set<number>('studySessionStart', Date.now());
  }

  static endStudySession(): void {
    const start = AppStorage.get<number>('studySessionStart');
    if (!start || start <= 0) return;
    const elapsed = Math.round((Date.now() - start) / 60000);
    AppStorage.set<number>('studySessionStart', 0);
    if (elapsed < 1) return;

    const dataKey = 'studyWeeklyData';
    let raw = AppStorage.get<string>(dataKey);
    let store: WeeklyStudyStore;
    const todayMonday = getMonday();
    if (raw) {
      try { store = JSON.parse(raw) as WeeklyStudyStore; } catch { store = { weekStart: todayMonday, minutes: [0, 0, 0, 0, 0, 0, 0] }; }
    } else {
      store = { weekStart: todayMonday, minutes: [0, 0, 0, 0, 0, 0, 0] };
    }
    if (store.weekStart !== todayMonday) {
      store = { weekStart: todayMonday, minutes: [0, 0, 0, 0, 0, 0, 0] };
    }
    const idx = getDayIndex();
    store.minutes[idx] = (store.minutes[idx] || 0) + elapsed;
    AppStorage.set<string>(dataKey, JSON.stringify(store));
  }

  static getWeeklyMinutes(): number[] {
    const dataKey = 'studyWeeklyData';
    const raw = AppStorage.get<string>(dataKey);
    if (raw) {
      try {
        const store = JSON.parse(raw) as WeeklyStudyStore;
        if (store.weekStart === getMonday()) {
          return store.minutes;
        }
      } catch {}
    }
    return [];
  }

  static async getWeeklyMinutesFallback(userId: string): Promise<number[]> {
    try {
      const courses = await CourseService.getCoursesByUser(userId);
      const dayMinutes: number[] = [0, 0, 0, 0, 0, 0, 0];
      const now = new Date();
      const dayOfWeek = now.getDay();
      const monday = new Date(now);
      monday.setDate(now.getDate() - (dayOfWeek === 0 ? 6 : dayOfWeek - 1));
      monday.setHours(0, 0, 0, 0);

      for (const course of courses) {
        if (!course.lastAccessedAt) continue;
        const accessTime = new Date(course.lastAccessedAt);
        const diffDays = Math.floor((accessTime.getTime() - monday.getTime()) / 86400000);
        if (diffDays >= 0 && diffDays < 7) {
          dayMinutes[diffDays] += 30;
        }
      }
      return dayMinutes;
    } catch {
      return [];
    }
  }

  static async getSubjectScores(userId: string): Promise<SubjectScore[]> {
    try {
      const courses = await CourseService.getCoursesByUser(userId);
      const activeCourses = courses.filter(c => c.status !== 'archived');
      const domainScores: Record<string, number[]> = {};

      for (const course of activeCourses) {
        const domain = course.domain;
        if (!domain) continue;
        if (!domainScores[domain]) domainScores[domain] = [];
        const rd = course.radarData;
        if (rd) {
          const vals = [rd.remember, rd.understand, rd.apply, rd.analyze, rd.evaluate, rd.create];
          const hasData = vals.some((v: number) => v > 0);
          if (hasData) {
            const avg = Math.round(vals.reduce((a: number, b: number) => a + b, 0) / vals.length);
            domainScores[domain].push(avg);
          }
        }
      }

      const scores: SubjectScore[] = [];
      const entries = Object.entries(domainScores);
      for (const entry of entries) {
        const vals = entry[1];
        if (vals.length === 0) continue;
        const sum = vals.reduce((a: number, b: number) => a + b, 0);
        scores.push({ subject: entry[0], score: Math.round(sum / vals.length) });
      }
      scores.sort((a, b) => b.score - a.score);
      return scores;
    } catch {
      return [];
    }
  }
}
