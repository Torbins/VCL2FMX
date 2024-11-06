unit ReflexiveMasks;

{$WARN WIDECHAR_REDUCED OFF}

// Based on System.Masks
{*******************************************************}
{                                                       }
{           CodeGear Delphi Runtime Library             }
{                                                       }
{ Copyright(c) 1995-2023 Embarcadero Technologies, Inc. }
{              All rights reserved                      }
{                                                       }
{*******************************************************}

interface

uses System.SysUtils;

type
  EReflexiveMaskException = class(Exception)
  end;

  TReflexiveMask = class
  private type
    TMaskStates = (msLiteral, msAny, msMBCSLiteral);
    TMaskState = record
      SkipTo: Boolean;
      TextChunk: String;
      case State: TMaskStates of
        msLiteral: (Literal: Char);
        msAny: ();
        msMBCSLiteral: (LeadByte, TrailByte: Char);
    end;
    TMaskStateArray = array of TMaskState;
  private
    FMaskStates: TMaskStateArray;
  protected
    procedure InitStatesArray(const MaskValue: string; var States: TMaskStateArray);
    function InitMaskStates(const Mask: string; var States: TMaskStateArray): Integer;
    function MatchesMaskStates(const TextStr: string): Boolean;
  public
    constructor Create(const MaskValue: string);
    destructor Destroy; override;
    function Matches(const TextStr: string): Boolean;
    function RestoreText(const MaskValue: string): string;
    class function ContainsWildcards(const TextStr: string): Boolean;
  end;

function MatchesMask(const TextStr, Mask: string): Boolean;

implementation

uses System.RTLConsts;

const
  MaxStack = 30;

{ TReflexiveMask }

function TReflexiveMask.InitMaskStates(const Mask: string; var States: TMaskStateArray): Integer;
var
  CurrMask: Integer;
  SkipTo: Boolean;
  Literal: Char;
  LeadByte, TrailByte: Char;
  P: Integer;
  StackDepth: Integer;

  procedure InvalidMask;
  begin
    raise EReflexiveMaskException.CreateResFmt(@SInvalidMask, [Mask, P + 1]);
  end;

  procedure Reset;
  begin
    SkipTo := False;
  end;

  procedure WriteScan(MaskState: TMaskStates);
  begin
    if CurrMask <= High(States) then
    begin
      if SkipTo then
      begin
        Inc(StackDepth);
        if StackDepth > MaxStack then
          InvalidMask;
      end;
      States[CurrMask].SkipTo := SkipTo;
      States[CurrMask].State := MaskState;
      case MaskState of
        msLiteral:
          begin
            States[CurrMask].Literal := UpCase(Literal);
            States[CurrMask].TextChunk := Literal;
          end;
        msMBCSLiteral:
          begin
            States[CurrMask].LeadByte := LeadByte;
            States[CurrMask].TrailByte := TrailByte;
            States[CurrMask].TextChunk := LeadByte + TrailByte;
          end;
      end;
    end;
    Inc(CurrMask);
    Reset;
  end;

begin
  P := 0;
  CurrMask := 0;
  StackDepth := 0;
  Reset;
  while P < Mask.Length do
  begin
    case Mask.Chars[P] of
      '*': SkipTo := True;
      '?': if not SkipTo then
        WriteScan(msAny);
    else
      if IsLeadChar(Mask.Chars[P]) then
      begin
        LeadByte := Mask.Chars[P];
        Inc(P);
        TrailByte := Mask.Chars[P];
        WriteScan(msMBCSLiteral);
      end
      else
      begin
        Literal := Mask.Chars[P];
        WriteScan(msLiteral);
      end;
    end;
    Inc(P);
  end;
  Literal := #0;
  WriteScan(msLiteral);
  Result := CurrMask;
end;

procedure TReflexiveMask.InitStatesArray(const MaskValue: string; var States: TMaskStateArray);
var
  Size: Integer;
begin
  SetLength(States, 1);
  Size := InitMaskStates(MaskValue, States);

  SetLength(States, Size);
  InitMaskStates(MaskValue, States);
end;

function TReflexiveMask.MatchesMaskStates(const TextStr: string): Boolean;
type
  TStackRec = record
    sP: Integer;
    sCurrMask: Integer;
  end;
var
  CurrStack: Integer;
  Stack: array of TStackRec;
  CurrStartMask: Integer;
  P, i: Integer;

  procedure Push(P: Integer; CurrMask: Integer);
  begin
    Stack[CurrStack].sP := P;
    Stack[CurrStack].sCurrMask := CurrMask;
    Inc(CurrStack);
  end;

  function Pop(var P: Integer; var CurrMask: Integer): Boolean;
  begin
    if CurrStack = 0 then
      Result := False
    else
    begin
      Dec(CurrStack);
      P := Stack[CurrStack].sP;
      CurrMask := Stack[CurrStack].sCurrMask;
      Result := True;
    end;
  end;

  procedure Skip(var P: Integer; CurrMask: Integer);
  var
    ChunkStart: Integer;
  begin
    ChunkStart := P;

    case FMaskStates[CurrMask].State of
      msLiteral:
        while (TextStr.Chars[P] <> #0) and (UpCase(TextStr.Chars[P]) <> FMaskStates[CurrMask].Literal) do
          Inc(P);
      msMBCSLiteral:
        while (P < TextStr.Length) do
        begin
          if (TextStr.Chars[P] <> FMaskStates[CurrMask].LeadByte) then
            Inc(P, 2)
          else
          begin
            Inc(P);
            if (TextStr.Chars[P] = FMaskStates[CurrMask].TrailByte) then
              Break;
            Inc(P);
          end;
        end;
    end;

    FMaskStates[CurrMask].TextChunk := FMaskStates[CurrMask].TextChunk + TextStr.Substring(ChunkStart, P - ChunkStart);

    if P < TextStr.Length then
      Push(P + 1, CurrMask);
  end;

  function Matches(P: Integer; StartMask: Integer): Boolean;
  var
    CurrMask: Integer;
  begin
    Result := False;
    for CurrMask := StartMask to High(FMaskStates) do
    begin
      if FMaskStates[CurrMask].SkipTo then
        Skip(P, CurrMask);

      case FMaskStates[CurrMask].State of
        msLiteral:
          if UpCase(TextStr.Chars[P]) = FMaskStates[CurrMask].Literal then
            FMaskStates[CurrMask].TextChunk := FMaskStates[CurrMask].TextChunk + TextStr.Chars[P]
          else
            Exit;
        msMBCSLiteral:
          begin
            if TextStr.Chars[P] = FMaskStates[CurrMask].LeadByte then
              FMaskStates[CurrMask].TextChunk := FMaskStates[CurrMask].TextChunk + TextStr.Chars[P]
            else
              Exit;
            Inc(P);
            if TextStr.Chars[P] = FMaskStates[CurrMask].TrailByte then
              FMaskStates[CurrMask].TextChunk := FMaskStates[CurrMask].TextChunk + TextStr.Chars[P]
            else
              Exit;
          end;
        msAny:
          if P < TextStr.Length then
            FMaskStates[CurrMask].TextChunk := TextStr.Chars[P]
          else
            Exit(False);
      end;

      Inc(P);
    end;
    Result := True;
  end;

begin
  SetLength(Stack, MaxStack);
  for i := 0 to High(FMaskStates) do
    FMaskStates[i].TextChunk := '';
  Result := True;
  CurrStack := 0;
  P := 0;
  CurrStartMask := 0;
  repeat
    if Matches(P, CurrStartMask) then
      Exit;
  until not Pop(P, CurrStartMask);
  Result := False;
end;

function TReflexiveMask.RestoreText(const MaskValue: string): string;
var
  NewStates: TMaskStateArray;
  CurrWild, i: Integer;
  OldMask: TMaskState;

  function LocateOldMask: TMaskState;
  var
    NeedToSkip, i: Integer;
  begin
    NeedToSkip := CurrWild;

    for i := 0 to High(FMaskStates) do
      if (FMaskStates[i].State = msAny) or FMaskStates[i].SkipTo then
      begin
        Dec(NeedToSkip);
        if NeedToSkip = 0 then
          Exit(FMaskStates[i]);
      end;

    raise EReflexiveMaskException.Create('Old mask is too short');
  end;

begin
  Result := '';
  InitStatesArray(MaskValue, NewStates);
  CurrWild := 0;
  for i := 0 to High(NewStates) - 1 do
  begin
    if (NewStates[i].State = msAny) or NewStates[i].SkipTo then
    begin
      Inc(CurrWild);
      OldMask := LocateOldMask;
      if NewStates[i].State = msAny then
        NewStates[i].TextChunk := OldMask.TextChunk
      else
        NewStates[i].TextChunk := OldMask.TextChunk.Substring(0, OldMask.TextChunk.Length - 1) +
          NewStates[i].TextChunk;
    end;
    Result := Result + NewStates[i].TextChunk;
  end;
end;

class function TReflexiveMask.ContainsWildcards(const TextStr: string): Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := 1 to TextStr.Length do
    if TextStr[i] in ['*', '?'] then
      Exit(True);
end;

constructor TReflexiveMask.Create(const MaskValue: string);
begin
  inherited Create;
  InitStatesArray(MaskValue, FMaskStates);
end;

destructor TReflexiveMask.Destroy;
begin
  SetLength(FMaskStates, 0);
  inherited;
end;

function TReflexiveMask.Matches(const TextStr: string): Boolean;
begin
  Result := MatchesMaskStates(TextStr);
end;

function MatchesMask(const TextStr, Mask: string): Boolean;
var
  CMask: TReflexiveMask;
begin
  CMask := TReflexiveMask.Create(Mask);
  try
    Result := CMask.Matches(TextStr);
  finally
    CMask.Free;
  end;
end;

end.
