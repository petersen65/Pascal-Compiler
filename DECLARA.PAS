(**************************************************)
(* Programmname    : DECLARA.PAS                  *)
(* Programmautor   : Michael Rippl                *)
(* Compiler        : Turbo Pascal V5.0            *)
(* Letzte Änderung : 18-Feb-1990                  *)
(* Inhalt          : Deklarationen                *)
(* Bemerkung       : Include Datei von PARSER.PAS *)
(**************************************************)

(* Parameterliste einer Prozedur oder Funktion in Symboltabelle eintragen *)
PROCEDURE ParameterList;
VAR VariableRemember : pRing;                      (* Variablen merken        *)
    ValueParameter,                                (* Wertparameter = True    *)
    Found            : BOOLEAN;
    Dummy,                                         (* Nur als Platzhalter     *)
    TypeRef          : pType;                      (* Datentyp der Parameter  *)
    Elt              : pNode;
    TypeSize,                                      (* Größe des Datentyps     *)
    FoundAt          : INTEGER;
BEGIN
   InSymbol;                                       (* LeftParent gelesen      *)
   TypeRef := NoTypeType;                          (* Defaultwert             *)
   CreateRing(VariableRemember);                   (* Variablen merken        *)
   Match([Identifier, VarSy], [RightParent, ForwardSy] + Symbols, 61);

   WHILE Sym IN [Identifier, VarSy] DO
   BEGIN
      IF Sym <> VarSy THEN ValueParameter := TRUE  (* Wertparameter           *)
      ELSE
      BEGIN
         InSymbol;
         ValueParameter := FALSE;                  (* Formaler Parameter      *)
      END;

      IF Sym = Identifier THEN
      BEGIN
         Insert(Id, Level, Variables, Elt, Found);
         IF NOT Found THEN Push(VariableRemember, Elt, NIL);
         InSymbol;
      END
      ELSE Error(20);                              (* Bezeichner erwartet     *)

      WHILE Sym = Comma DO                         (* Variablenliste einlesen *)
      BEGIN
         InSymbol;

         IF Sym = Identifier THEN
         BEGIN
            Insert(Id, Level, Variables, Elt, Found);
            IF NOT Found THEN Push(VariableRemember, Elt, NIL);
            InSymbol;
         END
         ELSE Error(20);                           (* Bezeichner erwartet     *)
      END;

      IF Sym = Colon THEN InSymbol
      ELSE Error(37);                              (* Symbol : erwartet       *)

      IF Sym = Identifier THEN                     (* Datentyp auswerten      *)
      BEGIN
         Locate(Id, Level, Elt, FoundAt);          (* Bezeichner suchen       *)

         IF FoundAt >= 0 THEN
         BEGIN
            IF Elt^.Obj <> Datatypes THEN
               Error(141)                          (* Datentyp erwartet       *)
            ELSE IF ValueParameter AND (Elt^.Typ = Files) THEN
               Error(135)                          (* Datei nur Var Parameter *)
            ELSE
            BEGIN
               TypeRef := Elt^.Ref;                (* Typ-Referenz merken     *)

               IF NOT ValueParameter THEN          (* Kein Wertparameter      *)
                  TypeSize := IntSize              (* Bedarf einer Adresse    *)
               ELSE TypeSize := TypeRef^.Size;     (* Speicherplatzbedarf     *)
            END;
         END;

         InSymbol;
      END
      ELSE
      BEGIN
         Error(129);                               (* Typbezeichner erwartet  *)

         IF Sym IN TypeBegSym THEN
            Typ([Semicolon, RightParent] + Symbols, Dummy);
      END;

      Match([Semicolon, RightParent], [Identifier,
            Comma, ForwardSy] + Symbols, 23);      (* Symbol ; erwartet       *)

      WHILE NOT RingIsEmpty(VariableRemember) DO
      BEGIN
         Pop(VariableRemember, Elt, Dummy);

         WITH Elt^ DO
         BEGIN
            Ref := TypeRef;                        (* Typ-Referenz            *)
            Typ := Ref^.Typ;
            Size := Ref^.Size;
            Adr := DataOffset;                     (* DataOffset aus Block    *)
            Nrm := ValueParameter;
            DataOffset := DataOffset + TypeSize;
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

         Match([Identifier, VarSy], [RightParent, ForwardSy] + Symbols, 6);
      END;
   END;

   IF Sym = RightParent THEN InSymbol
   ELSE Error(41);                                 (* Symbol ) erwartet       *)

   Match([Semicolon, Colon], [ForwardSy] + Symbols, 6);

   WHILE NOT RingIsEmpty(ProcElement^.Par) DO    (* Ein und dieselbe Prozedur *)
   BEGIN                                         (* kann im Fehlerfall mehr-  *)
      Pop(ProcElement^.Par, Elt, Dummy);         (* fach auftauchen. Siehe in *)
      dispose(Elt);                              (* ProcedureDeclaration nach *)
   END;

   WHILE NOT RingIsEmpty(Remember[Level]) DO       (* Parameterliste nicht    *)
   BEGIN                                           (* in der Speicherliste    *)
      Pop(Remember[Level], Elt, Dummy);
      Push(ProcElement^.Par, Elt, NIL);
   END;

   DeleteRing(VariableRemember);                   (* Listenkopf löschen      *)
END; (* ParameterList *)

(* Deklarierte Labels in Symboltabelle eintragen *)
PROCEDURE LabelDeclaration;
VAR Elt   : pNode;
    Found : BOOLEAN;
BEGIN
   InSymbol;                                       (* Label schon gelesen     *)
   Match([IntConst], [Comma] + BlockBegSym, 24);   (* Labelkonstante erwartet *)

   IF Sym = IntConst THEN
   BEGIN
      IF IntNum > LabelMax THEN Error(24)          (* Labelkonstante erwartet *)
      ELSE
      BEGIN
         Insert(Id, Level, Labels, Elt, Found);

         IF NOT Found THEN
            Push(LabelRemember, Elt, NIL);         (* Label merken            *)
      END;

      InSymbol;
   END;

   WHILE Sym = Comma DO
   BEGIN
      InSymbol;

      IF Sym = IntConst THEN
      BEGIN
         IF IntNum > LabelMax THEN Error(24)       (* Labelkonstante erwartet *)
         ELSE
         BEGIN
            Insert(Id, Level, Labels, Elt, Found);

            IF NOT Found THEN
               Push(LabelRemember, Elt, NIL);      (* Label merken            *)
         END;

         InSymbol;
      END
      ELSE Error(24);                              (* Labelkonstante erwartet *)
   END;

   IF Sym = Semicolon THEN InSymbol
   ELSE
   BEGIN
      Error(23);                                   (* Symbol ; erwartet       *)
      IF Sym = Colon THEN InSymbol;
   END;

   Match(BlockBegSym, Symbols, 6);
END; (* LabelDeclaration *)

(* Deklarierte Konstanten in Symboltabelle eintragen *)
PROCEDURE ConstantDeclaration;
VAR ConstRef : Node;                               (* Daten einer Konstante   *)
    Elt      : pNode;
    Found    : BOOLEAN;
BEGIN
   InSymbol;                                       (* Const schon gelesen     *)
   Match([Identifier], BlockBegSym, 20);           (* Bezeichner erwartet     *)

   WHILE Sym = Identifier DO
   BEGIN
      Insert(Id, Level, Nothing, Elt, Found);
      InSymbol;

      IF Sym = Eql THEN InSymbol
      ELSE
      BEGIN
         Error(43);                                (* Symbol = erwartet       *)
         IF Sym = Becomes THEN InSymbol;
      END;

      Constant([Semicolon, Comma, Identifier] + Symbols, ConstRef);

      IF ConstRef.Typ = Enumerations THEN          (* Aufzählungskonstante    *)
         Error(123)                                (* Falsche Konstante       *)
      ELSE IF NOT Found THEN
      BEGIN
         WITH Elt^ DO
         BEGIN
            Obj := Constants;
            Ref := ConstRef.Ref;                   (* Typ-Referenz            *)
            Typ := Ref^.Typ;
            Size := Ref^.Size;
            Value := ConstRef.Value;               (* Wert der Konstanten     *)
         END;
      END;

      MatchSemicolon;
   END;
END; (* ConstantDeclaration *)

(* Deklarierte Datentypen in Symboltabelle eintragen *)
PROCEDURE TypeDeclaration;
VAR Dummy : pType;                                 (* Nur Platzhalter         *)
    Elt   : pNode;
    Found : BOOLEAN;
BEGIN
   InSymbol;                                       (* Type schon gelesen      *)
   Match([Identifier], BlockBegSym, 20);           (* Bezeichner erwartet     *)

   WHILE Sym = Identifier DO
   BEGIN
      Insert(Id, Level, Nothing, Elt, Found);
      InSymbol;

      IF Sym = Eql THEN InSymbol
      ELSE
      BEGIN
         Error(43);                                (* Symbol = erwartet       *)
         IF Sym = Becomes THEN InSymbol;
      END;

      IF Found THEN Typ([Semicolon, Comma, Identifier] + Symbols, Dummy)
      ELSE
      BEGIN
         Typ([Semicolon, Comma, Identifier] + Symbols, Elt^.Ref);

         WITH Elt^ DO
         BEGIN
            Obj := Datatypes;
            Typ := Ref^.Typ;
            Size := Ref^.Size;
         END;
      END;

      MatchSemicolon;
   END;
END; (* TypeDeclaration *)

(* Deklarierte Variablen in Symboltabelle eintragen *)
PROCEDURE VariableDeclaration;
VAR VariableRemember : pRing;                      (* Variablen merken        *)
    TypeRef,                                       (* Typ-Referenz            *)
    Dummy            : pType;                      (* Nur Platzhalter         *)
    Elt              : pNode;
    Found            : BOOLEAN;
BEGIN
   InSymbol;                                       (* Var schon gelesen       *)
   Match([Identifier], BlockBegSym, 20);           (* Bezeichner erwartet     *)
   CreateRing(VariableRemember);

   WHILE Sym = Identifier DO
   BEGIN
      Insert(Id, Level, Variables, Elt, Found);

      IF NOT Found THEN
         Push(VariableRemember, Elt, NIL);         (* Variable merken         *)

      InSymbol;

      WHILE Sym = Comma DO
      BEGIN
         InSymbol;

         IF Sym = Identifier THEN
         BEGIN
            Insert(Id, Level, Variables, Elt, Found);

            IF NOT Found THEN
               Push(VariableRemember, Elt, NIL);   (* Variable merken         *)

            InSymbol;
         END
         ELSE Error(20);                           (* Bezeichner erwartet     *)
      END;

      IF Sym = Colon THEN InSymbol
      ELSE Error(37);                              (* Symbol : erwartet       *)

      Typ([Semicolon, Comma, Identifier] + Symbols, TypeRef);

      WHILE NOT RingIsEmpty(VariableRemember) DO
      BEGIN
         Pop(VariableRemember, Elt, Dummy);

         WITH Elt^ DO
         BEGIN
            Ref := TypeRef;                        (* Typ-Referenz            *)
            Typ := Ref^.Typ;
            Size := Ref^.Size;
            Adr := DataOffset;                     (* DataOffset aus Block    *)
            DataOffset := DataOffset + Size;
         END;
      END;

      MatchSemicolon;
   END;

   DeleteRing(VariableRemember);                   (* Listenkopf löschen      *)
END; (* VariableDeclaration *)

(* Deklarierte Prozeduren und Funktionen in Symboltabelle eintragen *)
PROCEDURE ProcedureDeclaration;
VAR Found,
    IsFunction : BOOLEAN;                          (* Funktion oder Prozedur  *)
    NrOfBytes  : INTEGER;                          (* Schreiben in Datei      *)
    Elt        : pNode;
BEGIN
   IsFunction := Sym = FunctionSy;
   InSymbol;

   IF Sym <> Identifier THEN
   BEGIN
      Error(20);                                   (* Bezeichner erwartet     *)
      Id := '                ';
   END;

   Search(Id, Level, Elt, Found);                  (* Programmname suchen     *)

   IF Found THEN                                   (* Name schon vorhanden    *)
   BEGIN
      IF Sym <> LeftParent THEN InSymbol;          (* Falls kein Programmname *)

      IF Elt^.Adr <> IsForward THEN                (* Vorwärtsdeklariert      *)
      BEGIN
         Error(72);                                (* Bereits vorhanden       *)
         Insert('----------------', Level, Nothing, Elt, Found);

         IF NOT Found THEN CreateRing(Elt^.Par);   (* Liste für Parameter     *)
      END
      ELSE
      BEGIN
         IF Level = LevelMax THEN Fatal(3);        (* Leveltabelle voll       *)

         Display[Level + 1] := Elt^.Rem;           (* Gemerkte Parameter      *)
         Elt^.Rem := NIL;
         DeleteElement(ProcedureRemember, Elt);    (* Gemerkte Prozedur       *)

         IF (IsFunction AND (Elt^.Obj = Procedures)) OR
            (NOT IsFunction AND (Elt^.Obj = Functions)) THEN
               Error(82);                          (* Forward <> Deklaration  *)

         IF Sym = LeftParent THEN
         BEGIN
            Skip([RightParent] + BlockBegSym + StateBegSym, 81);
            InSymbol;                              (* Unerlaubte Parameter    *)
         END;
      END;
   END
   ELSE
   BEGIN                                           (* Neuer Prozedureintrag   *)
      IF IsFunction THEN Insert(Id, Level, Functions, Elt, Found)
      ELSE Insert(Id, Level, Procedures, Elt, Found);

      CreateRing(Elt^.Par);                        (* Liste für Parameter     *)
      IF Sym <> LeftParent THEN InSymbol;          (* Falls kein Programmname *)
   END;

   IF Level = LevelMax THEN Fatal(3);              (* Leveltabelle voll       *)
   Block(Symbols, Level + 1, Elt, IsFunction);

   IF Sym = Semicolon THEN InSymbol
   ELSE Error(23);                                 (* Symbol ; erwartet       *)

   IF Elt^.Adr = IsForward THEN Push(ProcedureRemember, Elt, NIL)
   ELSE IF IsFunction THEN Emit(ExitFunction)
   ELSE Emit(ExitProcedure);

END; (* ProcedureDeclaration *)

(* END DECLARA.PAS *)
