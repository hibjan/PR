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

set of 1..T: antiestres; %Conjunto de trabajadores que pueden trabajar en turnos antiestrés
set of 1..T: doblar; %Conjunto de trabajadores que pueden doblar turnos
array[1..T, 1..D] of bool: diaND; %Día de trabajo que cada trabajador pide no trabajar
array[1..T, 1..D] of 0..3: turnoND; %Turno que cada trabajador pide no hacer cada día (0 = sin preferencia)

/*
==================================================================================================================
Variables de condición
==================================================================================================================
*/

% qué turno tiene asignado cada trabajador cada día o si libra (identificado con el 0)
array [1..T, 1..D] of var 0..3: sol; 

array[1..T, 1..D] of var bool: dobla; % dobla[t,d] y sol[t,d] = k -> trabajador t en día d trabaja en turno k y k+1

/*
==================================================================================================================
Asserts (Condiciones necesarias para una solución)
==================================================================================================================
*/

% constraint assert(N1 + N2 + N3 <= T, 
%    "No hay suficientes trabajadores para cubrir los turnos de un sólo día laboral (N1+N2+N3 > T)");

% Ya no se cumple al permitir que se doblen turnos
    
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
  sum(trabajador in 1..T)(sol[trabajador,dia] = 2 \/ (sol[trabajador, dia] = 1 /\ dobla[trabajador, dia])) = N2
  /\
  sum(trabajador in 1..T)(sol[trabajador,dia] = 3 \/ (sol[trabajador, dia] = 2 /\ dobla[trabajador, dia])) = N3
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
  sum(dia_rango in dia..dia+MaxDL)(
           (sol[trabajador,dia_rango] = 0 /\ dia_rango = 1 /\ not diaND[trabajador,dia_rango])
           \/
           (sol[trabajador,dia_rango] = 0 /\ dia_rango > 1 /\ not dobla[trabajador, dia_rango-1] /\ not diaND[trabajador,dia_rango])
                                  )
  <= 
  MaxDL
);



%5. Dado un número "MinDT", garantizar que todos trabajan como mínimo "MinDT" en los "D" días.

constraint forall(trabajador in 1..T) 
(
  sum(dia in 1..D)(sol[trabajador,dia] != 0) 
  >= 
  MinDT - sum(dia in 1..D)(dobla[trabajador, dia] + (diaND[trabajador, dia] /\ sol[trabajador,dia] = 0))
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
    (
        sol[trabajador_org, dia] = sol[trabajador_dst, dia]
        \/
        (
            sol[trabajador_org, dia] < 3
            /\
            dobla[trabajador_org, dia] 
            /\
            sol[trabajador_org, dia] + 1 = sol[trabajador_dst, dia]
        )
    )
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
  sum(trabajador in 1..T)(
                         (
                         sol[trabajador,dia] = 2 
                         \/ 
                         (dobla[trabajador,dia] /\ sol[trabajador,dia] = 1)
                         )
                         /\ 
                         trabajador in R
                        ) 
  > 
  0
  /\
  sum(trabajador in 1..T)(
                         (
                         sol[trabajador,dia] = 3
                         \/ 
                         (dobla[trabajador,dia] /\ sol[trabajador,dia] = 2)
                         )
                         /\ 
                         trabajador in R
                         )
  > 
  0
);

/*
==================================================================================================================
Restricciones adicionales y Problemas de optimización
==================================================================================================================
*/

% 1. Añadid la posibilidad de que algunos trabajadores puedan trabajar en "turnos antiestrés", es decir, en turnos rotatorios. De esta manera si un trabajador trabaja dos mañanas, dos tardes y una noche consecutivas librará dos días seguidos

% En R4, si MaxDL < 2 entonces esto no es posible directamente. En este apartado no se dice nada sobre si cuenta como un día "especial", entonces hemos optado por la negativa, y por tanto para que alguien pueda hacer estos turnos es necesario que MaxDL >= 2. Lo mismo ocurre en R3 con MaxDT < 5, que para que alguien pueda hacerlo se tiene que dar que MaxDT >= 5

constraint forall(trabajador in antiestres, dia in 1..D-6)
(
  (sol[trabajador, dia]   = 1 /\
   sol[trabajador, dia+1] = 1 /\
   sol[trabajador, dia+2] = 2 /\
   sol[trabajador, dia+3] = 2 /\
   sol[trabajador, dia+4] = 3)
  ->
  (sol[trabajador, dia+5] = 0 /\
   sol[trabajador, dia+6] = 0)
);



% 2.  Añadid la posibilidad de que los trabajadores soliciten doblar turnos. De esta manera, un trabajador podrá trabajar durante dos turnos consecutivos en un mismo día, librando al día siguiente. Tened en cuenta que ese día libre no cuenta en la restricción de días consecutivos libres y hay que descontarlo de "MinDT". Modificad las restricciones anteriores en caso de ser necesario.

% Sólo pueden doblar aquellos que hayan pedido doblar
constraint forall(trabajador in 1..T, dia in 1..D)(not(trabajador in doblar) -> dobla[trabajador, dia] = false);

% Sólo se puede doblar en el turno 1 o el turno 2
constraint forall(trabajador in 1..T, dia in 1..D) 
(
  dobla[trabajador, dia]
  -> 
  (sol[trabajador, dia] = 1 \/ sol[trabajador, dia] = 2)
);

% Si se dobla al día siguiente no se trabaja
constraint forall(trabajador in 1..T, dia in 1..D-1) 
(
  dobla[trabajador, dia]
  -> 
  sol[trabajador, dia + 1] = 0
);

/*
Se tendrán que modificar las siguientes restricciones:

R1: Cuando alguien doble se cuente el turno "k+1"
R2: Ninguno
R3: Ninguno. Pues, al no haber modificado sol la restricción lo cuenta como un sólo día
R4: Cuando alguien doble el día libre consecuente de ello no debe ser contado para los MaxDL días libres consecutivos permitidos
R5: Cuando alguien doble se debe tomar en cuenta como un día trabajado adicional para cubrir MinDT
R6: Ninguno. Pues, si dobla ya no trabaja ningún turno al día siguiente, incluido el primero
R7: Ninguno. Pues, si dobla, en particular el turno 2, y ha trabajado el día anterior en el 3, librará ya el día siguiente de igual forma
R8: Cuando alguien doble debe de contarse la afinidad también en el turno "k+1"
R9: Cuando alguien doble debe de tomarse en cuenta en el turno "k+1" para verificar si es encargado o no

*/


% 3. Añadid la posibilidad de que los trabajadores pidan días que no quieren trabajar. Tened en cuenta que estos días no cuentan en la restricción de días consecutivos libres y que hay que descontarlos de "MinDT". Convertid el problema en un problema de optimización, minimizando el número de veces que hacemos trabajar a alguien cuando no quiere. Pensad en formas de conseguir que los incumplimientos se distribuyan entre todos.

/*
Se tendrán que modificar las siguientes restricciones:

R1: Ninguno. Trivial
R2: Ninguno. Trivial
R3: Ninguno. Trivial
R4: Cuando alguien libre en consecuencia de habérselo pedido entonces no deberá contársele ese día para los MaxDL días consecutivos librados permitidos
R5: Cuando alguien libre en consecuencia de habérselo pedido entonces no deberá contársele ese día para los MinDL días librados totales que tienen que concedérsele
R6: Ninguno. Trivial
R7: Ninguno. Trivial
R8: Ninguno. Trivial
R9: Ninguno. Trivial
*/

% Primera versión en la que simplemente se minimiza sobre el total de incumplimientos
% La solución óptima podría resultar en que sólo para un trabajador se le otorgen sus días no deseados
/*
solve minimize sum(trabajador in 1..T, dia in 1..D)(
                  diaND[trabajador, dia] /\ sol[trabajador, dia] != 0
                );
*/
      
% Segunda versión en la que se minimiza sobre el máximo de incumplimientos en los trabajadores
% La solución óptima podría resultar en que con tal de minimizar el máximo la suma de incumplimientos sea mayor
/*
solve minimize max(trabajador in 1..T)(
                sum(dia in 1..D)(
                  diaND[trabajador, dia] /\ sol[trabajador, dia] != 0)
               );
*/

% Tercera versión en la que se combinan ambos, con un factor T en el máximo
/*
En el peor caso hay D incumplimientos por cada trabajador, por tanto T*D incumplimientos
Sumamos entonces el número de incumplimientos totales más el máximo de incumplimientos multiplicado por el número de trabajadores
Entonces, reducir en uno el máximo (oasar de maxVal a maxVal-1), reduce en T la función objetivo
Así, al reducir el máximo, es posible que el total aumente
El caso peor sería si al bajar el maxVal en uno, el resto fuese menor que maxVal-1 y todos tuvieran que incumplirse una vez para cumplir ese menor máximo
Lo cual haría que aumentase el total de incumplimientos en T-1
Es decir, disminuye en T y aumenta en T-1, por lo que no sacrificaría equidad para ganar en el total
En conclusión, dentro de todas las soluciones con el mismo máximo, el solver elige la de menor total. Y entre soluciones con distinto máximo, siempre prefiere el menor máximo
*/


solve minimize sum(trabajador in 1..T, dia in 1..D)(
                  diaND[trabajador, dia] /\ sol[trabajador, dia] != 0
                )
                +
                T *
                max(trabajador in 1..T)(
                  sum(dia in 1..D)(
                    diaND[trabajador, dia] /\ sol[trabajador, dia] != 0)
                );


% 4. Añadid la posibilidad de que los trabajadores pidan qué turno no quieren (único o para cada día), si es que tienen alguna preferencia. Convertid el problema en un problema de optimización, minimizando el número de veces que incumplimos la petición. Pensad en formas de conseguir que los incumplimientos se distribuyan entre todos.

% Primera versión: minimizar la suma total de incumplimientos de turno
% La solución óptima podría concentrar todos los incumplimientos en un único trabajador
/*
solve minimize sum(trabajador in 1..T, dia in 1..D)(
                  turnoND[trabajador, dia] != 0
                  /\
                  sol[trabajador, dia] = turnoND[trabajador, dia]
                );
*/

% Segunda versión: minimizar el máximo de incumplimientos por trabajador
% Garantiza equidad en el peor caso pero puede inflar el total innecesariamente
/*
solve minimize max(trabajador in 1..T)(
                  sum(dia in 1..D)(
                    turnoND[trabajador, dia] != 0
                    /\
                    sol[trabajador, dia] = turnoND[trabajador, dia]
                  )
               );
*/

% Tercera versión: combinación ponderada de total y máximo, con factor T en el máximo

/*
solve minimize sum(trabajador in 1..T, dia in 1..D)(
                  turnoND[trabajador, dia] != 0
                  /\
                  sol[trabajador, dia] = turnoND[trabajador, dia]
                )
                +
                T *
                max(trabajador in 1..T)(
                  sum(dia in 1..D)(
                    turnoND[trabajador, dia] != 0
                    /\
                    sol[trabajador, dia] = turnoND[trabajador, dia]
                  )
                );
*/

/*
==================================================================================================================
SOLVE / PRINT
==================================================================================================================
*/

%solve satisfy;

output 
["--- INCUMPLIMIENTOS DE DÍAS NO DESEADOS (diaND) ---\n"] ++
[
  "Trabajador " ++ show(trabajador) ++ ": " ++ 
  show(sum(dia in 1..D)(diaND[trabajador, dia] /\ sol[trabajador, dia] != 0)) ++ " incumplimientos\n"
  | trabajador in 1..T
] ++
["Total de días incumplidos: " ++ show(sum(trabajador in 1..T, dia in 1..D)(diaND[trabajador, dia] /\ sol[trabajador, dia] != 0)) ++ "\n\n"] ++


["--- INCUMPLIMIENTOS DE TURNOS NO DESEADOS (turnoND) ---\n"] ++
[
  "Trabajador " ++ show(trabajador) ++ ": " ++ 
  show(sum(dia in 1..D)(turnoND[trabajador, dia] != 0 /\ sol[trabajador, dia] = turnoND[trabajador, dia])) ++ " incumplimientos\n"
  | trabajador in 1..T
] ++
["Total de turnos incumplidos: " ++ show(sum(trabajador in 1..T, dia in 1..D)(turnoND[trabajador, dia] != 0 /\ sol[trabajador, dia] = turnoND[trabajador, dia])) ++ "\n"];