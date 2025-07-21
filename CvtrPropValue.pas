unit CvtrPropValue;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections;

type
  IHolder = interface(IInterface)
    function GetRef: TObject;
    property Ref: TObject read GetRef;
  end;

  TValueType = (vtEmpty, vtSymbol, vtInteger, vtFloat, vtString, vtData, vtItems, vtSet, vtList);

  TPropValueList = class;

  TPropValue = record
  private
    FVType: TValueType;
    FText: String;
    FHolder: IHolder;
    function GetText: String;
    procedure SetText(const Value: String);
    function GetData: TMemoryStream;
    function GetItems: TObject;
    function GetSet: TStringList;
    function GetList: TPropValueList;
    function GetInt: Int64;
    procedure SetInt(const Value: Int64);
  public
    property VType: TValueType read FVType;
    property Int: Int64 read GetInt write SetInt;
    property Text: String read GetText write SetText;
    property Data: TMemoryStream read GetData;
    property Items: TObject read GetItems;
    property SetItems: TStringList read GetSet;
    property List: TPropValueList read GetList;
    constructor CreateSymbolVal(AText: String);
    constructor CreateIntegerVal(AInt: Integer); overload;
    constructor CreateIntegerVal(AText: String); overload;
    constructor CreateFloatVal(AText: String);
    constructor CreateStringVal(AText: String);
    constructor CreateDataVal(AData: TMemoryStream);
    constructor CreateItemsVal(AItems: TObject);
    constructor CreateSetVal(ASet: TStringList); overload;
    constructor CreateSetVal(const SetItems: array of string); overload;
    constructor CreateListVal(APropValueList: TPropValueList);
    class operator Implicit(AVal: TPropValue): Int64;
    class operator Implicit(AVal: TPropValue): String;
    class operator Implicit(AVal: TPropValue): TMemoryStream;
  end;

  TPropValueList = class(TList<TPropValue>);

implementation

type
  TObjectHolder = class(TInterfacedObject, IHolder)
  private
    FRef: TObject;
    function GetRef: TObject;
  public
    constructor Create(ARef: TObject);
    destructor Destroy; override;
  end;

  EValueTypeException = class(Exception)
  public
    constructor Create(AReqType, ARealType: TValueType); overload;
    constructor Create(ARealType: TValueType); overload;
  end;

const
  TypeToStr: array[TValueType] of string = ('vtEmpty', 'vtSymbol', 'vtInteger', 'vtFloat', 'vtString', 'vtData',
    'vtItems', 'vtSet', 'vtList');
  STypeExceptionMessage = '%s type expected, but %s found';
  STextTypeExceptionMessage = 'vtSymbol, vtInteger, vtFloat or vtString type expected, but %s found';
  TextTypes: set of TValueType = [vtSymbol, vtInteger, vtFloat, vtString];

{ TObjectHolder }

constructor TObjectHolder.Create(ARef: TObject);
begin
  FRef := ARef;
end;

destructor TObjectHolder.Destroy;
begin
  FRef.Free;
  inherited;
end;

function TObjectHolder.GetRef: TObject;
begin
  Result := FRef;
end;

{ TPropValue }

constructor TPropValue.CreateDataVal(AData: TMemoryStream);
begin
  FVType := vtData;
  FHolder := TObjectHolder.Create(AData);
end;

constructor TPropValue.CreateFloatVal(AText: String);
begin
  FVType := vtFloat;
  FText := AText;
end;

constructor TPropValue.CreateIntegerVal(AText: String);
begin
  FVType := vtInteger;
  FText := AText;
end;

constructor TPropValue.CreateIntegerVal(AInt: Integer);
begin
  FVType := vtInteger;
  FText := AInt.ToString;
end;

constructor TPropValue.CreateItemsVal(AItems: TObject);
begin
  FVType := vtItems;
  FHolder := TObjectHolder.Create(AItems);
end;

constructor TPropValue.CreateSetVal(ASet: TStringList);
begin
  FVType := vtSet;
  FHolder := TObjectHolder.Create(ASet);
end;

constructor TPropValue.CreateSetVal(const SetItems: array of string);
var
  SL: TStringList;
begin
  SL := TStringList.Create(dupIgnore, {Sorted} False, {CaseSensitive} False);
  SL.AddStrings(SetItems);
  CreateSetVal(SL);
end;

constructor TPropValue.CreateListVal(APropValueList: TPropValueList);
begin
  FVType := vtList;
  FHolder := TObjectHolder.Create(APropValueList);
end;

constructor TPropValue.CreateStringVal(AText: String);
begin
  FVType := vtString;
  FText := AText;
end;

constructor TPropValue.CreateSymbolVal(AText: String);
begin
  FVType := vtSymbol;
  FText := AText;
end;

function TPropValue.GetData: TMemoryStream;
begin
  if FVType = vtData then
    Result := FHolder.Ref as TMemoryStream
  else
    raise EValueTypeException.Create(vtData, FVType);
end;

function TPropValue.GetInt: Int64;
begin
  if FVType = vtInteger then
    Result := StrToInt64(FText)
  else
    raise EValueTypeException.Create(vtInteger, FVType);
end;

function TPropValue.GetItems: TObject;
begin
  if FVType = vtItems then
    Result := FHolder.Ref
  else
    raise EValueTypeException.Create(vtItems, FVType);
end;

function TPropValue.GetSet: TStringList;
begin
  if FVType = vtSet then
    Result := FHolder.Ref as TStringList
  else
    raise EValueTypeException.Create(vtSet, FVType);
end;

function TPropValue.GetList: TPropValueList;
begin
  if FVType = vtList then
    Result := FHolder.Ref as TPropValueList
  else
    raise EValueTypeException.Create(vtList, FVType);
end;

function TPropValue.GetText: String;
begin
  if FVType in TextTypes then
    Result := FText
  else
    raise EValueTypeException.Create(FVType);
end;

class operator TPropValue.Implicit(AVal: TPropValue): TMemoryStream;
begin
  Result := AVal.GetData;
end;

class operator TPropValue.Implicit(AVal: TPropValue): Int64;
begin
  Result := AVal.GetInt;
end;

class operator TPropValue.Implicit(AVal: TPropValue): String;
begin
  Result := AVal.GetText;
end;

procedure TPropValue.SetInt(const Value: Int64);
begin
  if FVType = vtInteger then
    FText := Value.ToString
  else
    raise EValueTypeException.Create(vtInteger, FVType);
end;

procedure TPropValue.SetText(const Value: String);
begin
  if FVType in TextTypes then
    FText := Value
  else
    raise EValueTypeException.Create(FVType);
end;

{ EValueTypeException }

constructor EValueTypeException.Create(AReqType, ARealType: TValueType);
begin
  inherited CreateFmt(STypeExceptionMessage, [TypeToStr[AReqType], TypeToStr[ARealType]]);
end;

constructor EValueTypeException.Create(ARealType: TValueType);
begin
  inherited CreateFmt(STextTypeExceptionMessage, [TypeToStr[ARealType]]);
end;

end.
