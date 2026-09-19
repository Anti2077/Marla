<div align="center">
  <img src="Resources/Brand/PaperLantern/logo-512.png" width="112" alt="Marla Paper Lantern マーク">
  <h1>Marla</h1>
  <p><strong>読んでいるもののそばに留まる翻訳。</strong></p>
  <p>必要なときに現れ、原文の近くに留まり、作業の邪魔をしない macOS ネイティブの翻訳レイヤーです。</p>
  <p>原文のそばで翻訳を照らし、読み終えたら、そのまま今の作業を続けられます。</p>

  <p>
    <a href="README.md">简体中文</a> ·
    <a href="README.en.md">English</a> ·
    <a href="README.ja.md">日本語</a> ·
    <a href="README.fr.md">Français</a> ·
    <a href="README.es.md">Español</a> ·
    <a href="README.de.md">Deutsch</a> ·
    <a href="README.ko.md">한국어</a>
  </p>

  <p>
    <img src="https://img.shields.io/badge/status-incubation-C86652?style=flat-square" alt="ステータス: インキュベーション">
    <img src="https://img.shields.io/badge/platform-macOS%2014%2B-393554?style=flat-square&amp;logo=apple&amp;logoColor=white" alt="プラットフォーム: macOS 14 以降">
    <img src="https://img.shields.io/badge/Swift-6.2-C86652?style=flat-square&amp;logo=swift&amp;logoColor=white" alt="Swift 6.2">
    <img src="https://img.shields.io/badge/Rust-1.85-E6B86A?style=flat-square&amp;logo=rust&amp;logoColor=393554" alt="Rust 1.85">
  </p>

  <p>
    <a href="website/">Marla 紹介ホームページ</a> ·
    <a href="https://github.com/Anti2077/Marla/releases/latest">ダウンロード（GitHub Releases）</a> ·
    <a href="https://github.com/Anti2077/Marla">GitHub</a>
  </p>

  <p>
    <a href="#marla-を選ぶ理由">Marla を選ぶ理由</a> ·
    <a href="#3-つの使い方">使い方</a> ·
    <a href="#曖昧にしないプライバシー">プライバシー</a> ·
    <a href="#開発">開発</a> ·
    <a href="docs/README.md">ドキュメント</a>
  </p>
</div>

<p align="center">
  <strong><a href="website/public/media/desktop/marla-hero-in-place--desktop-5x4.mp4">実際の Marla ワークフローを見る（MP4）</a></strong>
</p>

<p align="center"><sub>macOS ネイティブアプリの実録です。GitHub のメディアビューアーで MP4 が開きます。</sub></p>

## はじめに

Marla の紹介ホームページは [`website/`](website/) にあります。ダウンロードする場合は [GitHub Releases](https://github.com/Anti2077/Marla/releases/latest) を、ソースコードと開発記録については [GitHub リポジトリ](https://github.com/Anti2077/Marla) を参照してください。現在、このリポジトリはリリース前の準備段階にあるため、Releases ページにはまだダウンロード可能なアセットがない場合があります。

## Marla を選ぶ理由

多くの翻訳ツールは、ユーザーを別の場所へ移動させます。Marla は、現在使っているアプリケーションを中心に保ちます。ショートカットで呼び出し、原文の近くに表示された結果を読み、閉じたら、同じ場所から作業を続けられます。

- **その場に留まります。** 選択テキストやスクリーンショットの結果は、メインの翻訳ウインドウではなく、近くのネイティブカードに表示されます。
- **操作意図をすぐに示します。** 安定した結果表示面はネットワーク応答より先に現れ、ストリーミングされる内容に合わせて広がります。
- **構造を保ちます。** Quick Input と対応するリッチテキスト選択では、翻訳からネイティブ表示までセマンティック Markdown を維持します。
- **プロバイダーを交換できます。** 名前付きの OpenAI 互換プロファイルにより、テキスト翻訳のエンドポイントとモデルをユーザーが明示的に選択できます。

## 3 つの使い方

| 入力方法 | デフォルトショートカット | 動作 |
| --- | --- | --- |
| **選択テキスト** | `⌃⇧D` | Marla が現在の選択内容を安全に取得し、原文のそばへ結果をストリーミング表示します。 |
| **画面領域** | `⌃⇧S` | 複数ディスプレイの静止フレームから領域を選択し、ローカルの Vision OCR または明示的に選択した GLM-OCR を利用できます。 |
| **Quick Input** | `⌃⇧Space` | コンパクトなエディターで、対応する Markdown 構造を含む入力内容や貼り付け内容を翻訳します。 |

ショートカットは設定できます。完了した結果では、比較、コピー、再試行、システム音声、ピン留め、言語変更、プロバイダー切り替えを利用できますが、Marla がドキュメントワークスペースになることはありません。

## 必要なところをネイティブに

```text
明示的なトリガー
  → SwiftUI / AppKit による取得と表示
  → バージョン管理されたプロセス内 C ABI
  → プロバイダー、ストリーミング、正規化、キャンセルを担う組み込み Rust コア
  → 近くに表示されるネイティブの結果画面
```

Marla は Swift 6 製の macOS アプリです。持続的な画面には SwiftUI、メニューバー、パネル、フォーカス、画面レベルの動作には AppKit を使用します。Rust 2024 コアは静的ライブラリとして組み込まれており、localhost バックエンドや常時稼働する別サービスはありません。

## 曖昧にしないプライバシー

| 経路 | 現在の境界 |
| --- | --- |
| **選択テキスト翻訳** | 明示的に実行された、保護された Copy トランザクションだけが内容を提供できます。Accessibility は権限と位置決めに使用し、隠れたテキスト取得元としては使用しません。 |
| **Vision スクリーンショット OCR** | 選択したスクリーンショット領域は OCR のためにローカルに留まります。ただし、テキスト翻訳には設定済みのクラウドプロバイダーが使用される場合があります。 |
| **GLM-OCR** | Settings の説明を確認した上でユーザーが GLM-OCR を明示的に選択した場合に限り、スクリーンショットのピクセルがアップロードされます。 |
| **保存** | スクリーンショットと最近の翻訳はセッション内だけに保持されます。永続的な翻訳履歴と、ウインドウ周辺のテキスト収集は実装されていません。 |

Marla は完全オフラインであるとは主張しません。プロバイダー、OCR、データの正確な境界を一つのプライバシースローガンにまとめず、意図的に明示します。

## 対応言語

Marla の現在の製品言語セットには、次の 7 つの選択肢があります。

| 言語 | コード |
| --- | --- |
| 简体中文 / 簡体字中国語 | `zh-Hans` |
| English / 英語 | `en` |
| 日本語 | `ja` |
| Français / フランス語 | `fr` |
| Español / スペイン語 | `es` |
| Deutsch / ドイツ語 | `de` |
| 한국어 / 韓国語 | `ko` |

繁体字中国語は簡体字中国語の製品オプションに正規化され、独立した設定項目ではありません。プロバイダーのドキュメントにより多くの言語が記載されていても、検出、ルーティング、UI、プロバイダーマッピングがまとめて検証されるまで、Marla はそれらを製品対応言語とは表明しません。

## プロジェクトの状態

公開入口の準備中であるため、Marla は引き続き **Incubation / Unreleased** の段階です。ネイティブアプリケーションと主要ワークフローは実装されていますが、公開 Release、割り当て済みの製品バージョン、公証済みパッケージ、アップデーター、選択済みの公開ライセンスはまだ宣言されていません。

- [検証済みの開発状況](docs/development/STATUS.md)
- [製品定義](docs/product/PRODUCT.md)
- [アーキテクチャ](docs/architecture/ARCHITECTURE.md)
- [Paper Lantern ブランド](docs/product/BRAND.md)
- [Marla 紹介ホームページ](website/)
- [Web サイトの実装メモ](website/README.md)

## 開発

### 前提条件

- Apple Silicon 上の macOS 14 以降
- Xcode 26.5 または互換性のある完全な Xcode 環境
- Swift 6.2 以降
- Rust 1.85 以降

リポジトリ全体のチェックを実行します。

```sh
./scripts/check.sh
```

このスクリプトは Rust コアと Swift レイヤーのフォーマット、ビルド、テストを行い、Cargo のデバッグライブラリを使用してネイティブ Debug アプリをビルドし、プロジェクト構造と差分を検証します。完全な Xcode の選択はスクリプト自身のコマンドだけに適用され、マシン全体の `xcode-select` 設定は変更しません。

固定パスに安定した署名を持つ Release 開発アプリをビルドします。

```sh
./scripts/build-test-app.sh
```

検証済みアーティファクトは、開発専用 Marketing Version `0.0.0` を持つ `artifacts/Marla_dev.app` として出力されます。この数値はバンドルメタデータであり、公開リリースバージョンではありません。

<details>
<summary><strong>最初のローカル署名ビルド</strong></summary>

パッケージングスクリプトには安定したローカルコード署名 ID が必要であり、暗黙に ad-hoc 署名へ切り替わることはありません。`security find-identity -v -p codesigning` が出力する ID 名または証明書ハッシュを指定します。

```sh
MARLA_CODE_SIGN_IDENTITY="Your Local Code Signing Identity" \
./scripts/build-test-app.sh
```

以降、引数なしのビルドでは既存の固定アプリから証明書ハッシュを取得し、置き換え前に designated requirement が安定していることを検証します。これはローカルテストだけを支援するものであり、Developer ID 配布、公証、TCC の自動承認を提供するものではありません。

</details>

### リポジトリ構成

| パス | 役割 |
| --- | --- |
| `Sources/MarlaApp/` | SwiftUI/AppKit アプリケーション、取得、設定、セッション、表示 |
| `Sources/MarlaCore/` | Swift 向けブリッジモデルとプロバイダー契約 |
| `Sources/MarlaRustFFI/` | Swift と Rust を接続するバージョン管理された C ブリッジ |
| `rust/marla-core/` | 組み込みのプロバイダー、ストリーミング、OCR 正規化、キャンセルのコア |
| `website/` | 独立した React/Vite 製品ホームページのプロトタイプ |
| `docs/` | 製品の事実、アーキテクチャ、Task、状況、検証証拠 |
| `scripts/` | リポジトリチェック、パッケージング、アーティファクト検証 |

変更を行う前に、まず[ドキュメントマップ](docs/README.md)を開き、次に[現在の状況](docs/development/STATUS.md)とそこに記載された Active Task を読んでください。このリポジトリでは、製品アイデア、確定済み Backlog、進行中の実装、検証済み証拠を意図的に分けて管理しています。

---

<p align="center"><sub>Paper Lantern：読者のそばに灯る、小さな明かり。</sub></p>
