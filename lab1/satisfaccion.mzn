/*
==================================================================================================================
Datos de entrada
==================================================================================================================
*/

int: D; %Días consecutivos para los que se tiene que hacer el plan
int: T; %Número de trabajadores
int: N1; %Número de trabajadores que tiene que tener el turno 1
int: N2; %Número de trabajadores que tiene que tener el turno 2
int: N3; %Número de trabajadores que tiene que tener el turno 3
int: MaxDT; %Número máximo de días consecutivos que se puede trabajar por persona
int: MaxDL; %Número máximo de días consecutivos que se puede librar por persona
int: MinDT; %Número mínimo de días que se tienen que trabajar por persona en los D días
int: A; %Número de trabajadores afines con los que se tiene que estar en un turno
array [1..T, 1..T] of bool: afines; %Afinidad por trabajador. E.g. afines[1,2] = afines[2,1] es la afinidad del trabajador 1 con el 2
set of 1..T: R; %Conjunto de trabajadores que son encargados

/*
==================================================================================================================
Variables de condición
==================================================================================================================
*/

% qué turno tiene asignado cada trabajador cada día o si libra (identificado con el 0)
array [1..T, 1..D] of var 0..3: sol; 

/*
==================================================================================================================
Asserts (Condiciones necesarias para una solución)
==================================================================================================================
*/

constraint assert(N1 + N2 + N3 <= T, 
    "No hay suficientes trabajadores para cubrir los turnos de un sólo día laboral (N1+N2+N3 > T)");
    
constraint assert(MinDT <= D, 
    "Se está exigiendo trabajar más días de los que hay (MinDT > D)");
    
constraint assert(A < max(N1, max(N2, N3)), 
    "Se están exigiendo más afines de lo que caben en los turnos (A >= max(N1, N2, N3))");
/*
==================================================================================================================
Restricciones
==================================================================================================================
*/

% 1. Cada turno tiene el número de trabajadores ("N1", "N2" o "N3") que le corresponde.

constraint forall(dia in 1..D) 
(
  sum(trabajador in 1..T)(sol[trabajador,dia] = 1) = N1
  /\
  sum(trabajador in 1..T)(sol[trabajador,dia] = 2) = N2
  /\
  sum(trabajador in 1..T)(sol[trabajador,dia] = 3) = N3
);



% 2. Un trabajador solo puede estar en un turno cada día.

% Está implícito en la propia definición de la variable de decisión
% pues cada trabajador tiene asignado para cada día un único turno o ninguno



% 3. Dado un número "MaxDT", garantizar que nadie trabaja "MaxDT" días consecutivos.

constraint forall(trabajador in 1..T, dia in 1..D-MaxDT) 
(
  sum(dia_rango in dia..dia+MaxDT)(sol[trabajador,dia_rango] != 0) <= MaxDT
);



% 4. Dado un número "MaxDL", garantizar que nadie tiene "MaxDL" días libres consecutivos.

constraint forall(trabajador in 1..T, dia in 1..D-MaxDL) 
(
  sum(dia_rango in dia..dia+MaxDL)(sol[trabajador,dia_rango] = 0) <= MaxDL
);



%5. Dado un número "MinDT", garantizar que todos trabajan como mínimo "MinDT" en los "D" días.

constraint forall(trabajador in 1..T) 
(
  sum(dia in 1..D)(sol[trabajador,dia] != 0) >= MinDT
);



%6. Si un trabajador hace el último turno de un día entonces no puede tener el primero del día siguiente.

constraint forall(trabajador in 1..T, dia in 1..D-1) 
(
  sol[trabajador, dia] = 3 
    -> 
  sol[trabajador, dia+1] != 1
);



%7. Si un trabajador hace el último turno dos días seguidos entonces tiene que librar el día siguiente.

constraint forall(trabajador in 1..T, dia in 1..D-2) 
(
  sol[trabajador, dia] = 3 /\ sol[trabajador, dia+1] = 3 
    ->
  sol[trabajador, dia + 2] = 0
);



%8. Dada una serie de parejas de trabajadores afines, que se indicarán con una matriz 1..T x 1..T de Booleanos “afines”, y un número “A”, cada trabajador de un turno tiene que estar con al menos A trabajadores afines en ese turno.

constraint forall(dia in 1..D, trabajador_org in 1..T) 
(
  % no se revisan los trabajadores que no tienen turno asignado ese día
  sol[trabajador_org, dia] = 0
  \/
  sum(trabajador_dst in 1..T)
    (
    trabajador_dst != trabajador_org 
    /\ 
    sol[trabajador_org, dia] = sol[trabajador_dst, dia]
    /\ 
    afines[trabajador_org, trabajador_dst]
    )
  >= A
);



%9. Sea "R" el conjunto de trabajadores (que se obtendrá como un set of números de trabajador) que tienen la categoría de encargados. En cada turno debe haber al menos un responsable.

constraint forall(dia in 1..D) 
(
  sum(trabajador in 1..T)(sol[trabajador,dia] = 1 /\ trabajador in R) > 0
  /\
  sum(trabajador in 1..T)(sol[trabajador,dia] = 2 /\ trabajador in R) > 0
  /\
  sum(trabajador in 1..T)(sol[trabajador,dia] = 3 /\ trabajador in R) > 0
);



/*
==================================================================================================================
SOLVE / PRINT
==================================================================================================================
*/

solve satisfy;