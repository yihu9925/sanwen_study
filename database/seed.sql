-- ============================================
-- 三问高效学习机 — 种子数据（示例）
-- 仅用于演示/测试目的
-- ============================================

-- 示例用户
INSERT INTO user_profile (id, nickname, total_study_hours, total_courses, avg_accuracy, created_at, updated_at)
VALUES ('demo_user', '演示学习者', 12.5, 3, 72.0, datetime('now'), datetime('now'));

-- 示例课程：微积分基础
INSERT INTO course (id, user_id, title, domain, question, status, progress_q1, progress_q2, progress_q3, progress_percent, radar_data, created_at, updated_at, last_accessed_at)
VALUES (
  'demo_course_1', 'demo_user', '什么是微积分？', '数学',
  '什么是微积分？它的核心思想是什么？',
  'active', 1, 0, 0, 33,
  '{"remember": 80, "understand": 65, "apply": 30, "analyze": 20, "evaluate": 10, "create": 5}',
  datetime('now'), datetime('now'), datetime('now')
);

-- 示例课程知识库
INSERT INTO knowledgebase (id, course_id, knowledge_graph, controversies, created_at, updated_at)
VALUES (
  'demo_kb_1', 'demo_course_1',
  '[{"id":"node1","label":"微积分","x":200,"y":200,"radius":40,"importance":5,"children":[{"id":"node2","label":"微分","x":120,"y":80,"radius":30,"importance":4,"children":[],"description":"研究变化率的数学分支","relatedDocs":[]},{"id":"node3","label":"积分","x":280,"y":80,"radius":30,"importance":4,"children":[],"description":"研究累积量的数学分支","relatedDocs":[]},{"id":"node4","label":"极限","x":200,"y":320,"radius":25,"importance":3,"children":[],"description":"微积分的基石概念","relatedDocs":[]}],"description":"研究连续变化的数学分支","relatedDocs":[]}]',
  '[{"id":"cont1","title":"无穷小量的合法性","proViewpoint":"无穷小量是合理的数学工具","proEvidence":[{"title":"非标准分析","content":"鲁滨逊建立的非标准分析为无穷小提供了严格的逻辑基础","source":"A. Robinson"}],"conViewpoint":"无穷小量缺乏严格的数学基础","conEvidence":[{"title":"标准分析","content":"Weierstrass的ε-δ语言才是严格的极限理论","source":"Weierstrass"}],"aiSummary":"历史上关于无穷小量的争论最终由非标准分析和标准分析两种路径解决"}]',
  datetime('now'), datetime('now')
);

-- 示例开放题
INSERT INTO question (id, course_id, bloom_level, question_text, correct_answer, explanation, difficulty, question_type, created_at)
VALUES
('demo_q1', 'demo_course_1', 1, '什么是微积分基本定理？请用自己的话简要描述。', '微积分基本定理建立了微分和积分之间的逆运算关系，表明定积分可以通过原函数在区间端点处的差值来计算。', '考察对微积分核心定理的基本理解', 2, 'open', datetime('now')),
('demo_q2', 'demo_course_1', 2, '请解释为什么导数可以用来求函数的极值？', '当导数为零时函数在该点可能取极值，因为导数表示函数的变化率，极值点处变化率为零。', '考察对导数几何意义的理解', 3, 'open', datetime('now')),
('demo_q3', 'demo_course_1', 3, '请用微积分解决：一个半径为r的球的体积公式是如何推导出来的？', '使用旋转体体积公式或三重积分可以推导出球体体积公式V=4/3πr³。', '考察微积分的实际应用能力', 4, 'open', datetime('now'));
