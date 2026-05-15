unit FS.FireDAC.CSVReader;

interface

uses
  System.SysUtils,System.Classes,FireDAC.Stan.Intf,Generics.Collections,
  Data.DB, FireDAC.Comp.Client,FireDAC.ConsoleUI.Wait,FireDAC.Comp.UI,System.Threading,
  FireDAC.Comp.BatchMove.Text,FireDAC.Comp.BatchMove.Dataset,FireDAC.Comp.BatchMove,System.SyncObjs;

type
  /// <summary>
  ///   FireDAC を利用した CSV 解析コンポーネント。
  ///   VCL / FMX への依存なし。
  /// </summary>

  //follow : CSVの1行目をヘッダとして読み込みます。重複したヘッダがあると読み込み時エラーになります。
  //Manual : ヘッダを考慮せず連番ヘッダを割り当てます。（1行目がヘッダの場合ヘッダもデータとして扱われます）
  //withDuplicate : CSVの1行目をヘッダとして重複したヘッダを連番ヘッダに置き換えて読み込みます。エラーは出ませんがCSVとは違うヘッダが設定されます。
  TfsHeaderMode = (fhmFollow,fhmManual,fhmWithDuplicate);

  TFDCSVAnalyzerException = procedure(ASender: TObject; AException: Exception) of object;

  TFDCSVAnalyzer = class(TComponent)
  public
    constructor Create(AOwner: TComponent;MaxFieldLength : integer = 1024;MaxFieldCount : integer = 256); overload;
    destructor Destroy; override;
  private
    FCursor : TFDGUIxWaitCursor;
    FDataSet: TFDMemTable;
    FDataSource : TDataSource;
    FSeparator: Char;
    FWithFieldNames: TfsHeaderMode;
    FEncoding : TFDEncoding;
    FFields : TStringList;
    FMaxLength : integer;
    FDelimiter : Char;
    FMaxFieldCount : integer;
    FTruncateField : boolean;
    FDuplicatePrefix : string;
    FTrimSpace : boolean;

    FAsync : boolean;

    FOnComplete : TNotifyEvent;
    FOnException : TFDCSVAnalyzerException;
    FOnProgress : TNotifyEvent;

    FReadCount : integer;
    FWriteCount : integer;

    FPhase : TFDBatchMovePhase;
    FDoneEvent: TEvent;

    FDestroying: Boolean;

    FRunningBatchMove: TFDBatchMove;

    procedure SetFieldNameAndTruncFields(var ADataSet : TFDMemTable);
    function GetDataSet : TFDMemTable;

    procedure BatchMoveProgress(ASender: TObject; APhase: TFDBatchMovePhase);
    procedure LoadCSVSync(AFileName: TFileName);
    procedure LoadCSVAsync(AFileName : TFileName);

    procedure ConfigureBatchMove(ABatchMove: TFDBatchMove; const AFileName: TFileName;
              out AReader: TFDBatchMoveTextReader; out AWriter: TFDBatchMoveDataSetWriter;
              out ATempDataSet: TFDMemTable);
  protected
    procedure DoComplete;
    procedure DoException(ASender: TObject; AException: Exception);
    procedure DoProgress(ASender : TObject);
  public
    /// <summary>指定した CSV ファイルを読み込み、DataSet に格納する</summary>
    procedure LoadCSV(AFileName: TFileName);

    /// <summary>DataSet の内容をクリアする</summary>
    procedure Clear;

    /// <summary>読み込んだデータを保持する TFDMemTable/DataSourceで抽象化</summary>
    property DataSet: TFDMemTable read getDataSet;

    /// <summary>データソースを他のコンポーネントから利用したい場合に使用</summary>
    property DataSource : TDataSource read FDataSource;

    /// <summary>前後の半角スペースをTrimするかどうか デフォルト値 True</summary>
    property TrimSpace : Boolean read FTrimSpace write FTrimSpace;

    property Fields : TStringList read FFields;

    property MaxLength : integer read FMaxLength write FMaxLength;

    /// <summary>重複ヘッダの場合、テンポラリとして一旦保存するカラム数 大きい場合はパフォーマンスが悪化し、小さい場合は切り捨てが発生する</summary>
    ///デフォルト値はBiff8の最大数とする
    property MaxFieldCount : integer read FMaxFieldCount write FMaxFieldCount default 256;

    ///<summary>仮フィールドの切り捨てを行うかどうか</summary>
    property TruncateField : boolean read FTruncateField write FTruncateField default true;

    ///<summary>フィールド名重複時のプレフィックス</summary>
    property DuplicatePrefix : string read FDuplicatePrefix write FDuplicatePrefix;

    ///<summary>非同期実行スイッチ</summary>
    property Async : boolean read FAsync write FAsync;

    /// <summary>改行区切りでフィールド名を設定 または Fieldsに直接delimitedText等で設定する</summary>
    procedure SetFields(AFields : string);

    property OnComplete : TNotifyEvent read FOnComplete write FOnComplete;
    property OnException : TFDCSVAnalyzerException read FOnException write FOnException;
    property OnProgress : TNotifyEvent read FOnProgress write FOnProgress;

    ///<summary>BatchMove関係のプロパティ</summary>
    property ReadCount : integer read FReadCount;
    property WriteCount : integer read FWriteCount;
    property Phase : TFDBatchMovePhase read FPhase;



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

constructor TFDCSVAnalyzer.Create(AOwner: TComponent;MaxFieldLength : integer = 1024;MaxFieldCount : integer = 256);
begin
  inherited Create(AOwner);
  FSeparator := ',';
  FDelimiter := '"';
  FDataSource := TDataSource.Create(self);
  FCursor := TFDGUIxWaitCursor.Create(self);
  FCursor.Provider := 'Console';
  FWithFieldNames := fhmFollow;
  FEncoding := ecDefault;
  FDataSet := TFDMemTable.Create(Self);
  FFields := TStringList.Create;
  FMaxLength := MaxFieldLength;
  FTruncateField := true;
  FMaxFieldCount := MaxFieldCount;
  FDuplicatePrefix := '';
  FDataSource.DataSet := FDataSet;
  FTrimSpace := True;
  FAsync := false;
  FOnComplete := nil;
  FOnException := nil;
  FOnProgress := nil;
  FDestroying := false;
  FDoneEvent := TEvent.Create(nil,True,True,'');
end;

procedure TFDCSVAnalyzer.DoComplete;
begin
  if Assigned(FOnComplete) and
   ((Owner = nil) or not (csLoading in Owner.ComponentState)) then
     FOnComplete(Self);
end;


procedure TFDCSVAnalyzer.DoException(ASender: TObject; AException: Exception);
begin
  if Assigned(FOnException) and
   ((Owner = nil) or not (csLoading in Owner.ComponentState)) then
     FOnException(ASender,AException);
end;

procedure TFDCSVAnalyzer.DoProgress(ASender : TObject);
begin
  if Assigned(FOnProgress) and
   ((Owner = nil) or not (csLoading in Owner.ComponentState)) then
  FOnProgress(Self);
end;

destructor TFDCSVAnalyzer.Destroy;
begin
  FDestroying := True;
  if Assigned(FRunningBatchMove) then begin
    try
      FRunningBatchMove.OnProgress := nil;   // ★ 先に Progress 経路を切る
      FRunningBatchMove.AbortJob;
    except
    end;
  end;

  while FDoneEvent.WaitFor(50) <> wrSignaled do
    try
      CheckSynchronize;
    except
      // 破棄中のラムダ例外はここで吸う（フォーム連鎖破棄に巻き込まれた AV 対策）
    end;

  FDoneEvent.Free;
  FFields.Free;
  inherited Destroy;
end;


function TFDCSVAnalyzer.GetDataSet: TFDMemTable;
begin
  result := TFDMemTable(FDataSource.DataSet);
end;

procedure TFDCSVAnalyzer.LoadCSV(AFileName: TFileName);
begin
  // 二重起動防止：前回の非同期がまだ走っているなら弾く
  if FDoneEvent.WaitFor(0) <> wrSignaled then
    raise Exception.Create('前回の非同期処理がまだ完了していません。');
  if not FileExists(AFileName) then
    raise EFileNotFoundException.CreateFmt('CSV file not found: %s', [AFileName]);

  if (FWithFieldNames = fhmManual) and (FFields.Count = 0) then
    raise Exception.Create('フィールド自動認識がオフの場合はフィールド名をセットしてください。');

  Clear;

  if FAsync then begin
    LoadCSVAsync(AFileName);
  end else begin
    LoadCSVSync(AFileName);
  end;
end;


procedure TFDCSVAnalyzer.ConfigureBatchMove(
  ABatchMove: TFDBatchMove; const AFileName: TFileName;
  out AReader: TFDBatchMoveTextReader; out AWriter: TFDBatchMoveDataSetWriter;
  out ATempDataSet: TFDMemTable);
var
  i: Integer;
begin
  ATempDataSet := nil;

  AReader := TFDBatchMoveTextReader.Create(ABatchMove);
  AReader.FileName               := AFileName;
  AReader.DataDef.Separator      := FSeparator;
  AReader.DataDef.WithFieldNames := FWithFieldNames in [fhmFollow];
  AReader.DataDef.Delimiter      := FDelimiter;
  AReader.Encoding               := FEncoding;

  AWriter := TFDBatchMoveDataSetWriter.Create(ABatchMove);
  AWriter.Optimise := False;
  AWriter.DataSet  := FDataSet;

  if FWithFieldNames = fhmFollow then begin
    ABatchMove.GuessFormat;
    for i := 0 to AReader.DataDef.Fields.Count - 1 do begin
      AReader.DataDef.Fields[i].DataType  := TFDtextDataType.atString;
      AReader.DataDef.Fields[i].FieldSize := FMaxLength;
    end;
  end else if FWithFieldNames = fhmWithDuplicate then begin
    ATempDataSet    := TFDMemTable.Create(nil);
    AWriter.DataSet := ATempDataSet;
    ABatchMove.Mappings.Clear;
    for i := 0 to FMaxFieldCount - 1 do begin
      with AReader.DataDef.Fields.Add do begin
        DataType  := TFDtextDataType.atString;
        FieldSize := FMaxLength;
        FieldName := 'Field' + (i + 1).ToString;
      end;
      ATempDataSet.FieldDefs.Add(
        'Field' + (i + 1).ToString, TFieldType.ftWideString, FMaxLength);
      with ABatchMove.Mappings.Add do begin
        SourceFieldName      := AReader.DataDef.Fields[i].FieldName;
        DestinationFieldName := ATempDataSet.FieldDefs[i].Name;
      end;
    end;
    ATempDataSet.CreateDataSet;
  end else begin
    ABatchMove.Mappings.Clear;
    for i := 0 to FFields.Count - 1 do begin
      with AReader.DataDef.Fields.Add do begin
        DataType  := TFDtextDataType.atString;
        FieldSize := FMaxLength;
        FieldName := FFields[i];
      end;
      FDataSet.FieldDefs.Add(FFields[i], TFieldType.ftWideString, FMaxLength);
      with ABatchMove.Mappings.Add do begin
        SourceFieldName      := AReader.DataDef.Fields[i].FieldName;
        DestinationFieldName := FDataSet.FieldDefs[i].Name;
      end;
    end;
    FDataSet.CreateDataSet;
  end;

  // GuessFormat の影響を避けるため Execute 直前に Trim 系を設定
  FDataSet.FormatOptions.StrsTrim := FTrimSpace;
  AReader.DataDef.TrimLeft        := FTrimSpace;
  AReader.DataDef.TrimRight       := FTrimSpace;
  if Assigned(ATempDataSet) then
    ATempDataSet.FormatOptions.StrsTrim := FTrimSpace;
end;

procedure TFDCSVAnalyzer.LoadCSVAsync(AFileName: TFileName);
begin

  FDataSet.DisableControls;

  // 進捗カウンタ初期化
  FReadCount  := 0;
  FWriteCount := 0;
  FPhase      := TFDBatchMovePhase(0);

  // 実行中マーク
  FDoneEvent.ResetEvent;

  //BatchMove はメインスレッドで生成（destructor から AbortJob するため）
  FRunningBatchMove := TFDBatchMove.Create(nil);
  FRunningBatchMove.OnProgress := BatchMoveProgress;

  try
    TTask.Run(
    procedure
    var
      LReader      : TFDBatchMoveTextReader;
      LWriter      : TFDBatchMoveDataSetWriter;
      LTempDataSet : TFDMemTable;
      LHasError    : Boolean;
      LErrMsg      : string;
      LErrClass    : ExceptClass;
    begin
        LTempDataSet := nil;
        LHasError    := False;
      try
        try
          ConfigureBatchMove(FRunningBatchMove, AFileName, LReader, LWriter, LTempDataSet);
          FRunningBatchMove.Execute;
          if FWithFieldNames = fhmWithDuplicate then SetFieldNameAndTruncFields(LTempDataSet) else FDataSet.First;
        except
          on E: Exception do begin
            LHasError := True;
            LErrMsg   := E.Message;
            LErrClass := ExceptClass(E.ClassType);
            if Assigned(LTempDataSet) then FreeAndNil(LTempDataSet);
          end;
        end;

        finally begin
          TThread.Queue(nil, procedure
          var
            LExc: Exception;
            LReraise  : Boolean;
          begin
            LReraise := False;
            try
              try
                if not FDestroying then begin
                  if Assigned(FDataSet) then FDataSet.EnableControls;

                  if LHasError then begin
                    if Assigned(FOnException) then begin
                      // ハンドラあり → 通常ルート
                      if LErrClass <> nil then
                        LExc := LErrClass.Create(LErrMsg)
                      else
                        LExc := Exception.Create(LErrMsg);
                      try
                        DoException(Self, LExc);
                      finally
                        LExc.Free;
                      end;
                    end else begin
                      // ハンドラなし → Sync版と同じく外へ投げる
                      LReraise := True;
                    end;
                  end else begin


                    DoComplete;
                  end;
                end;
              except
                // ユーザコールバック内例外は飲み込む
              end;
            finally
              // ★ クリーンアップを先に終わらせる
              FreeAndNil(FRunningBatchMove);
              FDoneEvent.SetEvent;
            end;

            if LReraise and not FDestroying then begin
              if LErrClass <> nil then
                raise LErrClass.Create(LErrMsg)
              else
                raise Exception.Create(LErrMsg);
            end;
          end);
        end;
      end;
    end);
  except
    FreeAndNil(FRunningBatchMove);
    FDataSet.EnableControls;
    FDoneEvent.SetEvent;
    raise;
  end;
end;

procedure TFDCSVAnalyzer.LoadCSVSync(AFileName: TFileName);
var
  LBatchMove: TFDBatchMove;
  LReader: TFDBatchMoveTextReader;
  LWriter: TFDBatchMoveDataSetWriter;
  LTempDataSet : TFDMemTable;
  IsError : boolean;
begin



  FDataSet.DisableControls;
  LBatchMove := TFDBatchMove.Create(nil);

  // 同期処理の場合はProgressを設定する意味がないのでNil固定
  LBatchMove.OnProgress := nil;

  isError := false;
  try
    ConfigureBatchMove(LBatchMove, AFileName, LReader, LWriter, LTempDataSet);
    try
      LBatchMove.Execute;
    except
      on E: Exception do begin
        isError := true;
        if Assigned(LTempDataSet) then LTempDataSet.Free;
        if Assigned(FOnException) then DoException(Self, E) else raise;
      end;
    end;
    if FWithFieldNames = fhmWithDuplicate then SetFieldNameAndTruncFields(LTempDataSet) else FDataSet.First;
  finally
    LBatchMove.Free;
    FDataSet.EnableControls;
    if isError = false then DoComplete;
  end;
end;


procedure TFDCSVAnalyzer.SetFieldNameAndTruncFields(var ADataSet : TFDMemTable);
var
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

        if (ADataSet.Fields[i].AsWideString = '') and (FTruncateField = false) then begin
          //空欄かつTruncateFieldがFalse（切り捨てない）場合、仮フィールド名をそのまま割り当てる
          if HeaderCount.TryGetValue(ADataSet.Fields[i].FieldName,cnt) then begin
            HeaderCount[ADataSet.Fields[i].FieldName] := cnt + 1;
            Headers.Add(ADataSet.Fields[i].FieldName + FDuplicatePrefix + HeaderCount[ADataSet.Fields[i].FieldName].ToString);
          end else begin
            HeaderCount.Add(ADataSet.Fields[i].FieldName,0);
            Headers.Add(ADataSet.Fields[i].FieldName);
          end;
        end else begin

          if HeaderCount.TryGetValue(ADataSet.Fields[i].AsWideString,cnt) then begin
            //重複している場合は末尾にFDuplicatePrefixとカウントをセット
            HeaderCount[ADataSet.Fields[i].AsWideString] := cnt + 1;
            Headers.Add(ADataSet.Fields[i].AsWideString + FDuplicatePrefix + HeaderCount[ADataSet.Fields[i].AsWideString].ToString);
          end else begin
            HeaderCount.Add(ADataSet.Fields[i].AsWideString,0);
            Headers.Add(ADataSet.Fields[i].AsWideString);
          end;
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
      ADataSet.FormatOptions.StrsTrim := TrimSpace;
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
    FreeAndNil(ADataSet);
  end;


end;

procedure TFDCSVAnalyzer.SetFields(AFields: string);
begin
  FFields.Text := AFields;
end;

procedure TFDCSVAnalyzer.BatchMoveProgress(ASender: TObject;
  APhase: TFDBatchMovePhase);
var
  BM : TFDBatchMove;
  LReadCount : integer;
  LWriteCount : integer;
  LPhase : TFDBatchMovePhase;
begin
  if not (ASender is TFDBatchMove) then Exit;
  BM := TFDBatchMove(ASender);
  LReadCount := BM.ReadCount;
  LWriteCount := BM.WriteCount;
  LPhase := APhase;

  if FAsync then begin
    TThread.Queue(nil,procedure
    begin
      if FDestroying then Exit;
      TInterlocked.Exchange(FReadCount,  LReadCount);
      TInterlocked.Exchange(FWriteCount, LWriteCount);
      TInterlocked.Exchange(Integer(FPhase), Integer(LPhase));  // enumをIntegerにcast
      DoProgress(Self);
    end);

  end else begin

    TInterlocked.Exchange(FReadCount,  LReadCount);
    TInterlocked.Exchange(FWriteCount, LWriteCount);
    TInterlocked.Exchange(Integer(FPhase), Integer(LPhase));  // enumをIntegerにcast
    DoProgress(Self);
  end;

end;

procedure TFDCSVAnalyzer.Clear;
begin
  if FDoneEvent.WaitFor(0) <> wrSignaled then raise Exception.Create('非同期実行中は Clear できません。');

  FDataSource.DataSet := nil;
  if Assigned(FDataSet) then begin
    FreeAndNil(FDataSet);
    FDataSet := TFDMemTable.Create(self);
  end;
  FDataSource.DataSet := FDataSet;
end;

end.
