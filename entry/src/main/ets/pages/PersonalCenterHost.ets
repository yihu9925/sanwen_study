import { PersonalCenter } from './PersonalCenter';

// 宿主容器：key 变化时强制重建 PersonalCenter（key 由 Index.ts 的 @State 驱动）
@Component
export struct PersonalCenterHost {
  build() {
    PersonalCenter();
  }
}
