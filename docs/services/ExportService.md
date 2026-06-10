# ExportService — 数据导出服务

## 文件
`entry/src/main/ets/services/ExportService.ets`

## 职责
将测评报告导出为 JSON 或 Markdown 格式，支持在 SettingsPage 中调用。

## 核心方法

| 方法 | 说明 | 异步 |
|-----|------|------|
| `exportReportAsJSON(courseId, courseTitle)` | 导出测评报告为 JSON 字符串 | 是 |
| `exportReportAsMarkdown(courseId, courseTitle)` | 导出测评报告为 Markdown 字符串 | 是 |

## JSON 导出格式

```json
{
  "courseTitle": "课程名称",
  "courseId": "uuid",
  "exportedAt": "2026-06-10T12:00:00.000Z",
  "totalQuestions": 12,
  "answeredQuestions": 10,
  "details": [
    {
      "question": "题目内容",
      "bloomLevel": 3,
      "userAnswer": "用户回答原文",
      "aiEvaluation": "LLM评语内容",
      "score": 85,
      "isCorrect": true,
      "answeredAt": "2026-06-10T12:00:00.000Z"
    }
  ]
}
```

## Markdown 导出格式

```
# 评估报告

**课程**：课程名称
**导出时间**：2026/6/10 ...

## 概览
- 总题数：12
- 已答：10
- 未答：2

## 得分概览
| 题号 | 布鲁姆层级 | 得分 | 正确否 |
|------|-----------|------|--------|
| 1 | 记忆 | 85 | v |
| 2 | 理解 | 90 | v |

**平均分**：87/100

## 对话原始记录
### 题目 1
**题目**：...
**你的回答**：
...
**AI评语**：
- 得分：85/100
- 评语：...
```

## 数据来源
- `AssessmentService.getQuestions(courseId)` — 获取题目列表
- `AssessmentService.getLearningRecords(courseId)` — 获取答题记录（含用户回答和AI评语）
