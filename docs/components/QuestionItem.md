# QuestionItem - 测评题目组件

## 组件目的
展示单个测评题目，支持选择题作答和即时反馈。

## 组件属性

```typescript
@Component
export struct QuestionItem {
  // 传入属性
  @Prop question: Question;
  @Prop questionNumber: number;
  @Prop totalQuestions: number;

  // 内部状态
  @State selectedOption: string = '';
  @State hasSubmitted: boolean = false;
  @State isCorrect: boolean = false;

  // 事件回调
  onAnswer?: (questionId: string, answer: string, isCorrect: boolean) => void;

  build() {
    Column() {
      // 题号 + 难度
      Row() {
        Text(`Q${this.questionNumber}.`)
          .fontSize(14)
          .fontWeight(FontWeight.Bold);
        DifficultyStars({ level: this.question.difficulty });
      }
      .width('100%')

      // 题目文本
      Text(this.question.questionText)
        .fontSize(16)
        .lineHeight(24)
        .margin({ top: 8, bottom: 16 });

      // 选项列表
      ForEach(this.question.options, (option: string, index: number) => {
        OptionRow({
          label: String.fromCharCode(65 + index), // A, B, C, D
          text: option,
          isSelected: this.selectedOption === option,
          isCorrect: this.hasSubmitted && option === this.question.correctAnswer,
          isWrong: this.hasSubmitted && this.selectedOption === option && option !== this.question.correctAnswer,
          onClick: () => this.selectOption(option)
        });
      });

      // 提交按钮
      Button('提交答案')
        .enabled(this.selectedOption.length > 0 && !this.hasSubmitted)
        .onClick(() => this.submit());

      // 答案解析（提交后显示）
      if (this.hasSubmitted) {
        AnswerFeedback({
          isCorrect: this.isCorrect,
          explanation: this.question.explanation
        });
      }
    }
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(12)
  }

  selectOption(option: string): void {
    if (this.hasSubmitted) return;
    this.selectedOption = option;
  }

  submit(): void {
    this.hasSubmitted = true;
    this.isCorrect = this.selectedOption === this.question.correctAnswer;
    this.onAnswer?.(this.question.id, this.selectedOption, this.isCorrect);
  }
}
```

## 子组件

### DifficultyStars

```typescript
@Component
struct DifficultyStars {
  @Prop level: number = 1;  // 1~5

  build() {
    Row() {
      ForEach(Array(5).fill(0), (_, i: number) => {
        Image($r(i < this.level ? 'app.media.star_filled' : 'app.media.star_empty'))
          .width(12).height(12)
      });
    }
  }
}
```

### OptionRow

```typescript
@Component
struct OptionRow {
  @Prop label: string = 'A';
  @Prop text: string = '';
  @Prop isSelected: boolean = false;
  @Prop isCorrect: boolean = false;
  @Prop isWrong: boolean = false;
  onClick?: () => void;

  build() {
    Row() {
      Radio({ value: this.label })
        .checked(this.isSelected)
        .onChange(() => this.onClick?.());
      Text(`${this.label}. ${this.text}`)
        .fontSize(15)
        .margin({ left: 8 });
    }
    .padding(12)
    .borderRadius(8)
    .backgroundColor(this.getBgColor())
    .width('100%')
    .onClick(() => this.onClick?.());
  }

  getBgColor(): ResourceColor {
    if (this.isCorrect) return Color.Green + '20';   // 淡绿
    if (this.isWrong) return Color.Red + '20';       // 淡红
    if (this.isSelected) return '#E0E7FF';           // 淡蓝
    return Color.White;
  }
}
```

### AnswerFeedback

```typescript
@Component
struct AnswerFeedback {
  @Prop isCorrect: boolean = false;
  @Prop explanation: string = '';

  build() {
    Column() {
      Text(this.isCorrect ? '✅ 回答正确！' : '❌ 回答错误')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.isCorrect ? Color.Green : Color.Red);

      Text(this.explanation)
        .fontSize(14)
        .lineHeight(22)
        .margin({ top: 8 });
    }
    .padding(16)
    .backgroundColor('#F0FDF4')
    .borderRadius(12)
    .margin({ top: 16 });
  }
}
```

## 交互状态

| 状态 | UI表现 | 用户操作 |
|------|--------|---------|
| 未选 | 选项白色背景 | 点击选项 |
| 已选未提交 | 选项淡蓝高亮 | 确认/重新选择 |
| 已提交-正确 | 选项变绿+✅ | 查看解析 |
| 已提交-错误 | 正确选项绿、选错红、显示❌ | 查看解析 |


## 完整 Props / Events / States 清单

### @Prop 输入属性

| 属性名 | 类型 | 必填 | 默认值 | 说明 |
|-------|------|------|-------|------|
| question | Question | 是 | — | 题目数据 |
| questionNumber | number | 否 | 0 | 题号（从1开始） |
| totalQuestions | number | 否 | 0 | 总题数 |
| showExplanation | boolean | 否 | true | 提交后是否显示解析 |
| disabled | boolean | 否 | false | 是否禁用（如已交卷） |

### 事件回调

| 回调名 | 签名 | 说明 |
|-------|------|------|
| onAnswer | `(questionId: string, answer: string, isCorrect: boolean) => void` | 提交答案后回调 |

### 内部 @State

| 状态变量 | 类型 | 初始值 | 说明 |
|---------|------|--------|------|
| selectedOption | string | '' | 用户当前选项 |
| hasSubmitted | boolean | false | 是否已提交 |
| isCorrect | boolean | false | 提交后判断是否正确 |

### 边界情况

| 场景 | 表现 |
|------|------|
| question.options 不足2个 | 显示"题目格式错误"提示 |
| 选项为空字符串 | 过滤掉空选项 |
| 用户未选答案点提交 | 按钮 disabled |
| 提交后快速双击 | 通过 hasSubmitted 守卫 |
