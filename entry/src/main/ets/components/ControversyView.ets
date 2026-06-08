// 争议点展示组件
import { Controversy } from '../models/Controversy';

@Component
export struct ControversyView {
  @Prop controversies: Controversy[] = [];
  @State selectedIndex: number = 0;

  build() {
    Column() {
      // 标题
      Row() {
        Text('争议点分析')
          .fontSize(18)
          .fontWeight(FontWeight.Bold);
        
        Text(`共${this.controversies.length}个争议点`)
          .fontSize(12)
          .fontColor('#999999')
          .margin({ left: 8 });
      }
      .width('100%')
      .padding(16);

      if (this.controversies.length === 0) {
        // 空状态
        Column() {
          Text('⚖️')
            .fontSize(48);

          Text('暂无争议点')
            .fontSize(14)
            .fontColor('#999999')
            .margin({ top: 12 });

          Text('点击"挖掘争议点"开始分析')
            .fontSize(12)
            .fontColor('#CCCCCC')
            .margin({ top: 8 });
        }
        .width('100%')
        .height(200)
        .justifyContent(FlexAlign.Center);
      } else {
        // 争议点列表
        Tabs() {
          ForEach(this.controversies, (controversy: Controversy, index: number) => {
            TabContent() {
              this.ControversyDetail(controversy);
            }
            .tabBar(`争议${index + 1}`);
          });
        }
        .width('100%')
        .height(400)
        .barMode(BarMode.Scrollable);
      }
    }
    .width('100%')
    .backgroundColor(Color.White)
    .borderRadius(12);
  }

  @Builder
  ControversyDetail(controversy: Controversy): void {
    Column() {
      // 争议标题
      Text(controversy.title)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .width('100%')
        .padding(16);

      // 正方观点
      Column() {
        Row() {
          Text('✅ 正方观点')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#52C41A');
        }
        .width('100%');

        Text(controversy.proViewpoint)
          .fontSize(14)
          .fontColor('#666666')
          .margin({ top: 8 });

        // 正方证据
        if (controversy.proEvidence && controversy.proEvidence.length > 0) {
          Column() {
            ForEach(controversy.proEvidence, (evidence: Record<string, string>) => {
              Row() {
                Text('•')
                  .fontSize(12)
                  .margin({ right: 4 });
                Text(evidence['title'] || evidence['content'] || '')
                  .fontSize(12)
                  .fontColor('#666666');
              }
              .width('100%')
              .margin({ top: 4 });
            });
          }
          .width('100%')
          .margin({ top: 8 });
        }
      }
      .width('100%')
      .padding(12)
      .backgroundColor('#F6FFED')
      .borderRadius(8)
      .margin({ top: 8, left: 16, right: 16 });

      // 反方观点
      Column() {
        Row() {
          Text('❌ 反方观点')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#F5222D');
        }
        .width('100%');

        Text(controversy.conViewpoint)
          .fontSize(14)
          .fontColor('#666666')
          .margin({ top: 8 });

        // 反方证据
        if (controversy.conEvidence && controversy.conEvidence.length > 0) {
          Column() {
            ForEach(controversy.conEvidence, (evidence: Record<string, string>) => {
              Row() {
                Text('•')
                  .fontSize(12)
                  .margin({ right: 4 });
                Text(evidence['title'] || evidence['content'] || '')
                  .fontSize(12)
                  .fontColor('#666666');
              }
              .width('100%')
              .margin({ top: 4 });
            });
          }
          .width('100%')
          .margin({ top: 8 });
        }
      }
      .width('100%')
      .padding(12)
      .backgroundColor('#FFF1F0')
      .borderRadius(8)
      .margin({ top: 12, left: 16, right: 16 });

      // AI总结
      if (controversy.aiSummary && controversy.aiSummary.length > 0) {
        Column() {
          Row() {
            Text('🤖 AI总结')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor('#007DFF');
          }
          .width('100%');

          Text(controversy.aiSummary)
            .fontSize(14)
            .fontColor('#666666')
            .margin({ top: 8 });
        }
        .width('100%')
        .padding(12)
        .backgroundColor('#E6F7FF')
        .borderRadius(8)
        .margin({ top: 12, left: 16, right: 16 });
      } else {
        Column() {
          Row() {
            Text('生成AI总结中...')
              .fontSize(14)
              .fontColor('#999999');
          }
          .width('100%');
        }
        .width('100%')
        .padding(12)
        .backgroundColor('#F5F5F5')
        .borderRadius(8)
        .margin({ top: 12, left: 16, right: 16 });
      }
    }
    .width('100%')
    .layoutWeight(1);
  }
}
