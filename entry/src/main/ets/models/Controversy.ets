// 争议点数据模型
export interface Evidence {
  title: string;
  content: string;
  source: string;
}

export interface Controversy {
  id: string;
  title: string;
  proViewpoint: string;      // 正方观点
  proEvidence: Evidence[];   // 正方证据
  conViewpoint: string;      // 反方观点
  conEvidence: Evidence[];   // 反方证据
  aiSummary: string;         // AI总结
}

