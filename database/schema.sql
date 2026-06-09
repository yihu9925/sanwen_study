-- ============================================
-- 三问高效学习机 — 数据库建表脚本
-- 数据库: learning_app.db (SQLite / RelationalStore)
-- 说明: 使用 @kit.ArkData relationalStore API
-- ============================================

-- 课程表
CREATE TABLE IF NOT EXISTS course (
  id              TEXT PRIMARY KEY,          -- UUID
  user_id         TEXT NOT NULL,              -- 用户ID
  title           TEXT NOT NULL DEFAULT '',
  domain          TEXT NOT NULL DEFAULT '',   -- 学科领域
  question        TEXT NOT NULL DEFAULT '',   -- 原始提问
  status          TEXT NOT NULL DEFAULT 'created',  -- created/active/completed/archived
  progress_q1     INTEGER NOT NULL DEFAULT 0, -- 第一问进度 0/1
  progress_q2     INTEGER NOT NULL DEFAULT 0, -- 第二问进度 0/1
  progress_q3     INTEGER NOT NULL DEFAULT 0, -- 第三问进度 0/1
  progress_percent INTEGER NOT NULL DEFAULT 0, -- 综合进度 0~100
  radar_data      TEXT NOT NULL DEFAULT '{}',  -- JSON: 6维能力评分
  created_at      TEXT NOT NULL DEFAULT '',
  updated_at      TEXT NOT NULL DEFAULT '',
  last_accessed_at TEXT NOT NULL DEFAULT ''
);

CREATE INDEX IF NOT EXISTS idx_course_user ON course(user_id);
CREATE INDEX IF NOT EXISTS idx_course_status ON course(status);

-- 知识库表
CREATE TABLE IF NOT EXISTS knowledgebase (
  id                TEXT PRIMARY KEY,
  course_id         TEXT NOT NULL,
  knowledge_graph   TEXT NOT NULL DEFAULT '[]',    -- JSON: 知识图谱节点数组
  controversies     TEXT NOT NULL DEFAULT '[]',     -- JSON: 争议点数组
  created_at        TEXT NOT NULL DEFAULT '',
  updated_at        TEXT NOT NULL DEFAULT '',
  FOREIGN KEY (course_id) REFERENCES course(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_kb_course ON knowledgebase(course_id);

-- 文档表（用户上传 + AI爬取资料）
CREATE TABLE IF NOT EXISTS document (
  id            TEXT PRIMARY KEY,
  course_id     TEXT NOT NULL,
  source_type   TEXT NOT NULL DEFAULT 'ai',        -- 'ai' | 'user' | 'reference'
  title         TEXT NOT NULL DEFAULT '',
  content       TEXT NOT NULL DEFAULT '',
  file_path     TEXT NOT NULL DEFAULT '',
  file_type     TEXT NOT NULL DEFAULT '',           -- 'pdf' | 'md' | 'txt' | 'docx'
  keywords      TEXT NOT NULL DEFAULT '[]',         -- JSON: 关键词数组
  uploaded_at   TEXT NOT NULL DEFAULT '',
  FOREIGN KEY (course_id) REFERENCES course(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_doc_course ON document(course_id);

-- 测评题目表
CREATE TABLE IF NOT EXISTS question (
  id              TEXT PRIMARY KEY,
  course_id       TEXT NOT NULL,
  bloom_level     INTEGER NOT NULL,    -- 1=记忆 2=理解 3=应用 4=分析 5=评价 6=创造
  question_text   TEXT NOT NULL DEFAULT '',
  options         TEXT NOT NULL DEFAULT '[]',    -- JSON: 选项数组（选择题模式用）
  correct_answer  TEXT NOT NULL DEFAULT '',      -- 参考答案（供LLM评判参考）
  explanation     TEXT NOT NULL DEFAULT '',      -- 题目解析/知识点提示
  difficulty      INTEGER NOT NULL DEFAULT 1,    -- 1~5 难度等级
  question_type   TEXT NOT NULL DEFAULT 'open',  -- 'choice' 选择题 | 'open' 开放题（默认）
  created_at      TEXT NOT NULL DEFAULT '',
  FOREIGN KEY (course_id) REFERENCES course(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_q_course ON question(course_id);
CREATE INDEX IF NOT EXISTS idx_q_bloom ON question(bloom_level);

-- 学习记录表（自由答题模式核心）
CREATE TABLE IF NOT EXISTS learning_record (
  id                TEXT PRIMARY KEY,
  user_id           TEXT NOT NULL,
  course_id         TEXT NOT NULL,
  question_id       TEXT NOT NULL,
  bloom_level       INTEGER NOT NULL,
  user_answer       TEXT NOT NULL DEFAULT '',    -- 选择题答案（兼容旧模式）
  user_answer_text  TEXT NOT NULL DEFAULT '',    -- 自由答题文本（新模式，核心字段）
  ai_evaluation     TEXT NOT NULL DEFAULT '',    -- LLM评语（JSON: {score, comment, strengths, weaknesses}）
  is_correct        INTEGER NOT NULL DEFAULT 0, -- 0=错误 1=正确（score>=60为1）
  score             INTEGER NOT NULL DEFAULT 0, -- LLM评分 0-100
  attempt_count     INTEGER NOT NULL DEFAULT 1,
  answered_at       TEXT NOT NULL DEFAULT '',
  FOREIGN KEY (course_id) REFERENCES course(id) ON DELETE CASCADE,
  FOREIGN KEY (question_id) REFERENCES question(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_lr_course ON learning_record(course_id);
CREATE INDEX IF NOT EXISTS idx_lr_user ON learning_record(user_id);

-- 用户信息表
CREATE TABLE IF NOT EXISTS user_profile (
  id                  TEXT PRIMARY KEY,
  nickname            TEXT NOT NULL DEFAULT '学习者',
  avatar              TEXT NOT NULL DEFAULT '',
  total_study_hours   REAL NOT NULL DEFAULT 0.0,
  total_courses       INTEGER NOT NULL DEFAULT 0,
  avg_accuracy        REAL NOT NULL DEFAULT 0.0,
  created_at          TEXT NOT NULL DEFAULT '',
  updated_at          TEXT NOT NULL DEFAULT ''
);
