# FS.FireDAC.CSVReader

FireDAC の `TFDBatchMove` を利用した、軽量な CSV 解析コンポーネント (Delphi)。
VCL / FMX に依存しないため、コンソールアプリやサービス、ライブラリ内部からも利用できます。
重複したヘッダを持つCSVにも対応。
- RFC4180 準拠（FireDAC CSVパーサによる準拠）
  - ダブルクォート囲みフィールド
  - フィールド内カンマ
  - エスケープされたダブルクォート (`""`)
  - 複数行フィールド
その他の特徴
  - 重複ヘッダ対応
  - ヘッダ自動リマップ
  - 区切り文字変更可能
  - コンソール / サービス利用対応
  - TFDMemTable ベース(DataSet/DataSourceとして利用可能)
>※日本語CSVの場合Shift-JIS（SJIS、CP932等）はFireDACの内部実装的に非対応です。
>事前にUTF8（BOM付き）に変換してご利用ください。

A lightweight CSV reader component for Delphi, built on top of FireDAC's `TFDBatchMove`.
No VCL / FMX dependency — usable from console apps, services, and libraries. It also supports CSV files with duplicate headers.
- RFC 4180 compliant CSV parsing(via FireDAC)
  - Quoted fields
  - Embedded commas
  - Escaped double quotes (`""`)
  - Multi-line fields
Other Features
  - Duplicate header support
  - Header remapping mode
  - Configurable separator / delimiter
  - Console / service friendly
  - TFDMemTable based(DataSet/DataSource)
> Note: Due to FireDAC's internal text parser behavior, legacy Japanese
> encodings such as Shift-JIS / CP932 are **not reliably supported**.
> Please convert your CSV files to UTF-8 (BOM recommended) before loading.

---

## 特徴 / Features

- **VCL / FMX 非依存** — `TComponent` のみを継承し、UI フレームワークに縛られない
- **`TFDMemTable` に格納** — 読み込み結果は `DataSet` プロパティ経由で `TFDMemTable` として取得でき、グリッド連携やクエリ、エクスポートが容易
- **ヘッダー行の自動認識**(`WithFieldNames`)、またはフィールド名を手動指定する両モードに対応
- **区切り文字、囲み文字、エンコーディング** をプロパティで指定可能
- **最大フィールド長(`MaxLength`)を拡張** — 上位行に短いデータしかない場合に発生する文字の切り捨てを防止
- **重複したヘッダを持つCSVにも対応**
- 単一ユニット (`FS.FireDAC.CSVReader.pas`) で完結
- FireDACによるRFC4180準拠
---

## 動作環境 / Requirements

- Delphi 10.x / 11.x / 12.x /13.x (FireDAC 同梱版)
- FireDAC (`FireDAC.Comp.BatchMove`, `FireDAC.Comp.BatchMove.Text`, `FireDAC.Comp.BatchMove.DataSet`)

> **Note:** Delphi Community Edition / Professional 以上で FireDAC が利用可能です。

---

## インストール / Installation

`FS.FireDAC.CSVReader.pas` をプロジェクトに追加するだけです。
パッケージ化や IDE への登録は不要 (ランタイムから直接利用するコンポーネントです)。

```pascal
uses
  FS.FireDAC.CSVReader;
```

---

## 使い方 / Usage

### 1. ヘッダー行ありの CSV を読み込む

```pascal
var
  Analyzer: TFDCSVAnalyzer;
begin
  Analyzer := TFDCSVAnalyzer.Create(nil);
  try
    Analyzer.Separator      := ',';         //区切り文字
    Analyzer.Delimiter      := '"';         //囲い文字
    Analyzer.WithFieldNames := fhmFollow;        // CSVに従う（1 行目をフィールド名として扱う）
    Analyzer.Encoding       := ecUTF8;      // 必要に応じて指定 (既定: ecDefault = OSデフォルトコードページ)

    Analyzer.LoadCSV('C:\data\sample.csv');

    // DataSet (TFDMemTable) として利用
    while not Analyzer.DataSet.Eof do
    begin
      Writeln(Analyzer.DataSet.FieldByName('Name').AsString);
      Analyzer.DataSet.Next;
    end;
  finally
    Analyzer.Free;
  end;
end;
```

### 2. ヘッダー行のない CSV を読み込む(フィールド名を手動指定)

```pascal
var
  Analyzer: TFDCSVAnalyzer;
begin
  Analyzer := TFDCSVAnalyzer.Create(nil);
  try
    Analyzer.WithFieldNames := fhmManual;

    // 改行区切りでフィールド名を設定
    Analyzer.SetFields('ID'#13#10'Name'#13#10'Email');
    // または Fields プロパティに直接 DelimitedText などで設定
    // Analyzer.Fields.CommaText := 'ID,Name,Email';

    Analyzer.LoadCSV('C:\data\noheader.csv');
  finally
    Analyzer.Free;
  end;
end;
```

### 3. ヘッダーが重複した CSV を読み込む

```pascal
var
  Analyzer: TFDCSVAnalyzer;
begin
  Analyzer := TFDCSVAnalyzer.Create(nil,1024,512); //第三引数は仮フィールドの数
  try
    Analyzer.Separator       := ',';         //区切り文字
    Analyzer.Delimiter       := '"';         //囲い文字
    Analyzer.WithFieldNames  := fhmWithDuplicate;  // 1 行目をフィールド名として扱い、重複を自動リネームする
    Analyzer.DuplicatePrefix := '__';        //重複時、連番の前に追加するプレフィックス（必要な場合）
    Analyzer.Encoding        := ecUTF8;      //必要に応じて指定 (既定: ecDefault = OSデフォルトコードページ)

    Analyzer.LoadCSV('C:\data\sample.csv');
  finally
    Analyzer.Free;
  end;
end;
```

### 4. 長いフィールドへの対応

CSV の上位行に短いデータしかない場合、FireDAC の自動判定によりフィールドサイズが小さくなり、後続行の長い値が切り捨てられることがあります。
本コンポーネントはコンストラクタの `MaxFieldLength` 引数(既定 `1024`)、または `MaxLength` プロパティで明示的にフィールドサイズを拡張できます。

```pascal
Analyzer := TFDCSVAnalyzer.Create(nil, 8192);
// または
Analyzer.MaxLength := 8192;
```

---

## API リファレンス / API Reference

### `TFDCSVAnalyzer`

| メンバー | 種別 | 説明 |
|---|---|---|
| `Create(AOwner; MaxFieldLength = 1024; MaxFieldCount = 256)` | constructor | コンポーネントを生成 |
| `LoadCSV(AFileName)` | method | CSV ファイルを読み込み `DataSet` に格納 |
| `Clear` | method | `DataSet` の内容をクリア |
| `SetFields(AFields)` | method | 改行区切り文字列でフィールド名を一括設定 |
| `DataSet` | `TFDMemTable` (read) | 読み込み結果を保持するメモリテーブル |
| `DataSource` | `TDataSource` (read) | 内部のDataSet（TFDMemTable）への参照を持ったDataSource |
| `TrimSpace` | `boolean` (property) | 前後に含まれる半角スペースをTrimするかどうか（既定 `true`）※RFC4180規定はFalse |
| `Fields` | `TStringList` (read) | 手動指定用フィールド名リスト |
| `MaxFieldCount` | `Integer` (property) | 重複ヘッダの場合、テンポラリとして一旦保存するカラム数 (既定 `256`) |
| `TruncateField` | `boolean` (property) | 仮フィールドの切り捨てを行うかどうか (既定 `true`) |
| `MaxLength` | `Integer` | 文字列フィールドの最大長 |
| `Separator` | `Char` (published) | 区切り文字 (既定 `,`) |
| `Delimiter` | `Char` (published) | 囲い文字 (既定 `"`) |
| `WithFieldNames` | `Enum` (published) | 1 行目をヘッダーとして扱う/重複をリネームする/ヘッダを手動で設定する (既定 `ヘッダーとして扱う`) |
| `DuplicatePrefix` | `string` | 重複時に連番の前に設定するプレフィックス |
| `Encoding` | `TFDEncoding` (published) | エンコーディング (既定 `ecDefault` = OSデフォルトコードページ) |

### ヘッダモード / HeaderMode

| メンバー | 説明 |
|---|---|
|`fhmFollow` | CSVに従う（1行目がヘッダ） |
|`fhmManual` | ヘッダを手動設定する |
|`fhmWithDuplicate` | 重複ヘッダをリネームする |


### 例外 / Exceptions

| 状況 | 例外 |
|---|---|
| 指定ファイルが存在しない | `EFileNotFoundException` |
| `WithFieldNames = fhmManual` かつ `Fields` が空 | `Exception` |

### 更新履歴

| 説明 | 詳細 |
|---|---|
|重複ヘッダモードでヘッダに空欄を含むCSVを読み込んだ場合を考慮|TruncateFieldがFalseでヘッダが空欄の場合仮フィールド名をそのまま採用|
|重複ヘッダ用に設定できるPrefixを追加|`dupHeader` `dupHeader` -> `dupHeader` `dupHeader__1`|
|外部コンポーネント連携用にDataSetを永続化|直接外に出ていたDataSetをDataSourceでラップして参照に変更|
|重複ヘッダモードの場合の利便性の為コンストラクタを変更|MaxFieldCountを指定できるよう変更 規定値256、大きなサイズが必要な場合はCreate時に指定|
|WithFieldNamesを破壊的変更| boolean -> Enum(fhmFollow,fhmManual,fhmWithDuplicate)|

### 参考ベンチマーク

4.2Ghz 8core Processor (VM)

| 説明 | 詳細 |
|---|---|
|KEN_ALL_ROME.CSV 11MB| 702ms / 50MB Memory |
|GeneratedCSVSample 1GB (6,000,000Rows / 1 billion words) | 59,786ms / 4.8GB Memory |

約4～5倍程度のメモリ消費なので要件に合わせて必要であればCSV側をChunk化してください

---

## テスト / Tests

リポジトリには手動テスト用の **FMX GUI テストアプリ** (`CSVTest.dpr`) を同梱しています。
RFC 4180 のエッジケース、各種文字コード、改行コードのバリエーションを含む CSV をワンクリックで読み込ませ、ヘッダー認識・行数・所要時間を確認できます。

A manual **FMX GUI test harness** (`CSVTest.dpr`) is included.
It loads CSVs covering RFC 4180 edge cases, encoding variants, and line-ending variants, reporting recognized headers, row count, and elapsed time with a single click.

### 操作方法 / How to use

| 項目 | 説明 |
|---|---|
| **事前準備 / Setup**| CSVTest.dprと同じフォルダにFS.FireDAC.CSVReader.pasを配置するかIDEからプロジェクトに追加してください |
| **TargetCSV** | `./` ルートフォルダから検証対象 CSV を選択（コンパイルした実行ファイルをCSVと同じフォルダに入れて実行してください） |
| **HeaderMode** | `fhmFollow` / `fhmManual` / `fhmWithDuplicate` を切替 |
| **Headers (for fhmManual)** | `fhmManual` 選択時のヘッダ名を改行区切りで入力 |
| **Separator** | `comma` / `tab` |
| **Encoding** | `ecANSI` / `ecUTF8` / `ecUTF16` / `ecDefault` |
| **truncateFields** | 空欄ヘッダの切り捨て ON/OFF (`fhmWithDuplicate` 時) |
| **ExportRowData** | データ本体をメモに全行ダンプ (ラージファイル時は OFF 推奨) |
| **Analyze!** | 解析実行 — メモにファイル名・ヘッダ・行数・経過時間 (ms) を追記 |

1. `CSVTest.dpr` を Delphi で開いてビルド・実行（CSVファイルと違うフォルダに実行ファイルが生成された場合はCSVのあるフォルダに実行ファイルを移動してください。）
2. 上記設定を行い **Analyze!** ボタンで実行
3. メモ欄に結果が追記される (連続実行で結果が蓄積)

### テストケース / Test cases

| # | ファイル | 検証内容 / What it verifies |
|---|---|---|
| 001 | `basic.csv` | 基本動作 (3列×2行 / ASCII / LF) |
| 002 | `quoted_comma.csv` | RFC 4180: 囲い文字内のカンマ |
| 003 | `quoted_newline.csv` | RFC 4180: 囲い文字内の改行 |
| 004 | `escaped_quote.csv` | RFC 4180: エスケープされたダブルクォート (`""`) |
| 005 | `missing_extra_columns.csv` | 列数不揃いの行 (3列→2列→4列) |
| 006 | `duplicate_empty_headers.csv` | 重複かつ空欄を含むヘッダ (`id,,id`) — `fhmWithDuplicate` モードの主用途 |
| 007 | `utf8_bom.csv` | UTF-8 BOM 付き + 日本語 |
| 008 | `shift_jis.csv` | Shift-JIS (※非サポート確認用 / **読み込み不可が期待動作、ecANSIで読み込める可能性もあります**) |
| 009 | `line_endings_lf.csv` | LF 改行 (Unix) |
| 010 | `line_endings_crlf.csv` | CRLF 改行 (Windows) |
| 011 | `line_endings_cr.csv` | CR 改行 (Classic Mac) |
| 012 | `tab_delimited.tsv` | タブ区切り |
| 013 | `trim_spaces.csv` | 前後スペース / 囲い文字内スペース ※RFC4180準拠の場合、TrimSpaceをFalseに設定してください |
| 014 | `unclosed_quote.csv` | 不正な CSV (囲い文字未閉じ) — 例外発生を確認 |
| 015 | `large_1mb.csv` | 1MB ファイルでのパフォーマンス検証 (※リポジトリ非同梱) |
| 016 | `large_100mb.csv` | 100MB ファイルでのパフォーマンス検証 (※リポジトリ非同梱) |
| 017 | `firedac_integration_UTF8.csv` / `*_UTF8N.csv` | 実用シナリオ: ASCII + 日本語 + 複数行クォート、**BOM 有り / 無し** をそれぞれ分離して検証 |

### ラージファイルの注意 / Notes on large files

- 015 / 016 はリポジトリサイズを抑えるため**同梱していません**。パフォーマンス検証が必要な場合は別途生成してください。
- 同梱していない CSV を選択すると、`LoadCSV` 内の `FileExists` チェックにより `EFileNotFoundException` で停止します。
- ラージファイル + `ExportRowData` の組み合わせはメモへの大量書き込みで応答性が落ちるため、テストアプリ側でガードしています。

015 / 016 are **not included** in the repository to keep its size small. Generate them locally if you need performance benchmarks. Selecting a missing file raises `EFileNotFoundException` inside `LoadCSV`. The harness also blocks the `ExportRowData` + large-file combination to avoid memo flooding.

---

## ライセンス / License

[MIT License](LICENSE) — Copyright (c) 2026 (fsystem)

---

## 貢献 / Contributing

Issue / Pull Request 歓迎です。バグ報告の際は、Delphi のバージョンと、可能であれば最小再現用の CSV サンプルを添えていただけると助かります。

Issues and pull requests are welcome. When reporting a bug, please include your Delphi version and, if possible, a minimal reproducible CSV sample.
