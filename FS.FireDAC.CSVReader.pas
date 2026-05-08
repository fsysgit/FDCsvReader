unit FS.FireDAC.CSVReader;

interface

uses
  System.SysUtils,System.Classes,FireDAC.Stan.Intf,
  Data.DB, FireDAC.Comp.Client,FireDAC.ConsoleUI.Wait,FireDAC.Comp.UI,
  FireDAC.Comp.BatchMove.Text,FireDAC.Comp.BatchMove.Dataset,FireDAC.Comp.BatchMove;

type
  /// <summary>
  ///   FireDAC を利用した CSV 解析コンポーネント。
  ///   VCL / FMX への依存なし。
  /// </summary>

  TFDCSVAnalyzer = class(TComponent)
  public

    constructor Create(AOwner: TComponent;MaxFieldLength : integer = 1024); overload;
    destructor Destroy; override;
  private
    FCursor : TFDGUIxWaitCursor;
    FDataSet: TFDMemTable;
    FSeparator: Char;
    FWithFieldNames: Boolean;
    FEncoding : TFDEncoding;
    FFields : TStringList;
    FMaxLength : integer;
    FDelimiter : Char;
  public
    /// <summary>指定した CSV ファイルを読み込み、DataSet に格納する</summary>
    procedure LoadCSV(AFileName: TFileName);

    /// <summary>DataSet の内容をクリアする</summary>
    procedure Clear;

    /// <summary>読み込んだデータを保持する TFDMemTable</summary>
    property DataSet: TFDMemTable read FDataSet;

    property Fields : TStringList read FFields;

    property MaxLength : integer read FMaxLength write FMaxLength;

    /// <summary>改行区切りでフィールド名を設定 または Fieldsに直接delimitedText等で設定する</summary>
    procedure SetFields(AFields : string);

  published
    /// <summary>フィールド区切り文字（デフォルト: ','）</summary>
    property Separator: Char read FSeparator write FSeparator default ',';

    /// <summary>囲い文字（デフォルト: '"'）</summary>
    property Delimiter :Char read FDelimiter write FDelimiter default '"';

    /// <summary>先頭行をヘッダー（フィールド名）として扱うか（デフォルト: True）</summary>
    property WithFieldNames: Boolean read FWithFieldNames write FWithFieldNames default True;

    property Encoding: TFDEncoding read FEncoding write FEncoding default ecDefault;

  end;

implementation

{ TFDCSVAnalyzer }

constructor TFDCSVAnalyzer.Create(AOwner: TComponent;MaxFieldLength : integer = 1024);
begin
  inherited Create(AOwner);
  FSeparator := ',';
  FDelimiter := '"';
  FCursor := TFDGUIxWaitCursor.Create(self);
  FCursor.Provider := 'Console';
  FWithFieldNames := True;
  FEncoding := ecDefault;
  FDataSet := TFDMemTable.Create(Self);
  FFields := TStringList.Create;
  FMaxLength := MaxFieldLength;
end;


destructor TFDCSVAnalyzer.Destroy;
begin

  FFields.Free;
  inherited Destroy;
end;

procedure TFDCSVAnalyzer.LoadCSV(AFileName: TFileName);
var
  LBatchMove: TFDBatchMove;
  LReader: TFDBatchMoveTextReader;
  LWriter: TFDBatchMoveDataSetWriter;
  i : integer;

begin
  if not FileExists(AFileName) then
    raise EFileNotFoundException.CreateFmt('CSV file not found: %s', [AFileName]);

  if (FWithFieldNames = false) and (FFields.Count = 0) then
    raise Exception.Create('フィールド自動認識がオフの場合はフィールド名をセットしてください。');

  // 既存データをクリア
  Clear;

  LBatchMove := TFDBatchMove.Create(nil);
  try

    // --- Reader（CSV テキストファイル） ---
    LReader := TFDBatchMoveTextReader.Create(LBatchMove);

    LReader.FileName := AFileName;
    LReader.DataDef.Separator := FSeparator;
    LReader.DataDef.WithFieldNames := FWithFieldNames;
    LReader.DataDef.Delimiter      := FDelimiter;
    //基本は文字コード自動認識、必要な場合は事前にFEncodingにセットしておく
    LReader.Encoding := FEncoding;

    // --- Writer（TFDMemTable） ---
    LWriter := TFDBatchMoveDataSetWriter.Create(LBatchMove);

    LWriter.DataSet := FDataSet;
    LWriter.Optimise := False;

    // CSV 構造を解析してデータを転送
    if FWithFieldNames then begin

      LBatchMove.GuessFormat;
      //上位に短いデータしかない場合文字の切り捨てが発生するのでフィールドサイズを拡張
      for i := 0 to LReader.DataDef.Fields.Count - 1 do begin
        LReader.DataDef.Fields[i].DataType := TFDtextDataType.atString;
        LReader.DataDef.Fields[i].FieldSize := FMaxLength;
      end;
    end else begin
      LBatchMove.Mappings.Clear;
      for i := 0 to FFields.Count - 1 do begin
        with LReader.DataDef.Fields.Add do begin
          DataType := TFDtextDataType.atString;
          FieldSize := FMaxLength;
          FieldName := FFields[i];
        end;

        FDataSet.FieldDefs.Add(FFields[i],TFieldType.ftWideString,FMaxLength);

        with LBatchMove.Mappings.Add do begin
          SourceFieldName      := LReader.DataDef.Fields[i].FieldName;
          DestinationFieldName := FDataSet.FieldDefs[i].Name;
        end;
      end;
      FDataSet.CreateDataSet;
    end;

    LBatchMove.Execute;

    FDataSet.First;

  finally
    LBatchMove.Free;
  end;
end;

procedure TFDCSVAnalyzer.SetFields(AFields: string);
begin
  FFields.Text := AFields;
end;

procedure TFDCSVAnalyzer.Clear;
begin
  if FDataSet.Active then
    FDataSet.Close;
  FDataSet.FieldDefs.Clear;
  FDataSet.Fields.Clear;
end;

end.
