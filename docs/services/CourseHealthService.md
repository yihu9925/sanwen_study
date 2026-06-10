# CourseHealthService — 课程内容健康检测

## 文件
`entry/src/main/ets/services/CourseHealthService.ets`

## 职责
检测课程三问（Q1知识图谱、Q2争议点、Q3测评题）是否已生成完整，并计算综合进度百分比。

## 数据结构

```typescript
export interface CourseContentStatus {
  courseId: string;
  q1KnowledgeGraph: boolean;    // 知识图谱是否已生成（非mock数据）
  q2Controversies: boolean;     // 争议点是否已生成
  q3Questions: boolean;         // 测评题是否已生成
  allComplete: boolean;         // 全部完成
  missingParts: string[];       // 缺失的部分名称（中文）
  progressPercent: number;      // 综合进度 0-100
}
```

## 核心方法

| 方法 | 说明 | 异步 |
|-----|------|------|
| `checkCourseStatus(courseId)` | 检测单个课程的内容完成状态 | 是 |

## 检测逻辑

### Q1 知识图谱
- 从 knowledgebase 表查询 courseId 对应的 json_graph 字段
- JSON 解析后检查 nodes 数组长度 > 0
- 过滤 mock 数据：如果节点 label 含"核心概念"则视为未完成

### Q2 争议点
- 从 knowledgebase 表查询 json_controversies 字段
- JSON 解析后检查数组长度 > 0

### Q3 测评题
- 从 question 表按 courseId 查询，检查行数 > 0

## 使用场景

```typescript
// CourseDetailPage 页面加载时
aboutToAppear(): void {
  this.loadCourseData();
}

async loadCourseData(): Promise<void> {
  // ... 加载课程数据 ...
  this.contentStatus = await CourseHealthService.checkCourseStatus(this.courseId);
  // 根据 contentStatus.missingParts 展示补全按钮
  // 根据 contentStatus.progressPercent 更新进度条
}
```
