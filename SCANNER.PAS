(*********************************************************)
(* Programmname    : SCANNER.PAS                         *)
(* Programmautor   : Michael Rippl                       *)
(* Compiler        : Turbo Pascal V5.0                   *)
(* Letzte Änderung : 13-Jan-1990                         *)
(* Inhalt          : Lexikalische Analyse von PASCAL.PAS *)
(* Bemerkung       : Include Datei von PASCAL.PAS        *)
(*********************************************************)

(* Nächstes Zeichen von Quelldatei einlesen und weitergeben *)
PROCEDURE NextChar;
VAR k : INTEGER;
BEGIN
   IF CharCount = LineLen THEN                     (* Ende der Programmzeile  *)
   BEGIN
      IF eof(source) THEN Fatal(0);                (* Unerwartetes Dateiende  *)
      IF ErrorPos <> 0 THEN PrintErrorSet;         (* Letzte Zeile hat Fehler *)

      LineNumber := LineNumber + 1;                (* Zeilennummer erhöhen    *)
      LineLen := 0;
      CharCount := 0;

      WHILE NOT eoln(source) DO                    (* Neue Zeile einlesen     *)
      BEGIN
         LineLen := LineLen + 1;
         read(source, Ch);
         Line[LineLen] := Ch;
      END;

      LineLen := LineLen + 1;
      read(source, Line[LineLen]);                 (* Linefeed einlesen       *)
      LineLen := LineLen + 1;
      read(source, Line[LineLen]);                 (* Return einlesen         *)
   END;

   CharCount := CharCount + 1;
   Ch := Line[CharCount];
END; (* NextChar *)

(* Scanner für die lexikalische Analyse *)
PROCEDURE InSymbol;
LABEL 1,                                           (* Anfang von InSymbol     *)
      2;                                           (* String eingelesen       *)
VAR i,
    j,
    k,
    Exponent : INTEGER;                            (* Exponent einer Realzahl *)

(* Exponent einlesen und dessen Wert berechnen *)
PROCEDURE ReadScale;
VAR i,
    e,                                             (* Eingelesener Exponent   *)
    Sign : INTEGER;                                (* Vorzeichen              *)
BEGIN
   NextChar;
   Sign := 1;
   e := 0;
   i := 0;

   IF Ch = '+' THEN NextChar                       (* Vorzeichen prüfen       *)
   ELSE IF Ch = '-' THEN
   BEGIN
      NextChar;
      Sign := -1;
   END;

   WHILE Ch IN ['0'..'9'] DO                       (* Exponent einlesen       *)
   BEGIN
      i := i + 1;
      IF i <= ExpDigit THEN e := e * 10 + ord(Ch) - ord('0');
      NextChar;
   END;

   IF i > ExpDigit THEN
   BEGIN
      Error(2);                                    (* Zahl ist zu groß        *)
      e := 0;
   END;

   Exponent := Exponent + e * Sign;
END; (* ReadScale *)

(* Exponent mit in die Realzahl übernehmen *)
PROCEDURE AdjustScale;
VAR e : INTEGER;
    d,
    t : REAL;
BEGIN
   IF k + Exponent > ExpMax THEN Error(2)          (* Zahl ist zu groß        *)
   ELSE IF k + Exponent < ExpMin THEN RealNum := 0 (* Bereich unterschritten  *)
   ELSE
   BEGIN
      e := abs(Exponent);
      t := 1.0;
      d := 10.0;

      REPEAT
         WHILE NOT odd(e) DO
         BEGIN
            e := e DIV 2;                          (* Exponent wird halbiert  *)
            d := sqr(d);                           (* Wert quadriert sich     *)
         END;

         e := e - 1;
         t := d * t;
      UNTIL e = 0;

      IF Exponent >= 0 THEN RealNum := RealNum * t
      ELSE RealNum := RealNum / t;
   END;
END; (* AdjustScale *)

(* Wandelt Großbuchstaben in Kleinbuchstaben um *)
FUNCTION LowerCase(Letter : CHAR) : CHAR;
BEGIN
   IF Letter IN ['A'..'Z'] THEN LowerCase := chr(ord(Letter) + 32)
   ELSE LowerCase := Letter;
END; (* LowerCase *)

BEGIN (* InSymbol *)
   1:
                                                   (* Unerlaubte Symbole und  *)
                                                   (* Leerstellen überlesen   *)
   WHILE ((ord(Ch) > 127) OR (ord(Ch) <= 32)) and (ord(Ch) <> 1) DO NextChar;

   IF ord(Ch) = 1 THEN                             (* Ersatz für Symbol ..    *)
   BEGIN
      Sym := DotDot;
      NextChar;
   END
   ELSE IF (Ch IN ['a'..'z']) OR (Ch IN ['A'..'Z']) THEN
   BEGIN                                           (* Es ist ein Wort         *)
      k := 0;
      Id := '                ';                    (* 16 Leerstellen          *)

      REPEAT                                       (* Wort einlesen           *)
         IF k < SigChars THEN
         BEGIN
            k := k + 1;
            Id[k] := LowerCase(Ch);                (* Nur Kleinbuchstaben     *)
         END;

         NextChar;
      UNTIL NOT (Ch IN ['A'..'Z', 'a'..'z', '0'..'9']);

      i := 1;                                      (* Untere Grenze           *)
      j := KeyWords;                               (* Obere Grenze            *)

      REPEAT                                       (* Binary Search           *)
         k := (i + j) DIV 2;
         IF Id <= KeyWord[k] THEN j := k - 1;
         IF Id >= KeyWord[k] THEN i := k + 1;
      UNTIL i > j;

      IF i - 1 > j THEN Sym := KeySymbol[k]        (* Schlüsselwort gefunden  *)
      ELSE Sym := Identifier;
   END
   ELSE IF Ch IN ['0'..'9'] THEN                   (* Es ist eine Zahl        *)
   BEGIN
      k := 0;
      IntNum := 0;
      Sym := IntConst;                             (* Integerkonstante        *)
      Id := '                ';                    (* 16 Leerstellen          *)

      REPEAT                                       (* Zahl einlesen           *)
         k := k + 1;
         IF k <= DigitMax THEN Id[k] := Ch;
         NextChar;
      UNTIL NOT (Ch IN ['0'..'9']);

      IF k > DigitMax THEN
      BEGIN
         k := 0;
         Error(2);                                 (* Zahl ist zu groß        *)
      END
      ELSE IF k < DigitMax THEN                    (* Zahl ist in Ordnung     *)
      BEGIN
         i := 1;

         REPEAT                                    (* Zahl in Wert umwandeln  *)
            IntNum := IntNum * 10 + ord(Id[i]) - ord('0');
            i := i + 1;
         UNTIL Id[i] = ' ';
      END
      ELSE IF Id > MaxIntStr THEN
      BEGIN
         k := 0;
         Error(2);                                 (* Zahl ist zu groß        *)
      END
      ELSE
      BEGIN                                        (* DigitMax Stellen        *)
         FOR i := 1 TO DigitMax DO                 (* Zahl in Wert umwandeln  *)
            IntNum := IntNum * 10 + ord(Id[i]) - ord('0');
      END;

      IF Ch = '.' THEN
      BEGIN
         NextChar;

         IF Ch = '.' THEN Ch := chr(1)             (* Ersatz für Symbol ..    *)
         ELSE
         BEGIN
            Sym := RealConst;                      (* Realkonstante           *)
            RealNum := IntNum;
            Exponent := 0;
            i := 0;

            WHILE Ch IN ['0'..'9'] DO              (* Nachkommastellen        *)
            BEGIN
               i := i + 1;

               IF i <= FracDigit THEN
               BEGIN
                  Exponent := Exponent - 1;
                  RealNum := RealNum * 10.0 + ord(Ch) - ord('0');
               END;

               NextChar;
            END;

            IF Ch = 'e' THEN ReadScale;            (* Exponent einlesen       *)
            IF Exponent <> 0 THEN AdjustScale;     (* In Realzahl übernehmen  *)
         END;
      END
      ELSE IF Ch = 'e' THEN
      BEGIN
         Sym := RealConst;                         (* Realkonstante           *)
         RealNum := IntNum;
         Exponent := 0;
         ReadScale;                                (* Exponent einlesen       *)
         IF Exponent <> 0 THEN AdjustScale;        (* In Realzahl übernehmen  *)
      END;
   END
   ELSE                                            (* Weder Zahl noch Wort    *)
   CASE Ch OF
      ':' :
      BEGIN
         NextChar;

         IF Ch = '=' THEN                          (* Zuweisung               *)
         BEGIN
            Sym := Becomes;
            NextChar;
         END
         ELSE Sym := Colon;                        (* Doppelpunkt             *)
      END;

      '<' :
      BEGIN
         NextChar;

         IF Ch = '=' THEN                          (* Kleiner gleich          *)
         BEGIN
            Sym := Leq;
            NextChar;
         END
         ELSE IF Ch = '>' THEN                     (* Nicht gleich            *)
         BEGIN
            Sym := Neq;
            NextChar;
         END
         ELSE Sym := Lss;                          (* Kleiner als             *)
      END;

      '>' :
      BEGIN
         NextChar;

         IF Ch = '=' THEN                          (* Größer gleich           *)
         BEGIN
            Sym := Geq;
            NextChar;
         END
         ELSE Sym := Gtr;                          (* Größer als              *)
      END;

      '.' :
      BEGIN
         NextChar;

         IF Ch = '.' THEN                          (* Symbol .. gefunden      *)
         BEGIN
            Sym := DotDot;
            NextChar;
         END
         ELSE Sym := Period;                       (* Punkt                   *)
      END;

      '''' :                                       (* String                  *)
      BEGIN
         k := 0;                                   (* Stringlänge = 0         *)

         WHILE TRUE DO                             (* Endlosschleife          *)
         BEGIN
            NextChar;

            IF CharCount = 1 THEN
            BEGIN
               Error(4);                           (* Nicht in Zeile beendet  *)
               k := -1;
               Sym := CharConst;
               IntNum := 0;
               GOTO 2;
            END;

            IF Ch = '''' THEN
            BEGIN
               NextChar;
               IF Ch <> '''' THEN GOTO 2;          (* Fall '' liegt nicht vor *)
            END;

            IF StringIndex + k > StringMax THEN
               Fatal(1);                           (* Stringtabelle voll      *)

            StringTable[StringIndex + k] := Ch;
            k := k + 1;
         END;

         2:

         IF k = 0 THEN
         BEGIN
            Error(9);                              (* Leerer String           *)
            Sym := CharConst;
            IntNum := 0;
         END
         ELSE IF k = 1 THEN
         BEGIN
            Sym := CharConst;                      (* Buchstabenkonstante     *)
            IntNum := ord(StringTable[StringIndex]);
         END
         ELSE IF k > 1 THEN
         BEGIN
            Sym := StringConst;                    (* Stringkonstante         *)
            IntNum := StringIndex;
            StringLen := k;
            StringIndex := StringIndex + k;
         END;
      END;

      '(' :
      BEGIN
         NextChar;

         IF Ch <> '*' THEN Sym := LeftParent       (* Klammer auf             *)
         ELSE
         BEGIN                                     (* Kommentar               *)
            NextChar;

            REPEAT
               WHILE Ch <> '*' DO NextChar;
               NextChar;
            UNTIL Ch = ')';

            NextChar;
            GOTO 1;
         END;
      END;

      '{' :                                        (* Kommentar               *)
      BEGIN
         WHILE Ch <> '}' DO NextChar;
         NextChar;
         GOTO 1;
      END;

      '+', '-', '*', '/', ')', '=', ',', '[', ']', ';', '^' :
      BEGIN
         Sym := SpecialSym[Ch];                    (* Spezialsymbol           *)
         NextChar;
      END;

      '$', '%', '@', '', '~', '"', '`', '!', '&', 'ß', '|', '#', '_', '\',
      'ä', 'Ä', 'ö', 'Ö', 'ü', 'Ü' :
      BEGIN
         NextChar;
         Error(0);                                 (* Symbol nicht erlaubt    *)
         GOTO 1;
      END;
   END;
END; (* InSymbol *)

(* Symbole überlesen, falls ein Fehler im Quelltext aufgetaucht ist *)
PROCEDURE Skip(Symbols : SymbolSet; Number : INTEGER);
BEGIN
   Error(Number);
   WHILE NOT (Sym IN Symbols) DO InSymbol;
END; (* Skip *)

(* Testen, ob aktuelles Symbol in vorgegebener Symbolmenge ist, sonst Fehler *)
PROCEDURE Match(GivenSymbols, Symbols : SymbolSet; Number : INTEGER);
BEGIN
   IF NOT (Sym IN GivenSymbols) THEN Skip(GivenSymbols + Symbols, Number);
END; (* Match *)

(* Testen, ob aktuelles Symbol ein Semicolon ist *)
PROCEDURE MatchSemicolon;
BEGIN
   IF Sym = Semicolon THEN InSymbol
   ELSE
   BEGIN
      Error(23);                                   (* Symbol ; erwartet       *)
      IF Sym IN [Comma, Colon] THEN InSymbol;
   END;

   Match([Identifier] + BlockBegSym, StateBegSym, 6);
END; (* MatchSemicolon *)

(* END SCANNER.PAS *)
