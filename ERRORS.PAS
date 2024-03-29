(*****************************************************)
(* Programmname    : ERRORS.PAS                      *)
(* Programmautor   : Michael Rippl                   *)
(* Compiler        : Turbo Pascal V5.0               *)
(* Letzte Änderung : 13-Mar-1990                     *)
(* Inhalt          : Fehlerbehandlung von PASCAL.PAS *)
(* Bemerkung       : Include-Datei von PASCAL.PAS    *)
(*****************************************************)

(* Gibt Fehlermeldung in verständlicher Form aus *)
PROCEDURE PrintMessage(Number : INTEGER);
BEGIN
   write('│ ', Number : 3, ' : ');

   CASE Number OF
      0   : write('illegal character in source file');
      2   : write('constant out of range');
      4   : write('string terminator not on this line');
      6   : write('indicated symbol incorrectly used');
      9   : write('string must contain at least one character');
      20  : write('identifier expected');
      21  : write('symbol ''['' expected');
      22  : write('symbol '']'' expected');
      23  : write('symbol '';'' expected');
      24  : write('label constant expected');
      26  : write('symbol '':='' expected');
      28  : write('symbol ''then'' expected');
      32  : write('symbol ''until'' expected');
      34  : write('symbol ''do'' expected');
      36  : write('symbol ''of'' expected');
      37  : write('symbol '':'' expected');
      38  : write('symbol ''begin'' expected');
      40  : write('symbol ''end'' expected');
      41  : write('symbol '')'' expected');
      43  : write('symbol ''='' expected');
      45  : write('symbol ''('' expected');
      48  : write('error in factor');
      52  : write('error in statement sequence');
      53  : write('symbol ''.'' expected');
      56  : write('symbol ''to'' or ''downto'' expected');
      59  : write('symbol ''..'' expected');
      61  : write('identifier or symbol ''var'' expected');
      62  : write('procedure-body expected');
      64  : write('cannot read or write variables of this type');
      65  : write('pointer variable expected');
      66  : write('variable expected');
      72  : write('identifier declared twice');
      73  : write('identifier not declared');
      75  : write('label not declared');
      76  : write('label defined twice');
      77  : write('case label defined twice');
      81  : write('no parameterlist allowed here');
      82  : write('previous forward declaration does not agree');
      83  : write('not all declared labels are defined');
      84  : write('not all forward-declared procedures are implemented');
      85  : write('not all pointer-referenced types are declared');
      86  : write('not all record-variants declared');
      88  : write('function type is not scalar or basic type');
      96  : write('subrange only with identical types');
      97  : write('first bound of subrange is greater than second');
      100 : write('type array or record expected');
      101 : write('record variable expected');
      105 : write('program name expected');
      107 : write('set base type out of range');
      108 : write('files cannot contain files');
      120 : write('type incompatible index');
      121 : write('illegal base type for subrange');
      123 : write('incorrect constant');
      129 : write('type identifier expected');
      130 : write('structure too large');
      131 : write('not enough actual parameters');
      132 : write('too many actual parameters');
      133 : write('error in procedure parameters');
      134 : write('actual and formal parameters must be of the same type');
      135 : write('files must be var parameters');
      136 : write('constant expected');
      137 : write('operands must be of type real');
      138 : write('operands must be of type boolean');
      139 : write('operands must be of type integer');
      140 : write('type of arithmetic expression is illegal');
      141 : write('type expected');
      142 : write('field selectors only allowed for records');
      143 : write('type incompatible comparands');
      144 : write('operand types do not match operator');
      145 : write('type incompatible assignment');
      146 : write('arrow not belonging to a pointer variable');
      147 : write('bracket not belonging to an array variable');
      148 : write('type incompatible parameter');
      149 : write('expression must be of type boolean');
      150 : write('type of control variable is illegal');
      151 : write('expression has not the same type as the control variable');
      152 : write('type incompatible case label');
      156 : write('integer or real constant expected');
      160 : write('assignment not allowed');
      200 : write('index out of range');
      201 : write('division by zero');
      203 : write('constant out of range');
   END;

   gotoxy(80, wherey);                             (* Cursor positionieren    *)
   write('│');
END; (* PrintMessage *)

(* Belegte Resourcen freigeben, vorwärtsdeklariert *)
PROCEDURE CleanUp; FORWARD;

(* Fehlermenge einer Programmzeile ausgeben *)
PROCEDURE PrintErrorSet;
VAR k      : INTEGER;
    Answer : CHAR;
BEGIN
   gotoxy(1,wherey);                               (* Cursor positionieren    *)
   write('│');
   gotoxy(80,wherey);                              (* Cursor positionieren    *)
   write('││');
   gotoxy(80,wherey);                              (* Cursor positionieren    *)
   write('││ errors at line ', LineNumber : 1, ' :');
   gotoxy(80,wherey);                              (* Cursor positionieren    *)
   write('│');
   ErrorPos := 0;
   k := 0;

   WHILE Errors <> [ ] DO                          (* Alle Fehler ausgeben    *)
   BEGIN
      WHILE NOT (k IN Errors) DO k := k + 1;

      PrintMessage(k);                             (* Fehlertext ausgeben     *)
      Errors := Errors - [k];
   END;

   write('È═══════════════════════════════════════'); (* 40 Zeichen           *)
   write('═══════════════════════════════════════¥'); (* 40 Zeichen           *)

   IF NrOfErrors >= AbortingMax THEN               (* Fehlergrenze erreicht   *)
   BEGIN
      writeln;
      write('would you like to abort compilation (y/n) : ');
      readln(Answer);

      if (Answer = 'y') OR (Answer = 'Y') THEN
      BEGIN
         writeln;
         writeln('compilation aborted');
         CleanUp;
         halt;
      END;

      NrOfErrors := 0;
      writeln;
   END;
END; (* PrintErrorSet *)

(* Zeigt Fehlerprosition in Programmzeile und gibt Fehlernummer aus *)
PROCEDURE Error(Number : INTEGER);
VAR Length,                                        (* Länge einer Zeile       *)
    k      : INTEGER;
BEGIN
   IF NrOfErrors = 0 THEN clrscr;                  (* Bildschirm löschen      *)

   IF ErrorPos = 0 THEN                            (* Erster Fehler in Zeile  *)
   BEGIN
      writeln;
      write('ı═══════════════════════════════════════'); (* 40 Zeichen        *)
      write('═══════════════════════════════════════©│ ');

      IF LineLen > 79 THEN Length := 78            (* Zeilelänge begrenzen    *)
      ELSE Length := LineLen;

      FOR k := 1 TO Length - 2 DO write(Line[k]);  (* Programmzeile ausgeben  *)

      gotoxy(80, wherey);                          (* Cursor positionieren    *)
      write('│');
   END;

   IF CharCount > ErrorPos THEN                    (* Platz zum Anzeigen      *)
   BEGIN
      IF CharCount < 75 THEN                       (* Rechter Bildschirmrand  *)
         write(' ' : CharCount - ErrorPos, chr(24), Number : 1);

      IF Number < 10 THEN ErrorPos := CharCount + 2
      ELSE IF (Number >= 10) AND (Number <= 99) THEN ErrorPos := CharCount + 3
      ELSE ErrorPos := CharCount + 4;              (* Nächst möglicher Platz  *)
   END;

   IF NOT (Number IN Errors) THEN                  (* Keine doppelten Fehler  *)
   BEGIN
      NrOfErrors := NrOfErrors + 1;                (* Anzahl der Fehler       *)
      Errors := Errors + [Number];                 (* Fehler merken           *)
      AbleToRun := FALSE;                          (* Quelltext fehlerhaft    *)
   END;
END; (* Error *)

(* Fataler Fehler führt zur Unterbrechung des Übersetzungsvorgangs *)
PROCEDURE Fatal(Number : INTEGER);
BEGIN
   IF ErrorPos <> 0 THEN PrintErrorSet;            (* Letzte Zeile hat Fehler *)
   AbleToRun := FALSE;                             (* Zielprogramm fehlerhaft *)
   write('fatal error : ');

   CASE Number OF
      0 : write('program is incomplete');
      1 : write('stringtable overflow');
      2 : write('realtable overflow');
      3 : write('leveltable overflow');
      4 : write('program body is too long');
      5 : write('symbol ''program'' expected');
      6 : write('symbol ''forward'' is not allowed here');
      7 : write('not enough memory for variables');
      8 : write('cannot write object file');
      9 : write('casetable overflow');
   END;

   writeln(' at line ', LineNumber : 1);
   CleanUp;
   halt;
END; (* Fatal *)

(* END ERRORS.PAS *)
