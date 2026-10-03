# よさこい集合時計

演舞の集合日時まで「あと何分」をスマートフォンとSABERAグラスに表示するFlutterアプリです。

## 機能

- 集合日・時刻、チーム名、集合場所を設定し端末に保存
- 1秒ごとに時計を確認し、残り分数を切り上げ表示
- 10分以内は赤色、1分以内は「まもなく集合」、集合後は0分と集合案内
- SABERA接続時にテレプロンプター画面へ送信。内容が変わったときだけ更新
- アプリ復帰時に時刻を再計算し、グラスに再送

時刻は端末のローカル時刻です。画面を開いている間に自動更新します。バックグラウンドや画面ロック中の継続送信・通知は実装していません。

## 起動

Flutter 3.41.6 / Dart 3.11.4で解析・テストを確認しています。

```sh
flutter pub get
flutter run -d <AndroidデバイスID>
```

AndroidはAPI 31以上。SDKの取得にGitHub Packagesの認証が必要です。ユーザーの `~/.gradle/gradle.properties` に以下を設定してください。認証情報をリポジトリへ保存しないでください。

```properties
GitHubPackagesUsername=<GitHubユーザー名>
GitHubPackagesPassword=<read:packagesを持つPAT>
```

iOSはMac、Xcode 26、iOS 18.2以上が必要です。`~/.netrc` に `maven.pkg.github.com` の認証を設定し、`ios/Runner.xcworkspace` を開いて署名Team / Bundle Identifierを設定してください。ルートの `Package.swift` を参照します。

```text
machine maven.pkg.github.com
  login <GitHubユーザー名>
  password <read:packagesを持つPAT>
```

グラスを接続せずに画面を試す場合は、Webプレビューを利用できます。

```sh
flutter run -d chrome
```

集合日時を選んで「この予定でカウントダウン」を押し、実機では「SABERAを接続」からデバイスを選択します。

## 検証

```sh
flutter analyze
flutter test
flutter build web
```

実機ではBluetooth権限の許可、デバイス選択のキャンセル、接続・切断・再接続、残り分数の更新、集合時刻到達を確認してください。

今回の環境ではFlutter CLIの子プロセス起動にアクセス制限があるため、解析サーバーとFlutterテストエンジンを直接実行して検証しました。Android / iOSの実機ビルドとBluetooth通信は未検証です。

## SDKとライセンス

[jig-SABERA/sabera-sdk](https://github.com/jig-SABERA/sabera-sdk) のFlutterサンプルを基にAndroid / iOSのMethodChannel / EventChannelブリッジを利用しています。Android SDK 1.0.1、iOS SDK 1.1.0を元サンプルに合わせています。サンプル由来のコードはApache-2.0（LICENSE / NOTICE）、SDKバイナリ自体は別途SDK利用規約が適用されます。
