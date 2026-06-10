import { KnowledgeHub } from './KnowledgeHub';

// 宿主容器：key 变化时强制重建 KnowledgeHub（key 由 Index.ts 的 @State 驱动）
@Component
export struct KnowledgeHubHost {
  build() {
    KnowledgeHub();
  }
}
