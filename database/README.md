# 数据库部署说明

## 文件说明

- `schema.sql` — 完整建表DDL（5张表：course, knowledgebase, document, question, learning_record, user_profile）
- `seed.sql` — 示例种子数据（演示/测试用）

## 初始化方式

应用启动时 `EntryAbility.ets` 中通过 `RelationalStoreManager.init()` 调用 `executeSql` 建表，
建表逻辑对应 `schema.sql` 中的DDL语句。

## 导出数据库

```bash
# 通过hdc连接模拟器/真机
hdc shell
cp /data/app/el2/100/database/com.example.learning_app/entry/rdb/learning_app.db /sdcard/
exit
hdc file recv /sdcard/learning_app.db ./database/
```

## 数据库设计要点

1. `learning_record` 表是**自由答题模式**的核心：
   - `user_answer_text` — 用户自由输入的答案（对话原始记录）
   - `ai_evaluation` — LLM评判结果JSON
   - `score` — 0-100评分
2. `question` 表的 `question_type` 字段区分选择题/开放题
3. 所有JSON字段使用 `TEXT` 类型存储
