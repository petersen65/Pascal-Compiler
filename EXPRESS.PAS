(************************************************************************)
(* Programmname    : EXPRESS.PAS                                        *)
(* Programmautor   : Michael Rippl                                      *)
(* Compiler        : Turbo Pascal V5.0                                  *)
(* Letzte Änderung : 28-Feb-1990                                        *)
(* Inhalt          : Auswertung arithmetischer Ausdrücke von PASCAL.PAS *)
(* Bemerkung       : Include Datei von PARSER.PAS                       *)
(************************************************************************)

(* Vorwärtsdeklariert *)
(* Einfache Ausdrücke (getrennt durch <, <=, <>, >, >=, =, in) auswerten *)
PROCEDURE Expression;
VAR Item2    : Node;                      (* Zweiter einfacher Ausdruck       *)
    Operator : Symbol;                    (* Operator =, <>, <, <=, >, >=, in *)
    Result   : BOOLEAN;                   (* Ergebnis bei Konstantenfaltung   *)

(* Positive oder negative Terme (getrennt durch +, -, or) auswerten *)
PROCEDURE SimpleExpression(Symbols : SymbolSet; VAR Item : Node);
VAR Item2    : Node;                               (* Zweiter Term            *)
    Operator : Symbol;                             (* Operator +, -, Or       *)

(* Faktoren (getrennt durch *, /, div, mod, and) auswerten *)
PROCEDURE Term(Symbols : SymbolSet; VAR Item : Node);
VAR Item2    : Node;                          (* Zweiter Faktor               *)
    Operator : Symbol;                        (* Operator *, /, Div, Mod, And *)

(* Konstanten, Variablen, Funktionen, Negationen, Klammerausdrücke auswerten *)
PROCEDURE Factor(Symbols : SymbolSet; VAR Item : Node);
VAR Elt        : pNode;
    FoundAt    : INTEGER;

(* Standardfunktionen auswerten und übergebenen Ausdruck auf Typ überprüfen *)
PROCEDURE StandardFunction(FunctionNumber : INTEGER);
VAR ParamType : TypeSet;                           (* Typ des Parameters      *)
    Param     : Node;
BEGIN
   IF Sym = LeftParent THEN InSymbol
   ELSE Error(45);                                 (* Symbol ( erwartet       *)

   Expression([RightParent] + Symbols, Param);

   CASE FunctionNumber OF                          (* Zulässiger Parametertyp *)
      0, 2 :                                       (* abs, sqr                *)
      BEGIN
         ParamType := [Ints, Reals];

         WITH Item DO
         BEGIN
            Ref := Param.Ref;                      (* Typ-Referenz            *)
            Typ := Ref^.Typ;
            Size := Ref^.Size;

            IF Typ = Reals THEN FunctionNumber := FunctionNumber + 1;
         END;
      END;

      4, 5 :                                       (* odd, chr                *)
         ParamType := [Ints];

      6 :                                          (* ord                     *)
         ParamType := [Ints, Bools, Chars, Enumerations];

      7, 8 :                                       (* succ, pred              *)
      BEGIN
         ParamType := [Ints, Bools, Chars, Enumerations];

         WITH Item DO
         BEGIN
            Ref := Param.Ref;                      (* Typ-Referenz            *)
            Typ := Ref^.Typ;
            Size := Ref^.Size;
         END;
      END;

      9, 10, 11, 12, 13, 14, 15, 16 :              (* round, trunc, sin, cos  *)
         ParamType := [Ints, Reals];               (* exp, ln, sqrt, arctan   *)

      17, 18 :                                     (* eof, eoln               *)
         ParamType :=[Files];
   END;

   IF Param.Typ IN ParamType THEN
   BEGIN
      IF Param.Obj = Constants THEN                (* Konstanter Parameter    *)
      BEGIN
         ProgCount := ProgCount - 1;               (* Einen Befehl löschen    *)

         WITH Item DO
         BEGIN
            Obj := Constants;
            Value := Param.Value;

            IF (FunctionNumber > 8) AND (FunctionNumber < 17) THEN
               IF Param.Typ = Ints THEN Value := EnterReal(Value);

            CASE FunctionNumber OF
               0 :                                 (* abs(integer)            *)
               BEGIN
                  Value := abs(Value);
                  Emit1(LoadInteger, Value);
               END;

               1 :                                 (* abs(real)               *)
               BEGIN
                  RealTable[Value] := abs(RealTable[Value]);
                  Emit1(LoadReal, Value);
               END;

               2 :                                 (* srq(integer)            *)
               BEGIN
                  Value := sqr(Value);
                  Emit1(LoadInteger, Value);
               END;

               3 :                                 (* sqr(real)               *)
               BEGIN
                  RealTable[Value] := sqr(RealTable[Value]);
                  Emit1(LoadReal, Value);
               END;

               4 :                                 (* odd                     *)
               BEGIN
                  IF odd(Value) THEN Value := 1
                  ELSE Value := 0;

                  Emit1(LoadInteger, Value);
               END;

               5 :                                 (* chr                     *)
               BEGIN
                  IF (Value < 0) OR (Value > 255) THEN
                     Error(203)                    (* Unzulässige Konstante   *)
                  ELSE Emit1(LoadInteger, Value);
               END;

               6 :                                 (* ord                     *)
                  Emit1(LoadInteger, Value);

               7 :                                 (* succ                    *)
               BEGIN
                  IF (Param.Typ = Bools) AND (Value >= 1) THEN
                     Error(203)                    (* Unzulässige Konstante   *)
                  ELSE IF (Param.Typ = Chars) AND (Value >= 255) THEN
                     Error(203)
                  ELSE IF Param.Typ = Enumerations THEN
                  BEGIN
                     IF Value >= Param.Ref^.EnumSize - 1 THEN
                        Error(203);
                  END
                  ELSE Value := Value + 1;

                  Emit1(LoadInteger, Value);
               END;

               8 :                                 (* pred                    *)
               BEGIN
                  IF (Param.Typ <> Ints) AND (Value <= 0) THEN
                     Error(203)                    (* Unzulässige Konstante   *)
                  ELSE Value := Value - 1;

                  Emit1(LoadInteger, Value);
               END;

               9 :                                 (* round                   *)
               BEGIN
                  Value := round(RealTable[Value]);
                  Emit1(LoadInteger, Value);
               END;

               10 :                                (* trunc                   *)
               BEGIN
                  Value := trunc(RealTable[Value]);
                  Emit1(LoadInteger, Value);
               END;

               11 :                                (* sin                     *)
               BEGIN
                  RealTable[Value] := sin(RealTable[Value]);
                  Emit1(LoadReal, Value);
               END;

               12 :                                (* cos                     *)
               BEGIN
                  RealTable[Value] := cos(RealTable[Value]);
                  Emit1(LoadReal, Value);
               END;

               13 :                                (* exp                     *)
               BEGIN
                  RealTable[Value] := exp(RealTable[Value]);
                  Emit1(LoadReal, Value);
               END;

               14 :                                (* ln                      *)
               BEGIN
                  RealTable[Value] := ln(RealTable[Value]);
                  Emit1(LoadReal, Value);
               END;

               15 :                                (* sqrt                    *)
               BEGIN
                  RealTable[Value] := sqrt(RealTable[Value]);
                  Emit1(LoadReal, Value);
               END;

               16 :                                (* arctan                  *)
               BEGIN
                  RealTable[Value] := arctan(RealTable[Value]);
                  Emit1(LoadReal, Value);
               END;
            END;
         END;
      END
      ELSE                                         (* Variabler Parameter     *)
      BEGIN
         IF (FunctionNumber > 8) AND (FunctionNumber < 17) THEN
            IF Param.Typ = Ints THEN Emit1(IntegerToReal, 0);

         Emit1(CallStandard, FunctionNumber);

         IF (FunctionNumber = 7) OR (FunctionNumber = 8) THEN
         BEGIN                                        (* succ oder pred       *)
            IF Param.Typ = Bools THEN                 (* Bereichsprüfung      *)
            BEGIN
               Emit1(LoadInteger, 1);
               Emit1(CheckConstantRange, 0);
            END
            ELSE IF Param.Typ = Chars THEN
            BEGIN
               Emit1(LoadInteger, 255);
               Emit1(CheckConstantRange, 0);
            END
            ELSE IF Param.Typ = Enumerations THEN
            BEGIN
               Emit1(LoadInteger, Param.Ref^.EnumSize - 1);
               Emit1(CheckConstantRange, 0);
            END;
         END;
      END;
   END
   ELSE IF Param.Typ <> NoType THEN
      Error(148);                                  (* Unzulässiger Parameter  *)

   IF Sym = RightParent THEN InSymbol
   ELSE Error(41);                                 (* Symbol ) erwartet       *)
END; (*StandardFunction *)

BEGIN (* Factor *)
   InitNode(Item);                                 (* Defaultwerte            *)
   Match(FactBegSym, Symbols, 48);                 (* Fehler in Faktor        *)

   WHILE Sym IN FactBegSym DO
   BEGIN
      IF Sym = Identifier THEN                     (* Bezeichner              *)
      BEGIN
         Locate(Id, Level, Elt, FoundAt);
         InSymbol;

         IF FoundAt >= 0 THEN                      (* Bezeichner gefunden     *)
         BEGIN
            CASE Elt^.Obj OF
               Nothing : ;

               Datatypes, Procedures :
                  Error(48);                       (* Fehler in Faktor        *)

               Constants :                         (* Konstanten              *)
               BEGIN
                  Item := Elt^;                    (* Eintrag kopieren        *)

                  CASE Item.Typ OF
                     NoType : ;

                     Ints, Chars, Bools, Enumerations :
                        Emit1(LoadInteger, Item.Value);

                     Reals :
                        Emit1(LoadReal, Item.Value);

                     Strings :
                     BEGIN
                        Emit1(LoadInteger, Item.Value);
                        Emit1(LoadStringConstant, Item.Size);
                     END;
                  END;
               END;

               Variables :                         (* Variablen               *)
               BEGIN
                  Item := Elt^;                    (* Eintrag kopieren        *)
                  LoadVarAddress(Symbols, FoundAt, Item);

                  WITH Item DO
                  BEGIN
                     IF Typ IN ScalarTypes THEN    (* Literale                *)
                        Emit(LoadIndirectToTop);

                     IF Typ = Subranges THEN       (* Unterbereichstypen      *)
                     BEGIN
                        Ref := Ref^.RangeType;     (* Typ ist jetzt Basistyp  *)
                        Typ := Ref^.Typ;
                        Size := Ref^.Size;
                     END
                     ELSE IF Typ = Arrays THEN     (* Arrayvariable           *)
                     BEGIN
                        IF Ref^.ElementType^.Typ = Chars THEN
                           Emit1(LoadBlock, Size); (* Textstring auf Stack    *)
                     END;
                  END;
               END;

               Functions :                         (* Funktionen              *)
               BEGIN
                  Item := Elt^;                    (* Eintrag kopieren        *)

                  IF FoundAt > 0 THEN Call(Symbols, Elt)
                  ELSE StandardFunction(Item.Adr);
               END;
            END;
         END;
      END
      ELSE IF Sym IN [IntConst, RealConst, CharConst, StringConst] THEN
      BEGIN                                        (* Zahlen und Strings      *)
         CASE Sym OF
            IntConst:                              (* Ganze Zahl              *)
            BEGIN
               WITH Item DO
               BEGIN
                  Ref := IntegerType;              (* Typ-Referenz            *)
                  Typ := Ref^.Typ;
                  Size := Ref^.Size;
                  Obj := Constants;                (* Für Konstantenfaltung   *)
                  Value := IntNum;                 (* Wert der Konstanten     *)
               END;

               Emit1(LoadInteger, IntNum);         (* Integer als Attribut    *)
            END;

            RealConst :                            (* Reelle Zahl             *)
            BEGIN
               WITH Item DO
               BEGIN
                  Ref := RealType;                 (* Typ-Referenz            *)
                  Typ := Ref^.Typ;
                  Size := Ref^.Size;
                  Obj := Constants;                (* Für Konstantenfaltung   *)
                  Value := EnterReal(RealNum);     (* Wert der reellen Zahl   *)

                  Emit1(LoadReal, Value);
               END;
            END;

            CharConst :                            (* Buchstabe               *)
            BEGIN
               WITH Item DO
               BEGIN
                  Ref := CharType;                 (* Typ-Referenz            *)
                  Typ := Ref^.Typ;
                  Size := Ref^.Size;
                  Obj := Constants;                (* Für Konstantenfaltung   *)
                  Value := IntNum;                 (* Code des Buchstabens    *)
               END;

               Emit1(LoadInteger, IntNum);
            END;

            StringConst :                          (* Zeichenkette            *)
            BEGIN
               WITH Item DO
               BEGIN
                  new(Ref);                        (* Neue Typ-Referenz       *)
                  Push(Remember[Level], NIL, Ref); (* Zum Löschen merken      *)
                  Ref^.Typ := Strings;
                  Ref^.Size:= StringLen;
                  Typ := Strings;
                  Size := StringLen;
                  Value := IntNum;                 (* Adresse des Strings     *)
                  Obj := Constants;
               END;

               Emit1(LoadInteger, IntNum);         (* Adresse als Attribut    *)
               Emit1(LoadStringConstant, StringLen);
            END;
         END;

         InSymbol;
      END
      ELSE IF Sym = LeftParent THEN                (* Klammerausdruck         *)
      BEGIN
         InSymbol;
         Expression([RightParent] + Symbols, Item);

         IF Sym = RightParent THEN InSymbol
         ELSE Error(41);                           (* Symbol ) erwartet       *)
      END
      ELSE IF Sym = LeftBrack THEN                 (* Mengenkonstante         *)
      BEGIN                                        (* Nicht implementiert     *)
         InSymbol;

         WHILE Sym <> RightBrack DO InSymbol;      (* Dient nur als Dummy     *)

         InSymbol;
      END
      ELSE IF Sym = NotSy THEN                     (* Bool'sches Not          *)
      BEGIN
         InSymbol;
         Factor(Symbols, Item);

         WITH Item DO
         BEGIN
            IF Typ = Bools THEN
            BEGIN
               IF Obj = Constants THEN             (* Konstantenfaltung       *)
               BEGIN
                  ProgCount := ProgCount - 1;      (* Einen Befehl löschen    *)

                  IF Value <> 0 THEN Value := 0    (* Wahrheitswert umdrehen  *)
                  ELSE Value := 1;

                  Emit1(LoadInteger, Value);
               END
               ELSE Emit(MakeNot);                 (* Wahrheitswert umdrehen  *)
            END
            ELSE IF Typ <> NoType THEN Error(138); (* Faktor muß Boolean sein *)
         END;
      END
      ELSE IF Sym = NilSy THEN                     (* Nil Konstante           *)
      BEGIN                                        (* Einzige Zeigerkonstante *)
         InSymbol;

         WITH Item DO
         BEGIN
            Typ := Pointers;
            Size := IntSize;                       (* Größe einer Adresse     *)
            Ref := NoTypeType;                     (* Defaultwert             *)
            Obj := Constants;
         END;

         Emit1(LoadInteger, NilAddress);           (* Wert von Nil auf Stack  *)
      END;

      Match(Symbols, FactBegSym, 6);
   END;
END; (* Factor *)

BEGIN (* Term *)
   Factor([Mult, RealDiv, IntDiv, IntMod, AndSy] + Symbols, Item);

   WHILE Sym IN [Mult, RealDiv, IntDiv, IntMod, AndSy] DO
   BEGIN
      Operator := Sym;                             (* Operator merken         *)
      InSymbol;
      Factor([Mult, RealDiv, IntDiv, IntMod, AndSy] + Symbols, Item2);

      IF (Item.Typ = NoType) OR (Item2.Typ = NoType) THEN
      BEGIN
         WITH Item DO
         BEGIN
            Ref := NoTypeType;                     (* Defaultwerte            *)
            Typ := Ref^.Typ;
            Size := Ref^.Size;
         END;
      END
      ELSE IF (Item.Obj = Constants) AND
              (Item2.Obj = Constants) AND
              (Item.Typ IN [Ints, Reals, Bools]) AND
              (Item2.Typ IN [Ints, Reals, Bools]) THEN
      BEGIN                                        (* Konstantenfaltung       *)
         ProgCount := ProgCount - 2;               (* Zwei Befehle löschen    *)

         CASE Operator OF
            Mult :                                 (* Multiplikation          *)
            BEGIN
               IF (Item.Typ = Ints) AND (Item2.Typ = Ints) THEN
               BEGIN
                  Item.Value := Item.Value * Item2.Value;
                  Emit1(LoadInteger, Item.Value);
               END
               ELSE IF (Item.Typ = Ints) AND (Item2.Typ = Reals) THEN
               BEGIN
                  WITH Item DO
                  BEGIN
                     RealTable[Item2.Value] := RealTable[Item2.Value] * Value;
                     Value := Item2.Value;
                     Ref := RealType;
                     Typ := Ref^.Typ;
                     Size := Ref^.Size;
                     Emit1(LoadReal, Value);
                  END;
               END
               ELSE IF (Item.Typ = Reals) AND (Item2.Typ = Ints) THEN
               BEGIN
                  RealTable[Item.Value] := RealTable[Item.Value] * Item2.Value;
                  Emit1(LoadReal, Item.Value);
               END
               ELSE IF (Item.Typ = Reals) AND (Item2.Typ = Reals) THEN
               BEGIN
                  RealTable[Item.Value] :=
                     RealTable[Item.Value] * RealTable[Item2.Value];

                  Emit1(LoadReal, Item.Value);
               END
               ELSE
               BEGIN
                  Error(140);                      (* Unerlaubte Operation    *)

                  WITH Item DO
                  BEGIN
                     Ref := NoTypeType;            (* Defaultwerte            *)
                     Typ := Ref^.Typ;
                     Size := Ref^.Size;
                  END;
               END;
            END;

            RealDiv :                              (* Real Division           *)
            BEGIN
               IF (Item.Typ = Ints) AND (Item2.Typ = Ints) THEN
               BEGIN
                  IF Item2.Value = 0 THEN
                  BEGIN
                     Error(201);                   (* Division durch Null     *)

                     WITH Item DO
                     BEGIN
                        Ref := NoTypeType;         (* Defaultwerte            *)
                        Typ := Ref^.Typ;
                        Size := Ref^.Size;
                     END;
                  END
                  ELSE                             (* Nenner ungleich Null    *)
                  BEGIN
                     WITH Item DO
                     BEGIN
                        Value := EnterReal(Value);
                        Ref := RealType;
                        Typ := Ref^.Typ;
                        Size := Ref^.Size;

                        RealTable[Value] := RealTable[Value] / Item2.Value;
                        Emit1(LoadReal, Value);
                     END;
                  END;
               END
               ELSE IF (Item.Typ = Ints) AND (Item2.Typ = Reals) THEN
               BEGIN
                  IF RealTable[Item2.Value] = 0.0 THEN
                  BEGIN
                     Error(201);                   (* Division durch Null     *)

                     WITH Item DO
                     BEGIN
                        Ref := NoTypeType;         (* Defaultwerte            *)
                        Typ := Ref^.Typ;
                        Size := Ref^.Size;
                     END;
                  END
                  ELSE                             (* Nenner ungleich Null    *)
                  BEGIN
                     WITH Item DO
                     BEGIN
                        RealTable[Item2.Value] :=
                           Value / RealTable[Item2.Value];

                        Value := Item2.Value;
                        Ref := RealType;
                        Typ := Ref^.Typ;
                        Size := Ref^.Size;
                        Emit1(LoadReal, Value);
                     END;
                  END;
               END
               ELSE IF (Item.Typ = Reals) AND (Item2.Typ = Ints) THEN
               BEGIN
                  IF Item2.Value = 0 THEN
                  BEGIN
                     Error(201);                   (* Division durch Null     *)

                     WITH Item DO
                     BEGIN
                        Ref := NoTypeType;         (* Defaultwerte            *)
                        Typ := Ref^.Typ;
                        Size := Ref^.Size;
                     END;
                  END
                  ELSE                             (* Nenner ungleich Null    *)
                  BEGIN
                     RealTable[Item.Value] :=
                        RealTable[Item.Value] / Item2.Value;

                     Emit1(LoadReal, Item.Value);
                  END;
               END
               ELSE IF (Item.Typ = Reals) AND (Item2.Typ = Reals) THEN
               BEGIN
                  IF RealTable[Item2.Value] = 0.0 THEN
                  BEGIN
                     Error(201);                   (* Division durch Null     *)

                     WITH Item DO
                     BEGIN
                        Ref := NoTypeType;         (* Defaultwerte            *)
                        Typ := Ref^.Typ;
                        Size := Ref^.Size;
                     END;
                  END
                  ELSE                             (* Nenner ungleich Null    *)
                  BEGIN
                     RealTable[Item.Value] :=
                        RealTable[Item.Value] / RealTable[Item2.Value];

                     Emit1(LoadReal, Item.Value);
                  END;
               END
               ELSE
               BEGIN
                  Error(140);                      (* Unerlaubte Operation    *)

                  WITH Item DO
                  BEGIN
                     Ref := NoTypeType;            (* Defaultwerte            *)
                     Typ := Ref^.Typ;
                     Size := Ref^.Size;
                  END;
               END;
            END;

            AndSy :                                (* Logisches Und           *)
            BEGIN
               IF (Item.Typ = Bools) AND (Item2.Typ = Bools) THEN
               BEGIN
                  IF (Item.Value = 0) OR (Item2.Value = 0) THEN Item.Value := 0;
                  Emit1(LoadInteger, Item.Value);
               END
               ELSE
               BEGIN
                  Error(140);                      (* Unerlaubte Operation    *)

                  WITH Item DO
                  BEGIN
                     Ref := NoTypeType;            (* Defaultwerte            *)
                     Typ := Ref^.Typ;
                     Size := Ref^.Size;
                  END;
               END;
            END;

            IntDiv, IntMod :                       (* Int Div oder Int Mod    *)
            BEGIN
               IF (Item.Typ = Ints) AND (Item2.Typ = Ints) THEN
               BEGIN
                  IF Item2.Value = 0 THEN
                  BEGIN
                     Error(201);                   (* Division durch Null     *)

                     WITH Item DO
                     BEGIN
                        Ref := NoTypeType;         (* Defaultwerte            *)
                        Typ := Ref^.Typ;
                        Size := Ref^.Size;
                     END;
                  END
                  ELSE
                  BEGIN
                     IF Operator = IntDiv THEN
                        Item.Value := Item.Value DIV Item2.Value
                     ELSE Item.Value := Item.Value MOD Item2.Value;

                     Emit1(LoadInteger, Item.Value);
                  END;
               END
               ELSE
               BEGIN
                  Error(139);                      (* Faktor muß Integer sein *)

                  WITH Item DO
                  BEGIN
                     Ref := NoTypeType;            (* Defaultwerte            *)
                     Typ := Ref^.Typ;
                     Size := Ref^.Size;
                  END;
               END;
            END;
         END;
      END
      ELSE                                         (* Keine Optimierungen     *)
      BEGIN
         Item.Obj := Nothing;                      (* Verhindert Optimierung  *)

         CASE Operator OF
            Mult :                                 (* Multiplikation          *)
            BEGIN
               IF (Item.Typ IN [Ints, Reals]) AND
                  (Item2.Typ IN [Ints, Reals]) THEN
               BEGIN
                  IF (Item.Typ = Ints) AND (Item2.Typ = Reals) THEN
                  BEGIN
                     WITH Item DO
                     BEGIN
                        Ref := RealType;           (* Typ-Referenz            *)
                        Typ := Ref^.Typ;
                        Size := Ref^.Size;
                     END;

                     Emit1(IntegerToReal, 1);      (* Item Int nach Real      *)
                  END
                  ELSE IF (Item.Typ = Reals) AND (Item2.Typ = Ints) THEN
                     Emit1(IntegerToReal, 0);      (* Item2 Int nach Real     *)

                  IF Item.Typ = Ints THEN Emit(IntegerMultiplication)
                  ELSE Emit(RealMultiplication);
               END
               ELSE IF (Item.Typ = Sets) AND (Item2.Typ = Sets) THEN
               BEGIN
                  ;                                (* Nicht implementiert     *)
               END
               ELSE
               BEGIN
                  Error(140);                      (* Unerlaubte Operation    *)

                  WITH Item DO
                  BEGIN
                     Ref := NoTypeType;            (* Defaultwerte            *)
                     Typ := Ref^.Typ;
                     Size := Ref^.Size;
                  END;
               END;
            END;

            RealDiv :                              (* Real Division           *)
            BEGIN
               IF Item2.Obj = Constants THEN       (* Prüfung zur Compilezeit *)
               BEGIN
                  IF Item2.Typ = Reals THEN        (* Division durch Null     *)
                     IF RealTable[Item2.Value] = 0.0 THEN Error(201);

                  IF Item2.Typ = Ints THEN         (* Division durch Null     *)
                     IF Item2.Value = 0 THEN Error(201);
               END;

               IF Item.Typ = Ints THEN
               BEGIN
                  Emit1(IntegerToReal, 1);         (* Item Int nach Real      *)

                  WITH Item DO
                  BEGIN
                     Ref := RealType;              (* Typ-Referenz            *)
                     Typ := Ref^.Typ;
                     Size := Ref^.Size;
                  END;
               END;

               IF Item2.Typ = Ints THEN
               BEGIN
                  Emit1(IntegerToReal, 0);         (* Item2 Int nach Real     *)

                  WITH Item2 DO
                  BEGIN
                     Ref := RealType;              (* Typ-Referenz            *)
                     Typ := Ref^.Typ;
                     Size := Ref^.Size;
                  END;
               END;

               IF (Item.Typ = Reals) AND (Item2.Typ = Reals) THEN
                  Emit(RealDivision)               (* Reelle Division         *)
               ELSE
               BEGIN
                  Error(140);                      (* Unerlaubte Operation    *)

                  WITH Item DO
                  BEGIN
                     Ref := NoTypeType;            (* Defaultwerte            *)
                     Typ := Ref^.Typ;
                     Size := Ref^.Size;
                  END;
               END;
            END;

            AndSy :                                (* Logisches Und           *)
            BEGIN
               IF (Item.Typ = Bools) AND (Item2.Typ = Bools) THEN
                  Emit(LogicalAnd)
               ELSE
               BEGIN
                  Error(140);                      (* Unerlaubte Operation    *)

                  WITH Item DO
                  BEGIN
                     Ref := NoTypeType;            (* Defaultwerte            *)
                     Typ := Ref^.Typ;
                     Size := Ref^.Size;
                  END;
               END;
            END;

            IntDiv, IntMod :                       (* Int Div oder Int Mod    *)
            BEGIN
               IF (Item.Typ = Ints) AND (Item2.Typ = Ints) THEN
               BEGIN
                  IF Item2.Obj = Constants THEN    (* Division durch Null     *)
                     IF Item2.Value = 0 THEN Error(201);

                  IF Operator = IntDiv THEN Emit(IntegerDivision)
                  ELSE Emit(IntegerModulo)
               END
               ELSE
               BEGIN
                  Error(139);                      (* Faktor muß Integer sein *)

                  WITH Item DO
                  BEGIN
                     Ref := NoTypeType;            (* Defaultwerte            *)
                     Typ := Ref^.Typ;
                     Size := Ref^.Size;
                  END;
               END;
            END;
         END;
      END;
   END;
END; (* Term *)

BEGIN (* SimpleExpression *)
   IF Sym IN [Plus, Minus] THEN                    (* Vorzeichen              *)
   BEGIN
      Operator := Sym;
      InSymbol;
      Term([Plus, Minus] + Symbols, Item);         (* Vorzeichen, erster Term *)

      IF Item.Typ IN [NoType, Ints, Reals] THEN
      BEGIN
         IF Operator = Minus THEN
         BEGIN
            IF Item.Obj = Constants THEN           (* Konstantenfaltung       *)
            BEGIN
               ProgCount := ProgCount - 1;         (* Einen Befehl löschen    *)

               CASE Item.Typ OF
                  NoType : ;
                  Ints   : Emit1(LoadInteger, -Item.Value);

                  Reals :
                  BEGIN
                     RealTable[Item.Value] := -RealTable[Item.Value];
                     Emit1(LoadReal, Item.Value);
                  END;
               END;
            END
            ELSE
            BEGIN
               CASE Item.Typ OF
                  NoType : ;
                  Ints   : Emit(NegateInteger);    (* Ganze Zahl negieren     *)
                  Reals  : Emit(NegateReal);       (* Reelle Zahl negieren    *)
               END;
            END;
         END;
      END
      ELSE
      BEGIN
         Error(140);                               (* Unerlaubter Typ         *)

         WITH Item DO
         BEGIN
            Ref := NoTypeType;                     (* Defaultwerte            *)
            Typ := Ref^.Typ;
            Size := Ref^.Size;
         END;
      END;
   END
   ELSE Term([Plus, Minus, OrSy] + Symbols, Item); (* Erster Term             *)

   WHILE Sym IN [Plus, Minus, OrSy] DO
   BEGIN
      Operator := Sym;
      InSymbol;
      Term([Plus, Minus, OrSy] + Symbols, Item2);  (* Zweiter Term            *)

      IF (Item.Typ = NoType) OR (Item2.Typ = NoType) THEN
      BEGIN
         WITH Item DO
         BEGIN
            Ref := NoTypeType;                     (* Defaultwerte            *)
            Typ := Ref^.Typ;
            Size := Ref^.Size;
         END;
      END
      ELSE IF (Item.Obj = Constants) AND
              (Item2.Obj = Constants) AND
              (Item.Typ IN [Ints, Reals, Bools]) AND
              (Item2.Typ IN [Ints, Reals, Bools]) THEN
      BEGIN                                        (* Konstantenfaltung       *)
         ProgCount := ProgCount - 2;               (* Zwei Befehle löschen    *)

         CASE Operator OF
            OrSy :                                 (* Logisches Oder          *)
            BEGIN
               IF (Item.Typ = Bools) AND (Item2.Typ = Bools) THEN
               BEGIN
                  IF (Item.Value <> 0) OR (Item2.Value <> 0) THEN
                     Item.Value := 1;

                  Emit1(LoadInteger, Item.Value);
               END
               ELSE
               BEGIN
                  Error(138);                      (* Faktor muß Boolean sein *)

                  WITH Item DO
                  BEGIN
                     Ref := NoTypeType;            (* Defaultwerte            *)
                     Typ := Ref^.Typ;
                     Size := Ref^.Size;
                  END;
               END;
            END;

            Plus :                                 (* Plus                    *)
            BEGIN
               IF (Item.Typ = Ints) AND (Item2.Typ = Ints) THEN
               BEGIN
                  Item.Value := Item.Value + Item2.Value;
                  Emit1(LoadInteger, Item.Value);
               END
               ELSE IF (Item.Typ = Ints) AND (Item2.Typ = Reals) THEN
               BEGIN
                  WITH Item DO
                  BEGIN
                     RealTable[Item2.Value] := RealTable[Item2.Value] + Value;
                     Value := Item2.Value;
                     Ref := RealType;
                     Typ := Ref^.Typ;
                     Size := Ref^.Size;
                     Emit1(LoadReal, Value);
                  END;
               END
               ELSE IF (Item.Typ = Reals) AND (Item2.Typ = Ints) THEN
               BEGIN
                  RealTable[Item.Value] := RealTable[Item.Value] + Item2.Value;
                  Emit1(LoadReal, Item.Value);
               END
               ELSE IF (Item.Typ = Reals) AND (Item2.Typ = Reals) THEN
               BEGIN
                  RealTable[Item.Value] :=
                     RealTable[Item.Value] + RealTable[Item2.Value];

                  Emit1(LoadReal, Item.Value);
               END
               ELSE
               BEGIN
                  Error(140);                      (* Unerlaubte Operation    *)

                  WITH Item DO
                  BEGIN
                     Ref := NoTypeType;            (* Defaultwerte            *)
                     Typ := Ref^.Typ;
                     Size := Ref^.Size;
                  END;
               END;
            END;

            Minus :                                (* Minus                   *)
            BEGIN
               IF (Item.Typ = Ints) AND (Item2.Typ = Ints) THEN
               BEGIN
                  Item.Value := Item.Value - Item2.Value;
                  Emit1(LoadInteger, Item.Value);
               END
               ELSE IF (Item.Typ = Ints) AND (Item2.Typ = Reals) THEN
               BEGIN
                  WITH Item DO
                  BEGIN
                     RealTable[Item2.Value] := Value - RealTable[Item2.Value];
                     Value := Item2.Value;
                     Ref := RealType;
                     Typ := Ref^.Typ;
                     Size := Ref^.Size;
                     Emit1(LoadReal, Value);
                  END;
               END
               ELSE IF (Item.Typ = Reals) AND (Item2.Typ = Ints) THEN
               BEGIN
                  RealTable[Item.Value] := RealTable[Item.Value] - Item2.Value;
                  Emit1(LoadReal, Item.Value);
               END
               ELSE IF (Item.Typ = Reals) AND (Item2.Typ = Reals) THEN
               BEGIN
                  RealTable[Item.Value] :=
                     RealTable[Item.Value] - RealTable[Item2.Value];

                  Emit1(LoadReal, Item.Value);
               END
               ELSE
               BEGIN
                  Error(140);                      (* Unerlaubte Operation    *)

                  WITH Item DO
                  BEGIN
                     Ref := NoTypeType;            (* Defaultwerte            *)
                     Typ := Ref^.Typ;
                     Size := Ref^.Size;
                  END;
               END;
            END;
         END;
      END
      ELSE                                         (* Keine Optimierungen     *)
      BEGIN
         Item.Obj := Nothing;                      (* Verhindert Optimierung  *)

         CASE Operator OF
            OrSy :                                 (* Logisches Oder          *)
            BEGIN
               IF (Item.Typ = Bools) AND (Item2.Typ = Bools) THEN
                  Emit(LogicalOr)
               ELSE
               BEGIN
                  Error(138);                      (* Faktor muß Boolean sein *)

                  WITH Item DO
                  BEGIN
                     Ref := NoTypeType;            (* Defaultwerte            *)
                     Typ := Ref^.Typ;
                     Size := Ref^.Size;
                  END;
               END;
            END;

            Plus :                                 (* Plus                    *)
            BEGIN                                  (* Zahlen und Mengen       *)
               IF (Item.Typ IN [Ints, Reals]) AND
                  (Item2.Typ IN [Ints, Reals]) THEN
               BEGIN
                  IF (Item.Typ = Ints) AND (Item2.Typ = Reals) THEN
                  BEGIN
                     WITH Item DO
                     BEGIN
                        Ref := RealType;           (* Typ-Referenz            *)
                        Typ := Ref^.Typ;
                        Size := Ref^.Size;
                     END;

                     Emit1(IntegerToReal, 1);      (* Item Int nach Real      *)
                  END
                  ELSE IF (Item.Typ = Reals) AND (Item2.Typ = Ints) THEN
                     Emit1(IntegerToReal, 0);      (* Item2 Int nach Real     *)

                  IF Item.Typ = Ints THEN Emit(IntegerPlus)
                  ELSE Emit(RealPlus);
               END
               ELSE IF (Item.Typ = Sets) AND (Item2.Typ = Sets) THEN
               BEGIN
                  ;                                (* Nicht implementiert     *)
               END
               ELSE
               BEGIN
                  Error(140);                      (* Unerlaubter Typ         *)

                  WITH Item DO
                  BEGIN
                     Ref := NoTypeType;            (* Defaultwerte            *)
                     Typ := Ref^.Typ;
                     Size := Ref^.Size;
                  END;
               END;
            END;

            Minus :                                (* Minus                   *)
            BEGIN                                  (* Zahlen, Mengen          *)
               IF (Item.Typ IN [Ints, Reals]) AND
                  (Item2.Typ IN [Ints, Reals]) THEN
               BEGIN
                  IF (Item.Typ = Ints) AND (Item2.Typ = Reals) THEN
                  BEGIN
                     WITH Item DO
                     BEGIN
                        Ref := RealType;           (* Typ-Referenz            *)
                        Typ := Ref^.Typ;
                        Size := Ref^.Size;
                     END;

                     Emit1(IntegerToReal, 1);      (* Item Int nach Real      *)
                  END
                  ELSE IF (Item.Typ = Reals) AND (Item2.Typ = Ints) THEN
                     Emit1(IntegerToReal, 0);      (* Item2 Int nach Real     *)

                  IF Item.Typ = Ints THEN Emit(IntegerMinus)
                  ELSE Emit(RealMinus);
               END
               ELSE IF (Item.Typ = Sets) AND (Item2.Typ = Sets) THEN
               BEGIN
                  ;                                (* Nicht implementiert     *)
               END
               ELSE
               BEGIN
                  Error(140);                      (* Unerlaubter Typ         *)

                  WITH Item DO
                  BEGIN
                     Ref := NoTypeType;            (* Defaultwerte            *)
                     Typ := Ref^.Typ;
                     Size := Ref^.Size;
                  END;
               END;
            END;
         END;
      END;
   END;
END; (* SimpleExpression *)

BEGIN (* Expression *)
   SimpleExpression([Eql, Neq, Lss, Leq, Gtr, Geq, InSy] + Symbols, Item);

   IF Sym IN [Eql, Neq, Lss, Leq, Gtr, Geq, InSy] THEN
   BEGIN
      Operator := Sym;
      InSymbol;
      SimpleExpression(Symbols, Item2);

      IF (Item.Typ = NoType) OR (Item2.Typ = NoType) THEN
      BEGIN
         WITH Item DO
         BEGIN
            Ref := NoTypeType;                     (* Defaultwerte            *)
            Typ := Ref^.Typ;
            Size := Ref^.Size;
         END;
      END
      ELSE IF (Item.Obj = Constants) AND
              (Item2.Obj = Constants) AND
              (Item.Typ IN [Ints, Reals, Bools, Chars, Enumerations]) AND
              (Item2.Typ IN [Ints, Reals, Bools, Chars, Enumerations]) THEN
      BEGIN                                        (* Konstantenfaltung       *)
         ProgCount := ProgCount - 2;               (* Zwei Befehle löschen    *)
         Result := FALSE;                          (* Defaultwert             *)

         IF (Item.Typ IN [Ints, Bools, Chars, Enumerations]) AND
            (Item.Ref = Item2.Ref) THEN
         BEGIN
            CASE Operator OF
               Eql  : Result := Item.Value = Item2.Value;
               Neq  : Result := Item.Value <> Item2.Value;
               Lss  : Result := Item.Value < Item2.Value;
               Leq  : Result := Item.Value <= Item2.Value;
               Gtr  : Result := Item.Value > Item2.Value;
               Geq  : Result := Item.Value >= Item2.Value;
               InSy : Error(144);                  (* Operator unzulässig     *)
            END;
         END
         ELSE IF (Item.Typ = Ints) AND (Item2.Typ = Reals) THEN
         BEGIN
            CASE Operator OF
               Eql  : Result := Item.Value = RealTable[Item2.Value];
               Neq  : Result := Item.Value <> RealTable[Item2.Value];
               Lss  : Result := Item.Value < RealTable[Item2.Value];
               Leq  : Result := Item.Value <= RealTable[Item2.Value];
               Gtr  : Result := Item.Value > RealTable[Item2.Value];
               Geq  : Result := Item.Value >= RealTable[Item2.Value];
               InSy : Error(144);                  (* Operator unzulässig     *)
            END;
         END
         ELSE IF (Item.Typ = Reals) AND (Item2.Typ = Ints) THEN
         BEGIN
            CASE Operator OF
               Eql  : Result := RealTable[Item.Value] = Item2.Value;
               Neq  : Result := RealTable[Item.Value] <> Item2.Value;
               Lss  : Result := RealTable[Item.Value] < Item2.Value;
               Leq  : Result := RealTable[Item.Value] <= Item2.Value;
               Gtr  : Result := RealTable[Item.Value] > Item2.Value;
               Geq  : Result := RealTable[Item.Value] >= Item2.Value;
               InSy : Error(144);                  (* Operator unzulässig     *)
            END;
         END
         ELSE IF (Item.Typ = Reals) AND (Item2.Typ = Reals) THEN
         BEGIN
            CASE Operator OF
               Eql  : Result := RealTable[Item.Value] = RealTable[Item2.Value];
               Neq  : Result := RealTable[Item.Value] <> RealTable[Item2.Value];
               Lss  : Result := RealTable[Item.Value] < RealTable[Item2.Value];
               Leq  : Result := RealTable[Item.Value] <= RealTable[Item2.Value];
               Gtr  : Result := RealTable[Item.Value] > RealTable[Item2.Value];
               Geq  : Result := RealTable[Item.Value] >= RealTable[Item2.Value];
               InSy : Error(144);                  (* Operator unzulässig     *)
            END;
         END
         ELSE Error(143);                          (* Typenvergleich verboten *)

         WITH Item DO
         BEGIN
            IF Result THEN Value := 1
            ELSE Value := 0;

            Ref := BooleanType;
            Typ := Ref^.Typ;
            Size := Ref^.Size;
            Emit1(LoadInteger, Value);
         END;
      END
      ELSE                                         (* Keine Optimierungen     *)
      BEGIN
         Item.Obj := Nothing;                      (* Verhindert Optimierung  *)

         IF (Item.Typ IN [Ints, Bools, Chars, Enumerations]) AND
            (Item.Ref = Item2.Ref) THEN
         BEGIN
            CASE Operator OF
               Eql  : Emit(IntegerEql);
               Neq  : Emit(IntegerNeq);
               Lss  : Emit(IntegerLss);
               Leq  : Emit(IntegerLeq);
               Gtr  : Emit(IntegerGtr);
               Geq  : Emit(IntegerGeq);
               InSy : Error(144);                  (* Operator unzulässig     *)
            END;
         END
         ELSE IF (Item.Typ = Pointers) AND (Item2.Typ = Pointers) THEN
         BEGIN
            IF (Item.Obj <> Constants) AND
               (Item2.Obj <> Constants) THEN       (* Keine Nil Konstanten    *)
                  IF Item.Ref <> Item2.Ref THEN    (* Gleiche Pointertypen    *)
                     Error(143);                   (* Typenvergleich verboten *)

            IF Operator = Eql THEN Emit(IntegerEql)
            ELSE IF Operator = Neq THEN Emit(IntegerNeq)
            ELSE Error(144);                       (* Operator unzulässig     *)
         END
         ELSE IF (Item.Typ = Sets) AND (Item2.Typ = Sets) THEN
         BEGIN
            ;                                      (* Nicht implementiert     *)
         END
         ELSE IF (Item.Typ IN [Ints, Bools, Chars, Enumerations]) AND
            (Item2.Typ = Sets) THEN
         BEGIN
            IF Operator <> InSy THEN Error(144)    (* Operator unzulässig     *)
            ELSE
            BEGIN
               ;                                   (* Nicht implementiert     *)
            END;
         END
         ELSE IF (Item.Typ IN [Ints, Reals]) AND
            (Item2.Typ IN [Ints, Reals]) THEN
         BEGIN
            IF Item.Typ = Ints THEN
            BEGIN
               WITH Item DO
               BEGIN
                  Ref := RealType;                 (* Typ-Referenz            *)
                  Typ := Ref^.Typ;
                  Size := Ref^.Size;
               END;

               Emit1(IntegerToReal, 1);            (* Item Int nach Real      *)
            END
            ELSE IF Item2.Typ = Ints THEN
               Emit1(IntegerToReal, 0);            (* Item2 Int nach Real     *)

            CASE Operator OF
               Eql  : Emit(RealEql);
               Neq  : Emit(RealNeq);
               Lss  : Emit(RealLss);
               Leq  : Emit(RealLeq);
               Gtr  : Emit(RealGtr);
               Geq  : Emit(RealGeq);
               InSy : Error(144);                  (* Operator unzulässig     *)
            END;
         END
         ELSE IF (Item.Typ IN [Strings, Arrays]) AND
            (Item2.Typ IN [Strings, Arrays]) THEN
         BEGIN
            IF Item.Typ = Arrays THEN
               IF Item.Ref^.ElementType^.Typ <> Chars THEN
                  Error(144);                      (* Operator unzulässig     *)

            IF Item2.Typ = Arrays THEN
               IF Item2.Ref^.ElementType^.Typ <> Chars THEN
                  Error(144);                      (* Operator unzulässig     *)

            IF (Item.Typ = Arrays) AND (Item2.Typ = Arrays) THEN
            BEGIN
               IF Item.Ref <> Item2.Ref THEN
                  Error(143);                      (* Typenvergleich verboten *)
            END
            ELSE IF Item.Size <> Item2.Size THEN Error(143);

            CASE Operator OF
               Eql  : Emit1(StringEql, Item.Size);
               Neq  : Emit1(StringNeq, Item.Size);
               Lss  : Emit1(StringLss, Item.Size);
               Leq  : Emit1(StringLeq, Item.Size);
               Gtr  : Emit1(StringGtr, Item.Size);
               Geq  : Emit1(StringGeq, Item.Size);
               InSy : Error(144);                  (* Operator unzulässig     *)
            END;
         END
         ELSE Error(143);                          (* Typenvergleich verboten *)

         WITH Item DO
         BEGIN
            Ref := BooleanType;                    (* Ergebnistyp             *)
            Typ := Ref^.Typ;
            Size := Ref^.Size;
         END;
      END;
   END;
END; (* Expression *)

(* END EXPRESS.PAS *)
