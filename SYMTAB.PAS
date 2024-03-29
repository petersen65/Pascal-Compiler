(*************************************************************)
(* Programmname    : SYMTAB.PAS                              *)
(* Programmautor   : Michael Rippl                           *)
(* Compiler        : Turbo Pascal V5.0                       *)
(* Letzte Änderung : 14-Jan-1990                             *)
(* Inhalt          : Symboltabllen-Verwaltung von PASCAL.PAS *)
(* Bemerkung       : Include Datei von PASCAL.PAS            *)
(*************************************************************)

(* Ring für Aufnahme von Zeigern erzeugen *)
PROCEDURE CreateRing(VAR Head : pRing);
BEGIN
   new(Head);

   Head^.Next := Head;                             (* Leere Liste zeigt auf   *)
   Head^.Prev := Head;                             (* sich selbst             *)
END; (* CreateRing *)

(* Ring wird überprüft, ob er leer ist *)
FUNCTION RingIsEmpty(Head : pRing) : BOOLEAN;
BEGIN
   RingIsEmpty := Head = Head^.Next;
END; (* RingIsEmpty *)

(* Element in die Liste einfügen *)
PROCEDURE Push(Head : pRing; ObjContent : pNode; TypContent : pType);
VAR Elt : pRing;
BEGIN
   new(Elt);

   WITH Elt^ DO                                    (* Neues Element           *)
   BEGIN
      ObjectContent := ObjContent;                 (* Objekt eintragen        *)
      TypeContent := TypContent;                   (* Datentyp eintragen      *)
      Next := Head;                                (* Nachfolger des Elements *)
      Prev := Head^.Prev;                          (* Vorgänger des Elements  *)
   END;

   WITH Head^ DO                                   (* Listenkopf              *)
   BEGIN
      Prev^.Next := Elt;                           (* Vorgängers Nachfolger   *)
      Prev := Elt;                                 (* Vorgänger               *)
   END;
END; (* Push *)

(* Element aus der Liste entfernen *)
PROCEDURE Pop(Head : pRing; VAR ObjContent : pNode; VAR TypContent : pType);
VAR Elt : pRing;
BEGIN
   IF NOT RingIsEmpty(Head) THEN                   (* Liste nicht leer        *)
   BEGIN
      Elt := Head^.Next;                           (* Zu entfernendes Element *)
      ObjContent := Elt^.ObjectContent;
      TypContent := Elt^.TypeContent;

      WITH Head^ DO
      BEGIN
         Next := Elt^.Next;                        (* Neuer Nachfolger        *)
         Next^.Prev := Head;                       (* Nachfolgers Vorgänger   *)
      END;

      dispose(Elt);                                (* Element löschen         *)
   END;
END; (* Pop *)

(* Kompletten Ring löschen *)
PROCEDURE DeleteRing(VAR Head : pRing);
VAR Elt  : pNode;                                  (* Nur als Dummy           *)
    Elt1 : pType;                                  (* Nur als Dummy           *)
BEGIN
   WHILE NOT RingIsEmpty(Head) DO
      Pop(Head, Elt, Elt1);                        (* Ring leeren             *)

   dispose(Head);                                  (* Listenkopf löschen      *)
   Head := NIL;
END; (* DeleteRing *)

(* Durch Inhalt bestimmtes Objekt suchen und löschen *)
PROCEDURE DeleteElement(Head : pRing; ObjContent : pNode);
VAR Elt1 : pRing;                                  (* Hilfszeiger             *)
BEGIN
   IF NOT RingIsEmpty(Head) THEN                   (* Liste nicht leer        *)
   BEGIN
      Elt1 := Head^.Next;

      WHILE Elt1 <> Head DO                        (* Liste durchlaufen       *)
      BEGIN
         IF Elt1^.ObjectContent = ObjContent THEN  (* Gesuchtes Element       *)
         BEGIN
            Elt1^.Prev^.Next := Elt1^.Next;        (* Vorgängers Nachfolger   *)
            Elt1^.Next^.Prev := Elt1^.Prev;        (* Nachfolgers Vorgänger   *)
            dispose(Elt1);                         (* Element löschen         *)
            Elt1 := Head;
         END
         ELSE Elt1 := Elt1^.Next;
      END;
   END;
END; (* Delete Element *)

(* Bezeichner in Symboltabelle eines Levels suchen *)
PROCEDURE Search(IdName : IdText; Level : INTEGER; VAR Elt : pNode;
                 VAR Found : BOOLEAN);

(* Binärbaum nach Bezeichner durchsuchen *)
PROCEDURE Visit(Nd : pNode);
BEGIN
   IF IdName < Nd^.Name THEN                       (* Im linken Teilbaum      *)
   BEGIN
      IF Nd^.Left <> NIL THEN Visit(Nd^.Left)
      ELSE
      BEGIN
         Elt := Nd;
         Found := FALSE;
      END;
   END
   ELSE IF IdName > Nd^.Name THEN                  (* Im rechten Teilbaum     *)
   BEGIN
      IF Nd^.Right <> NIL THEN Visit(Nd^.Right)
      ELSE
      BEGIN
         Elt := Nd;
         Found := FALSE;
      END;
   END
   ELSE                                            (* Bezeichner gefunden     *)
   BEGIN
      Elt := Nd;
      Found := TRUE;
   END;
END; (* Visit *)

BEGIN (* Search *)
   IF Display[Level] = NIL THEN                    (* Baum ist leer           *)
   BEGIN
      Elt := NIL;
      Found := FALSE;
   END
   ELSE Visit(Display[Level]);
END; (* Search *)

(* Inhalt eines Baumknotens der Symboltabelle mit Defaultwerten belegen *)
PROCEDURE InitNode(VAR Elt : Node);
BEGIN
   WITH Elt DO
   BEGIN
      Left := NIL;
      Right := NIL;
      Typ := NoType;
      Nrm := TRUE;
      Lev := -1;
      Size := 0;
      Adr := NilAddress;
      Ref := NoTypeType;
      Obj := Nothing;
   END;
END; (* InitNode *)

(* Bezeichner in Symboltabelle eines Levels eintragen *)
PROCEDURE Insert(IdName : IdText; Level : INTEGER; IdObject : Objects;
                 VAR Elt : pNode; VAR Found : BOOLEAN);
BEGIN
   IF Display[Level] = NIL THEN                    (* Baum ist leer           *)
   BEGIN
      new(Display[Level]);                         (* Knoten erzeugen         *)
      Elt := Display[Level];
      InitNode(Elt^);                              (* Defaultwerte            *)

      WITH Elt^ DO
      BEGIN
         Name := IdName;
         Obj := IdObject;
         Lev := Level;
      END;

      Found := FALSE;
      Push(Remember[Level], Elt, NIL);             (* Zum Löschen merken      *)
   END
   ELSE
   BEGIN
      Search(IdName, Level, Elt, Found);           (* Baum durchsuchen        *)

      IF NOT Found THEN                            (* Nicht gefunden          *)
      BEGIN
         IF IdName < Elt^.Name THEN
         BEGIN
            new(Elt^.Left);                        (* Linker Nachfolger       *)
            Elt := Elt^.Left;
         END
         ELSE
         BEGIN
            new(Elt^.Right);                       (* Rechter Nachfolger      *)
            Elt := Elt^.Right;
         END;

         InitNode(Elt^);                           (* Defaultwerte            *)

         WITH Elt^ DO
         BEGIN
            Name := IdName;
            Obj := IdObject;
            Lev := Level;
         END;

         Push(Remember[Level], Elt, NIL);          (* Zum Löschen merken      *)
      END
      ELSE Error(72);                              (* Bereits vorhanden       *)
   END;
END; (* Insert *)

(* Ein gesamtes Level wird gelöscht *)
PROCEDURE DeleteLevel(Level : INTEGER);
VAR ObjContent,
    ObjContent1 : pNode;
    TypContent,
    TypContent1 : pType;
BEGIN
   WHILE NOT RingIsEmpty(Remember[Level]) DO       (* Speicher eines Levels   *)
   BEGIN
      Pop(Remember[Level], ObjContent, TypContent);

      IF ObjContent <> NIL THEN                    (* Objekt zu löschen       *)
      BEGIN
         IF ObjContent^.Obj IN [Procedures, Functions] THEN
         BEGIN
            WHILE NOT RingIsEmpty(ObjContent^.Par) DO
            BEGIN
               Pop(ObjContent^.Par, ObjContent1, TypContent1);
               dispose(ObjContent1);
            END;

            DeleteRing(ObjContent^.Par);           (* Listenkopf löschen      *)
         END;

         dispose(ObjContent);
      END;

      IF TypContent <> NIL THEN
         dispose(TypContent);                      (* Datentyp zu löschen     *)
   END;

   Display[Level] := NIL;                          (* Kein Binärbaum mehr     *)
END; (* DeleteLevel *)

(* Bezeichner in gesamter Symboltabelle suchen *)
PROCEDURE Locate(IdName : IdText; Level : INTEGER; VAR Elt : pNode;
                 VAR FoundAt : INTEGER);
VAR Found : BOOLEAN;
BEGIN
   REPEAT                                          (* Levels durchsuchen      *)
      Search(IdName, Level, Elt, Found);
      Level := Level - 1;
   UNTIL (Level < 0) OR (Found = TRUE);

   IF Found THEN FoundAt := Level + 1              (* Bezeichner gefunden     *)
   ELSE
   BEGIN
      Error(73);                                   (* Bezeichner unbekannt    *)
      Elt := NIL;
      FoundAt := -1;
   END;
END; (* Locate *)

(* Standardbezeichner in die Symboltabelle eintragen *)
PROCEDURE Enter(IdName : IdText; IdObject : Objects; IdType : Types;
                Address : INTEGER);
VAR Elt,
    Elt1  : pNode;
    Found : BOOLEAN;
BEGIN
   Insert(IdName, 0, IdObject, Elt, Found);        (* In Level 0 eintragen    *)

   CASE IdObject OF
      DataTypes :                                  (* Standardtypen           *)
      BEGIN
         WITH Elt^ DO
         BEGIN
            new(Ref);                              (* Typ-Referenz anlegen    *)
            Push(Remember[0], NIL, Ref);           (* Zum Löschen merken      *)
            Ref^.Size := Address;                  (* Speicherplatzbedarf     *)
            Ref^.Typ := IdType;                    (* Datentyp                *)
         END;

         CASE IdType OF                            (* Globale Zeiger setzen   *)
            Ints   : IntegerType := Elt^.Ref;
            Reals  : RealType := Elt^.Ref;
            Bools  : BooleanType := Elt^.Ref;
            Chars  : CharType := Elt^.Ref;
            NoType : NoTypeType := Elt^.Ref;

            Files :
            BEGIN
               TextType := Elt^.Ref;
               Elt^.Ref^.FileType := CharType;     (* File Of Char eintragen  *)
            END;
         END;
      END;

      Variables :                                  (* Input und Output        *)
         Elt^.Ref := TextType;                     (* File Of Char            *)

      Procedures, Functions :                      (* Prozeduren, Funktionen  *)
      BEGIN
         CASE IdType OF
            Ints   : Elt^.Ref := IntegerType;
            Reals  : Elt^.Ref := RealType;
            Bools  : Elt^.Ref := BooleanType;
            Chars  : Elt^.Ref := CharType;
            NoType : Elt^.Ref := NoTypeType;
         END;

         Elt^.Adr := Address;
         CreateRing(Elt^.Par);                     (* Wichtig für CleanUp     *)
      END;

      Constants :                                  (* False, True, MaxInt     *)
      BEGIN
         WITH Elt^ DO
         BEGIN
            Value := Address;                      (* Wert der Konstanten     *)

            CASE IdType OF
               Ints  : Ref := IntegerType;
               Bools : Ref := BooleanType;
            END;
         END;
      END;
   END;

   Elt^.Typ := Elt^.Ref^.Typ;
   Elt^.Size := Elt^.Ref^.Size;
END; (* Enter *)

(* Realzahlen in Tabelle eintragen *)
FUNCTION EnterReal(RealNumber : REAL) : INTEGER;
BEGIN
   IF RealIndex = RealMax THEN Fatal(2);           (* Realtabelle voll        *)

   RealIndex := RealIndex + 1;
   RealTable[RealIndex] := RealNumber;
   EnterReal := RealIndex;
END; (* EnterReal *)

(* END SYMTAB.PAS *)
