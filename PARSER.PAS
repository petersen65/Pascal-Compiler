(**************************************************************************)
(* Programmname    : PARSER.PAS                                           *)
(* Programmautor   : Michael Rippl                                        *)
(* Compiler        : Turbo Pascal V5.0                                    *)
(* Letzte Änderung : 13-Apr-1990                                          *)
(* Inhalt          : Syntaxüberprüfung und Codegenerierung von PASCAL.PAS *)
(* Bemerkung       : Include Datei von PASCAL.PAS                         *)
(**************************************************************************)

(* Übersetzung eines Prozedurkörpers *)
PROCEDURE Block(Symbols : SymbolSet; Level : INTEGER; ProcElement : pNode;
                IsFunction : BOOLEAN);
VAR StackCorrection,                               (* Stack-Korrektur         *)
    WithLevel,                                     (* Level von With          *)
    DataOffset        : INTEGER;                   (* Stackoffset             *)
    GotoRemember,                                  (* Unvollständige Goto's   *)
    LabelRemember,                                 (* Deklarierte Labels      *)
    PointerRemember,                               (* Zeiger                  *)
    ProcedureRemember : pRing;                     (* Forward-Prozeduren      *)
    Elt               : pNode;
    FoundAt,
    NrOfBytes         : INTEGER;                   (* Schreiben in Datei      *)
    Dummy             : pType;                     (* Dummy für Funktionen    *)

(*$I TYPE.PAS*)                                    (* Datentypen, Konstanten  *)
(*$I DECLARA.PAS*)                                 (* Deklarationen           *)

(* Sprungmarken auswerten *)
PROCEDURE LabelStatement(Symbols : SymbolSet);
VAR Elt   : pNode;
    Found : BOOLEAN;
BEGIN
   Search(Id, Level, Elt, Found);

   IF NOT Found THEN Error(75)                     (* Label nicht deklariert  *)
   ELSE IF Elt^.Adr <> NilAddress THEN Error(76)   (* Label zweimal definiert *)
   ELSE
   BEGIN
      DeleteElement(LabelRemember, Elt);           (* Gemerktes Label löschen *)
      Elt^.Adr := ProgCount;                       (* Aktuelle Adresse        *)
      Elt^.Stack := StackCorrection;               (* Stack-Korrektur         *)
   END;

   InSymbol;

   IF Sym = Colon THEN InSymbol
   ELSE Error(37);                                 (* Symbol : erwartet       *)

   Match(Symbols, [ ], 6);
END; (* LabelStatement *)

(* Pascal-Anweisungen auswerten *)
PROCEDURE Statement(Symbols : SymbolSet);
VAR Elt     : pNode;
    FoundAt : INTEGER;

(* Vorwärtsdeklariert *)
(* Einfache Ausdrücke (getrennt durch <, <=, <>, >, >=, =, in) auswerten *)
PROCEDURE Expression(Symbols : SymbolSet; VAR Item : Node); FORWARD;

(* Selektoren von Arrays, Records und Pointern auswerten *)
PROCEDURE Selector(Symbols : SymbolSet; VAR Item : Node);
VAR Elt   : pNode;
    Found : BOOLEAN;
    Index : Node;
BEGIN
   REPEAT
      IF Sym = Period THEN                         (* Verbundvariable         *)
      BEGIN
         InSymbol;

         IF Sym <> Identifier THEN Error(20)       (* Bezeichner erwartet     *)
         ELSE
         BEGIN
            IF Item.Typ <> Records THEN Error(142) (* Record erwartet         *)
            ELSE
            BEGIN
               IF Level = LevelMax THEN Fatal(3);  (* Leveltabelle voll       *)
               Level := Level + 1;

               Display[Level] :=
                  Item.Ref^.RecordTree;            (* Teilbaum des Records    *)

               Search(Id, Level, Elt, Found);      (* Verbundvariable suchen  *)

               IF Found THEN
               BEGIN
                  Item := Elt^;
                  IF Item.Adr <> 0 THEN Emit1(AddOffset, Item.Adr);
               END
               ELSE Error(73);                     (* Bezeichner unbekannt    *)

               Display[Level] := NIL;              (* Teilbaum wieder löschen *)
               Level := Level - 1;
            END;

            InSymbol;
         END;
      END
      ELSE IF Sym = PointerTo THEN                 (* Zeigervariable          *)
      BEGIN
         InSymbol;

         WITH Item DO
         BEGIN
            IF (Typ <> Pointers) OR (Obj <> Variables) THEN
               Error(146)                          (* Keine Zeigervariable    *)
            ELSE
            BEGIN
               Emit(LoadIndirectToTop);            (* Inhalt ist Adresse      *)
               Emit(CheckPointerAddress);          (* Nil-Zugriff prüfen      *)

               Ref := Ref^.PointerType;            (* Typ-Referenz vom Zeiger *)
               Typ := Ref^.Typ;
               Size := Ref^.Size;
            END;
         END;
      END
      ELSE                                         (* Feldvariable            *)
      BEGIN
         IF Sym <> LeftBrack THEN Error(21);       (* Symbol [ erwartet       *)

         REPEAT                                    (* Index auswerten         *)
            InSymbol;
            Expression([Comma, RightBrack] + Symbols, Index);

            IF Item.Typ = Arrays THEN
            BEGIN
               WITH Item DO
               BEGIN
                  IF Ref^.IndexType^.RangeType <> Index.Ref THEN
                     Error(120)                    (* Inkompatibler Indextyp  *)
                  ELSE
                  BEGIN
                     IF Index.Obj = Constants THEN (* Konstanter Index        *)
                     BEGIN
                        IF (Index.Value < Ref^.IndexType^.RangeLow) OR
                           (Index.Value > Ref^.IndexType^.RangeHigh) THEN
                              Error(200)           (* Unzulässiger Index      *)
                        ELSE IF Ref^.ElementType^.Size = 1 THEN
                           Emit1(SimpleArrayIndex, Ref^.IndexType^.RangeLow)
                        ELSE
                        BEGIN
                           Emit1(LoadInteger, Ref^.ElementType^.Size);
                           Emit1(ArrayIndex, Ref^.IndexType^.RangeLow);
                        END;
                     END
                     ELSE                          (* Variabler Index         *)
                     BEGIN
                        Emit1(LoadInteger, Ref^.IndexType^.RangeHigh);
                        Emit1(CheckArrayIndex, Ref^.IndexType^.RangeLow);

                        IF Ref^.ElementType^.Size = 1 THEN
                           Emit1(SimpleArrayIndex, Ref^.IndexType^.RangeLow)
                        ELSE
                        BEGIN
                           Emit1(LoadInteger, Ref^.ElementType^.Size);
                           Emit1(ArrayIndex, Ref^.IndexType^.RangeLow);
                        END;
                     END;
                  END;

                  WITH Item DO
                  BEGIN
                     Ref := Ref^.ElementType;      (* Nächste Dimension       *)
                     Typ := Ref^.Typ;
                     Size := Ref^.Size;
                  END;
               END;
            END
            ELSE Error(147);                       (* Array erwartet          *)
         UNTIL Sym <> Comma;

         IF Sym = RightBrack THEN InSymbol
         ELSE
         BEGIN
            Error(22);                             (* Symbol ] erwartet       *)
            IF Sym = RightParent THEN InSymbol;
         END;
      END;
   UNTIL NOT (Sym IN [LeftBrack, LeftParent, Period, PointerTo]);

   Match(Symbols, [ ], 6);
END; (* Selector *)

(* Lädt die Adresse einer Variablen auf den Stack *)
PROCEDURE LoadVarAddress(Symbols : SymbolSet; FoundAt : INTEGER;
                         VAR Item : Node);
VAR OutputCode : Orders;
BEGIN
   IF (WithLevel > 0) AND (FoundAt > Level - WithLevel) THEN
   BEGIN
      Emit1(LoadWithAddress, (WithLevel - (Level - FoundAt)) - 1);
      IF Item.Adr <> 0 THEN Emit1(AddOffset, Item.Adr);
   END
   ELSE
   BEGIN
      IF Item.Nrm THEN
         OutputCode := LoadAddress                 (* Normale Variable        *)
      ELSE OutputCode := LoadValue;                (* Parameter               *)

      Emit2(OutputCode, Item.Lev, Item.Adr);
   END;

   IF Sym IN [LeftBrack, LeftParent, Period, PointerTo] THEN
      Selector(Symbols, Item);
END; (* LoadVarAddress *)

(* Prozeduraufruf auswerten *)
PROCEDURE Call(Symbols : SymbolSet; CalledProcedure : pNode);
VAR Parameter  : pNode;                            (* Aktueller Parameter     *)
    RingElt    : pRing;                            (* Aktuelles Ringelement   *)
    Item       : Node;                             (* Arithmetischer Ausdruck *)
    CallRem,                                       (* Call merken             *)
    Elt        : pNode;
    FoundAt    : INTEGER;
BEGIN
   WITH CalledProcedure^ DO
   BEGIN
      IF (Adr = IsForward) OR (Adr = NilAddress) THEN
      BEGIN                                        (* Call ohne Zieladresse   *)
         new(CallRem);
         CallRem^ := CalledProcedure^;             (* Inhalt merken           *)

         CallRem^.CallCount := ProgCount;          (* Programmzähler merken   *)
         CallRem^.ProcAdr := CalledProcedure;      (* Daten später bearbeiten *)

         IF Adr = IsForward THEN Push(ForwardCall[Lev], CallRem, NIL)
         ELSE Push(ForwardCall[Lev + 1], CallRem, NIL);
      END;

      Emit1(MarkStack, VarSize);                   (* Aufruf vorbereiten      *)
      RingElt := Par;                              (* Zeigt auf Listenkopf    *)
   END;

   IF Sym = LeftParent THEN
   BEGIN
      REPEAT
         InSymbol;

         IF RingElt^.Next = CalledProcedure^.Par THEN
         BEGIN
            Error(132);                            (* Zu viele Parameter      *)

            IF Sym IN FactBegSym THEN
               Expression([Comma, RightParent] + Symbols, Item);
         END
         ELSE
         BEGIN
            RingElt := RingElt^.Next;
            Parameter := RingElt^.ObjectContent;   (* Aktueller Parameter     *)

            IF Parameter^.Nrm THEN                 (* Call By Value           *)
            BEGIN
               Expression([Comma, RightParent] + Symbols, Item);

               IF (Parameter^.Typ = Subranges) AND (* Unterbereiche           *)
                  (Item.Typ IN [Ints, Bools, Chars, Enumerations]) THEN
               BEGIN
                  IF Parameter^.Ref^.RangeType = Item.Ref THEN
                  BEGIN
                     IF Item.Obj = Constants THEN  (* Konstanter Ausdruck     *)
                     BEGIN
                        IF (Item.Value < Parameter^.Ref^.RangeLow) OR
                           (Item.Value > Parameter^.Ref^.RangeHigh) THEN
                              Error(203);          (* Unzulässige Konstante   *)
                     END
                     ELSE
                     BEGIN
                        Emit1(LoadInteger, Item.Ref^.RangeHigh);
                        Emit1(CheckConstantRange, Item.Ref^.RangeLow);
                     END;
                  END
                  ELSE Error(134);                 (* Unzulässiger Parameter  *)
               END
               ELSE IF (Parameter^.Typ = Arrays) AND (* Ganze Felder, Strings *)
                  (Item.Typ IN [Strings, Arrays]) THEN
               BEGIN
                  IF Item.Typ = Arrays THEN        (* Ganze Felder            *)
                  BEGIN
                     IF Parameter^.Ref <> Item.Ref THEN Error(134);

                     IF Item.Ref^.ElementType^.Typ <> Chars THEN
                        Emit1(LoadBlock, Item.Size);
                  END
                  ELSE                             (* Strings                 *)
                  BEGIN
                     IF (Parameter^.Ref^.ElementType^.Typ <> Chars) OR
                        (Parameter^.Size <> Item.Size) THEN
                           Error(134);
                  END;
               END
               ELSE IF Parameter^.Typ = Item.Typ THEN    (* Typengleichheit   *)
               BEGIN
                  IF Item.Typ IN ScalarTypes THEN
                  BEGIN
                     IF Item.Typ = Pointers THEN
                     BEGIN
                        IF Item.Obj <> Constants THEN  (* Keine Nil Konstante *)
                           IF Parameter^.Ref <> Item.Ref THEN
                              Error(134);
                     END
                     ELSE IF Parameter^.Ref <> Item.Ref THEN Error(134);
                  END
                  ELSE IF Item.Typ = Sets THEN     (* Mengen                  *)
                  BEGIN
                     ;                             (* Nicht implmentiert      *)
                  END
                  ELSE IF Item.Typ = Records THEN  (* Records                 *)
                  BEGIN
                     IF Parameter^.Ref <> Item.Ref THEN Error(134);
                     Emit1(LoadBlock, Item.Size);
                  END;
               END
               ELSE IF (Parameter^.Typ = Reals) AND (Item.Typ = Ints) THEN
                  Emit1(IntegerToReal, 0)
               ELSE IF (Parameter^.Typ <> NoType) AND (Item.Typ <> NoType) THEN
                  Error(134);                      (* Unzulässiger Parameter  *)
            END
            ELSE                                   (* Call By Reference       *)
            BEGIN
               IF Sym <> Identifier THEN
               BEGIN
                  Error(20);                       (* Bezeichner erwartet     *)

                  IF Sym IN FactBegSym THEN
                     Expression([Comma, RightParent] + Symbols, Item);
               END
               ELSE
               BEGIN
                  Locate(Id, Level, Elt, FoundAt);
                  InSymbol;

                  IF FoundAt >= 0 THEN
                  BEGIN
                     Item := Elt^;

                     LoadVarAddress([Comma, RightParent] + Symbols, FoundAt,
                                    Item);         (* Adresse auf Stack       *)

                     IF (Item.Obj <> Variables) THEN
                        Error(66)                  (* Variable erwartet       *)
                     ELSE IF Parameter^.Ref <> Item.Ref THEN Error(134);
                  END;
               END;
            END;
         END;

         Match([Comma, RightParent], Symbols, 6);
      UNTIL Sym <> Comma;

      IF Sym = RightParent THEN InSymbol
      ELSE Error(41);                              (* Symbol ) erwartet       *)
   END;

   WITH CalledProcedure^ DO
   BEGIN
      IF RingElt^.Next <> Par THEN Error(131);     (* Zu wenig Parameter      *)

      Emit2(CallProcedure, Lev, ParSize - 1);

      IF (Adr = IsForward) OR (Adr = NilAddress) THEN
      BEGIN                                        (* Call ohne Zieladresse   *)
         new(CallRem);
         CallRem^ := CalledProcedure^;             (* Inhalt merken           *)

         CallRem^.CallCount := ProgCount;          (* Programmzähler merken   *)
         CallRem^.ProcAdr := CalledProcedure;      (* Daten später bearbeiten *)

         IF Adr = IsForward THEN Push(ForwardCall[Lev], CallRem, NIL)
         ELSE Push(ForwardCall[Lev + 1], CallRem, NIL);
      END;

      Emit1(Jump, Adr);
      IF Lev < Level THEN Emit2(UpdateDisplay, Lev, Level);
   END;
END; (* Call *)

(*$I EXPRESS.PAS*)                                 (* Arithmetische Ausdrücke *)
(*$I STATEMEN.PAS*)                                (* Pascal-Anweisungen      *)

BEGIN (* Statement *)
   IF Sym IN [Identifier] + StateBegSym THEN
   BEGIN
      CASE Sym OF
         Identifier :
         BEGIN
            Locate(Id, Level, Elt, FoundAt);
            InSymbol;

            IF FoundAt >= 0 THEN
            BEGIN
               CASE Elt^.Obj OF
                  Nothing :
                     ;

                  Constants, Datatypes :
                     Error(52);                    (* Fehler in Anweisung     *)

                  Variables :
                     Assignment(Elt^, FoundAt);    (* Variablenzuweisung      *)

                  Procedures :
                     IF FoundAt > 0 THEN Call(Symbols, Elt)
                     ELSE StandardProcedure(Elt^.Adr);

                  Functions :
                  BEGIN
                     IF ProcElement <> Elt THEN
                        Error(160);                (* Unzulässige Zuweisung   *)

                     Assignment(Elt^, FoundAt);
                  END;
               END;
            END;
         END;

         GotoSy   : GotoStatement;
         WithSy   : WithStatement;
         BeginSy  : CompoundStatement;
         IfSy     : IfStatement;
         CaseSy   : CaseStatement;
         WhileSy  : WhileStatement;
         RepeatSy : RepeatStatement;
         ForSy    : ForStatement;
      END;
   END;

   Match(Symbols, [ ], 23);                        (* Symbol ; erwartet       *)
END; (* Statement *)

BEGIN (* Block *)
   DataOffset := ProcOffset;                       (* Ab hier Variablen       *)

   IF ProcElement^.Adr <> IsMainProg THEN
      Match([LeftParent, Colon, Semicolon], [ForwardSy] + Symbols, 133);

   IF ProcElement^.Adr <> IsForward THEN           (* Keine Forward-Prozedur  *)
   BEGIN
      IF Sym = LeftParent THEN ParameterList;      (* Parameter eintragen     *)
      ProcElement^.ParSize := DataOffset;

      IF IsFunction THEN                           (* Funktionsdeklaration    *)
      BEGIN
         IF Sym = Colon THEN InSymbol
         ELSE Error(37);                           (* Symbol : erwartet       *)

         IF Sym = Identifier THEN
         BEGIN
            Locate(Id, Level, Elt, FoundAt);       (* Bezeichner suchen       *)

            IF FoundAt >= 0 THEN
            BEGIN
               IF Elt^.Obj <> Datatypes THEN
                  Error(141)                       (* Datentyp erwartet       *)
               ELSE IF Elt^.Typ IN ScalarTypes THEN
               BEGIN
                  WITH ProcElement^ DO
                  BEGIN
                     Ref := Elt^.Ref;              (* Typ-Referenz            *)
                     Typ := Ref^.Typ;
                     Size := Ref^.Size;
                  END;
               END
               ELSE Error(88);                     (* Nur skalar oder einfach *)
            END;

            InSymbol;
         END
         ELSE
         BEGIN
            Error(129);                            (* Typbezeichner erwartet  *)
            IF Sym IN TypeBegSym THEN Typ([Semicolon] + Symbols, Dummy);
         END;
      END;
   END
   ELSE DataOffset := ProcElement^.ParSize;        (* Parameter beachten      *)

   IF Sym = Semicolon THEN InSymbol
   ELSE Skip([ForwardSy] + Symbols, 23);           (* Symbol ; erwartet       *)

   IF Sym = ForwardSy THEN                         (* Forward Deklaration     *)
   BEGIN
      InSymbol;

      IF ProcElement^.Adr = IsMainProg THEN
         Fatal(6);                                 (* Programm nicht Forward  *)

      IF ProcElement^.Adr = IsForward THEN
         Error(62)                                 (* Prozedurkörper erwartet *)
      ELSE
      BEGIN
         ProcElement^.Rem := Display[Level];       (* Parameter merken        *)
         ProcElement^.Adr := IsForward;            (* Vorwärtsdeklaration     *)
         Display[Level] := NIL;                    (* Parameter entfernen     *)
      END;
   END
   ELSE                                            (* Prozedurdeklaration     *)
   BEGIN
      CreateRing(PointerRemember);                 (* Zeiger merken           *)
      CreateRing(ProcedureRemember);               (* Prozeduren merken       *)
      CreateRing(LabelRemember);                   (* Labels merken           *)

      WHILE Sym IN [LabelSy, ConstSy, TypeSy, VarSy, ProcedureSy, FunctionSy] DO
      BEGIN
         CASE Sym OF
            LabelSy : LabelDeclaration;
            ConstSy : ConstantDeclaration;
            TypeSy  : TypeDeclaration;
            VarSy   : VariableDeclaration;

            ProcedureSy, FunctionSy :
            BEGIN
               IF NOT RingIsEmpty(PointerRemember) THEN
                  CompletePointer;                 (* Zeiger vervollständigen *)

               ProcedureDeclaration;
            END;
         END;
      END;

      IF DataOffset > StackMax THEN Fatal(7)       (* Nicht genug Speicher    *)
      ELSE ProcElement^.VarSize := DataOffset;     (* Variablengröße merken   *)

      ProcElement^.Adr := ProgCount;               (* Adresse der Prozedur    *)
      StackCorrection := 0;                        (* Korrekturwert für Goto  *)
      WithLevel := 0;                              (* Leveltiefe von With     *)
      Match([BeginSy], Symbols, 38);               (* Symbol begin erwartet   *)

      IF NOT RingIsEmpty(ProcedureRemember) THEN
         Error(84);                                (* Undefinierte Prozeduren *)

      IF NOT RingIsEmpty(PointerRemember) THEN
         CompletePointer;                          (* Zeiger vervollständigen *)

      WHILE NOT RingIsEmpty(ForwardCall[Level]) DO (* Call's ohne Zieladresse *)
      BEGIN
         Pop(ForwardCall[Level], Elt, Dummy);
         CreateRing(Elt^.Par);                     (* Für Löschen wichtig     *)
         Push(Remember[Level], Elt, NIL);          (* Zum Löschen merken      *)

         WITH Elt^ DO                              (* Variablengröße          *)
            Code^[CallCount].y := ProcAdr^.VarSize;

         Pop(ForwardCall[Level], Elt, Dummy);
         CreateRing(Elt^.Par);                     (* Für Löschen wichtig     *)
         Push(Remember[Level], Elt, NIL);          (* Zum Löschen merken      *)

         WITH Elt^ DO                              (* Zieladresse             *)
            Code^[CallCount].y := ProcAdr^.Adr;
      END;

      DeleteRing(PointerRemember);                 (* Liste komplett löschen  *)
      DeleteRing(ProcedureRemember);               (* Liste komplett löschen  *)
      CreateRing(GotoRemember);                    (* Goto's merken           *)

      IF Sym = BeginSy THEN InSymbol;              (* Kein Compound-Statement *)

                                                   (* Ab hier Anweisungsteil  *)
      WHILE Sym = IntConst DO                      (* Labels auswerten        *)
         LabelStatement([Semicolon, EndSy, IntConst, Identifier] + Symbols);

      Statement([Semicolon, EndSy] + Symbols);     (* Anweisungen auswerten   *)

      WHILE Sym IN [Semicolon] + StateBegSym DO
      BEGIN
         IF Sym = Semicolon THEN InSymbol
         ELSE Error(23);                           (* Symbol ; erwartet       *)

         WHILE Sym = IntConst DO                   (* Labels auswerten        *)
            LabelStatement([Semicolon, EndSy, IntConst, Identifier] + Symbols);

         Statement([Semicolon, EndSy] + Symbols);  (* Anweisungen auswerten   *)
      END;

      IF Sym = EndSy THEN InSymbol
      ELSE Error(40);                              (* Symbol end erwartet     *)

      IF NOT RingIsEmpty(LabelRemember) THEN
         Error(83);                                (* Undefinierte Labels     *)

      WHILE NOT RingIsEmpty(GotoRemember) DO       (* Goto ohne Zieladresse   *)
      BEGIN
         Pop(GotoRemember, Elt, Dummy);

         WITH Elt^ DO
         BEGIN
            Code^[Count].y := LabelAdr^.Stack - Correct;
            Code^[Count + 1].y := LabelAdr^.Adr;   (* Zieladresse eintragen   *)
         END;
      END;

      DeleteLevel(Level);                          (* Binärbaum löschen       *)
      DeleteRing(GotoRemember);                    (* Liste komplett löschen  *)
      DeleteRing(LabelRemember);                   (* Liste komplett löschen  *)
   END;

   Match([Period, Semicolon] + Symbols, [ ], 6);
END; (* Block *)

(* Überprüfung und Übersetzung starten *)
PROCEDURE Parser;
VAR Elt       : pNode;
    Found     : BOOLEAN;
    NrOfBytes : INTEGER;
BEGIN
   InSymbol;
   IF Sym <> ProgramSy THEN Fatal(5);              (* Symbol program erwartet *)
   InSymbol;

   IF Sym = Identifier THEN
   BEGIN
      ProgramName := Id;                           (* Programmname merken     *)
      InSymbol;
   END
   ELSE Error(105);                                (* Programmname erwartet   *)

   IF Sym = LeftParent THEN
   BEGIN
      InSymbol;

      Match([Identifier], [RightParent, Comma, Semicolon] + StateBegSym +
            BlockBegSym, 20);

      IF Sym = Identifier THEN InSymbol;

      WHILE Sym = Comma DO
      BEGIN
         InSymbol;

         IF Sym = Identifier THEN InSymbol
         ELSE Error(20);                           (* Bezeichner erwartet     *)
      END;

      IF Sym = RightParent THEN InSymbol
      ELSE Error(41);                              (* Symbol ) erwartet       *)
   END;

   Search('main program    ', 0, Elt, Found);
   Block(BlockBegSym + StateBegSym, 1, Elt, FALSE);

   IF Sym <> Period THEN Error(53);                (* Symbol . erwartet       *)
   Emit(StopProgram);                              (* Letzter Befehl          *)

   (*$I-*)                                         (* I/O Überprüfung aus     *)
   blockwrite(target, Code^, sizeof(Order) * ProgCount, NrOfBytes);
   IF ioresult <> 0 THEN Fatal(8);                 (* Fehler beim Schreiben   *)

                                                   (* Anzahl der Realzahlen   *)
   blockwrite(target, RealIndex, sizeof(INTEGER), NrOfBytes);

                                                   (* RealTable schreiben     *)
   blockwrite(target, RealTable, sizeof(REAL) * RealIndex, NrOfBytes);

   StringIndex := StringIndex - 1;                 (* Länge aller Strings     *)
   blockwrite(target, StringIndex, sizeof(INTEGER), NrOfBytes);

                                                   (* StringTable schreiben   *)
   blockwrite(target, StringTable, sizeof(CHAR) * StringIndex, NrOfBytes);

                                                   (* Adresse des Hauptprg's  *)
   blockwrite(target, Elt^.Adr, sizeof(INTEGER), NrOfBytes);

                                                   (* Variablengröße vom Prg. *)
   blockwrite(target, Elt^.VarSize, sizeof(INTEGER), NrOfBytes);

   IF ioresult <> 0 THEN Fatal(8);                 (* Fehler beim Schreiben   *)
   (*$I+*)                                         (* I/O Überprüfung an      *)
END; (* Parser *)

(* END PARSER.PAS *)
