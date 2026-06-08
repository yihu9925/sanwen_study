# RelationalStoreManager - 数据库管理服务

> ⚠ API 20：使用 `@kit.ArkData` 导入，严格类型

## 导入方式

```typescript
import { relationalStore, RdbStore, ValuesBucket, RdbPredicates, ResultSet } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
```

## 完整实现

```typescript
import { relationalStore, RdbStore, ValuesBucket, RdbPredicates, ResultSet } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

export class RelationalStoreManager {
  private static rdbStore: RdbStore;

  static async init(context: common.UIAbilityContext): Promise<void> {
    this.rdbStore = await relationalStore.getRdbStore(context, {
      name: 'learning_app.db',
      securityLevel: relationalStore.SecurityLevel.S1,
    });
    await this.createTables();
  }

  private static async createTables(): Promise<void> {
    const SQL_CREATE_COURSE = \`
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
      )\`;
    await this.rdbStore.executeSql(SQL_CREATE_COURSE);

    const SQL_CREATE_KNOWLEDGEBASE = \`
      CREATE TABLE IF NOT EXISTS knowledgebase (
        id TEXT PRIMARY KEY,
        course_id TEXT NOT NULL,
        knowledge_graph TEXT NOT NULL DEFAULT '[]',
        controversies TEXT NOT NULL DEFAULT '[]',
        created_at TEXT NOT NULL DEFAULT '',
        updated_at TEXT NOT NULL DEFAULT '',
        FOREIGN KEY (course_id) REFERENCES course(id) ON DELETE CASCADE
      )\`;
    await this.rdbStore.executeSql(SQL_CREATE_KNOWLEDGEBASE);

    // ... 其余建表语句同02_数据库设计.md
  }

  // 通用CRUD操作（严格类型版本）
  static async insert(table: string, data: Record<string, string | number | boolean>): Promise<number> {
    const bucket: ValuesBucket = data as ValuesBucket;
    return await this.rdbStore.insert(table, bucket);
  }

  static async query(table: string, field?: string, value?: string | number): Promise<Record<string, string | number | boolean>[]> {
    const predicates = new RdbPredicates(table);
    if (field !== undefined && value !== undefined) {
      predicates.equalTo(field, value);
    }
    const resultSet = await this.rdbStore.query(predicates);
    return this.parseResultSet(resultSet);
  }

  static async update(
    table: string,
    data: Record<string, string | number | boolean>,
    field: string,
    value: string | number
  ): Promise<number> {
    const bucket: ValuesBucket = data as ValuesBucket;
    const predicates = new RdbPredicates(table);
    predicates.equalTo(field, value);
    return await this.rdbStore.update(bucket, predicates);
  }

  static async delete(table: string, field: string, value: string | number): Promise<number> {
    const predicates = new RdbPredicates(table);
    predicates.equalTo(field, value);
    return await this.rdbStore.delete(predicates);
  }

  private static parseResultSet(rs: ResultSet): Record<string, string | number | boolean>[] {
    const results: Record<string, string | number | boolean>[] = [];
    while (rs.goToNextRow()) {
      const row: Record<string, string | number | boolean> = {};
      for (let i = 0; i < rs.columnCount; i++) {
        const colName = rs.getColumnName(i);
        const colType = rs.getColumnType(i);
        switch (colType) {
          case relationalStore.ColumnType.COLUMN_TYPE_STRING:
            row[colName] = rs.getString(i);
            break;
          case relationalStore.ColumnType.COLUMN_TYPE_INTEGER:
            row[colName] = rs.getLong(i);
            break;
          case relationalStore.ColumnType.COLUMN_TYPE_FLOAT:
            row[colName] = rs.getDouble(i);
            break;
          default:
            row[colName] = rs.getString(i);
        }
      }
      results.push(row);
    }
    rs.close();
    return results;
  }

  static async executeSql(sql: string): Promise<void> {
    await this.rdbStore.executeSql(sql);
  }
}
```

## 错误处理

```typescript
// 封装错误处理
export async function safeDbOperation<T>(
  operation: () => Promise<T>,
  fallback: T
): Promise<T> {
  try {
    return await operation();
  } catch (error) {
    console.error('Database operation failed:', error);
    return fallback;
  }
}

// 使用示例
const courses = await safeDbOperation(
  () => RelationalStoreManager.query('course', 'user_id', userId),
  []  // 失败时返回空数组
);
```


## 数据流

```
其他Service → RelationalStoreManager.insert/query/update/delete
  └→ @kit.ArkData relationalStore.RdbStore
    └→ SQLite 数据库文件 (learning_app.db)

事务示例:
const promise = this.rdbStore.beginTransaction();
try {
  await this.insert('course', ...);
  await this.insert('knowledgebase', ...);
  await this.rdbStore.commit();
} catch (e) {
  await this.rdbStore.rollback();
}
```
