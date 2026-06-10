// 个人中心页
import { promptAction } from '@kit.ArkUI';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { UserProfileService } from '../services/UserProfileService';
import { CourseService } from '../services/CourseService';
import { AppRouter } from '../AppRouter';
import { UiStyle, StyleColors } from '../utils/UiStyle';

@Component
export struct PersonalCenter {
  @State nickname: string = '\u5B66\u4E60\u8005';
  @State avatarUri: string = '';
  @State avatarVersion: number = 0;
  @State isEditingName: boolean = false;
  @State editNameValue: string = '';
  @StorageLink('themeMode') themeMode: string = 'auto';
  @StorageLink('uiStyle') uiStyle: string = 'default';
  @StorageLink('statTotal') statTotal: number = 0;
  @StorageLink('statCompleted') statCompleted: number = 0;
  @StorageLink('statArchived') statArchived: number = 0;

  private userId: string = 'default_user';

  aboutToAppear(): void {
    this.loadProfile();
    CourseService.refreshStatsInStorage(this.userId);
  }

  async loadProfile(): Promise<void> {
    try {
      let profile = await UserProfileService.getProfile(this.userId);
      if (!profile) {
        await UserProfileService.initProfile(this.userId);
        profile = await UserProfileService.getProfile(this.userId);
      }
      if (profile) {
        this.nickname = profile.nickname;
        if (profile.avatar && profile.avatar.length > 0) {
          this.avatarVersion++;
          this.avatarUri = profile.avatar;
        }
      }
    } catch (e) {
      //
    }
  }

  async onAvatarLongPress(): Promise<void> {
    try {
      const photoViewPicker = photoAccessHelper.PhotoViewPicker;
      const picker = new photoViewPicker();
      const result: photoAccessHelper.PhotoSelectResult = await picker.select();
      if (result.photoUris.length > 0) {
        this.avatarVersion++;
        this.avatarUri = result.photoUris[0];
        await UserProfileService.updateAvatar(this.userId, this.avatarUri);
      }
    } catch (e) {
      promptAction.showToast({ message: '\u9009\u62E9\u5931\u8D25: ' + JSON.stringify(e) });
    }
  }

  onNameLongPress(): void {
    this.editNameValue = this.nickname;
    this.isEditingName = true;
  }

  async onNameSubmit(): Promise<void> {
    const val: string = this.editNameValue.trim();
    if (val.length > 0 && val !== this.nickname) {
      this.nickname = val;
      await UserProfileService.updateNickname(this.userId, val);
    }
    this.isEditingName = false;
  }

  colors(): StyleColors {
    return UiStyle.getColors(this.uiStyle || 'default', this.themeMode === 'dark');
  }

  build() {
    Column() {
      Column() {
        this.UserInfoCard();

        // 学习统计数据
        Row() {
          Column() {
            Text(this.statTotal.toString()).fontSize(24).fontWeight(FontWeight.Bold).fontColor(this.colors().accent);
            Text('\u8BFE\u7A0B\u603B\u6570').fontSize(12).fontColor(this.colors().textTertiary).margin({ top: 4 });
          }
          .layoutWeight(1);
          Divider().vertical(true).height(40).color(this.colors().divider);
          Column() {
            Text(this.statCompleted.toString()).fontSize(24).fontWeight(FontWeight.Bold).fontColor(this.colors().accent);
            Text('\u5DF2\u5B8C\u6210').fontSize(12).fontColor(this.colors().textTertiary).margin({ top: 4 });
          }
          .layoutWeight(1);
          Divider().vertical(true).height(40).color(this.colors().divider);
          Column() {
            Text(this.statArchived.toString()).fontSize(24).fontWeight(FontWeight.Bold).fontColor(this.colors().accent);
            Text('\u5DF2\u5F52\u6863').fontSize(12).fontColor(this.colors().textTertiary).margin({ top: 4 });
          }
          .layoutWeight(1);
        }
        .width('100%')
        .padding(16)
        .backgroundColor(this.colors().cardBg)
        .margin({ top: 12 });

        this.FunctionList();
      }
      .width('100%');
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(this.colors().pageBg);
  }

  @Builder
  UserInfoCard(): void {
    Column() {
      Row() {
        Column() {
          if (this.avatarUri) {
            Image(this.avatarUri)
              .key('avatar_' + this.avatarVersion)
              .width(64)
              .height(64)
              .borderRadius(32)
              .objectFit(ImageFit.Cover);
          } else {
            Circle()
              .width(64)
              .height(64)
              .fill('#E5E5E5');
          }
        }
        .gesture(
          LongPressGesture()
            .onAction(() => {
              this.onAvatarLongPress();
            })
        )
        .width(64)
        .height(64);

        Column() {
          if (this.isEditingName) {
            TextInput({ placeholder: '\u8F93\u5165\u6635\u79F0', text: this.editNameValue })
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .width(200)
              .onChange((val: string) => {
                this.editNameValue = val;
              })
              .onSubmit(() => {
                this.onNameSubmit();
              });
          } else {
            Text(this.nickname)
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .gesture(
                LongPressGesture()
                  .onAction(() => {
                    this.onNameLongPress();
                  })
              );
          }

          Text('\u9AD8\u6548\u5B66\u4E60\uFF0C\u6DF1\u5EA6\u7406\u89E3')
            .fontSize(14)
            .fontColor(this.colors().textTertiary)
            .margin({ top: 4 });
        }
        .alignItems(HorizontalAlign.Start)
        .margin({ left: 16 });
      }
      .width('100%');
    }
    .width('100%')
    .padding(24)
    .backgroundColor(this.colors().cardBg);
  }

  @Builder
  FunctionList(): void {
    Column() {
      this.FunctionItem('\uD83D\uDCDA \u5F52\u6863\u7BA1\u7406', '\u67E5\u770B\u5DF2\u5F52\u6863\u7684\u8BFE\u7A0B', () => {
        AppRouter.toArchive();
      });

      Divider();

      this.FunctionItem('\uD83C\uDFA8 \u5916\u89C2', '\u6DF1\u8272\u6A21\u5F0F\u3001UI\u4E3B\u9898', () => {
        AppRouter.toAppearance();
      });

      Divider();

      this.FunctionItem('\u2699\uFE0F \u8BBE\u7F6E', 'API\u914D\u7F6E\u3001\u5BFC\u51FA\u6570\u636E', () => {
        AppRouter.toSettings();
      });
    }
    .width('100%')
    .backgroundColor(this.colors().cardBg)
    .margin({ top: 12 });
  }

  @Builder
  FunctionItem(title: string, desc: string, onClick: () => void): void {
    Row() {
      Column() {
        Text(title)
          .fontSize(16)
          .fontWeight(FontWeight.Bold);

        Text(desc)
          .fontSize(12)
          .fontColor(this.colors().textTertiary)
          .margin({ top: 4 });
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start);

      Text('>')
        .fontSize(20)
        .fontColor('#CCCCCC');
    }
    .width('100%')
    .padding(16)
    .onClick(onClick);
  }
}
