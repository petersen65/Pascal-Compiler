(*************************************)
(* Programmname  : Load V1.0         *)
(* Programmautor : Michael Rippl     *)
(* Compiler      : Turbo Pascal V5.0 *)
(* Datum         : 07-Mar-1990       *)
(*************************************)

PROGRAM Load(input, output, source);

CONST LevelMax    = 64;                            (* Höchstes Level          *)
		CodeMax     = 16380;                         (* Größtes Programm        *)
		StackMax    = 4096;                          (* Ende des Stacks         *)
      HeapBase    = 4097;                          (* Anfang des Heaps        *)
      HeapMax     = 8192;                          (* Ende des Heaps          *)
      NumberMax   = 32767;                         (* 2^16-1 Größte Zahl      *)
      StringMax   = 4096;                          (* Größe der Stringtablle  *)
      RealMax     = 1024;                          (* Größe der Realtabelle   *)
      NilAddress  = -1;                            (* Adresse von Nil-Zeigern *)
      ProcOffset  = 12;                            (* Belegter Stackbereich   *)
      WithOffset  = 4;                             (* Offset der With-Tabelle *)
      IntField    = 10;                            (* Integer rechtsbündig    *)
      CharField   = 1;                             (* Character rechtsbündig  *)
      BoolField   = 10;                            (* Boolean rechtsbündig    *)
      RealField   = 20;                            (* Real rechtsbündig       *)

TYPE Orders = (LoadAddress, LoadValue, UpdateDisplay, CallProcedure,
               StoreWithAddress, LoadWithAddress, CorrectStack, CallStandard,
               StoreArrayChar, LoadPointerAddress, AddOffset, Jump,
               JumpConditional, CaseSwitch, CaseTable, ForBeginUp, ForEndUp,
               ForBeginDown, ForEndDown, MarkStack, SimpleArrayIndex,
               ArrayIndex, LoadBlock, CopyBlock, LoadStringConstant,
               LoadInteger, LoadReal, IntegerToReal, StoreSubrange,
               CheckArrayIndex, CheckConstantRange, StringEql, StringNeq,
               StringLss, StringLeq, StringGtr, StringGeq, ReadValue,
               WriteString, WriteStandard, WriteFormatted, LoadIndirectToTop,
               StopProgram, ExitProcedure, ExitFunction, MakeNot,
               NegateInteger, NegateReal, WriteFormattedReal, StoreValue,
               RealEql, RealNeq, RealLss, RealLeq, RealGtr, RealGeq,
               IntegerEql, IntegerNeq, IntegerLss, IntegerLeq, IntegerGtr,
               IntegerGeq, LogicalOr, IntegerPlus, IntegerMinus, RealPlus,
               RealMinus, LogicalAnd, IntegerMultiplication, IntegerDivision,
               IntegerModulo, RealMultiplication, RealDivision,
               CheckPointerAddress, FreeMemory, OnlyWriteLn, OnlyReadLn);

     Types  = (NoType, Ints, Reals, Bools, Chars, Arrays, Records, Pointers,
               Subranges, Enumerations, Sets, Files, Strings);

     Order  = RECORD                               (* Ein Programmbefehl      *)
                 f : Orders;                       (* Funktionscode           *)
                 x : 0..LevelMax;                  (* Level = Parameter 1     *)
                 y : -NumberMax..+NumberMax;       (* Offset = Parameter 2    *)
              END;

     tCode  = ARRAY [0..CodeMax] OF Order;         (* Programmspeicher        *)

VAR ProgramCounter,                                (* Programmzähler          *)
    Top,                                           (* Stackspitze             *)
    Base        : INTEGER;                         (* Basis eines Stackblocks *)
    source      : FILE;                            (* Quelldatei = Programm   *)
    Code        : ^tCode;                          (* Zeiger auf Speicher     *)
    StringTable : ARRAY [1..StringMax] OF CHAR;    (* Stringtabelle           *)
    RealTable   : ARRAY [1..RealMax] OF REAL;      (* Tabelle der Realzahlen  *)

    Stack       : ARRAY [1..HeapMax] OF            (* Stack zur Laufzeit      *)
                     RECORD
                        CASE Types OF
                           Ints  : (i : INTEGER);  (* + 0 : Function-Result   *)
                           Reals : (r : REAL);     (* + 1 : Return-Address    *)
                           Chars : (c : CHAR);     (* + 2 : Static Link       *)
                           Bools : (b : BOOLEAN);  (* + 3 : Dynamic Link      *)
                        END;                       (* + 4 bis 11 With-Tabelle *)

(* --------------------------- Initialisierungen ---------------------------- *)

(* Variablen vorinitialisieren *)
PROCEDURE InitVariables;
BEGIN
   new(Code);                                      (* Programmspeicher belegt *)
END; (* InitVariables *)

(* Belegte Resourcen freigeben *)
PROCEDURE CleanUp;
BEGIN
   dispose(Code);                                  (* Programmspeicher frei   *)
   close(source);                                  (* Datei schließen         *)
END; (* CleanUp *)

(* Übergebene Parameter an den Lader überprüfen *)
PROCEDURE CheckParameters;
BEGIN
   write('Pascal Loader  Version 0.95a  ');
   writeln('Copyright (c) 1989, 1990 by Michael Rippl');
   writeln;

   IF paramcount <> 1 THEN
   BEGIN
      writeln('usage : load <filename>');
      halt;
   END;

   (*$I-*)                                            (* I/O Überprüfung aus  *)
   assign(source, paramstr(1) + '.obj');
   reset(source, 1);                                  (* Quelldatei öffnen    *)

   IF ioresult <> 0 THEN
   BEGIN
      writeln('fatal error : unable to open ', paramstr(1) + '.obj');
      halt;
   END;
   (*$I+*)                                            (* I/O Überprüfung an   *)
END; (* CheckParameters *)

(* ----------------------------- Datenaufnahme ------------------------------ *)

(* Komplette Objektdatei einlesen *)
PROCEDURE ReadFile;
VAR i,
    Status,                                        (* Kein I/O-Abbruch        *)
    RealIndex,                                     (* Index für Realtabelle   *)
    StringIndex : INTEGER;                         (* Index für Stringtabelle *)
    Criterion   : ARRAY [1..6] OF CHAR;            (* Kennung für Zieldatei   *)
BEGIN
   (*$I-*)                                         (* I/O Überprüfung aus     *)
   blockread(source, Criterion, sizeof(Criterion),
             Status);                              (* Dateikennung einlesen   *)

   IF Criterion <> 'PASCAL' THEN
   BEGIN
      writeln('fatal error : file is not an object module');
      CleanUp;
      halt;
   END;

   i := -1;                                        (* Startwert - 1           *)
   Code^[0].f := Jump;                             (* Nur ein Defaultwert     *)

   REPEAT                                          (* Programm einlesen       *)
      i := i + 1;
      blockread(source, Code^[i], sizeof(Order), Status);

      IF ioresult <> 0 THEN                        (* Fehler beim Lesen       *)
      BEGIN
         writeln('fatal error : cannot read object file');
         CleanUp;
         halt;
      END;
   UNTIL (Code^[i].f = StopProgram) OR (i = CodeMax);

   IF (i = CodeMax) AND (Code^[i].f <> StopProgram) THEN
   BEGIN
      writeln('fatal error : program too long');   (* Objektprogramm zu lang  *)
      CleanUp;
      halt;
   END;

   blockread(source, RealIndex, sizeof(integer), Status);
                                                   (* Realzahlen einlesen     *)
   blockread(source, RealTable, sizeof(real) * RealIndex, Status);
   blockread(source, StringIndex, sizeof(integer), Status);

                                                   (* Strings einlesen        *)
   blockread(source, StringTable, sizeof(char) * StringIndex, Status);

                                                   (* Adresse des Hauptprg's  *)
   blockread(source, ProgramCounter, sizeof(integer), Status);
   blockread(source, Top, sizeof(integer), Status);(* VarSize vom Programm    *)
   (*$I+*)                                         (* I/O Überprüfung an      *)
END; (* ReadFile *)

(* ---------------------------- Interpretation ------------------------------ *)

(* Interpretiert den übersetzten Pseudocode *)
PROCEDURE Interpret;
VAR ProgramStatus : (Run, Finish, UnknownCase, StackOverflow,
                     ConstantOutOfRange, IndexOutOfRange, DivisionByZero,
                     UndefinedPointer, OutOfMemory);
    Instruction   : Order;                         (* Aktueller Befehl        *)
    a0,
    a1,
    a2,                                            (* Adressregister          *)
    d0,
    d1,
    d2,                                            (* Datenregister           *)
    Heap          : INTEGER;                       (* Dynamischer Speicher    *)

    Display       : ARRAY [1..LevelMax] OF INTEGER;(* Basis jedes Levels      *)
BEGIN
   Heap := HeapBase;                               (* Ab hier Heap            *)
   Base := 0;                                      (* Basis vom Hauptprogramm *)
   Top := Top -1;                                  (* Neues StackTop          *)

                                                   (* Level 1 = Hauptprogramm *)
   Display[1] := Base;                             (* Basis für Level 1       *)
   Stack[1].i := 0;                                (* Keine Return Adresse    *)
   Stack[2].i := 0;                                (* Kein Static Link        *)
   Stack[3].i := 0;                                (* Kein Dynamic Link       *)

   IF Top > StackMax THEN ProgramStatus := StackOverflow
   ELSE ProgramStatus := Run;                      (* Programm läuft          *)

   WHILE ProgramStatus = Run DO
   BEGIN
      Instruction := Code^[ProgramCounter];        (* Aktuellen Befehl merken *)
      ProgramCounter := ProgramCounter + 1;        (* Programmzähler erhöhen  *)

      CASE Instruction.f OF                        (* Ausführung von Befehlen *)
         LoadAddress :                             (* Adresse einer Variablen *)
         BEGIN                                     (* x = Level               *)
            Top := Top + 1;                        (* y = Offset              *)

            IF Top > StackMax THEN ProgramStatus := StackOverflow
            ELSE Stack[Top].i := Display[Instruction.x] + Instruction.y;
         END;

         LoadValue :                               (* Wert einer Variablen    *)
         BEGIN                                     (* x = Level               *)
            Top := Top + 1;                        (* y = Offset              *)

            IF Top > StackMax THEN ProgramStatus := StackOverflow
            ELSE Stack[Top] := Stack[Display[Instruction.x] + Instruction.y];
         END;

         UpdateDisplay :                           (* Display korrigieren     *)
         BEGIN                                     (* x = Level von Proz.name *)
            d0 := Instruction.y;                   (* y = Aktuelles Level     *)
            a0 := Base;                            (* Aktuelle Basis          *)

            REPEAT
               Display[d0] := a0;                  (* Basis eintragen         *)
               d0 := d0 - 1;                       (* Level erniedrigen       *)
               a0 := Stack[a0 + 2].i;              (* Static Link             *)
            UNTIL d0 = Instruction.x;
         END;

         CallProcedure :                           (* Prozeduraufruf          *)
         BEGIN                                     (* x = Level von Proz.name *)
                                                   (* y = Parametergröße - 1  *)
            a0 := Top - Instruction.y;             (* Zeigt jetzt auf Basis   *)
            d0 := Instruction.x;
            a1 := a0 + Stack[a0].i;                (* Neues StackTop          *)
            Display[d0 + 1] := a0;                 (* Nun Basis von Level + 1 *)
            Stack[a0 + 1].i := ProgramCounter + 1; (* Rückkehradresse - 1     *)
            Stack[a0 + 2].i := Display[d0];        (* Static Link             *)
            Stack[a0 + 3].i := Base;               (* Dynamic Link            *)
            Base := a0;                            (* Neue Basis              *)
            Top := a1;                             (* Neues StackTop          *)
         END;

         StoreWithAddress :                        (* Adresse von With merken *)
         BEGIN                                     (* y = Offset von With     *)
            a0 := Base + WithOffset;
            a0 := a0 + Instruction.y;              (* Adresse in With-Tabelle *)
            Stack[a0].i := Stack[Top].i;
            Top := Top - 1;
         END;

         LoadWithAddress :                         (* Record-Adresse laden    *)
         BEGIN                                     (* y = Offset von With     *)
            Top := Top + 1;

            IF Top > StackMax THEN ProgramStatus := StackOverflow
            ELSE
            BEGIN
               a0 := Base + WithOffset;
               a0 := a0 + Instruction.y;           (* Adresse in With-Tabelle *)
               Stack[Top].i := Stack[a0].i;
            END;
         END;

         CorrectStack :                            (* Stack korrigieren       *)
            Top := Top + Instruction.y;            (* y = Korrekturwert       *)

         CallStandard :                            (* Standardfunktion        *)
         BEGIN                                     (* y = Nummer der Funktion *)
            CASE Instruction.y OF
               0 : Stack[Top].i := abs(Stack[Top].i);
               1 : Stack[Top].r := abs(Stack[Top].r);
               2 : Stack[Top].i := sqr(Stack[Top].i);
               3 : Stack[Top].r := sqr(Stack[Top].r);
               4 : Stack[Top].i := ord(odd(Stack[Top].i));

               5 :
               BEGIN
                  IF Stack[Top].i < 0 THEN ProgramStatus := ConstantOutOfRange
                  ELSE IF Stack[Top].i > 255 THEN
                     ProgramStatus := ConstantOutOfRange;

                  (* Stack[Top].c := chr(Stack[Top].i); *)
               END;

               6 : (* Stack[Top].i := ord(Stack[Top].i); *) ;
               7 : Stack[Top].i := Stack[Top].i + 1;     (* succ              *)
               8 : Stack[Top].i := Stack[Top].i - 1;     (* pred              *)
               9 : Stack[Top].i := round(Stack[Top].r);
               10 : Stack[Top].i := trunc(Stack[Top].r);
               11 : Stack[Top].r := sin(Stack[Top].r);
               12 : Stack[Top].r := cos(Stack[Top].r);
               13 : Stack[Top].r := exp(Stack[Top].r);
               14 : Stack[Top].r := ln(Stack[Top].r);
               15 : Stack[Top].r := sqrt(Stack[Top].r);
               16 : Stack[Top].r := arctan(Stack[Top].r);
               17 : Stack[Top].i := 0;             (* eof (false)             *)
               18 : Stack[Top].i := 0;             (* eoln (false)            *)
            END;
         END;

         StoreArrayChar :                          (* Zeichenfeld speichern   *)
         BEGIN                                     (* y = Länge des Feldes    *)
            d0 := Instruction.y;                   (* Länge des Feldes        *)
            a0 := Top - d0;
            a1 := Stack[a0].i;                     (* Zieladresse             *)
            a0 := a0 + 1;                          (* Quelladresse            *)

            WHILE a0 <= Top DO                     (* Zeichenfeld kopieren    *)
            BEGIN
               Stack[a1].i := Stack[a0].i;
               a0 := a0 + 1;
               a1 := a1 + 1;
            END;

            Top := Top - d0;                       (* Zeichenfeld beseitigt   *)
            Top := Top - 1;                        (* Adresse beseitigt       *)
         END;

         LoadPointerAddress :                      (* Neue Zeigeradresse      *)
         BEGIN                                     (* y = Größe des Datentyps *)
            Top := Top + 1;

            IF Top > StackMax THEN ProgramStatus := StackOverflow
            ELSE
            BEGIN
               Stack[Top].i := Heap;               (* Freier Speicherbereich  *)
               Heap := Heap + Instruction.y;       (* Neuer freier Speicher   *)

               IF Heap > HeapMax THEN ProgramStatus := OutOfMemory;
            END;
         END;

         AddOffset :                               (* Offsetadresse addieren  *)
            Stack[Top].i := Stack[Top].i + Instruction.y;       (* y = Offset *)

         Jump :                                    (* Unbedingter Sprung      *)
            ProgramCounter := Instruction.y;       (* y = Zieladresse         *)

         JumpConditional :                         (* Bedingter Sprung        *)
         BEGIN                                     (* y = Zieladresse         *)
            IF NOT Stack[Top].b THEN ProgramCounter := Instruction.y;
            Top := Top - 1;
         END;

         CaseSwitch :                              (* Case-Anweisung          *)
         BEGIN                                     (* y = Adresse der Tabelle *)
            d0 := Stack[Top].i;                    (* Errechneter Ausdruck    *)
            a0 := Instruction.y;                   (* Adresse der Casetabelle *)
            d1 := 0;                               (* Suchkriterium           *)
            Top := Top - 1;

            REPEAT                                 (* Case-Konstante suchen   *)
               IF Code^[a0].f <> CaseTable THEN
               BEGIN
                  d1 := 1;                         (* Schleifenende           *)
                  ProgramStatus := UnknownCase;
               END
               ELSE IF Code^[a0].y = d0 THEN       (* Konstante gefunden      *)
               BEGIN
                  d1 := 1;                         (* Schleifenende           *)
                  ProgramCounter := Code^[a0 + 1].y;
               END
               ELSE a0 := a0 + 2;                  (* Nächster Eintrag        *)
            UNTIL d1 <> 0;
         END;

         ForBeginUp :                              (* For Anfang ... To       *)
         BEGIN                                     (* y = Endadresse          *)
            d0 := Stack[Top - 1].i;                (* Startwert               *)

            IF d0 <= Stack[Top].i THEN             (* Anfang <= Ende          *)
               Stack[Stack[Top - 2].i].i := d0     (* CtrlVar = Anfangswert   *)
            ELSE
            BEGIN
               Top := Top - 3;
               ProgramCounter := Instruction.y;
            END;
         END;

         ForEndUp :                                (* For Ende ... To         *)
         BEGIN                                     (* y = Anfangsadresse      *)
            a0 := Stack[Top - 2].i;                (* Adresse der CtrlVar     *)
            d0 := Stack[a0].i + 1;                 (* Wert der CtrlVar + 1    *)

            IF d0 <= Stack[Top].i THEN             (* Anfang <= Ende          *)
            BEGIN
               Stack[a0].i := d0;
               ProgramCounter := Instruction.y;
            END
            ELSE Top := Top - 3;
         END;

         ForBeginDown :                            (* For Anfang ... DownTo   *)
         BEGIN                                     (* y = Endadresse          *)
            d0 := Stack[Top - 1].i;                (* Startwert               *)

            IF d0 >= Stack[Top].i THEN             (* Anfang >= Ende          *)
               Stack[Stack[Top - 2].i].i := d0     (* CtrlVar = Anfangswert   *)
            ELSE
            BEGIN
               Top := Top - 3;
               ProgramCounter := Instruction.y;
            END;
         END;

         ForEndDown :                              (* For Ende ... DownTo     *)
         BEGIN                                     (* y = Anfangsadresse      *)
            a0 := Stack[Top - 2].i;                (* Adresse der CtrlVar     *)
            d0 := Stack[a0].i - 1;                 (* Wert der CtrlVar + 1    *)

            IF d0 >= Stack[Top].i THEN             (* Anfang >= Ende          *)
            BEGIN
               Stack[a0].i := d0;
               ProgramCounter := Instruction.y;
            END
            ELSE Top := Top - 3;
         END;

         MarkStack :                               (* Prozedur vorbereiten    *)
         BEGIN                                     (* y = Variablengröße      *)
            d0 := Instruction.y;

            IF Top + d0 > StackMax THEN ProgramStatus := StackOverflow
            ELSE
            BEGIN
               Stack[Top + 1].i := d0 - 1;         (* VarSize - 1 merken      *)
               Top := Top + ProcOffset;
            END;
         END;

         SimpleArrayIndex :                        (* Feldindex auswerten     *)
         BEGIN                                     (* Elementgröße ist 1      *)
            d0 := Instruction.y;                   (* y = Untere Grenze       *)
            d1 := Stack[Top].i;                    (* Index                   *)
            Top := Top - 1;

            Stack[Top].i := Stack[Top].i + (d1 - d0);
         END;

         ArrayIndex :                              (* Feldindex auswerten     *)
         BEGIN                                     (* Elementgröße beliebig   *)
            d0 := Instruction.y;                   (* y = Untere Grenze       *)
            d1 := Stack[Top - 1].i;                (* Index                   *)
            d2 := Stack[Top].i;                    (* Elementgröße            *)
            Top := Top - 2;

            Stack[Top].i := Stack[Top].i + (d1 - d0) * d2;
         END;

         LoadBlock :                               (* Speicherblock auf Stack *)
         BEGIN                                     (* y = Größe des Blocks    *)
            a0 := Stack[Top].i;                    (* Quelladresse            *)
            Top := Top - 1;
            a1 := Top + Instruction.y;             (* Neue obere Grenze       *)

            IF a1 > StackMax THEN ProgramStatus := StackOverflow
            ELSE
            BEGIN
               WHILE Top < a1 DO                   (* Block kopieren          *)
               BEGIN
                  Top := Top + 1;
                  Stack[Top] := Stack[a0];
                  a0 := a0 + 1;
               END;
            END;
         END;

         CopyBlock :                               (* Speicherblock kopieren  *)
         BEGIN                                     (* y = Größe des Blocks    *)
            a0 := Stack[Top - 1].i;                (* Zieladresse             *)
            a1 := Stack[Top].i;                    (* Quelladresse            *)
            a2 := a0 + Instruction.y;              (* Obere Grenze des Ziels  *)

            WHILE a0 < a2 DO                       (* Speicherzellen kopieren *)
            BEGIN
               Stack[a0] := Stack[a1];
               a0 := a0 + 1;
               a1 := a1 + 1;
            END;

            Top := Top - 2;
         END;

         LoadStringConstant :                      (* Stringkonstante laden   *)
         BEGIN                                     (* y = Länge des Strings   *)
            a0 := Stack[Top].i;                    (* Adresse des Strings     *)
            d0 := Instruction.y;                   (* Länge des Strings       *)
            Top := Top - 1;
            a1 := Top + d0;                        (* Neue Stackspitze        *)

            IF a1 > StackMax THEN ProgramStatus := StackOverflow
            ELSE
            BEGIN
               WHILE Top < a1 DO                   (* String kopieren         *)
               BEGIN
                  Top := Top + 1;
                  Stack[Top].i := ord(StringTable[a0]);
                  a0 := a0 + 1;
               END;
            END;
         END;

         LoadInteger :                             (* Ganze Zahl auf Stack    *)
         BEGIN                                     (* y = Integerwert         *)
            Top := Top + 1;
            IF Top > StackMax THEN ProgramStatus := StackOverflow
            ELSE Stack[Top].i := Instruction.y;
         END;

         LoadReal :                                (* Reelle Zahl auf Stack   *)
         BEGIN                                     (* y = Index in RealTable  *)
            Top := Top + 1;
            IF Top > StackMax THEN ProgramStatus := StackOverflow
            ELSE Stack[Top].r := RealTable[Instruction.y];
         END;

         IntegerToReal :                           (* Integer nach Real       *)
         BEGIN                                     (* y = Offset              *)
            a0 := Top - Instruction.y;
            Stack[a0].r := Stack[a0].i;
         END;

         StoreSubrange :                           (* Unterbereich speichern  *)
         BEGIN                                     (* y = Untere Grenze       *)
            d0 := Instruction.y;                   (* Untere Grenze           *)
            d1 := Stack[Top].i;                    (* Obere Grenze            *)
            d2 := Stack[Top - 1].i;                (* Zu speichernder Wert    *)

            IF d2 < d0 THEN ProgramStatus := ConstantOutOfRange
            ELSE IF d2 > d1 THEN ProgramStatus := ConstantOutOfRange
            ELSE
            BEGIN
               Stack[Stack[Top - 2].i].i := d2;    (* Wert speichern          *)
               Top := Top - 3;
            END;
         END;

         CheckArrayIndex :                         (* Index von Feld prüfen   *)
         BEGIN                                     (* y = Untere Grenze       *)
            d0 := Instruction.y;                   (* Untere Grenze           *)
            d1 := Stack[Top].i;                    (* Obere Grenze            *)
            Top := Top - 1;

            IF Stack[Top].i < d0 THEN ProgramStatus := IndexOutOfRange
            ELSE IF Stack[Top].i > d1 THEN ProgramStatus := IndexOutOfRange;
         END;

         CheckConstantRange :                      (* Bereichsüberprüfung     *)
         BEGIN                                     (* y = Untere Grenze       *)
            d0 := Instruction.y;                   (* Untere Grenze           *)
            d1 := Stack[Top].i;                    (* Obere Grenze            *)
            Top := Top - 1;

            IF Stack[Top].i < d0 THEN ProgramStatus := ConstantOutOfRange
            ELSE IF Stack[Top].i > d1 THEN ProgramStatus := ConstantOutOfRange;
         END;

         StringEql :                               (* String =                *)
         BEGIN                                     (* y = Länge der Strings   *)
            d0 := Instruction.y;                   (* Länge der Strings       *)
            a1 := Top - d0;                        (* Adresse -1 von String 2 *)
            a0 := a1 - d0;                         (* Adresse -1 von String 1 *)
            a2 := a0 + 1;                          (* Adresse für Ergebnis    *)

            REPEAT                                 (* Strings vergleichen     *)
               a0 := a0 + 1;
               a1 := a1 + 1;
               d0 := d0 - 1;
            UNTIL (Stack[a0].c <> Stack[a1].c) OR (d0 = 0);

            Stack[a2].i := ord(Stack[a0].c = Stack[a1].c);
            Top := a2;
         END;

         StringNeq :                               (* String <>               *)
         BEGIN                                     (* y = Länge der Strings   *)
            d0 := Instruction.y;                   (* Länge der Strings       *)
            a1 := Top - d0;                        (* Adresse -1 von String 2 *)
            a0 := a1 - d0;                         (* Adresse -1 von String 1 *)
            a2 := a0 + 1;                          (* Adresse für Ergebnis    *)

            REPEAT                                 (* Strings vergleichen     *)
               a0 := a0 + 1;
               a1 := a1 + 1;
               d0 := d0 - 1;
            UNTIL (Stack[a0].c <> Stack[a1].c) OR (d0 = 0);

            Stack[a2].i := ord(Stack[a0].c <> Stack[a1].c);
            Top := a2;
         END;

         StringLss :                               (* String <                *)
         BEGIN                                     (* y = Länge der Strings   *)
            d0 := Instruction.y;                   (* Länge der Strings       *)
            a1 := Top - d0;                        (* Adresse -1 von String 2 *)
            a0 := a1 - d0;                         (* Adresse -1 von String 1 *)
            a2 := a0 + 1;                          (* Adresse für Ergebnis    *)

            REPEAT                                 (* Strings vergleichen     *)
               a0 := a0 + 1;
               a1 := a1 + 1;
               d0 := d0 - 1;
            UNTIL (Stack[a0].c <> Stack[a1].c) OR (d0 = 0);

            Stack[a2].i := ord(Stack[a0].c < Stack[a1].c);
            Top := a2;
         END;

         StringLeq :                               (* String <=               *)
         BEGIN                                     (* y = Länge der Strings   *)
            d0 := Instruction.y;                   (* Länge der Strings       *)
            a1 := Top - d0;                        (* Adresse -1 von String 2 *)
            a0 := a1 - d0;                         (* Adresse -1 von String 1 *)
            a2 := a0 + 1;                          (* Adresse für Ergebnis    *)

            REPEAT                                 (* Strings vergleichen     *)
               a0 := a0 + 1;
               a1 := a1 + 1;
               d0 := d0 - 1;
            UNTIL (Stack[a0].c <> Stack[a1].c) OR (d0 = 0);

            Stack[a2].i := ord(Stack[a0].c <= Stack[a1].c);
            Top := a2;
         END;

         StringGtr :                               (* String >                *)
         BEGIN                                     (* y = Länge der Strings   *)
            d0 := Instruction.y;                   (* Länge der Strings       *)
            a1 := Top - d0;                        (* Adresse -1 von String 2 *)
            a0 := a1 - d0;                         (* Adresse -1 von String 1 *)
            a2 := a0 + 1;                          (* Adresse für Ergebnis    *)

            REPEAT                                 (* Strings vergleichen     *)
               a0 := a0 + 1;
               a1 := a1 + 1;
               d0 := d0 - 1;
            UNTIL (Stack[a0].c <> Stack[a1].c) OR (d0 = 0);

            Stack[a2].i := ord(Stack[a0].c > Stack[a1].c);
            Top := a2;
         END;

         StringGeq :                               (* String >=               *)
         BEGIN                                     (* y = Länge der Strings   *)
            d0 := Instruction.y;                   (* Länge der Strings       *)
            a1 := Top - d0;                        (* Adresse -1 von String 2 *)
            a0 := a1 - d0;                         (* Adresse -1 von String 1 *)
            a2 := a0 + 1;                          (* Adresse für Ergebnis    *)

            REPEAT                                 (* Strings vergleichen     *)
               a0 := a0 + 1;
               a1 := a1 + 1;
               d0 := d0 - 1;
            UNTIL (Stack[a0].c <> Stack[a1].c) OR (d0 = 0);

            Stack[a2].i := ord(Stack[a0].c >= Stack[a1].c);
            Top := a2;
         END;

         ReadValue :                               (* Wert einlesen           *)
         BEGIN                                     (* y = Datentyp            *)
            (*$I-*)                                (* I/O Überprüfung aus     *)

            CASE Instruction.y OF
               1 : read(Stack[Stack[Top].i].i);    (* Integer einlesen        *)
               2 : read(Stack[Stack[Top].i].r);    (* Real einlesen           *)
               4 : read(Stack[Stack[Top].i].c);    (* Character einlesen      *)
            END;

            (*$I+*)                                (* I/O Überprüfung an      *)

            Top := Top - 1;
         END;

         WriteString :                             (* Texte ausgeben          *)
         BEGIN                                     (* y = Länge des Strings   *)
            d0 := Instruction.y;                   (* Länge des Strings       *)
            a0 := Top - d0;                        (* Adresse des Strings - 1 *)

            WHILE Top > a0 DO                      (* Text ausgeben           *)
            BEGIN
               a0 := a0 + 1;
               write(Stack[a0].c : 1);
            END;

            Top := Top - d0;
         END;

         WriteStandard :                           (* Ausgabeformat standard  *)
         BEGIN                                     (* y = Datentyp            *)
            CASE Instruction.y OF
               1 : write(Stack[Top].i : IntField); (* Integer ausgeben        *)
               2 : write(Stack[Top].r : RealField);(* Real ausgeben           *)
               3 : write(Stack[Top].b : BoolField);(* Boolean ausgeben        *)
               4 : write(Stack[Top].c : CharField);(* Character ausgeben      *)
            END;

            Top := Top - 1;
         END;

         WriteFormatted :                          (* Ausgabe formatiert      *)
         BEGIN                                     (* y = Datentyp            *)
            CASE Instruction.y OF
               1 : write(Stack[Top - 1].i : Stack[Top].i);  (* Integer        *)
               2 : write(Stack[Top - 1].r : Stack[Top].i);  (* Real           *)
               3 : write(Stack[Top - 1].b : Stack[Top].i);  (* Boolean        *)
               4 : write(Stack[Top - 1].c : Stack[Top].i);  (* Character      *)
            END;

            Top := Top - 2;
         END;

         LoadIndirectToTop :                       (* Wert indirekt auf Top   *)
            Stack[Top] := Stack[Stack[Top].i];

         StopProgram :                             (* Programmende            *)
            ProgramStatus := Finish;

         ExitProcedure :                           (* Ende einer Prozedur     *)
         BEGIN
            Top := Base - 1;                       (* Daten v. Stack entfernt *)
            ProgramCounter := Stack[Base + 1].i;   (* Rückkehradresse         *)
            Base := Stack[Base + 3].i;             (* Neue Base, Dynamic Link *)
         END;

         ExitFunction :                            (* Ende einer Funktion     *)
         BEGIN
            Top := Base;                           (* Daten v. Stack entfernt *)
                                                   (* Fct Result auf Stacktop *)
            ProgramCounter := Stack[Base + 1].i;   (* Rückkehradresse         *)
            Base := Stack[Base + 3].i;             (* Neue Base, Dynamic Link *)
         END;

         MakeNot :                                 (* Wahrheitswert umdrehen  *)
         BEGIN
            IF Stack[Top].i = 0 THEN Stack[Top].i := 1
            ELSE Stack[Top].i := 0;
         END;

         NegateInteger :                           (* Integer negieren        *)
            Stack[Top].i := -Stack[Top].i;

         NegateReal :                              (* Real negieren           *)
            Stack[Top].r := -Stack[Top].r;

         WriteFormattedReal :                      (* Reelle Zahl formatiert  *)
         BEGIN
            write(Stack[Top - 2].r : Stack[Top - 1].i : Stack[Top].i);
            Top := Top - 3;
         END;

         StoreValue :                              (* Skalaren Wert speichern *)
         BEGIN
            Stack[Stack[Top - 1].i] := Stack[Top];
            Top := Top - 2;
         END;

         RealEql :                                 (* Real =                  *)
         BEGIN
            Top := Top - 1;
            Stack[Top].i := ord(Stack[Top].r = Stack[Top + 1].r);
         END;

         RealNeq :                                 (* Real <>                 *)
         BEGIN
            Top := Top - 1;
            Stack[Top].i := ord(Stack[Top].r <> Stack[Top + 1].r);
         END;

         RealLss :                                 (* Real <                  *)
         BEGIN
            Top := Top - 1;
            Stack[Top].i := ord(Stack[Top].r < Stack[Top + 1].r);
         END;

         RealLeq :                                 (* Real <=                 *)
         BEGIN
            Top := Top - 1;
            Stack[Top].i := ord(Stack[Top].r <= Stack[Top + 1].r);
         END;

         RealGtr :                                 (* Real >                  *)
         BEGIN
            Top := Top - 1;
            Stack[Top].i := ord(Stack[Top].r > Stack[Top + 1].r);
         END;

         RealGeq :                                 (* Real >=                 *)
         BEGIN
            Top := Top - 1;
            Stack[Top].i := ord(Stack[Top].r >= Stack[Top + 1].r);
         END;

         IntegerEql :                              (* Integer =               *)
         BEGIN
            Top := Top - 1;
            Stack[Top].i := ord(Stack[Top].i = Stack[Top + 1].i);
         END;

         IntegerNeq :                              (* Integer <>              *)
         BEGIN
            Top := Top - 1;
            Stack[Top].i := ord(Stack[Top].i <> Stack[Top + 1].i);
         END;

         IntegerLss :                              (* Integer <               *)
         BEGIN
            Top := Top - 1;
            Stack[Top].i := ord(Stack[Top].i < Stack[Top + 1].i);
         END;

         IntegerLeq :                              (* Integer <=              *)
         BEGIN
            Top := Top - 1;
            Stack[Top].i := ord(Stack[Top].i <= Stack[Top + 1].i);
         END;

         IntegerGtr :                              (* Integer >               *)
         BEGIN
            Top := Top - 1;
            Stack[Top].i := ord(Stack[Top].i > Stack[Top + 1].i);
         END;

         IntegerGeq :                              (* Integer >=              *)
         BEGIN
            Top := Top - 1;
            Stack[Top].i := ord(Stack[Top].i >= Stack[Top + 1].i);
         END;

         LogicalOr :                               (* Logisches Oder          *)
         BEGIN
            Top := Top - 1;
            IF Stack[Top + 1].i <> 0 THEN Stack[Top].i := 1;
         END;

         IntegerPlus :                             (* Ganzzahliges Plus       *)
         BEGIN
            Top := Top - 1;
            Stack[Top].i := Stack[Top].i + Stack[Top + 1].i;
         END;

         IntegerMinus :                            (* Ganzzahliges Minus      *)
         BEGIN
            Top := Top - 1;
            Stack[Top].i := Stack[Top].i - Stack[Top + 1].i;
         END;

         RealPlus :                                (* Reelles Plus            *)
         BEGIN
            Top := Top - 1;
            Stack[Top].r := Stack[Top].r + Stack[Top + 1].r;
         END;

         RealMinus :                               (* Reelles Minus           *)
         BEGIN
            Top := Top - 1;
            Stack[Top].r := Stack[Top].r - Stack[Top + 1].r;
         END;

         LogicalAnd :                              (* Logisches Und           *)
         BEGIN
            Top := Top - 1;
            IF Stack[Top + 1].i = 0 THEN Stack[Top].i := 0;
         END;

         IntegerMultiplication :                   (* Ganzzahlige Multiplik.  *)
         BEGIN
            Top := Top - 1;
            Stack[Top].i := Stack[Top].i * Stack[Top + 1].i;
         END;

         IntegerDivision :                         (* Ganzzahlige Division    *)
         BEGIN
            Top := Top - 1;

            IF Stack[Top + 1].i = 0 THEN ProgramStatus := DivisionByZero
            ELSE Stack[Top].i := Stack[Top].i DIV Stack[Top + 1].i;
         END;

         IntegerModulo :                           (* Modulo                  *)
         BEGIN
            Top := Top - 1;

            IF Stack[Top + 1].i = 0 THEN ProgramStatus := DivisionByZero
            ELSE Stack[Top].i := Stack[Top].i MOD Stack[Top + 1].i;
         END;

         RealMultiplication :                      (* Reelle Multiplikation   *)
         BEGIN
            Top := Top - 1;
            Stack[Top].r := Stack[Top].r * Stack[Top + 1].r;
         END;

         RealDivision :
         BEGIN
            Top := Top - 1;

            IF Stack[Top + 1].r = 0 THEN ProgramStatus := DivisionByZero
            ELSE Stack[Top].r := Stack[Top].r / Stack[Top + 1].r;
         END;

         CheckPointerAddress :                     (* Zeigeradresse prüfen    *)
         BEGIN
            IF Stack[Top].i < HeapBase THEN ProgramStatus := UndefinedPointer
            ELSE IF Stack[Top].i > HeapMax THEN
               ProgramStatus := UndefinedPointer;
         END;

         FreeMemory :                              (* Speicherfreigabe        *)
         BEGIN
            a0 := Stack[Stack[Top].i].i;           (* Zieladresse des Zeigers *)

            IF a0 < HeapBase THEN ProgramStatus := UndefinedPointer
            ELSE IF a0 > HeapMax THEN ProgramStatus := UndefinedPointer
            ELSE
            BEGIN
               Stack[Stack[Top].i].i := NilAddress;
               Top := Top - 1;
            END;
         END;

         OnlyWriteLn : writeln;                    (* Nur Write Line          *)
         OnlyReadLn  : readln;                     (* Nur Read Line           *)
      END;
   END;

   IF ProgramStatus <> Finish THEN                 (* Laufzeitfehler          *)
   BEGIN
      writeln;
      writeln;
      write('run time error : ');

      CASE ProgramStatus OF
         UnknownCase        : write('unknown case');
         StackOverflow      : write('stack overflow');
         ConstantOutOfRange : write('constant out of range');
         IndexOutOfRange    : write('index out of range');
         DivisionByZero     : write('division by zero');
         UndefinedPointer   : write('undefined pointer');
         OutOfMemory        : write('out of memory');
      END;

      writeln(' at ', ProgramCounter : 1);
   END;
END; (* Interpret *)

(* ----------------------------- Hauptprogramm ------------------------------ *)

BEGIN
   InitVariables;
   CheckParameters;
   ReadFile;
   Interpret;
   CleanUp;
END. (* Hauptprogramm *)
