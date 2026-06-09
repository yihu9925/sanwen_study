// 数据库管理器 - 基于 @kit.ArkData RelationalStore
import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

export class RelationalStoreManager {
  private static rdbStore: relationalStore.RdbStore | null = null;
  private static context: common.UIAbilityContext | null = null;
  private static readonly DB_NAME = 'learning_app.db';

  // 初始化数据库
  static async init(context: common.UIAbilityContext): Promise<void> {
    if (RelationalStoreManager.rdbStore) {
      return;
    }
    RelationalStoreManager.context = context;

    const config: relationalStore.StoreConfig = {
      name: RelationalStoreManager.DB_NAME,
      securityLevel: relationalStore.SecurityLevel.S1,
    };

    RelationalStoreManager.rdbStore = await relationalStore.getRdbStore(context, config);
    // 启用外键约束（确保级联删除生效）
    await RelationalStoreManager.rdbStore.executeSql('PRAGMA foreign_keys = ON');
    await RelationalStoreManager.createTables();
  }

  // 获取数据库实例
  static getStore(): relationalStore.RdbStore {
    if (!RelationalStoreManager.rdbStore) {
      throw new Error('Database not initialized. Call init() first.');
    }
    return RelationalStoreManager.rdbStore;
  }

  // 创建所有数据表
  private static async createTables(): Promise<void> {
    if (!RelationalStoreManager.rdbStore) {
      return;
    }

    // 课程表
    const SQL_CREATE_COURSE = `
      CREATE TABLE IF NOT EXISTS course (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        title TEXT NOT NULL DEFAULT '',
        domain TEXT NOT NULL DEFAULT '',
        question TEXT NOT NULL DEFAULT '',
        status TEXT NOT NULL DEFAULT 'created',
        progress_q1 INTEGER NOT NULL DEFAULT 0,
        progress_q2 INTEGER NOT NULL DEFAULT 0,
        progress_q3 INTEGER NOT NULL DEFAULT 0,
        progress_percent INTEGER NOT NULL DEFAULT 0,
        radar_data TEXT NOT NULL DEFAULT '{}',
        created_at TEXT NOT NULL DEFAULT '',
        updated_at TEXT NOT NULL DEFAULT '',
        last_accessed_at TEXT NOT NULL DEFAULT ''
      )`;

    // 知识库表
    const SQL_CREATE_KNOWLEDGEBASE = `
      CREATE TABLE IF NOT EXISTS knowledgebase (
        id TEXT PRIMARY KEY,
        course_id TEXT NOT NULL,
        knowledge_graph TEXT NOT NULL DEFAULT '[]',
        controversies TEXT NOT NULL DEFAULT '[]',
        created_at TEXT NOT NULL DEFAULT '',
        updated_at TEXT NOT NULL DEFAULT '',
        FOREIGN KEY (course_id) REFERENCES course(id) ON DELETE CASCADE
      )`;

    // 文档表
    const SQL_CREATE_DOCUMENT = `
      CREATE TABLE IF NOT EXISTS document (
        id TEXT PRIMARY KEY,
        course_id TEXT NOT NULL,
        source_type TEXT NOT NULL DEFAULT 'ai',
        title TEXT NOT NULL DEFAULT '',
        content TEXT NOT NULL DEFAULT '',
        file_path TEXT NOT NULL DEFAULT '',
        file_type TEXT NOT NULL DEFAULT '',
        keywords TEXT NOT NULL DEFAULT '[]',
        uploaded_at TEXT NOT NULL DEFAULT '',
        FOREIGN KEY (course_id) REFERENCES course(id) ON DELETE CASCADE
      )`;

    // 测评题表
    const SQL_CREATE_QUESTION = `
      CREATE TABLE IF NOT EXISTS question (
        id TEXT PRIMARY KEY,
        course_id TEXT NOT NULL,
        bloom_level INTEGER NOT NULL,
        question_text TEXT NOT NULL DEFAULT '',
        options TEXT NOT NULL DEFAULT '[]',
        correct_answer TEXT NOT NULL DEFAULT '',
        explanation TEXT NOT NULL DEFAULT '',
        difficulty INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL DEFAULT '',
        FOREIGN KEY (course_id) REFERENCES course(id) ON DELETE CASCADE
      )`;

    // 学习记录表
    const SQL_CREATE_LEARNING_RECORD = `
      CREATE TABLE IF NOT EXISTS learning_record (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        course_id TEXT NOT NULL,
        question_id TEXT NOT NULL,
        bloom_level INTEGER NOT NULL,
        user_answer TEXT NOT NULL DEFAULT '',
        is_correct INTEGER NOT NULL DEFAULT 0,
        attempt_count INTEGER NOT NULL DEFAULT 1,
        answered_at TEXT NOT NULL DEFAULT '',
        FOREIGN KEY (course_id) REFERENCES course(id) ON DELETE CASCADE,
        FOREIGN KEY (question_id) REFERENCES question(id) ON DELETE CASCADE
      )`;

    // 用户信息表
    const SQL_CREATE_USER_PROFILE = `
      CREATE TABLE IF NOT EXISTS user_profile (
        id TEXT PRIMARY KEY,
        nickname TEXT NOT NULL DEFAULT '学习者',
        avatar TEXT NOT NULL DEFAULT '',
        total_study_hours REAL NOT NULL DEFAULT 0.0,
        total_courses INTEGER NOT NULL DEFAULT 0,
        avg_accuracy REAL NOT NULL DEFAULT 0.0,
        created_at TEXT NOT NULL DEFAULT '',
        updated_at TEXT NOT NULL DEFAULT ''
      )`;

    // 执行建表语句
    await RelationalStoreManager.rdbStore.executeSql(SQL_CREATE_COURSE);
    await RelationalStoreManager.rdbStore.executeSql(SQL_CREATE_KNOWLEDGEBASE);
    await RelationalStoreManager.rdbStore.executeSql(SQL_CREATE_DOCUMENT);
    await RelationalStoreManager.rdbStore.executeSql(SQL_CREATE_QUESTION);
    await RelationalStoreManager.rdbStore.executeSql(SQL_CREATE_LEARNING_RECORD);
    await RelationalStoreManager.rdbStore.executeSql(SQL_CREATE_USER_PROFILE);
    
    // 数据库迁移：为旧表添加新列（如果已存在则静默跳过）
    const migrations: string[] = [
      'ALTER TABLE question ADD COLUMN question_type TEXT NOT NULL DEFAULT \'open\'',
      'ALTER TABLE learning_record ADD COLUMN user_answer_text TEXT NOT NULL DEFAULT \'\'',
      'ALTER TABLE learning_record ADD COLUMN ai_evaluation TEXT NOT NULL DEFAULT \'\'',
      'ALTER TABLE learning_record ADD COLUMN score INTEGER NOT NULL DEFAULT 0',
    ];
    for (const migrationSql of migrations) {
      try {
        await RelationalStoreManager.rdbStore.executeSql(migrationSql);
      } catch (e) {
        // 列已存在或其他错误，静默跳过
        console.info('Migration skip (column may already exist): ' + migrationSql);
      }
    }
    
    // 创建索引
    await RelationalStoreManager.rdbStore.executeSql('CREATE INDEX IF NOT EXISTS idx_course_user ON course(user_id)');
    await RelationalStoreManager.rdbStore.executeSql('CREATE INDEX IF NOT EXISTS idx_course_status ON course(status)');
    await RelationalStoreManager.rdbStore.executeSql('CREATE INDEX IF NOT EXISTS idx_kb_course ON knowledgebase(course_id)');
    await RelationalStoreManager.rdbStore.executeSql('CREATE INDEX IF NOT EXISTS idx_doc_course ON document(course_id)');
    await RelationalStoreManager.rdbStore.executeSql('CREATE INDEX IF NOT EXISTS idx_question_course ON question(course_id)');
    await RelationalStoreManager.rdbStore.executeSql('CREATE INDEX IF NOT EXISTS idx_question_level ON question(bloom_level)');
    await RelationalStoreManager.rdbStore.executeSql('CREATE INDEX IF NOT EXISTS idx_lr_user ON learning_record(user_id)');
    await RelationalStoreManager.rdbStore.executeSql('CREATE INDEX IF NOT EXISTS idx_lr_course ON learning_record(course_id)');
  }

  // 关闭数据库
  static async close(): Promise<void> {
    if (RelationalStoreManager.rdbStore && RelationalStoreManager.context) {
      await relationalStore.deleteRdbStore(RelationalStoreManager.context, RelationalStoreManager.DB_NAME);
      RelationalStoreManager.rdbStore = null;
      RelationalStoreManager.context = null;
    }
  }
}
