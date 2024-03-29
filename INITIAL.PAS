(******************************************************************)
(* Programmname    : INITIAL.PAS                                  *)
(* Programmautor   : Michael Rippl                                *)
(* Compiler        : Turbo Pascal V5.0                            *)
(* Letzte Änderung : 13-Apr-1990                                  *)
(* Inhalt          : Initialisierungen und Cleanup von PASCAL.PAS *)
(* Bemerkung       : Include Datei von PASCAL.PAS                 *)
(******************************************************************)

(* Belegte Resourcen freigeben, vorwärtsdeklariert *)
PROCEDURE CleanUp;
VAR k     : INTEGER;
BEGIN
   close(source);                                  (* Quelldatei schließen    *)
   close(target);                                  (* Zieldatei schließen     *)

   IF NOT AbleToRun THEN erase(target)             (* Programm fehlerhaft     *)
   ELSE
   BEGIN
      write(LineNumber : 1, ' lines, ');
      writeln(ProgCount * sizeof(Order) : 1, ' bytes code,');
      write(RealIndex * sizeof(REAL) : 1, ' bytes real constants, ');
      write(StringIndex * sizeof(CHAR) : 1, ' bytes characters, ');
      writeln(6 * sizeof(CHAR) + 4 * sizeof(INTEGER) : 1, ' bytes system use');
   END;

   k := 0;

   WHILE NOT RingIsEmpty(Remember[k]) DO           (* Speicher freigeben      *)
   BEGIN
      DeleteLevel(k);
      k := k + 1;
   END;

   FOR k := 0 TO LevelMax DO
   BEGIN
      DeleteRing(Remember[k]);                     (* Liste komplett löschen  *)
      DeleteRing(ForwardCall[k]);                  (* Liste komplett löschen  *)
   END;

   dispose(Code);                                  (* Programm freigeben      *)
END; (* CleanUp *)

(* Übergebene Parameter an den Compiler überprüfen *)
PROCEDURE CheckParameters;
BEGIN
   write('Pascal Compiler  Version 0.86a  ');
   writeln('Copyright (c) 1989, 1990 by Michael Rippl');
   writeln;

   IF paramcount <> 1 THEN
   BEGIN
      writeln('usage : pascal <filename>');
      halt;
   END;

   (*$I-*)                                         (* I/O Überprüfung aus     *)
   assign(source, paramstr(1) + '.pas');
   reset(source);                                  (* Quelldatei öffnen       *)

   IF ioresult <> 0 THEN
   BEGIN
      writeln('fatal error : unable to open ', paramstr(1) + '.pas');
      halt;
   END;

   assign(target, paramstr(1) + '.obj');           (* Zieldatei öffnen        *)
   rewrite(target, 1);                             (* Byteweise schreiben     *)

   IF ioresult <> 0 THEN
   BEGIN
      writeln('fatal error : unable to open ', paramstr(1) + '.obj');
      close(source);
      halt;
   END;
   (*$I+*)
END; (* CheckParameters *)

(* Variablen vorinitialisieren *)
PROCEDURE InitVariables;
VAR i         : INTEGER;
    Criterion : ARRAY [1..6] OF CHAR;
BEGIN
   Criterion := 'PASCAL';                          (* Zieldateikennung        *)
   (*$I-*)                                         (* I/O Überprüfung aus     *)
   blockwrite(target, Criterion, sizeof(Criterion));
   (*$I+*)                                         (* I/O Überprüfung an      *)

   new(Code);                                      (* Speicher für Programm   *)

   FOR i := 0 TO LevelMax DO
   BEGIN
      Display[i] := NIL;
      CreateRing(Remember[i]);
      CreateRing(ForwardCall[i]);
   END;

   Ch := ' ';
   Errors := [ ];                                  (* Leere Fehlermenge       *)
   StringIndex := 1;                               (* Leere Stringtabelle     *)
   RealIndex := 0;                                 (* Leere Realtabelle       *)
   ErrorPos := 0;
   NrOfErrors := 0;                                (* Keine Fehler            *)
   AbleToRun := TRUE;
   LineLen := 0;
   LineNumber := 0;                                (* Zeilennummer            *)
   CharCount := 0;
   ProgCount := 0;
   ProgramName := 'No Name         ';

   ConstBegSym := [Plus, Minus, IntConst, RealConst, CharConst, StringConst,
                   Identifier];
   TypeBegSym  := [Identifier, ArraySy, RecordSy, SetSy, FileSy, LeftParent,
                   PointerTo, PackedSy, Plus, Minus, IntConst, CharConst];
   BlockBegSym := [LabelSy, ConstSy, TypeSy, VarSy, ProcedureSy, FunctionSy,
                   BeginSy];
   FactBegSym  := [IntConst, RealConst, CharConst, StringConst, Identifier,
                   LeftBrack, LeftParent, NotSy, NilSy];
   StateBegSym := [BeginSy, IfSy, WhileSy, RepeatSy, ForSy, CaseSy, WithSy,
                   GotoSy];
   ScalarTypes := [NoType, Ints, Reals, Bools, Chars, Pointers, Subranges,
                   Enumerations];

   KeyWord[ 1] := 'and             ';     KeyWord[ 2] := 'array           ';
   KeyWord[ 3] := 'begin           ';     KeyWord[ 4] := 'case            ';
   KeyWord[ 5] := 'const           ';     KeyWord[ 6] := 'div             ';
   KeyWord[ 7] := 'do              ';     KeyWord[ 8] := 'downto          ';
   KeyWord[ 9] := 'else            ';     KeyWord[10] := 'end             ';
   KeyWord[11] := 'file            ';     KeyWord[12] := 'for             ';
   KeyWord[13] := 'forward         ';     KeyWord[14] := 'function        ';
   KeyWord[15] := 'goto            ';     KeyWord[16] := 'if              ';
   KeyWord[17] := 'in              ';     KeyWord[18] := 'label           ';
   KeyWord[19] := 'mod             ';     KeyWord[20] := 'nil             ';
   KeyWord[21] := 'not             ';     KeyWord[22] := 'of              ';
   KeyWord[23] := 'or              ';     KeyWord[24] := 'packed          ';
   KeyWord[25] := 'procedure       ';     KeyWord[26] := 'program         ';
   KeyWord[27] := 'record          ';     KeyWord[28] := 'repeat          ';
   KeyWord[29] := 'set             ';     KeyWord[30] := 'then            ';
   KeyWord[31] := 'to              ';     KeyWord[32] := 'type            ';
   KeyWord[33] := 'until           ';     KeyWord[34] := 'var             ';
   KeyWord[35] := 'while           ';     KeyWord[36] := 'with            ';

   KeySymbol[ 1] := AndSy;           KeySymbol[ 2] := ArraySy;
   KeySymbol[ 3] := BeginSy;         KeySymbol[ 4] := CaseSy;
   KeySymbol[ 5] := ConstSy;         KeySymbol[ 6] := IntDiv;
   KeySymbol[ 7] := DoSy;            KeySymbol[ 8] := DownToSy;
   KeySymbol[ 9] := ElseSy;          KeySymbol[10] := EndSy;
   KeySymbol[11] := FileSy;          KeySymbol[12] := ForSy;
   KeySymbol[13] := ForwardSy;       KeySymbol[14] := FunctionSy;
   KeySymbol[15] := GotoSy;          KeySymbol[16] := IfSy;
   KeySymbol[17] := InSy;            KeySymbol[18] := LabelSy;
   KeySymbol[19] := IntMod;          KeySymbol[20] := NilSy;
   KeySymbol[21] := NotSy;           KeySymbol[22] := OfSy;
   KeySymbol[23] := OrSy;            KeySymbol[24] := PackedSy;
   KeySymbol[25] := ProcedureSy;     KeySymbol[26] := ProgramSy;
   KeySymbol[27] := RecordSy;        KeySymbol[28] := RepeatSy;
   KeySymbol[29] := SetSy;           KeySymbol[30] := ThenSy;
   KeySymbol[31] := ToSy;            KeySymbol[32] := TypeSy;
   KeySymbol[33] := UntilSy;         KeySymbol[34] := VarSy;
   KeySymbol[35] := WhileSy;         KeySymbol[36] := WithSy;

   SpecialSym['+'] := Plus;          SpecialSym['-'] := Minus;
   SpecialSym['*'] := Mult;          SpecialSym['/'] := RealDiv;
   SpecialSym['('] := LeftParent;    SpecialSym[')'] := RightParent;
   SpecialSym['='] := Eql;           SpecialSym[','] := Comma;
   SpecialSym['['] := LeftBrack;     SpecialSym[']'] := RightBrack;
   SpecialSym[';'] := Semicolon;     SpecialSym['^'] := PointerTo;

   Enter('no type         ', Datatypes, NoType, 0);
   Enter('real            ', Datatypes, Reals, RealSize);
   Enter('char            ', Datatypes, Chars, CharSize);
   Enter('boolean         ', Datatypes, Bools, BoolSize);
   Enter('integer         ', Datatypes, Ints, IntSize);
   Enter('text            ', Datatypes, Files, FileSize);
   Enter('false           ', Constants, Bools, 0);
   Enter('true            ', Constants, Bools, 1);
   Enter('maxint          ', Constants, Ints, NumberMax);
   Enter('input           ', Variables, Files, FileSize);
   Enter('output          ', Variables, Files, FileSize);
   Enter('abs             ', Functions, Ints, 0);
   Enter('sqr             ', Functions, Ints, 2);
   Enter('odd             ', Functions, Bools, 4);
   Enter('chr             ', Functions, Chars, 5);
   Enter('ord             ', Functions, Ints, 6);
   Enter('succ            ', Functions, Chars, 7);
   Enter('pred            ', Functions, Chars, 8);
   Enter('round           ', Functions, Ints, 9);
   Enter('trunc           ', Functions, Ints, 10);
   Enter('sin             ', Functions, Reals, 11);
   Enter('cos             ', Functions, Reals, 12);
   Enter('exp             ', Functions, Reals, 13);
   Enter('ln              ', Functions, Reals, 14);
   Enter('sqrt            ', Functions, Reals, 15);
   Enter('arctan          ', Functions, Reals, 16);
   Enter('eof             ', Functions, Bools, 17);
   Enter('eoln            ', Functions, Bools, 18);
   Enter('read            ', Procedures, NoType, 1);
   Enter('readln          ', Procedures, NoType, 2);
   Enter('write           ', Procedures, NoType, 3);
   Enter('writeln         ', Procedures, NoType, 4);
   Enter('new             ', Procedures, NoType, 5);
   Enter('dispose         ', Procedures, NoType, 6);
   Enter('main program    ', Procedures, NoType, IsMainProg);
END; (* InitVariables *)

(* END INITIAL.PAS *)
