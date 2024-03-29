(**************************************************)
(* Programmname    : EMITTER.PAS                  *)
(* Programmautor   : Michael Rippl                *)
(* Compiler        : Turbo Pascal V5.0            *)
(* Letzte Änderung : 12-Apr-1990                  *)
(* Inhalt          : Codeerzeugung von PASCAL.PAS *)
(* Bemerkung       : Include Datei von PASCAL.PAS *)
(**************************************************)

(* Funktion ohne Parameter *)
PROCEDURE Emit(Func : Orders);
BEGIN
   IF ProgCount = CodeMax THEN Fatal(4);           (* Programm zu groß        *)

   Code^[ProgCount].f := Func;
   ProgCount := ProgCount + 1;
END; (* Emit *)

(* Funktion mit einem Parameter *)
PROCEDURE Emit1(Func : Orders; Offset : INTEGER);
BEGIN
   IF ProgCount = CodeMax THEN Fatal(4);           (* Programm zu groß        *)

   WITH Code^[ProgCount] DO
   BEGIN
      f := Func;
      y := Offset;
   END;

   ProgCount := ProgCount + 1;
END; (* Emit1 *)

(* Funktion mit zwei Parametern *)
PROCEDURE Emit2(Func : Orders; Level, Offset : INTEGER);
BEGIN
   IF ProgCount = CodeMax THEN Fatal(4);           (* Programm zu groß        *)

   WITH Code^[ProgCount] DO
   BEGIN
      f := Func;
      x := Level;
      y := Offset;
   END;

   ProgCount := ProgCount + 1;
END; (* Emit2 *)

(* END EMITTER.PAS *)
