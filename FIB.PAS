(*****************************************************)
(* Programmautor : Michael Rippl                     *)
(* Programmname  : Fibonacci.pas                     *)
(* Datum         : 11-Jan-1990                       *)
(*                                                   *)
(* Dieses Programm berechnet eine Fibonaccische Zahl *)
(* aus ihrer Platznummer in der Fibonacci-Folge.     *)
(*****************************************************)
PROGRAM Fibonacci (input, output);
VAR FibNum : INTEGER;

(* Rekursive Funktion berechnet Fibonacci-Zahl *)
FUNCTION Fib(Nummer : INTEGER) : INTEGER;
BEGIN
   IF Nummer > 1 THEN Fib := Fib(Nummer - 1) + Fib(Nummer - 2)
   ELSE IF Nummer = 1 THEN Fib := 1
   ELSE Fib := 0;
END; (* Fib *)

BEGIN
   writeln; writeln;
   writeln('Dieses Programm berechnet eine Fibonaccische Zahl');
   writeln('aus ihrer Platznummer in der Fibonacci-Folge.');
   writeln;

   write('Bitte geben Sie eine positive Zahl ein : ');
   readln(FibNum);
   writeln('Die Fibonacci-Zahl lautet : ', Fib(FibNum));
END. (* Fibonacci *)
