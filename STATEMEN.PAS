(*******************************************************)
(* Programmname    : STATEMEN.PAS                      *)
(* Programmautor   : Michael Rippl                     *)
(* Compiler        : Turbo Pascal V5.0                 *)
(* Letzte Änderung : 07-Mar-1990                       *)
(* Inhalt          : Pascal-Anweisungen von PASCAL.PAS *)
(* Bemerkung       : Include Datei von PARSER.PAS      *)
(*******************************************************)

(* Goto-Anweisung auswerten *)
PROCEDURE GotoStatement;
VAR Elt,
    GtoRem : pNode;                                (* Goto ohne Zieladresse   *)
    Found  : BOOLEAN;
BEGIN
   InSymbol;                                       (* Goto schon gelesen      *)

   IF Sym <> IntConst THEN Error(24)               (* Labelkonstante erwartet *)
   ELSE
   BEGIN
      Search(Id, Level, Elt, Found);

      IF NOT Found THEN Error(75)                  (* Label nicht deklariert  *)
      ELSE IF Elt^.Adr <> NilAddress THEN          (* Labeladresse bekannt    *)
      BEGIN
         WITH Elt^ DO
         BEGIN
            IF Stack - StackCorrection <> 0 THEN
               Emit1(CorrectStack, Stack - StackCorrection);

            Emit1(Jump, Adr);                      (* Unbedingter Sprung      *)
         END;
      END
      ELSE
      BEGIN                                        (* Labeladresse unbekannt  *)
         new(GtoRem);
         Push(Remember[Level], GtoRem, NIL);       (* Zum Löschen merken      *)
         GtoRem^ := Elt^;                          (* Inhalt von Label merken *)

         WITH GtoRem^ DO
         BEGIN
            Count := ProgCount;                    (* Programmzähler merken   *)
            Correct := StackCorrection;            (* Korrekturwert für Goto  *)
            LabelAdr := Elt;                       (* Label-Adresse später    *)
         END;

         Emit(CorrectStack);                       (* Stack Korrektur merken  *)
         Emit(Jump);                               (* Unbedingter Sprung      *)
         Push(GotoRemember, GtoRem, NIL);          (* An Prozedurende auswer. *)
      END;

      InSymbol;
   END;
END; (* GotoStatement *)

(* With-Anweisung auswerten *)
PROCEDURE WithStatement;
VAR Item : Node;
BEGIN
   InSymbol;                                       (* With schon gelesen      *)
   Expression([DoSy] + Symbols, Item);

   IF NOT (Item.Typ IN [NoType, Records]) THEN
      Error(101)                                   (* Record erwartet         *)
   ELSE
   BEGIN
      IF (Level = LevelMax) OR (WithLevel = WithMax) THEN
         Fatal(3);                                 (* Leveltabelle voll       *)

      Emit1(StoreWithAddress, WithLevel);          (* Record-Adresse merken   *)
      Level := Level + 1;
      WithLevel := WithLevel + 1;
      Display[Level] := Item.Ref^.RecordTree;
   END;

   IF Sym = DoSy THEN InSymbol
   ELSE Error(34);                                 (* Symbol Do erwartet      *)

   Statement(Symbols);

   IF Item.Typ IN [NoType, Records] THEN
   BEGIN
      Display[Level] := NIL;
      Level := Level - 1;
      WithLevel := WithLevel - 1;
   END;
END; (* WithStatement *)

(* Anweisungsblock auswerten *)
PROCEDURE CompoundStatement;
BEGIN
   InSymbol;                                       (* Begin schon gelesen     *)

   WHILE Sym = IntConst DO                         (* Labels auswerten        *)
      LabelStatement([Semicolon, EndSy, IntConst, Identifier] + Symbols);

   Statement([Semicolon, EndSy] + Symbols);        (* Anweisungen auswerten   *)

   WHILE Sym IN [Semicolon] + StateBegSym DO
   BEGIN
      IF Sym = Semicolon THEN InSymbol
      ELSE Error(23);                              (* Symbol ; erwartet       *)

      WHILE Sym = IntConst DO                      (* Labels auswerten        *)
         LabelStatement([Semicolon, EndSy, IntConst, Identifier] + Symbols);

      Statement([Semicolon, EndSy] + Symbols);     (* Anweisungen auswerten   *)
   END;

   IF Sym = EndSy THEN InSymbol
   ELSE Error(40);                                 (* Symbol end erwartet     *)
END; (* CompoundStatement *)

(* If-Anweisung auswerten *)
PROCEDURE IfStatement;
VAR Item      : Node;                              (* Ausdruck nach If        *)
    LocCount1,
    LocCount2 : INTEGER;                           (* Programmzähler merken   *)
BEGIN
   InSymbol;                                       (* If schon gelesen        *)
   Expression([ThenSy, DoSy] + Symbols, Item);

   IF NOT (Item.Typ IN [NoType, Bools]) THEN
      Error(149);                                  (* Typ Boolean erwartet    *)

   LocCount1 := ProgCount;                         (* Programmzähler merken   *)
   Emit(JumpConditional);                          (* Bedingter Sprung        *)

   IF Sym = ThenSy THEN InSymbol
   ELSE
   BEGIN
      Error(28);                                   (* Symbol Then erwartet    *)
      IF Sym = DoSy THEN InSymbol;
   END;

   Statement([ElseSy] + Symbols);

   IF Sym = ElseSy THEN                            (* If .. Then .. Else      *)
   BEGIN
      InSymbol;
      LocCount2 := ProgCount;                      (* Programmzähler merken   *)
      Emit(Jump);                                  (* Unbedingter Sprung      *)
      Code^[LocCount1].y := ProgCount;
      Statement(Symbols);
      Code^[LocCount2].y := ProgCount;
   END
   ELSE Code^[LocCount1].y := ProgCount;
END; (* IfStatement *)

(* Case-Anweisung auswerten *)
PROCEDURE CaseStatement;
VAR Item       : Node;                             (* Ausdruck nach Case      *)
    Labels,                                        (* Anzahl der Labels       *)
    Cases,                                         (* Anzahl der Cases        *)
    k,
    LocCount   : INTEGER;                          (* Programmzähler merken   *)

    CasesTable : ARRAY [1..CaseMax] OF             (* Case-Konstanten         *)
                   RECORD
                      Value,                       (* Wert einer Konstante    *)
                      Count : INTEGER;             (* Adresse des Statements  *)
                   END;
    ExitTable  : ARRAY [1..CaseMax] OF INTEGER;    (* Ende der Statements     *)

(* Konstanten der Case-Anweisung auswerten, ein Label pro Aufruf *)
PROCEDURE CaseLabel;
VAR Lab : Node;                                    (* Einzelne Case-Konstante *)
    k   : INTEGER;
BEGIN
   Constant([Comma, Colon, EndSy] + Symbols, Lab);

   IF Lab.Ref <> Item.Ref THEN Error(152)          (* Unzulässiges Case-Label *)
   ELSE IF Labels = CaseMax THEN Fatal(9)          (* Case-Tabelle voll       *)
   ELSE
   BEGIN
      Labels := Labels + 1;
      k := 0;
      CasesTable[Labels].Value := Lab.Value;
      CasesTable[Labels].Count := ProgCount;       (* Programmzähler merken   *)

      REPEAT                                       (* Prüfen ob Label doppelt *)
         k := k + 1;
      UNTIL CasesTable[k].Value = Lab.Value;

      IF k < Labels THEN Error(77);                (* Case-Label doppelt      *)
   END;
END; (* CaseLabel *)

(* Ein Case-Statement auswerten *)
PROCEDURE OneCase;
BEGIN
   IF Sym IN ConstBegSym THEN
   BEGIN
      CaseLabel;                                   (* Labels auswerten        *)

      WHILE Sym = Comma DO
      BEGIN
         InSymbol;
         CaseLabel;
      END;

      IF Sym = Colon THEN InSymbol
      ELSE Error(37);                              (* Symbol : erwartet       *)

      Statement([Semicolon, EndSy] + Symbols);

      Cases := Cases + 1;
      ExitTable[Cases] := ProgCount;               (* Programmzähler merken   *)
      Emit(Jump);
   END;
END; (* OneCase *)

BEGIN (* CaseStatement *)
   InSymbol;                                       (* Case schon gelesen      *)
   Labels := 0;
   Cases := 0;
   Expression([OfSy, Comma, Colon] + Symbols, Item);

   IF NOT (Item.Typ IN [NoType, Ints, Bools, Chars, Enumerations]) THEN
      Error(140);                                  (* Unzulässiger Ausdruck   *)

   LocCount := ProgCount;                          (* Programmzähler merken   *)
   Emit(CaseSwitch);                               (* Switch (JmpX)           *)

   IF Sym = OfSy THEN InSymbol
   ELSE Error(36);                                 (* Symbol Of erwartet      *)

   OneCase;                                        (* Anweisungen auswerten   *)

   WHILE Sym = Semicolon DO
   BEGIN
      InSymbol;
      OneCase;
   END;

   Code^[LocCount].y := ProgCount;                 (* Anfang der Case-Tabelle *)

   FOR k := 1 TO Labels DO                         (* Tabelle ausgeben        *)
   BEGIN
      Emit1(CaseTable, CasesTable[k].Value);       (* Wert der Konstanten     *)
      Emit1(CaseTable, CasesTable[k].Count);       (* Adresse des Statements  *)
   END;

   Emit1(Jump, 0);                                 (* Nur Dummy, Tabellenende *)

   FOR k := 1 TO Cases DO                          (* Exit der Statements     *)
      Code^[ExitTable[k]].y := ProgCount;

   IF Sym = EndSy THEN InSymbol
   ELSE Error(40);                                 (* Symbol End erwartet     *)
END; (* CaseStatement *)

(* While-Anweisung auswerten *)
PROCEDURE WhileStatement;
VAR Item      : Node;                              (* Ausdruck nach While     *)
    LocCount1,
    LocCount2 : INTEGER;                           (* Programmzähler merken   *)
BEGIN
   InSymbol;                                       (* While schon gelesen     *)
   LocCount1 := ProgCount;                         (* Programmzähler merken   *)
   Expression([DoSy] + Symbols, Item);

   IF NOT (Item.Typ IN [NoType, Bools]) THEN
      Error(149);                                  (* Typ Boolean erwartet    *)

   LocCount2 := ProgCount;                         (* Programmzähler merken   *)
   Emit(JumpConditional);                          (* Bedingter Sprung        *)

   IF Sym = DoSy THEN InSymbol
   ELSE Error(34);                                 (* Symbol Do erwartet      *)

   Statement(Symbols);
   Emit1(Jump, LocCount1);                         (* Unbedingter Sprung      *)
   Code^[LocCount2].y := ProgCount;
END; (* WhileStatement *)

(* Repeat-Anweisung auswerten *)
PROCEDURE RepeatStatement;
VAR Item     : Node;                               (* Ausdruck nach Until     *)
    LocCount : INTEGER;                            (* Programmzähler merken   *)
BEGIN
   LocCount := ProgCount;                          (* Programmzähler merken   *)
   InSymbol;                                       (* Repeat schon gelesen    *)

   WHILE Sym = IntConst DO                         (* Labels auswerten        *)
      LabelStatement([Semicolon, UntilSy, IntConst, Identifier] + Symbols);

   Statement([Semicolon, UntilSy] + Symbols);      (* Anweisungen auswerten   *)

   WHILE Sym IN [Semicolon] + StateBegSym DO
   BEGIN
      IF Sym = Semicolon THEN InSymbol
      ELSE Error(23);                              (* Symbol ; erwartet       *)

      WHILE Sym = IntConst DO                      (* Labels auswerten        *)
         LabelStatement([Semicolon, UntilSy, IntConst, Identifier] + Symbols);

      Statement([Semicolon, UntilSy] + Symbols);   (* Anweisungen auswerten   *)
   END;

   IF Sym = UntilSy THEN
   BEGIN
      InSymbol;
      Expression(Symbols, Item);

      IF NOT (Item.Typ IN [NoType, Bools]) THEN
         Error(149);                               (* Typ Boolean erwartet    *)

      Emit1(JumpConditional, LocCount);            (* Bedingter Sprung        *)
   END
   ELSE Error(32);                                 (* Symbol Until erwartet   *)
END; (* RepeatStatement *)

(* For-Anweisung auswerten *)
PROCEDURE ForStatement;
VAR CtrlVarType : Types;                           (* Kontrollvariable        *)
    Item,
    Item2       : Node;                            (* Ausdrücke               *)
    Elt         : pNode;
    FoundAt     : INTEGER;
    OutputCode  : Orders;                          (* Übersetzungscode        *)
    LocCount1,
    LocCount2   : INTEGER;                         (* Programmzähler merken   *)
BEGIN
   InSymbol;                                       (* For schon gelesen       *)

   IF Sym = Identifier THEN                        (* Kontrollvariable        *)
   BEGIN
      Locate(Id, Level, Elt, FoundAt);
      InSymbol;

      IF FoundAt < 0 THEN CtrlVarType := Ints      (* Variable nicht gefunden *)
      ELSE
      BEGIN
         Item := Elt^;

         LoadVarAddress([Becomes, ToSy, DownToSy, DoSy] + Symbols, FoundAt,
                        Item);                     (* Adresse auf Stack       *)

         IF Item.Obj = Variables THEN
         BEGIN
            CtrlVarType := Item.Typ;

            IF NOT (CtrlVarType IN [Ints, Bools, Chars, Subranges, Enumerations,
                    NoType]) THEN Error(150);      (* Typ unzulässig          *)
         END
         ELSE
         BEGIN
            Error(66);                             (* Variable erwartet       *)
            CtrlVarType := Ints;
         END;
      END;
   END                                             (* Bezeichner erwartet     *)
   ELSE Skip([Becomes, ToSy, DownToSy, DoSy] + Symbols, 20);

   IF Sym = Becomes THEN
   BEGIN
      InSymbol;
      Expression([ToSy, DownToSy, DoSy], Item2);

      IF (CtrlVarType = Subranges) AND
         (Item2.Typ IN [Ints, Bools, Chars, Enumerations]) THEN
      BEGIN
         IF Item.Ref^.RangeType = Item2.Ref THEN
         BEGIN
            IF Item2.Obj = Constants THEN          (* Konstanter Ausdruck     *)
            BEGIN
               IF (Item2.Value < Item.Ref^.RangeLow) OR
                  (Item2.Value > Item.Ref^.RangeHigh) THEN
                     Error(203);                   (* Unzulässige Konstante   *)
            END
            ELSE                                   (* Bereichsprüfung         *)
            BEGIN
               Emit1(LoadInteger, Item.Ref^.RangeHigh);
               Emit1(CheckConstantRange, Item.Ref^.RangeLow);
            END;
         END
         ELSE Error(151);                          (* Typen inkompatibel      *)
      END
      ELSE IF Item.Ref <> Item2.Ref THEN
         Error(151);                               (* Typen inkompatibel      *)
   END
   ELSE Skip([ToSy, DownToSy, DoSy], 26);          (* Symbol := erwartet      *)

   OutputCode := ForBeginUp;                       (* Übersetzung             *)

   IF Sym IN [ToSy, DownToSy] THEN
   BEGIN
      IF Sym = DownToSy THEN OutputCode := ForBeginDown;
      InSymbol;
      Expression([DoSy] + Symbols, Item2);

      IF (CtrlVarType = Subranges) AND
         (Item2.Typ IN [Ints, Bools, Chars, Enumerations]) THEN
      BEGIN
         IF Item.Ref^.RangeType = Item2.Ref THEN
         BEGIN
            IF Item2.Obj = Constants THEN          (* Konstanter Ausdruck     *)
            BEGIN
               IF (Item2.Value < Item.Ref^.RangeLow) OR
                  (Item2.Value > Item.Ref^.RangeHigh) THEN
                     Error(203);                   (* Unzulässige Konstante   *)
            END
            ELSE                                   (* Bereichsprüfung         *)
            BEGIN
               Emit1(LoadInteger, Item.Ref^.RangeHigh);
               Emit1(CheckConstantRange, Item.Ref^.RangeLow);
            END;
         END
         ELSE Error(151);                          (* Typen inkompatibel      *)
      END
      ELSE IF Item.Ref <> Item2.Ref THEN
         Error(151);                               (* Typen inkompatibel      *)
   END
   ELSE Skip([DoSy] + Symbols, 56);               (* Symbol (Down)To erwartet *)

   IF Sym = DoSy THEN InSymbol
   ELSE Error(34);                                 (* Symbol Do erwartet      *)

   LocCount1 := ProgCount;                         (* Programmzähler merken   *)
   Emit(OutputCode);
   LocCount2 := ProgCount;                         (* Programmzähler merken   *)
   StackCorrection := StackCorrection + 3;         (* Stack Korrektur f. Goto *)
   Statement(Symbols);
   StackCorrection := StackCorrection - 3;         (* Stack Korrektur f. Goto *)

   IF OutputCode = ForBeginUp THEN Emit1(ForEndUp, LocCount2)
   ELSE Emit1(ForEndDown, LocCount2);

   Code^[LocCount1].y := ProgCount;
END; (* ForStatement *)

(* Variablenzuweisung. Auch ganze Arrays, Records und Strings sind erlaubt. *)
PROCEDURE Assignment(ItemTarget : Node; FoundAt : INTEGER);
VAR ItemSource : Node;                             (* Ausdruck, rechts von := *)
BEGIN
   IF ItemTarget.Obj = Functions THEN              (* Rückgabe einer Funktion *)
   BEGIN
      ItemTarget.Adr := 0;
      ItemTarget.Lev := ItemTarget.Lev + 1;
   END;

   LoadVarAddress([Becomes, Eql] + Symbols, FoundAt, ItemTarget);

   IF Sym = Becomes THEN InSymbol
   ELSE
   BEGIN
      Error(26);                                   (* Symbol := erwartet      *)
      IF Sym = Eql THEN InSymbol;
   END;

   Expression(Symbols, ItemSource);                (* Rechte Seite auswerten  *)

   IF (ItemTarget.Typ = Subranges) AND             (* Unterbereiche           *)
      (ItemSource.Typ IN [Ints, Bools, Chars, Enumerations]) THEN
   BEGIN
      IF ItemTarget.Ref^.RangeType = ItemSource.Ref THEN
      BEGIN
         IF ItemSource.Obj = Constants THEN        (* Konstante rechte Seite  *)
         BEGIN
            IF (ItemSource.Value < ItemTarget.Ref^.RangeLow) OR
               (ItemSource.Value > ItemTarget.Ref^.RangeHigh) THEN
                  Error(203)                       (* Unzulässige Konstante   *)
            ELSE Emit(StoreValue);                 (* Konstante speichern     *)
         END
         ELSE
         BEGIN
            Emit1(LoadInteger, ItemTarget.Ref^.RangeHigh);
            Emit1(StoreSubrange, ItemTarget.Ref^.RangeLow);
         END;
      END
      ELSE Error(145);                             (* Typen inkompatibel      *)
   END
   ELSE IF (ItemTarget.Typ = Arrays) AND           (* Ganze Felder, Strings   *)
      (ItemSource.Typ IN [Strings, Arrays]) THEN
   BEGIN
      IF ItemSource.Typ = Arrays THEN              (* Ganze Felder            *)
      BEGIN
         IF ItemTarget.Ref <> ItemSource.Ref THEN
            Error(145);                            (* Typen inkompatibel      *)

         IF ItemSource.Ref^.ElementType^.Typ = Chars THEN
            Emit1(StoreArrayChar, ItemSource.Size)
         ELSE Emit1(CopyBlock, ItemSource.Size);
      END
      ELSE                                         (* Strings                 *)
      BEGIN
         IF (ItemTarget.Ref^.ElementType^.Typ <> Chars) OR
            (ItemTarget.Size <> ItemSource.Size) THEN Error(145)
         ELSE Emit1(StoreArrayChar, ItemSource.Size);
      END;
   END
   ELSE IF ItemTarget.Typ = ItemSource.Typ THEN    (* Typengleichheit         *)
   BEGIN
      IF ItemTarget.Typ IN ScalarTypes THEN
      BEGIN
         IF ItemTarget.Typ = Pointers THEN         (* Zuweisung von Zeigern   *)
         BEGIN
            IF ItemSource.Obj <> Constants THEN    (* Keine Nil Konstante     *)
               IF ItemTarget.Ref <> ItemSource.Ref THEN
                  Error(145);                      (* Typen inkompatibel      *)
         END
         ELSE IF ItemTarget.Ref <> ItemSource.Ref THEN Error(145);

         Emit(StoreValue);                         (* Wert speichern          *)
      END
      ELSE IF ItemTarget.Typ = Sets THEN           (* Mengen                  *)
      BEGIN
         ;                                         (* Nicht implementiert     *)
      END
      ELSE IF ItemTarget.Typ = Records THEN        (* Records                 *)
      BEGIN
         IF ItemTarget.Ref <> ItemSource.Ref THEN
            Error(145);                            (* Typen inkompatibel      *)

         Emit1(CopyBlock, ItemTarget.Size);        (* Ganzes Record kopieren  *)
      END
      ELSE Error(160);                             (* Zuweisung verboten      *)
   END
   ELSE IF (ItemTarget.Typ = Reals) AND (ItemSource.Typ = Ints) THEN
   BEGIN
      Emit1(IntegerToReal, 0);                     (* Int Source nach Real    *)
      Emit(StoreValue);                            (* Wert speichern          *)
   END
   ELSE IF (ItemTarget.Typ <> NoType) AND (ItemSource.Typ <> NoType) THEN
      Error(145);                                  (* Typen inkompatibel      *)
END; (* Assignment *)

(* Aufruf einer Standardprozedur auswerten *)
PROCEDURE StandardProcedure(CalledNumber : INTEGER);
VAR Elt          : pNode;
    Item,
    Item2        : Node;
    FoundAt      : INTEGER;
    FilePossible : BOOLEAN;                        (* Nur eine Dateivariable  *)
BEGIN
   CASE CalledNumber OF
      1, 2 :                                       (* Read, ReadLn            *)
      BEGIN
         FilePossible := TRUE;                     (* Dateivariable möglich   *)

         IF Sym = LeftParent THEN
         BEGIN
            REPEAT                                 (* Parameter auswerten     *)
               InSymbol;

               IF Sym <> Identifier THEN Error(20) (* Identifier erwartet     *)
               ELSE
               BEGIN
                  Locate(Id, Level, Elt, FoundAt);
                  InSymbol;

                  IF FoundAt >= 0 THEN
                  BEGIN
                     Item := Elt^;

                     IF Item.Obj <> Variables THEN
                        Error(66)                  (* Variable erwartet       *)
                     ELSE
                     BEGIN
                        LoadVarAddress([Comma, RightParent] + Symbols, FoundAt,
                                       Item);      (* Adresse auf Stack       *)

                        IF Item.Typ IN [NoType, Ints, Reals, Chars] THEN
                           Emit1(ReadValue, ord(Item.Typ))
                        ELSE IF Item.Typ = Files THEN  (* Dateivariable       *)
                        BEGIN
                           IF NOT FilePossible THEN
                              Error(64)            (* Datei nicht erlaubt     *)
                           ELSE
                           BEGIN
                              ;                    (* Nicht implementiert     *)
                           END;
                        END
                        ELSE Error(64);            (* Unzulässige Eingabe     *)
                     END;
                  END;
               END;

               FilePossible := FALSE;              (* Dateien nicht möglich   *)
            UNTIL Sym <> Comma;

            IF Sym = RightParent THEN InSymbol
            ELSE Error(41);                        (* Symbol ) erwartet       *)
         END;

         IF CalledNumber = 2 THEN Emit(OnlyReadLn);
      END;

      3, 4 :                                       (* Write, WriteLn          *)
      BEGIN
         FilePossible := TRUE;                     (* Dateivariable möglich   *)

         IF Sym = LeftParent THEN
         BEGIN
            REPEAT                                 (* Parameter auswerten     *)
               InSymbol;

               Expression([Comma, Colon, RightParent] + Symbols, Item);

               IF Sym = Colon THEN                 (* Formatierte Ausgabe     *)
               BEGIN
                  IF NOT (Item.Typ IN [Ints, Reals, Bools, Chars]) THEN
                     Error(64);                    (* Unzulässige Ausgabe     *)

                  InSymbol;
                  Expression([Comma, Colon, RightParent] + Symbols, Item2);

                  IF Item2.Typ <> Ints THEN
                     Error(139);                   (* Typ Integer erwartet    *)

                  IF Sym = Colon THEN              (* Formatierte Real        *)
                  BEGIN
                     IF Item.Typ <> Reals THEN
                        Error(137);                (* Typ Real erwartet       *)

                     InSymbol;
                     Expression([Comma, RightParent] + Symbols, Item2);

                     IF Item2.Typ <> Ints THEN
                        Error(139);                (* Typ Integer erwartet    *)

                     Emit(WriteFormattedReal);
                  END
                  ELSE Emit1(WriteFormatted, ord(Item.Typ));
               END
               ELSE IF Item.Typ IN [Ints, Reals, Bools, Chars, Strings, Arrays]
                  THEN
               BEGIN
                  IF Item.Typ = Arrays THEN
                     IF Item.Ref^.ElementType^.Typ <> Chars THEN
                        Error(64);                 (* Unzulässige Ausgabe     *)

                  IF Item.Typ IN [Strings, Arrays] THEN
                     Emit1(WriteString, Item.Size)
                  ELSE Emit1(WriteStandard, ord(Item.Typ));
               END
               ELSE IF Item.Typ = Files THEN       (* Dateivariable           *)
               BEGIN
                  IF NOT FilePossible THEN
                     Error(64)                     (* Datei nicht erlaubt     *)
                  ELSE
                  BEGIN
                     ;                             (* Nicht implementiert     *)
                  END;
               END
               ELSE Error(64);                     (* Unzulässige Ausgabe     *)

               FilePossible := FALSE;              (* Dateien nicht möglich   *)
            UNTIL Sym <> Comma;

            IF Sym = RightParent THEN InSymbol
            ELSE Error(41);                        (* Symbol ) erwartet       *)
         END;

         IF CalledNumber = 4 THEN Emit(OnlyWriteLn);
      END;

      5 :                                          (* New                     *)
      BEGIN
         IF Sym <> LeftParent THEN Error(45)       (* Symbol ( erwartet       *)
         ELSE
         BEGIN
            InSymbol;

            IF Sym <> Identifier THEN Error(20)    (* Bezeichner erwartet     *)
            ELSE
            BEGIN
               Locate(Id, Level, Elt, FoundAt);
               InSymbol;

               IF FoundAt >= 0 THEN
               BEGIN
                  Item := Elt^;
                  LoadVarAddress([Comma, RightParent] + Symbols, FoundAt, Item);

                  IF (Item.Obj <> Variables) OR (Item.Typ <> Pointers) THEN
                     Error(65)                     (* Zeigervariable erwartet *)
                  ELSE
                  BEGIN
                     Emit1(LoadPointerAddress, Item.Ref^.PointerType^.Size);
                     Emit(StoreValue);
                  END;
               END;
            END;

            IF Sym = RightParent THEN InSymbol
            ELSE Error(41);                        (* Symbol ) erwartet       *)
         END;
      END;

      6 :                                          (* Dispose                 *)
      BEGIN
         IF Sym <> LeftParent THEN Error(45)       (* Symbol ( erwartet       *)
         ELSE
         BEGIN
            InSymbol;

            IF Sym <> Identifier THEN Error(20)    (* Bezeichner erwartet     *)
            ELSE
            BEGIN
               Locate(Id, Level, Elt, FoundAt);
               InSymbol;

               IF FoundAt >= 0 THEN
               BEGIN
                  Item := Elt^;
                  LoadVarAddress([Comma, RightParent] + Symbols, FoundAt, Item);

                  IF (Item.Obj <> Variables) OR (Item.Typ <> Pointers) THEN
                     Error(65)                     (* Zeigervariable erwartet *)
                  ELSE Emit(FreeMemory);
               END;
            END;

            IF Sym = RightParent THEN InSymbol
            ELSE Error(41);                        (* Symbol ) erwartet       *)
         END;
      END;
   END;
END; (* StandardProcedure *)

(* END STATEMEN.PAS *)
