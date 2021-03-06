(**************************************************)
(* Programmname    : GLOBAL.PAS                   *)
(* Programmautor   : Michael Rippl                *)
(* Compiler        : Turbo Pascal V5.0            *)
(* Letzte �nderung : 12-Apr-1990                  *)
(* Inhalt          : Globale Daten von PASCAL.PAS *)
(* Bemerkung       : Include Datei von PASCAL.PAS *)
(**************************************************)

CONST LevelMax    = 64;                         (* H�chstes Level             *)
      LineMax     = 256;                        (* Maximale Zeilenl�nge       *)
      StringMax   = 4096;                       (* Gr��e der Stringtabelle    *)
      CaseMax     = 256;                        (* Anzahl der Case-Konstanten *)
      RealMax     = 1024;                       (* Gr��e der Realtabelle      *)
      WithMax     = 8;                          (* Maximales Level von With   *)
      CodeMax     = 16380;                      (* Gr��ter Programmk�rper     *)
      SetMax      = 256;                        (* 2^8  Gr��te Menge          *)
      LabelMax    = 9999;                       (* Gr��te Label-Konstante     *)
      AbortingMax = 2;                          (* Fehleranzahl f�r Abbruch   *)
      NumberMax   = 32767;                      (* 2^16-1  Gr��te ganze Zahl  *)
      MaxIntStr   = '32767           ';         (* String der gr��ten Zahl    *)
      DigitMax    = 5;                          (* Stellen einer Zahl         *)
      ExpDigit    = 2;                          (* Stellen eines Exponenten   *)
      FracDigit   = 6;                          (* Nachkommastellen           *)
      NilAddress  = -1;                         (* Adresse eines Nil-Zeigers  *)
      IsForward   = -2;                         (* Forw�rtsdeklaration        *)
      IsMainProg  = -3;                         (* Hauptprogramm-Adresse      *)
      ErrorMax    = 255;                        (* H�chste Fehlernummer       *)
      SigChars    = 16;                         (* Signifikante Buchstaben    *)
      KeyWords    = 36;                         (* Anzahl der Schl�sselworte  *)
      ExpMax      = +38;                        (* Gr��ter Exponent           *)
      ExpMin      = -38;                        (* Kleinster Exponent         *)
      StackMax    = 4096;                       (* Maximale Stackgr��e        *)
      ProcOffset  = 12;                         (* Reservierter Stackbereich  *)
      IntSize     = 1;                          (* Gr��e einer Integer        *)
      RealSize    = 1;                          (* Gr��e einer Real           *)
      CharSize    = 1;                          (* Gr��e einer Character      *)
      BoolSize    = 1;                          (* Gr��e einer Boolean        *)
      SetSize     = 32;                         (* Gr��e einer Menge          *)
      FileSize    = 1;                          (* Gr��e einer Dateivariablen *)

TYPE IdText   = ARRAY [1..SigChars] OF CHAR;    (* Text f�r Bezeichner        *)

TYPE Orders   = (LoadAddress, LoadValue, UpdateDisplay, CallProcedure,
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

     Symbol   = (IntConst, RealConst, CharConst, StringConst, Plus, Minus,
                 Mult, IntDiv, RealDiv, IntMod, Eql, Neq, Gtr, Geq, Lss, Leq,
                 NotSy, AndSy, OrSy, LeftParent, RightParent, LeftBrack,
                 RightBrack, PointerTo, Comma, Semicolon, Period, DotDot,
                 Colon, Becomes, Identifier, LabelSy, ConstSy, TypeSy, VarSy,
                 ProcedureSy, FunctionSy, SetSy, InSy, FileSy, ArraySy,
                 RecordSy, ProgramSy, BeginSy, EndSy, CaseSy, RepeatSy,
                 UntilSy, WhileSy, DoSy, ForSy, ToSy, DownToSy, IfSy, ThenSy,
                 ElseSy, GotoSy, OfSy, WithSy, ForwardSy, PackedSy, NilSy);

     Objects  = (Nothing, Labels, Constants, Datatypes, Variables, Procedures,
                 Functions);

     Types    = (NoType, Ints, Reals, Bools, Chars, Arrays, Records, Pointers,
                 Subranges, Enumerations, Sets, Files, Strings);

     pNode    = ^Node;                          (* Zeiger auf Baumknoten      *)
     pType    = ^tType;                         (* Zeiger auf Typ-Referenz    *)
     pRing    = ^Ring;                          (* Zeiger auf Ringelement     *)

     tType    = RECORD                          (* Typ-Referenz eines Objekts *)
                   Size : INTEGER;              (* Speicherplatzbedarf        *)

                   CASE Typ : Types OF
                     NoType, Ints, Reals, Bools, Chars, Strings :
                        ();
                     Arrays :                   (* Datenfelder                *)
                        (IndexType,             (* Datentyp vom Index         *)
                         ElementType : pType);  (* Datentyp der Feldelemente  *)
                     Records :                  (* Variablenverbunde          *)
                        (RecordTree : pNode);   (* Baum der Verbundvariablen  *)
                     Subranges :                (* Unterbereichstyp           *)
                        (RangeType : pType;     (* Basistyp                   *)
                         RangeLow,              (* Untere Grenze              *)
                         RangeHigh : INTEGER);  (* Obere Grenze               *)
                     Enumerations :             (* Aufz�hlungstyp             *)
                        (EnumSize : INTEGER);   (* Anzahl der Elemente        *)
                     Pointers :                 (* Zeigertyp                  *)
                        (PointerType : pType;   (* Datentyp des Zeigers       *)
                         PointerTo   : IdText); (* Name des Datentyps         *)
                     Sets :                     (* Mengentyp                  *)
                        (BaseType : pType);     (* Datentyp der Elemente      *)
                     Files :                    (* Dateien                    *)
                        (FileType : pType);     (* Datentyp der Elemente      *)
                END;

     Node     = RECORD                          (* Symboltabelle = Bin�rbaum  *)
                   Name  : IdText;              (* Name des Bezeichners       *)
                   Left,                        (* Linker Nachfolger          *)
                   Right : pNode;               (* Rechter Nachfolger         *)
                   Typ   : Types;               (* Datentyp des Bezeichners   *)
                   Nrm   : BOOLEAN;             (* Variable oder Parameter    *)
                   Lev,                         (* Prozedurtiefe              *)
                   Size,                        (* Speicherplatzbedarf        *)
                   Adr   : INTEGER;             (* Adresse des Bezeichners    *)
                   Ref   : pType;               (* Typ-Referenz des Objekts   *)

                   CASE Obj : Objects OF
                      Datatypes, Nothing, Variables :
                         ();
                      Constants :               (* Konstanten                 *)
                         (Value : INTEGER);     (* Wert oder Index            *)
                      Labels :                  (* Sprungmarken               *)
                         (LabelAdr : pNode;     (* F�r Goto-Spr�nge vorw�rts  *)
                          Stack,                (* Stack-Korrektur von Label  *)
                          Correct,              (* Stack-Korrektur von Goto   *)
                          Count : INTEGER);     (* Adresse eines Goto-Befehls *)
                      Procedures, Functions :   (* Prozeduren, Funktionen     *)
                         (Par       : pRing;    (* Parameter einer Prozedur   *)
                          Rem,                  (* Forward-Prozedur Parameter *)
                          ProcAdr   : pNode;    (* F�r Call ohne Zieladresse  *)
                          CallCount,            (* Adresse von einem Call     *)
                          VarSize,              (* Variablen-Speicherplatz    *)
                          ParSize   : INTEGER); (* Parameter-Speicherplatz    *)
                END;

     Ring     = RECORD                          (* Ringelement                *)
                   ObjectContent : pNode;       (* Zeigt auf Bezeichner       *)
                   TypeContent   : pType;       (* Zeigt auf Typ-Referenz     *)
                   Next,                        (* N�chstes Ringelement       *)
                   Prev          : pRing;       (* Vorheriges Ringelement     *)
                END;

     Order    = RECORD                          (* Befehl der Zielsprache     *)
                   f : Orders;                  (* Funktionscode              *)
                   x : 0..LevelMax;             (* Level = Parameter 1        *)
                   y : -NumberMax..+NumberMax;  (* Offset = Parameter 2       *)
                END;

    SymbolSet = SET OF Symbol;                  (* Menge aller Symbole        *)
    TypeSet   = SET OF Types;                   (* Menge aller Datentypen     *)
    tCode     = ARRAY [0..CodeMax] OF Order;    (* Speicher f�r Zielprogramm  *)

VAR source      : TEXT;                         (* Quelldatei = Quelltext     *)
    target      : FILE;                         (* Zieldatei = typenlos       *)
    Ch          : CHAR;                         (* Lookahead vom Scanner      *)
    Sym         : Symbol;                       (* Symbol vom Scanner         *)
    AbleToRun   : BOOLEAN;                      (* Quelltext fehlerhaft       *)
    Errors      : SET OF 0..ErrorMax;           (* Fehlermenge einer Zeile    *)
    ProgramName : IdText;                       (* Name des Hauptprogrammes   *)

    Id          : IdText;                       (* Bezeichnername = Attribut  *)
    IntNum      : INTEGER;                      (* Integerzahl = Attribut     *)
    RealNum     : REAL;                         (* Realzahl = Attribut        *)
    StringLen   : INTEGER;                      (* Stringl�nge = Attribut     *)

    IntegerType,                                (* Eintrag von 'integer'      *)
    BooleanType,                                (* Eintrag von 'boolean'      *)
    CharType,                                   (* Eintrag von 'char'         *)
    RealType,                                   (* Eintrag von 'real'         *)
    TextType,                                   (* Eintrag von 'text'         *)
    NoTypeType  : pType;                        (* Bei Fehlern 'notype'       *)

    ErrorPos,                                   (* Fehlerposition in Zeile    *)
    NrOfErrors,                                 (* Anzahl der Fehler          *)
    CharCount,                                  (* Buchstabenz�hler pro Zeile *)
    ProgCount,                                  (* Programmz�hler             *)
    LineLen,                                    (* L�nge der aktuellen Zeile  *)
    LineNumber,                                 (* Aktuelle Zeilennummer      *)
    StringIndex,                                (* Index f�r Stringtabelle    *)
    RealIndex   : INTEGER;                      (* Index f�r Realtabelle      *)

    ConstBegSym,                                (* Konstantensymbole          *)
    TypeBegSym,                                 (* Typensymbole               *)
    BlockBegSym,                                (* Blocksymbole               *)
    FactBegSym,                                 (* Faktorsymbole              *)
    StateBegSym : SymbolSet;                    (* Anweisungssymbole          *)
    ScalarTypes : TypeSet;                      (* Skalare Datentypen         *)

    Code        : ^tCode;                          (* �bersetzter Code        *)
    Line        : ARRAY [1..LineMax] OF CHAR;      (* Aktuelle Eingabezeile   *)
    KeyWord     : ARRAY [1..KeyWords] OF IdText;   (* Schl�sselworte          *)
    KeySymbol   : ARRAY [1..KeyWords] OF Symbol;   (* Schl�sselsymbole        *)
    SpecialSym  : ARRAY [CHAR] OF Symbol;          (* Spezielle Symbole       *)
    StringTable : ARRAY [1..StringMax] OF CHAR;    (* Stringtabelle           *)
    RealTable   : ARRAY [1..RealMax] OF REAL;      (* Tabelle der Realzahlen  *)
    Remember    : ARRAY [0..LevelMax] OF pRing;    (* Zur Speicherfreigabe    *)
    ForwardCall : ARRAY [0..LevelMax] OF pRing;    (* Call's ohne Zieladresse *)
    Display     : ARRAY [0..LevelMax] OF pNode;    (* Display der Levels      *)

(* END GLOBAL.PAS *)
