# ContentUtils — 文档内容解析工具

## 文件
`entry/src/main/ets/utils/ContentUtils.ets`

## 职责
解析文档内容为文本/代码块分段，支持两种模式：

1. **[CODE] 标记模式**：LLM 生成的文档中显式标记 `[CODE]...[/CODE]`
2. **启发式检测模式**：无标记时自动识别代码行

## 数据结构

```typescript
export interface ContentSegment {
  type: 'text' | 'code';
  content: string;
}
```

## 核心函数

| 函数 | 说明 |
|-----|------|
| `parseContentSegments(text)` | 解析文档内容为 ContentSegment 数组（主入口） |

## 解析流程

```
parseContentSegments(text):
  1. 查找 [CODE] 标记
  2. 有标记 -> 按标记分割（标记内的为 code，外的进入启发式检测）
  3. 无标记 -> 全部进入启发式检测
  4. 启发式检测: 按行判断
     -> 缩进行（2空格/tab开头）-> code
     -> 关键字开头（def/class/import/return/if/for/function/var/let/...）-> code
     -> 含特殊符号且行短（[{()}();=]）-> code
     -> 函数调用格式（xxx()）-> code
     -> 其余 -> text（trim后）
  5. 返回 ContentSegment[]
```

## 使用场景

```typescript
// DocSheet 弹窗和 CourseDetailPage 资料库Tab中
import { parseContentSegments, ContentSegment } from '../utils/ContentUtils';

const segments: ContentSegment[] = parseContentSegments(doc.content);
// 在 UI 中遍历渲染
ForEach(segments, (seg: ContentSegment) => {
  if (seg.type === 'code') {
    Text(seg.content).fontFamily('Courier New').backgroundColor('#F5F5F5');
  } else {
    Text(seg.content).textIndent(32);
  }
})
```
