(*************************************************************)
(* Programmname    : PASCAL.PAS V1.0                         *)
(* Programmautor   : Michael Rippl                           *)
(* Compiler        : Turbo Pascal V5.0                       *)
(* Letzte Änderung : 05-Mar-1990                             *)
(* Inhalt          : Hauptprogramm des Compilers PASCAL V1.0 *)
(* Bemerkung       : Hauptdatei von PASCAL.PAS V1.0          *)
(*************************************************************)

PROGRAM Pascal(input, output, source, target);

USES Crt;                                          (* Ein/Ausgabe-Routinen    *)

(*$I GLOBAL.PAS*)                                  (* Globale Definitionen    *)
(*$I ERRORS.PAS*)                                  (* Fehlerbehandlung        *)
(*$I EMITTER.PAS*)                                 (* Codeerzeugung           *)
(*$I SYMTAB.PAS*)                                  (* Symboltabelle           *)
(*$I SCANNER.PAS*)                                 (* Lexikalsiche Analyse    *)
(*$I PARSER.PAS*)                                  (* Syntaktische Analyse    *)
(*$I INITIAL.PAS*)                                 (* Initialisierungen       *)

BEGIN (* Hauptprogramm *)
   CheckParameters;                                (* Parameter überprüfen    *)
   InitVariables;                                  (* Vorinitialisierung      *)
   Parser;                                         (* Syntaxüberprüfung       *)

   IF ErrorPos <> 0 THEN PrintErrorSet;            (* Zeile hatte Fehler      *)
   CleanUp;
END. (* Hauptprogramm *)
