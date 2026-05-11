unit FS.FireDAC.CSVReader;

interface

uses
  System.SysUtils,System.Classes,FireDAC.Stan.Intf,Generics.Collections,
  Data.DB, FireDAC.Comp.Client,FireDAC.ConsoleUI.Wait,FireDAC.Comp.UI,
  FireDAC.Comp.BatchMove.Text,FireDAC.Comp.BatchMove.Dataset,FireDAC.Comp.BatchMove;

type
  /// <summary>
  ///   FireDAC を利用した CSV 解析コンポーネント。
  ///   VCL / FMX への依存なし。
  /// </summary>

  //follow : CSVの1行目をヘッダとして読み込みます。重複したヘッダがあると読み込み時エラーになります。
  //withOut : ヘッダを考慮せず連番ヘッダを割り当てます。（1行目がヘッダの場合ヘッダもデータとして扱われます）
  //withDuplicate : CSVの1行目をヘッダとして重複したヘッダを連番ヘッダに置き換えて読み込みます。エラーは出ませんがCSVとは違うヘッダが設定されます。
  TfsHeaderMode = (fhmFollow,fhmWithOut,fhmWithDuplicate);

  TFDCSVAnalyzer = class(TComponent)
  public

    constructor Create(AOwner: TComponent;MaxFieldLength : integer = 1024); overload;
    destructor Destroy; override;
  private
    FCursor : TFDGUIxWaitCursor;
    FDataSet: TFDMemTable;
    FSeparator: Char;
    FWithFieldNames: TfsHeaderMode;
    FEncoding : TFDEncoding;
    FFields : TStringList;
    FMaxLength : integer;
    FDelimiter : Char;
    FMaxFieldCount : integer;
    FTruncateField : boolean;
    procedure SetFieldNameAndTruncFields(var ADataSet : TFDMemTable);
  public
    /// <summary>指定した CSV ファイルを読み込み、DataSet に格納する</summary>
    procedure LoadCSV(AFileName: TFileName);

    /// <summary>DataSet の内容をクリアする</summary>
    procedure Clear;

    /// <summary>読み込んだデータを保持する TFDMemTable</summary>
    property DataSet: TFDMemTable read FDataSet;

    property Fields : TStringList read FFields;

    property MaxLength : integer read FMaxLength write FMaxLength;

    /// <summary>重複ヘッダの場合、テンポラリとして一旦保存するカラム数 大きい場合はパフォーマンスが悪化し、小さい場合は切り捨てが発生する</summary>
    ///デフォルト値はBiff8の最大数とする
    property MaxFieldCount : integer read FMaxFieldCount write FMaxFieldCount default 256;

    //<summary>仮フィールドの切り捨てを行うかどうか</summary>
    property TruncateField : boolean read FTruncateField write FTruncateField default true;
    
    /// <summary>改行区切りでフィールド名を設定 または Fieldsに直接delimitedText等で設定する</summary>
    procedure SetFields(AFields : string);

  published
    /// <summary>フィールド区切り文字（デフォルト: ','）</summary>
    property Separator: Char read FSeparator write FSeparator default ',';

    /// <summary>囲い文字（デフォルト: '"'）</summary>
    property Delimiter :Char read FDelimiter write FDelimiter default '"';

    /// <summary>ヘッダ行の取り扱い（デフォルト: fhmFollow）</summary>
    property WithFieldNames: TfsHeaderMode read FWithFieldNames write FWithFieldNames default fhmFollow;

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
  FWithFieldNames := fhmFollow;
  FEncoding := ecDefault;
  FDataSet := TFDMemTable.Create(Self);
  FFields := TStringList.Create;
  FMaxLength := MaxFieldLength;
  FTruncateField := true;
  FMaxFieldCount := 256;
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
  tempDataSet : TFDMemTable;
  i : integer;
begin
  if not FileExists(AFileName) then
    raise EFileNotFoundException.CreateFmt('CSV file not found: %s', [AFileName]);

  if (FWithFieldNames = fhmWithOut) and (FFields.Count = 0) then
    raise Exception.Create('フィールド自動認識がオフの場合はフィールド名をセットしてください。');

  // 既存データをクリア
  Clear;

  LBatchMove := TFDBatchMove.Create(nil);
  try

    // --- Reader（CSV テキストファイル） ---
    LReader := TFDBatchMoveTextReader.Create(LBatchMove);

    LReader.FileName := AFileName;
    LReader.DataDef.Separator := FSeparator;
    LReader.DataDef.WithFieldNames := FWithFieldNames in [fhmFollow];
    LReader.DataDef.Delimiter      := FDelimiter;
    //基本は文字コード自動認識、必要な場合は事前にFEncodingにセットしておく
    LReader.Encoding := FEncoding;

    // --- Writer（TFDMemTable） ---
    LWriter := TFDBatchMoveDataSetWriter.Create(LBatchMove);
    LWriter.Optimise := false;
    LWriter.DataSet := FDataSet;

    // CSV 構造を解析してデータを転送
    if FWithFieldNames = fhmFollow then begin
      
      LBatchMove.GuessFormat;
      //上位に短いデータしかない場合文字の切り捨てが発生するのでフィールドサイズを拡張
      for i := 0 to LReader.DataDef.Fields.Count - 1 do begin
        LReader.DataDef.Fields[i].DataType := TFDtextDataType.atString;
        LReader.DataDef.Fields[i].FieldSize := FMaxLength;
      end;

    end else if FWithFieldNames = fhmWithDuplicate then begin
      //重複ヘッダがある場合

      //メモリが二重化されるのでSetFieldNameAandTruncFields内でFreeする為所有権は設定しない
      TempDataSet := TFDMemTable.Create(nil);

      //テンポラリデータセットに再指定する
      LWriter.DataSet := TempDataSet;
      
      LBatchMove.Mappings.Clear;
      //仮に連番フィールドとして設定する
      for i := 0 to FMaxFieldCount - 1 do begin
        with LReader.DataDef.Fields.Add do begin
          DataType := TFDtextDataType.atString;
          FieldSize := FMaxLength;
          FieldName := 'Field' + (i + 1).ToString;
        end;

        TempDataSet.FieldDefs.Add('Field' + (i + 1).ToString,TFieldType.ftWideString,FMaxLength);

        with LBatchMove.Mappings.Add do begin
          SourceFieldName      := LReader.DataDef.Fields[i].FieldName;
          DestinationFieldName := TempDataSet.FieldDefs[i].Name;
        end;
      end;
      TempDataSet.CreateDataSet;
    end else begin
      //ヘッダが無い場合
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

    if FWithFieldNames = fhmWithDuplicate then SetFieldNameAndTruncFields(tempDataSet) else FDataSet.First;

  finally
    LBatchMove.Free;
  end;
end;

procedure TFDCSVAnalyzer.SetFieldNameAndTruncFields(var ADataSet : TFDMemTable);
var
  s : string;
  i,cnt : integer;
  Headers : TStringList;
  HeaderCount : TDictionary<string,integer>;
 
  LBatchMove : TFDBatchMove;
  LWriter : TFDBatchMoveDataSetWriter;
  LReader : TFDBatchMoveDataSetReader;
begin
  Headers := TStringList.Create;
  HeaderCount := TDictionary<string,integer>.Create;
  try

    ADataSet.First;
    //テンポラリの1行目にあるヘッダを積みなおす
    for i := 0 to ADataSet.FieldCount - 1 do begin
      //FTruncateFieldに従い1行目が空文字のフィールドは仮フィールドとして切り捨てる

      if (ADataSet.Fields[i].AsWideString <> '') or (FTruncateField = false) then begin

        if HeaderCount.TryGetValue(ADataSet.Fields[i].AsWideString,cnt) then begin
          //重複している場合は末尾にカウントをセット
          HeaderCount[ADataSet.Fields[i].AsWideString] := cnt + 1;
          Headers.Add(ADataSet.Fields[i].AsWideString + HeaderCount[ADataSet.Fields[i].AsWideString].ToString);
        end else begin
          HeaderCount.Add(ADataSet.Fields[i].AsWideString,1);
          Headers.Add(ADataSet.Fields[i].AsWideString);
        end;
        
      end else begin
        break;
      end;
    end;

    //1行目を削除する（ヘッダのため）
    ADataSet.First;
    ADataSet.Delete;
    
    //BatchMoveを利用してテンポラリから書き出す
    LBatchMove := TFDBatchMove.Create(nil);
    LReader := TFDBatchMoveDataSetReader.Create(LBatchMove);
    LWriter := TFDBatchMoveDataSetWriter.Create(LBatchMove);
    try
      LReader.DataSet := ADataSet;
      LReader.Optimise := false;
      
      LWriter.DataSet := FDataSet;
      LWriter.Optimise := false;
      
      for i := 0 to Headers.Count - 1 do begin
        FDataSet.FieldDefs.Add(Headers[i],TFieldType.ftWideString,FMaxLength);

        with LBatchMove.Mappings.Add do begin
          SourceFieldName      := LReader.DataSet.Fields[i].FieldName;
          DestinationFieldName := Headers[i];
        end;
      end;
      FDataSet.CreateDataSet;
      LBatchMove.Execute;
    finally
      FreeAndNil(LBatchMove);
    end;
    
    FDataSet.First;
  finally
    FreeAndNil(Headers);
    FreeAndNil(HeaderCount);
    //テンポラリをFreeする
    ADataSet.Free;
  end;
  
  
end;

procedure TFDCSVAnalyzer.SetFields(AFields: string);
begin
  FFields.Text := AFields;
end;

procedure TFDCSVAnalyzer.Clear;
begin

  if Assigned(FDataSet) then begin
    FreeAndNil(FDataSet);
    FDataSet := TFDMemTable.Create(self);
  end;

end;

end.
