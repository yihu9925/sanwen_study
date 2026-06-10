// 知识图谱数据模型
export interface GraphNode {
  id: string;
  label: string;
  x: number;
  y: number;
  radius: number;
  importance: number;       // 1~5 重要程度
  children: GraphNode[];
  description: string;
  relatedDocs: string[];    // document IDs
}

export interface GraphEdge {
  from: string;
  to: string;
  label: string;            // 关系类型: "包含" | "依赖于" | "对立" 等
}

export interface KnowledgeGraph {
  nodes: GraphNode[];
  edges: GraphEdge[];
}

