# リリース前チェック

**金曜日の午後3時**までに次の確認を完了し、すべてのコマンドとプレースホルダーを変更せずに保持してください。

## 基本フロー

1. `Marla_dev.app` を起動します。
2. 設定を開き、API Profileの名前が **Staging** であることを確認します。
3. *強調テキスト*、リンク、コードを含む内容を翻訳します。

> ステータスが `ready` でない場合は、リリースを中止して `{{STATUS}}` を記録してください。

### 受け入れ項目

- [ ] 見出しとリストの階層が正しい
- [ ] リンク先が変更されていない
- [ ] インラインコード `MARLA_API_KEY` が翻訳されていない
- [ ] コピーした結果が完全なMarkdownのままである

| 項目 | 期待値 | 実際の値 |
| --- | --- | --- |
| ビルド番号 | `${BUILD_ID}` | `{{BUILD_ID}}` |
| 最低システム | macOS 14 | `{{MIN_OS}}` |
| ステータス | ready | `{{STATUS}}` |

詳細は[リリース文書](https://example.com/docs?lang=ja&section=release)を参照してください。

```sh
export MARLA_API_KEY="${MARLA_API_KEY}"
launchctl kickstart -k gui/501/com.example.marla
```

最後に、**リリース可能**または**ロールバックが必要**のどちらかで結論を示してください。
