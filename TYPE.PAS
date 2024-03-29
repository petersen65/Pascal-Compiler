(************************************************************************)
(* Programmname    : TYPE.PAS                                           *)
(* Programmautor   : Michael Rippl                                      *)
(* Compiler        : Turbo Pascal V5.0                                  *)
(* Letzte Änderung : 13-Mar-1990                                        *)
(* Inhalt          : Datentypen und Konstanten auswerten von PASCAL.PAS *)
(* Bemerkung       : Include Datei von PARSER.PAS                       *)
(************************************************************************)

(* Typ-Referenz von Zeigern nachträglich vervollständigen *)
PROCEDURE CompletePointer;
VAR TypContent : pType;
    ObjContent,
    PointerTyp : pNode;
    Lev        : INTEGER;
    Found      : BOOLEAN;
BEGIN
   WHILE NOT RingIsEmpty(PointerRemember) DO
   BEGIN
      Pop(PointerRemember, ObjContent, TypContent);
      Lev := Level;

      REPEAT
         Search(TypContent^.PointerTo, Lev, PointerTyp, Found);
         Lev := Lev - 1;
      UNTIL (Lev < 0) OR (Found = TRUE);           (* Datentyp suchen         *)

      IF Found THEN
      BEGIN
         IF PointerTyp^.Obj = Datatypes THEN       (* Typ-Referenz            *)
            TypContent^.PointerType := PointerTyp^.Ref
         ELSE Error(85);                           (* Typ nicht definiert     *)
      END
      ELSE Error(85);                              (* Typ nicht definiert     *)
   END;
END; (* CompletePointer *)

(* Konstanten jedes zulässigen Datentyps einlesen *)
PROCEDURE Constant(Symbols : SymbolSet; VAR Info : Node);
VAR Sign,
    FoundAt      : INTEGER;
    Elt          : pNode;
    UseSign      : BOOLEAN;                        (* Vorzeichen verwendet    *)
BEGIN
   InitNode(Info);                                 (* Defaultwerte eintragen  *)
   Info.Obj := Constants;
   Info.Value := 0;
   Match(ConstBegSym, Symbols, 136);               (* Konstante erwartet      *)

   IF Sym IN ConstBegSym THEN
   BEGIN
      IF Sym = StringConst THEN                    (* Stringkonstante         *)
      BEGIN
         WITH Info DO
         BEGIN
            new(Ref);
            Push(Remember[Level], NIL, Ref);       (* Zum Löschen merken      *)
            Ref^.Typ := Strings;
            Ref^.Size:= StringLen;                 (* Attribut vom Scanner    *)
            Value := IntNum;                       (* Attribut vom Scanner    *)
         END;

         InSymbol;
      END
      ELSE IF Sym = CharConst THEN                 (* Buchstabenkonstante     *)
      BEGIN
         Info.Ref := CharType;                     (* Typ-Referenz            *)
         Info.Value := IntNum;                     (* Attribut vom Scanner    *)
         InSymbol;
      END
      ELSE
      BEGIN
         Sign := 1;                                (* Positives Vorzeichen    *)
         UseSign := FALSE;                         (* Kein Vorzeichen benutzt *)

         IF Sym IN [Plus, Minus] THEN
         BEGIN
            IF Sym = Minus THEN Sign := -1;
            UseSign := TRUE;                       (* Vorzeichen benutzt      *)
            InSymbol;
         END;

         IF Sym = Identifier THEN                  (* Bezeichner              *)
         BEGIN
            Locate(Id, Level, Elt, FoundAt);

            IF FoundAt >= 0 THEN                   (* Bezeichner gefunden     *)
            BEGIN
               IF Elt^.Obj <> Constants THEN
                  Error(136)                       (* Konstante erwartet      *)
               ELSE
               BEGIN
                  IF NOT (Elt^.Typ IN [Ints, Reals]) AND UseSign THEN
                     Error(156)                    (* Integer, Real erwartet  *)
                  ELSE
                  BEGIN
                     Info := Elt^;                 (* Eintrag zuweisen        *)

                     WITH Info DO
                     BEGIN
                        IF Typ = Reals THEN
                           Value := EnterReal(RealTable[Value] * Sign)
                        ELSE IF Typ = Ints THEN Value := Value * Sign;
                     END;
                  END;
               END;
            END;

            InSymbol;
         END
         ELSE IF Sym = IntConst THEN               (* Ganzzahlige Konstante   *)
         BEGIN
            Info.Ref := IntegerType;               (* Typ-Referenz            *)
            Info.Value := IntNum * Sign;
            InSymbol;
         END
         ELSE IF Sym = RealConst THEN              (* Reellwertige Konstante  *)
         BEGIN
            Info.Ref := RealType;                  (* Typ-Referenz            *)
            Info.Value := EnterReal(RealNum * Sign);
            InSymbol;
         END
         ELSE Skip(Symbols, 156);                  (* Ints, Reals erwartet    *)
      END;

      Match(Symbols, [ ], 6);
   END;

   Info.Typ := Info.Ref^.Typ;
   Info.Size := Info.Ref^.Size;
END; (* Constant *)

(* Datentypen von Pascal auswerten *)
PROCEDURE Typ(Symbols : SymbolSet; VAR Reference : pType);
VAR VariableRemember : pRing;                      (* Variablen merken        *)
    TypeRef,                                       (* Strukturierte Typen     *)
    Dummy            : pType;                      (* Variablenverbunde       *)
    Elt              : pNode;
    Found            : BOOLEAN;
    Counter,                                       (* Zähler für Aufzählungen *)
    FoundAt,
    RecOffset        : INTEGER;                    (* Offset für Records      *)

(* Unterbereiche jedes zulässigen Datentypes auswerten *)
PROCEDURE SubrangeType(Symbols : SymbolSet; VAR Reference : pType);
VAR Low,                                           (* Untere Grenze           *)
    High     : Node;                               (* Obere Grenze            *)
    Elt      : pNode;
    FoundAt  : INTEGER;
    EnumType : pType;                              (* Basistyp bei Aufzählung *)
BEGIN
   WITH Low DO                                     (* Defaultwerte            *)
   BEGIN
      Ref := NoTypeType;
      Size := IntSize;
      Value := 0;
      High.Value := 0;
      Reference := NIL;                            (* Merkmal für New         *)
   END;

   IF Sym = Identifier THEN
   BEGIN
      Locate(Id, Level, Elt, FoundAt);

      IF FoundAt < 0 THEN InSymbol
      ELSE
      BEGIN
         IF Elt^.Obj = Datatypes THEN              (* Unterbereichstyp        *)
         BEGIN
            InSymbol;

            IF Elt^.Typ IN [Ints, Reals] THEN
               Error(130)                          (* Zu viele Elemente       *)
            ELSE IF Elt^.Typ = Chars THEN          (* Menge über Char         *)
            BEGIN
               WITH Low DO
               BEGIN
                  Size := CharType^.Size;          (* Speicherplatzbedarf     *)
                  Ref := CharType;                 (* Typ-Referenz            *)
                  Value := 0;                      (* Untere Grenze           *)
                  High.Value := 255;               (* Obere Grenze            *)
               END;
            END
            ELSE IF Elt^.Typ = Bools THEN          (* Menge über Boolean      *)
            BEGIN
               WITH Low DO
               BEGIN
                  Size := BooleanType^.Size;       (* Speicherplatzbedarf     *)
                  Ref := BooleanType;              (* Typ-Referenz            *)
                  Value := 0;                      (* Untere Grenze           *)
                  High.Value := 1;                 (* Obere Grenze            *)
               END;
            END
            ELSE IF Elt^.Typ = Enumerations THEN   (* Menge über Aufzählung   *)
            BEGIN
               WITH Low DO
               BEGIN
                  Size := Elt^.Size;               (* Speicherplatzbedarf     *)
                  Ref := Elt^.Ref;                 (* Typ-Referenz            *)
                  Value := 0;
                  High.Value := Elt^.Ref^.EnumSize - 1;
               END;
            END
            ELSE IF Elt^.Typ = Subranges THEN      (* Unterbereich            *)
               Reference := Elt^.Ref
            ELSE Error(121);                       (* Typ nicht erlaubt       *)
         END
         ELSE                                      (* Zahl .. Zahl            *)
         BEGIN
            Constant([DotDot] + Symbols, Low);     (* Konstante vor '..'      *)

            IF Low.Typ IN [Reals, Strings] THEN
               Error(121);                         (* Unerlaubter Subrange    *)

            IF Sym = DotDot THEN InSymbol
            ELSE Error(59);                        (* Symbol .. erwartet      *)

            Constant(Symbols, High);               (* Konstante nach '..'     *)

            IF High.Ref <> Low.Ref THEN            (* Typ-Referenz ungleich   *)
            BEGIN
               Error(96);                          (* Nur identische Typen    *)
               High.Ref := Low.Ref;
            END;

            IF High.Value < Low.Value THEN         (* Low > High              *)
            BEGIN
               Error(97);                          (* 1. Grenze > 2. Grenze   *)
               High.Value := Low.Value;
            END;
         END;
      END;
   END
	ELSE IF Sym = LeftParent THEN							(* Aufzählungstyp				*)
	BEGIN
		Typ(Symbols, EnumType);								(* Aufzählung auswerten		*)
		New(Reference);
		Push(Remember[Level], NIL, Reference);			(* Zum Löschen merken		*)

		WITH Reference^ DO
		BEGIN
			Typ := Subranges;
			RangeType := EnumType;                    (* Typ-Referenz            *)
			Size := EnumType^.Size;                   (* Speicherplatzbedarf     *)
			RangeLow := 0;				                  (* Untere Grenze           *)
			RangeHigh := EnumType^.EnumSize - 1;      (* Obere Grenze            *)
		END;
	END
   ELSE                                            (* Zahl .. Zahl            *)
   BEGIN
      Constant([DotDot] + Symbols, Low);           (* Konstante vor '..'      *)

      IF Low.Typ IN [Reals, Strings] THEN
         Error(121);                               (* Unerlaubter Subrange    *)

      IF Sym = DotDot THEN InSymbol
         ELSE Error(59);                           (* Symbol .. erwartet      *)

      Constant(Symbols, High);                     (* Konstante nach '..'     *)

      IF High.Ref <> Low.Ref THEN                  (* Typ-Referenz ungleich   *)
      BEGIN
         Error(96);                                (* Nur identische Typen    *)
         High.Ref := Low.Ref;
      END;

      IF High.Value < Low.Value THEN               (* Low > High              *)
      BEGIN
         Error(97);                                (* 1. Grenze > 2. Grenze   *)
         High.Value := Low.Value;
      END;
   END;

   IF Reference = NIL THEN                         (* Neuer Unterbereich      *)
   BEGIN
      new(Reference);
      Push(Remember[Level], NIL, Reference);       (* Zum Löschen merken      *)

      WITH Reference^ DO
      BEGIN
         Typ := Subranges;
         Size := Low.Size;                         (* Speicherplatzbedarf     *)
         RangeType := Low.Ref;                     (* Typ-Referenz            *)
         RangeLow := Low.Value;                    (* Untere Grenze           *)
         RangeHigh := High.Value;                  (* Obere Grenze            *)
      END;
   END;

   Match(Symbols, [ ], 6);
END; (* SubrangeType *)

(* Beliebig dimensionale zulässige Datenfelder auswerten *)
PROCEDURE ArrayType(Symbols : SymbolSet; VAR Reference : pType);
VAR Elt     : pNode;
    FoundAt : INTEGER;
BEGIN
   new(Reference);
   Push(Remember[Level], NIL, Reference);          (* Zum Löschen merken      *)

   WITH Reference^ DO
   BEGIN
      Typ := Arrays;
      Size := IntSize;                             (* Defaultwerte            *)
      ElementType := NoTypeType;

      SubrangeType([RightBrack, RightParent, Comma, OfSy] + Symbols +
                   TypeBegSym, IndexType);         (* Index auswerten         *)
   END;

   IF Sym = Comma THEN                             (* Höhere Dimension        *)
   BEGIN
      InSymbol;
      ArrayType(Symbols, Reference^.ElementType);  (* Elemente = Datenfelder  *)
   END
   ELSE
   BEGIN
      IF Sym = RightBrack THEN InSymbol
      ELSE
      BEGIN
         Error(22);                                (* Symbol ] erwartet       *)
         IF Sym = RightParent THEN InSymbol;
      END;

      IF Sym = OfSy THEN InSymbol
      ELSE Error(36);                              (* Symbol of erwartet      *)

      Typ(Symbols, Reference^.ElementType);        (* Typ der Elemente        *)
   END;

   WITH Reference^ DO                              (* Speicherplatzbedarf     *)
      Size := (IndexType^.RangeHigh - IndexType^.RangeLow + 1) *
               ElementType^.Size;
END; (* ArrayType *)

(* Wertet den varianten Teil eines Variablenverbundes aus *)
PROCEDURE VariantRecord;
VAR Found      : BOOLEAN;
    Labels,                                        (* Anzahl der Labels       *)
    Lev,                                           (* Level merken            *)
    RemOffset,                                     (* Aktueller Offset        *)
    MaxOffset  : INTEGER;                          (* Größter Offset          *)
    Elt,
    Elt1,
    Default    : pNode;
    Dummy,
    TypeRef    : pType;                            (* Information über Typ    *)
    CasesTable : ARRAY [1..CaseMax] OF INTEGER;    (* Case-Konstanten         *)

(* Die Liste der Variablen einer Variante auswerten *)
PROCEDURE VariableList;
VAR Elt   : pNode;
    Found : BOOLEAN;
    Dummy : pType;
BEGIN
   IF Sym = LeftParent THEN InSymbol
   ELSE Error(45);                                 (* Symbol ( erwartet       *)

   WHILE Sym <> RightParent DO
   BEGIN
      IF Sym = Identifier THEN
      BEGIN
         Insert(Id, Level, Variables, Elt, Found);
         IF NOT Found THEN Push(VariableRemember, Elt, NIL);
         InSymbol;

         WHILE Sym = Comma DO
         BEGIN
            InSymbol;

            IF Sym = Identifier THEN
            BEGIN
               Insert(Id, Level, Variables, Elt, Found);
               IF NOT Found THEN Push(VariableRemember, Elt, NIL);
               InSymbol;
            END
            ELSE Error(20);                        (* Bezeichner erwartet     *)
         END;

         IF Sym = Colon THEN InSymbol
         ELSE Error(37);                           (* Symbol : erwartet       *)

         WHILE NOT RingIsEmpty(Remember[Level]) DO
         BEGIN
            Pop(Remember[Level], Elt, Dummy);
            Push(Remember[Level - 1], Elt, NIL);
         END;                                      (* Löschliste kopieren     *)

         Elt := Display[Level];                    (* Teilbaum merken         *)
         Display[Level] := NIL;
         Level := Level - 1;
         Typ([EndSy, RightParent] + Symbols, TypeRef);
         Level := Level + 1;
         Display[Level] := Elt;                    (* Zustand hergestellt     *)

         WHILE NOT RingIsEmpty(VariableRemember) DO
         BEGIN
            Pop(VariableRemember, Elt, Dummy);

            WITH Elt^ DO
            BEGIN
               Ref := TypeRef;            (* Typ-Referenz eintragen  *)
               Typ := Ref^.Typ;           (* Datentyp eintragen      *)
               Size := Ref^.Size;         (* Speicherplatzbedarf     *)
               Adr := RecOffset;          (* Adresse                 *)
               Lev := Lev - 1;            (* Level berichtigen       *)
               RecOffset := RecOffset + Size;
            END;
         END;
      END;

      IF Sym <> RightParent THEN
      BEGIN
         IF Sym = Semicolon THEN InSymbol
         ELSE
         BEGIN
            Error(23);                             (* Symbol ; erwartet       *)
            IF Sym = Comma THEN InSymbol;
         END;

         Match([Identifier, RightParent, Semicolon], Symbols, 6);
      END;
   END;

   InSymbol;                                       (* RightParent einlesen    *)
END; (* VariableList *)

(* Ein Label einer Variante auswerten *)
PROCEDURE VariantLabel;
VAR Lab : Node;                                    (* Einzelnes Label         *)
    k   : INTEGER;
BEGIN
   Constant([Comma, Colon, EndSy] + Symbols, Lab);

   IF Elt^.Typ = Subranges THEN                    (* Enthält keine Defaults  *)
   BEGIN
      WITH Elt^.Ref^ DO
      BEGIN
         IF RangeType <> Lab.Ref THEN
            Error(152)                             (* Unzulässiges Case-Label *)
         ELSE IF (Lab.Value < RangeLow) OR (Lab.Value > RangeHigh) THEN
            Error(2);                              (* Unzulässige Konstante   *)
      END;
   END;

   IF Labels = CaseMax THEN Fatal(9)               (* Case-Tabelle voll       *)
   ELSE
   BEGIN
      Labels := Labels + 1;
      k := 0;
      CasesTable[Labels] := Lab.Value;             (* Aktuelles Label merken  *)

      REPEAT                                       (* Prüfen ob Label doppelt *)
         k := k + 1;
      UNTIL CasesTable[k] = Lab.Value;

      IF k < Labels THEN Error(77);                (* Case-Label doppelt      *)
   END;
END; (* VariantLabel *)

(* Eine Variante auswerten *)
PROCEDURE OneVariant;
BEGIN
   IF Sym IN ConstBegSym THEN
   BEGIN
      VariantLabel;                                (* Labels der Variante     *)

      WHILE Sym = Comma DO
      BEGIN
         InSymbol;
         VariantLabel;
      END;

      IF Sym = Colon THEN InSymbol
      ELSE Error(37);                              (* Symbol : erwartet       *)

      VariableList;                                (* Eintragsliste auswerten *)
   END;
END; (* OneVariant *)

BEGIN (* VariantRecord *)
   InSymbol;                                       (* Case schon gelesen      *)
   new(Default);                                   (* Enthält Defaultwerte    *)
   Push(Remember[Level - 1], Default, NIL);        (* Zum Löschen merken      *)
   InitNode(Default^);

   IF Sym = Identifier THEN
   BEGIN
      Lev := Level;                                (* Aktuelles Level merken  *)

      REPEAT                                       (* Levels durchsuchen      *)
         Search(Id, Lev, Elt, Found);
         Lev := Lev - 1;
      UNTIL (Lev < 0) OR (Found = TRUE);

      IF Found THEN                                (* Bezeichner ist Datentyp *)
      BEGIN
         Elt := Default;                           (* Enthält Defaultwerte    *)
         Elt1 := Display[Level];                   (* Teilbaum merken         *)
         Display[Level] := NIL;
         Level := Level - 1;
         SubrangeType([EndSy, OfSy] + Symbols, TypeRef);
         Level := Level + 1;
         Display[Level] := Elt1;                   (* Zustand hergestellt     *)

         WITH Elt^ DO
         BEGIN
            Ref := TypeRef;                        (* Typ-Referenz eintragen  *)
            Typ := Ref^.Typ;                       (* Datentyp eintragen      *)

            IF (Ref^.RangeHigh - Ref^.RangeLow + 1) > CaseMax THEN
               Error(130);                         (* Zu viele Elemente       *)
         END;
      END
      ELSE                                         (* Bezeichner ist Variable *)
      BEGIN
         Insert(Id, Level, Variables, Elt, Found);
         InSymbol;

         Pop(Remember[Level], Elt1, Dummy);        (* Löschliste kopieren     *)
         Push(Remember[Level - 1], Elt1, NIL);

         IF Sym = Colon THEN InSymbol
         ELSE Error(37);                           (* Symbol : erwartet       *)

         Elt1 := Display[Level];                   (* Teilbaum merken         *)
         Display[Level] := NIL;
         Level := Level - 1;
         SubrangeType([EndSy, OfSy] + Symbols, TypeRef);
         Level := Level + 1;
         Display[Level] := Elt1;                   (* Zustand hergestellt     *)

         WITH Elt^ DO
         BEGIN
            Ref := TypeRef;                        (* Typ-Referenz eintragen  *)
            Typ := Ref^.Typ;                       (* Datentyp eintragen      *)
            Size := Ref^.Size;                     (* Speicherplatzbedarf     *)
            Adr := RecOffset;                      (* Adresse                 *)
            Lev := Lev - 1;                        (* Level berichtigen       *)
            RecOffset := RecOffset + Size;

            IF (Ref^.RangeHigh - Ref^.RangeLow + 1) > CaseMax THEN
               Error(130);                         (* Zu viele Elemente       *)
         END;
      END;
   END
   ELSE
   BEGIN
      Elt := Default;                              (* Zeigt auf Defaultwerte  *)
      Skip([Identifier, EndSy, OfSy] + Symbols, 20);
   END;

   IF Sym = OfSy THEN InSymbol
   ELSE Error(36);                                 (* Symbol Of erwartet      *)

   Labels := 0;                                    (* Defaultwerte            *)
   RemOffset := RecOffset;                         (* Aktuelles Offset merken *)
   OneVariant;                                     (* Varianten auswerten     *)
   MaxOffset := RecOffset;                         (* Anfangswert setzen      *)

   WHILE Sym = Semicolon DO
   BEGIN
      InSymbol;
      RecOffset := RemOffset;                      (* Anfangswert             *)
      OneVariant;

      IF RecOffset > MaxOffset THEN
         MaxOffset := RecOffset;                   (* Maximalen Offset merken *)
   END;

   RecOffset := MaxOffset;                         (* Gesamtgröße des Records *)

   WITH Elt^.Ref^ DO
   BEGIN
      IF Labels < (RangeHigh - RangeLow + 1) THEN
         Error(86);                                (* Nicht alles definiert   *)
   END;

   IF Sym = EndSy THEN InSymbol
   ELSE Error(40);                                 (* Symbol End erwartet     *)
END; (* VariantRecord *)

BEGIN (* Typ *)
   Reference := NoTypeType;                        (* Defaultwert             *)
   Match(TypeBegSym, Symbols, 141);                (* Datentyp erwartet       *)

   IF Sym IN TypeBegSym THEN
   BEGIN
      IF Sym = PointerTo THEN                      (* Zeigertyp               *)
      BEGIN
         InSymbol;

         IF Sym = Identifier THEN
         BEGIN
            new(Reference);
            Push(Remember[Level], NIL, Reference); (* Zum Löschen merken      *)
            Push(PointerRemember, NIL, Reference); (* Vorwärtsbezogen, merken *)

            WITH Reference^ DO
            BEGIN
               Typ := Pointers;
               Size := IntSize;                    (* Größe einer Adresse     *)
               PointerType := NoTypeType;          (* Defaultwert             *)
               PointerTo := Id;                    (* Bezeichnername merken   *)
            END;

            InSymbol;
         END
         ELSE
         BEGIN
            Error(129);                            (* Typbezeichner erwartet  *)
            IF Sym IN TypeBegSym THEN Typ(Symbols, TypeRef);
         END;
      END
      ELSE IF Sym = LeftParent THEN                (* Aufzählungstyp          *)
      BEGIN
         InSymbol;
         new(Reference);
         Push(Remember[Level], NIL, Reference);    (* Zum Löschen merken      *)
         Counter := 0;
         Match([Identifier], [RightParent] + Symbols, 20);

         IF Sym = Identifier THEN
         BEGIN
            Insert(Id, Level, Constants, Elt, Found);

            IF NOT Found THEN
            BEGIN
               WITH Elt^ DO
               BEGIN
                  Typ := Enumerations;
                  Size := IntSize;                 (* Speicherplatzbedarf     *)
                  Ref := Reference;                (* Typ-Referenz            *)
                  Value := Counter;
               END;
            END;

            InSymbol;
         END;

         WHILE Sym = Comma DO
         BEGIN
            InSymbol;

            IF Sym = Identifier THEN
            BEGIN
               Insert(Id, Level, Constants, Elt, Found);
               Counter := Counter + 1;

               IF NOT Found THEN
               BEGIN
                  WITH Elt^ DO
                  BEGIN
                     Typ := Enumerations;
                     Size := IntSize;              (* Speicherplatzbedarf     *)
                     Ref := Reference;             (* Typ-Referenz            *)
                     Value := Counter;
                  END;
               END;

               InSymbol;
            END
            ELSE Error(20);                        (* Bezeichner erwartet     *)
         END;

         IF Sym = RightParent THEN InSymbol
         ELSE Error(41);                           (* Symbol ) erwartet       *)

         WITH Reference^ DO
         BEGIN
            Typ := Enumerations;
            Size := IntSize;                       (* Speicherplatzbedarf     *)
            EnumSize := Counter + 1;               (* Anzahl der Konstanten   *)
         END;
      END
      ELSE IF Sym IN ConstBegSym THEN              (* Subranges + Identifier  *)
      BEGIN
         IF Sym = Identifier THEN
         BEGIN
            Locate(Id, Level, Elt, FoundAt);

            IF FoundAt >= 0 THEN
            BEGIN
               IF Elt^.Obj = Datatypes THEN
                  Reference := Elt^.Ref            (* Identifier              *)
               ELSE IF Elt^.Obj = Constants THEN
                  SubrangeType(Symbols, Reference) (* Unterbereichstyp        *)
               ELSE Error(141);                    (* Datentyp erwartet       *)
            END;

            IF FoundAt < 0 THEN InSymbol
            ELSE IF Elt^.Obj <> Constants THEN InSymbol;
         END
         ELSE SubrangeType(Symbols, Reference);    (* Unterbereichstyp        *)
      END
      ELSE IF Sym = SetSy THEN                     (* Mengen                  *)
      BEGIN
         InSymbol;
         new(Reference);
         Push(Remember[Level], NIL, Reference);    (* Zum Löschen merken      *)

         WITH Reference^ DO
         BEGIN
            Typ := Sets;
            Size := SetSize;                       (* Speicherplatzbedarf     *)

            IF Sym = OfSy THEN InSymbol
            ELSE Error(36);                        (* Symbol of erwartet      *)

            SubrangeType(Symbols, BaseType);       (* Datentyp hinter Of      *)

            IF BaseType^.RangeHigh - BaseType^.RangeLow + 1 > SetMax THEN
            BEGIN
               Error(107);                         (* Zu viele Elemente       *)
               BaseType^.RangeLow := 0;
               BaseType^.RangeHigh := 0;
            END;
         END;
      END
      ELSE IF Sym = FileSy THEN                    (* Dateien                 *)
      BEGIN
         InSymbol;
         new(Reference);
         Push(Remember[Level], NIL, Reference);    (* Zum Löschen merken      *)

         WITH Reference^ DO
         BEGIN
            Typ := Files;
            Size := FileSize;                      (* Speicherplatzbedarf     *)
            FileType := NoTypeType;                (* Defaultwert             *)
         END;

         IF Sym = OfSy THEN InSymbol
         ELSE Error(36);                           (* Symbol of erwartet      *)

         Typ(Symbols, TypeRef);

         IF TypeRef^.Typ <> NoType THEN
         BEGIN
            IF TypeRef^.Typ = Files THEN
               Error(108)                          (* Keine Files erlaubt     *)
            ELSE Reference^.FileType := TypeRef;   (* Typ-Referenz            *)
         END;
      END
      ELSE                                         (* Arrays oder Records     *)
      BEGIN
         IF Sym = PackedSy THEN InSymbol;          (* Gepackte Datentypen     *)

         IF Sym = ArraySy THEN                     (* Datenfelder             *)
         BEGIN
            InSymbol;

            IF Sym = LeftBrack THEN InSymbol
            ELSE
            BEGIN
               Error(21);                          (* Symbol [ erwartet       *)
               IF Sym = LeftParent THEN InSymbol;
            END;

            ArrayType(Symbols, Reference);         (* Array auswerten         *)
         END
         ELSE IF Sym = RecordSy THEN               (* Variablenverbunde       *)
         BEGIN
            IF Level = LevelMax THEN Fatal(3);     (* Leveltabelle voll       *)

            InSymbol;
            Level := Level + 1;
            RecOffset := 0;
            CreateRing(VariableRemember);          (* Für Datentyp merken     *)

            WHILE NOT (Sym IN [EndSy, CaseSy]) DO
            BEGIN
               IF Sym = Identifier THEN
               BEGIN
                  Insert(Id, Level, Variables, Elt, Found);
                  IF NOT Found THEN Push(VariableRemember, Elt, NIL);
                  InSymbol;

                  WHILE Sym = Comma DO
                  BEGIN
                     InSymbol;

                     IF Sym = Identifier THEN
                     BEGIN
                        Insert(Id, Level, Variables, Elt, Found);
                        IF NOT Found THEN Push(VariableRemember, Elt, NIL);
                        InSymbol;
                     END
                     ELSE Error(20);               (* Bezeichner erwartet     *)
                  END;

                  IF Sym = Colon THEN InSymbol
                  ELSE Error(37);                  (* Symbol : erwartet       *)

                  WHILE NOT RingIsEmpty(Remember[Level]) DO
                  BEGIN
                     Pop(Remember[Level], Elt, Dummy);
                     Push(Remember[Level - 1], Elt, NIL);
                  END;                             (* Löschliste kopieren     *)

                  Elt := Display[Level];           (* Teilbaum merken         *)
                  Display[Level] := NIL;
                  Level := Level - 1;
                  Typ([EndSy, CaseSy] + Symbols, TypeRef);
                  Level := Level + 1;
                  Display[Level] := Elt;           (* Zustand hergestellt     *)

                  WHILE NOT RingIsEmpty(VariableRemember) DO
                  BEGIN
                     Pop(VariableRemember, Elt, Dummy);

                     WITH Elt^ DO
                     BEGIN
                        Ref := TypeRef;            (* Typ-Referenz eintragen  *)
                        Typ := Ref^.Typ;           (* Datentyp eintragen      *)
                        Size := Ref^.Size;         (* Speicherplatzbedarf     *)
                        Adr := RecOffset;          (* Adresse                 *)
                        Lev := Lev - 1;            (* Level berichtigen       *)
                        RecOffset := RecOffset + Size;
                     END;
                  END;
               END;

               IF NOT (Sym IN [EndSy, CaseSy]) THEN
               BEGIN
                  IF Sym = Semicolon THEN InSymbol
                  ELSE
                  BEGIN
                     Error(23);                    (* Symbol ; erwartet       *)
                     IF Sym = Comma THEN InSymbol;
                  END;

                  Match([Identifier, EndSy, CaseSy, Semicolon], Symbols, 6);
               END;
            END;

            IF Sym = CaseSy THEN VariantRecord     (* Varianter Verbund       *)
            ELSE InSymbol;

            new(Reference);
            Push(Remember[Level - 1], NIL, Reference);

            WITH Reference^ DO
            BEGIN
               Typ := Records;
               Size := RecOffset;                  (* Speicherplatzbedarf     *)
               RecordTree := Display[Level];       (* Verbundvariablen        *)
            END;

            Display[Level] := NIL;                 (* Binärbaum löschen       *)
            Level := Level - 1;
            DeleteRing(VariableRemember);          (* Listenkopf löschen      *)
         END
         ELSE
         BEGIN
            Error(100);                            (* Nur Arrays oder Records *)
            IF Sym IN TypeBegSym THEN Typ(Symbols, TypeRef);
         END;
      END;

      Match(Symbols, [ ], 6);
   END;
END; (* Typ *)

(* END TYPE.PAS *)
