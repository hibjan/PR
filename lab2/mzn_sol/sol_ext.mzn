bool: optimizar = true; % override con -D "optimizar=false" para resolver el punto 1 (satisfy)



enum Aceites = { VEG1, VEG2, ANV1, ANV2, ANV3 };
enum Meses = {Enero, Febrero, Marzo, Abril, Mayo, Junio};

function bool: esVegetal(Aceites: aceite) = aceite == VEG1 \/ aceite == VEG2;

function var bool: refinadoNV(Meses: mes) = exists(aceite in Aceites)(not esVegetal(aceite) /\ refinado[mes, aceite] > 0);

/*
==================================================================================================================
Datos de entrada
==================================================================================================================
*/

array [Meses, Aceites] of int: precios; %Precio en euros/tonelada en el mes X del aceite Y

int: VALOR; %Precio en euros/tonelada de venta del producto final

int: MAXV; %Máximo de toneladas de aceite vegetal que se puede refinar por mes 
int: MAXN; %Máximo de toneladas de aceite no vegetal que se puede refinar por mes 

int: PV; %Máxima variación porcentual del uso de aceite vegetales respecto a los no vegetales
          %Si es 25 entonces el uso de aceite vegetal puede ser hasta un 25% más que el de los no vegetales
            % NumNV = 100 -> NumV = 0-125
          %Si es -10 entonces el uso de aceite vegatal puede ser hasta un 10% menos que el de los no vegetales
            % NumNV = 100 -> NumV = 0-90
            
int: MCAP; %Capacidad de almacenamiento de la fábrica en toneladas para cada tipo de aceite al inicio de cada mes
int: CA; %Costes por tonelada de almacenamiento por cada tipo de aceite al inicio de cada mes

array [Aceites] of float: dureza; %Dureza de cada tipo de aceite
float: MinD; %Mínimo de dureza
float: MaxD; %Máximo de dureza

array [Aceites] of int: inicial; %Las cantidades que se tienen al inicio (01 de enero)

int: MinB; %Mínimo beneficio que se tiene que conseguir

/*
==================================================================================================================
Datos de entrada (extensiones)
==================================================================================================================
*/

array [Meses] of int: K; %K número de aceites que al menos han de usarse cada mes

array [Meses,Aceites] of int: T; %T toneladas que al menos han usarse en caso de que se use el aceite en un mes

array [Aceites,Aceites] of bool: requiere; %Si es cierto requiere[i,j] entonces i requiere de j

array [Aceites,Aceites] of bool: reemplazo; %Si es cierto reemplazo[i,j] entonces i tiene que ser reemplazado por j
                  
/*
==================================================================================================================
Variables de condición
==================================================================================================================
*/

array [Meses, Aceites] of var 0..MCAP + max(MAXV, MAXN): comprado; % Cuánto se ha comprado de aceite cada mes

array [Meses, Aceites] of var 0..max(MAXV, MAXN): refinado; % Cuánto se ha refinado de cada aceite en cada mes

array [Meses, Aceites] of var 0..MCAP: almacenado; % Cuánto hay almacenado de cada aceite al inicio de cada mes (01-XX)
                                                      % Almacenado[Enero] = inicial
                                                      % Almacenado[Febrero] = Comprado[Enero] + Almacenado[Enero] - Refinado[Enero]
                                                      % Almacenado[Marzo] ...
                                                      % (Almacenado[Julio]) = Comprado[Junio] + Almacenado[Junio] - Refinado[Junio] = inicial

/*
==================================================================================================================
Asserts (Condiciones necesarias para una solución)
==================================================================================================================
*/

% --- Comunes ---

% Precios y costes no negativos
constraint assert(forall(m in Meses, a in Aceites)(precios[m,a] >= 0),
  "Los precios no pueden ser negativos");
constraint assert(VALOR > 0, 
  "VALOR debe ser positivo");
constraint assert(CA >= 0, 
  "CA no puede ser negativo");

% Capacidades no negativas
constraint assert(MAXV >= 0, 
  "MAXV no puede ser negativo");
constraint assert(MAXN >= 0, 
  "MAXN no puede ser negativo");
constraint assert(MCAP >= 0, 
  "MCAP no puede ser negativo");

% PV razonable: con PV <= -100 la cota (1+PV/100)*nv sería <= 0 y obligaría veg=0
constraint assert(PV > -100, 
  "PV debe ser > -100 para que la restricción sea coherente");

% Dureza
constraint assert(MinD <= MaxD, 
  "MinD debe ser <= MaxD");
constraint assert(forall(a in Aceites)(dureza[a] > 0.0),
  "Las durezas deben ser positivas");

% Stock inicial coherente con la capacidad
constraint assert(forall(a in Aceites)(inicial[a] >= 0 /\ inicial[a] <= MCAP),
  "inicial[a] debe estar en [0, MCAP]");

% Factibilidad de la dureza: el rango [MinD, MaxD] debe intersectar las durezas
constraint assert(MinD <= max(a in Aceites)(dureza[a]) /\ MaxD >= min(a in Aceites)(dureza[a]),
  "El rango [MinD, MaxD] no es alcanzable con las durezas dadas");

% Cota laxa de factibilidad económica de MinB
constraint assert(MinB <= 6 * (MAXV + MAXN) * VALOR,
  "MinB es inalcanzable incluso con ingresos máximos sin costes");

% --- Específicos de las extensiones ---

% K coherente con el número de aceites
constraint assert(forall(m in Meses)(K[m] >= 0 /\ K[m] <= card(Aceites)),
  "K[mes] debe estar en [0, |Aceites|]");

% T no negativo y compatible con la línea de refinado correspondiente
constraint assert(forall(m in Meses, a in Aceites)(T[m,a] >= 0),
  "T[mes,aceite] no puede ser negativo");
constraint assert(forall(m in Meses, a in Aceites where esVegetal(a))(T[m,a] <= MAXV),
  "T[mes,aceite vegetal] excede MAXV");
constraint assert(forall(m in Meses, a in Aceites where not esVegetal(a))(T[m,a] <= MAXN),
  "T[mes,aceite no vegetal] excede MAXN");

% requiere y reemplazo sin auto-referencias
constraint assert(forall(a in Aceites)(not requiere[a,a]),
  "requiere[a,a] debe ser false");
constraint assert(forall(a in Aceites)(not reemplazo[a,a]),
  "reemplazo[a,a] debe ser false");

% Coherencia entre requiere y reemplazo: reemplazo[a,b] /\ requiere[b,a] es contradictorio
constraint assert(forall(a, b in Aceites)(not (reemplazo[a,b] /\ requiere[b,a])),
  "Conflicto: reemplazo[a,b] y requiere[b,a] son incompatibles");

/*
==================================================================================================================
Restricciones
==================================================================================================================
*/

% 1. No se refina más de MAXV aceite vegetal al mes
constraint forall(mes in Meses)(sum(aceite in Aceites)(refinado[mes, aceite]*esVegetal(aceite)) <= MAXV);

% 2. No se refina más de MAXN aceite no vegetal al mes
constraint forall(mes in Meses)(sum(aceite in Aceites)(refinado[mes, aceite]*(not(esVegetal(aceite)))) <= MAXN);

% 3. Variación del uso aceite vegetal respecto al no vegetal es como máximo PV al mes
constraint forall(mes in Meses)
  (
  sum(aceite in Aceites)(refinado[mes, aceite]*esVegetal(aceite)) 
  <= 
  (1 + (PV/100.0)) * sum(aceite in Aceites)(refinado[mes, aceite]*(not(esVegetal(aceite))))
  );
  
% 4. La cantidad de aceite almacenado por cada tipo de aceite no puede ser más que MCAP al mes
% Implícito en almacenado

% 5. Si se usan aceites no vegetales, la dureza del producto tiene que estar entre MinD y MaxD cada mes
% SUM(REFINADO*DUREZA) / SUM(REFINADO) <= MaxD
% =>
% SUM(REFINADO*DUREZA) <= MaxD * SUM(REFINADO)
constraint forall(mes in Meses)(
  refinadoNV(mes) -> 
  (
    sum(aceite in Aceites)(refinado[mes,aceite]*dureza[aceite]) 
    <= 
    MaxD * sum(aceite in Aceites)(refinado[mes,aceite])
    /\
    sum(aceite in Aceites)(refinado[mes,aceite]*dureza[aceite]) 
    >= 
    MinD * sum(aceite in Aceites)(refinado[mes,aceite])
  )
);

% 6. El aceite almacenado al inicio es el dado por inicial
constraint forall(aceite in Aceites)(almacenado[Enero,aceite] = inicial[aceite]);

% 7. El aceite almacenado al final (01 de julio) tiene que ser igual al almacenado al principio (01 de enero)
constraint forall(aceite in Aceites) (comprado[Junio,aceite] + almacenado[Junio,aceite] - refinado[Junio,aceite] = inicial[aceite]);

% 8. Lo que hay almacenado en Mes es igual a Comprado[Mes - 1] + Almacenado[Mes - 1] - Refinado[Mes - 1]
constraint forall(mes in Meses, aceite in Aceites where mes != Enero)(
  almacenado[mes,aceite] = comprado[enum_prev(mes),aceite] + almacenado[enum_prev(mes),aceite] - refinado[enum_prev(mes),aceite]
);

% 9. El beneficio tiene que ser al menos MinB

var int: beneficio =
sum(mes in Meses)(
  sum(aceite in Aceites)(refinado[mes,aceite])*VALOR %Refinado[Mes]*VALOR
  -
  sum(aceite in Aceites)(comprado[mes,aceite]*precios[mes,aceite]) %Comprado[Mes]*Precio[Mes]
  -
  sum(aceite in Aceites)(almacenado[mes,aceite])*CA %Almacenado[Mes]*CA
);

constraint beneficio >= MinB;

/*
Beneficio[Enero] = Refinado[Enero]*VALOR - Comprado[Enero]*Precio[Enero] - Almacenado[Enero]*CA
Beneficio[Febrero] = Refinado[Febrero]*VALOR - Comprado[Febrero]*Precio[Febrero] - Almacenado[Febrero]*CA
...
*/

/*
==================================================================================================================
Extensiones
==================================================================================================================
*/

% 1. El producto debe hacerse con un mínimo de K aceites. Este número pueden ser distinto cada mes.

constraint forall(mes in Meses)(sum(aceite in Aceites)(refinado[mes,aceite] > 0) >= K[mes]);

% 2. Si un mes usamos un cierto aceite, entonces debemos usar como mínimo T toneladas.

constraint forall(mes in Meses, aceite in Aceites)(refinado[mes,aceite] > 0 -> refinado[mes,aceite] >= T[mes, aceite]);

% 3.1. Si usamos el aceite ANV 1 o el aceite ANV 2 en un cierto mes, entonces VEG 1 también debe ser usado ese mes. 
/*
constraint forall(mes in Meses)(refinado[mes,ANV1] > 0 -> refinado[mes,VEG1] > 0);
constraint forall(mes in Meses)(refinado[mes,ANV2] > 0 -> refinado[mes,VEG1] > 0);
*/
% 3.2. Generalizad esta restricción a que haya aceites que requieren el uso de otro aceite.
constraint forall(mes in Meses, aceite in Aceites)(
  forall(aceite_check in Aceites where aceite_check != aceite /\ requiere[aceite,aceite_check])(
    refinado[mes,aceite] > 0 -> refinado[mes,aceite_check] > 0
  )
);

% 4.1. Si no usamos el aceite ANV 3 entonces debemos usar VEG 1 ese mes. 
% constraint forall(mes in Meses)(refinado[mes,ANV3] = 0 -> refinado[mes,VEG1] > 0);
% 4.2. Generalizad esta restricción a que haya aceites que si no se usan deben ser reemplazados por otro.
constraint forall(mes in Meses, aceite in Aceites)(
  forall(aceite_check in Aceites where aceite_check != aceite /\ reemplazo[aceite,aceite_check])(
    refinado[mes,aceite] = 0 -> refinado[mes,aceite_check] > 0
  )
);

/*
==================================================================================================================
SOLVE / PRINT
==================================================================================================================
*/

var int: objetivo = if optimizar then beneficio else 0 endif;
solve maximize objetivo;

output
[ "Beneficio: ", show(beneficio), "\n\n" ]
++
[ "--- " ++ show(mes) ++ " ---\n" ++
  "  Comprado:    " ++ show([comprado[mes, a]   | a in Aceites]) ++ "\n" ++
  "  Almacenado:  " ++ show([almacenado[mes, a] | a in Aceites]) ++ "\n" ++
  "  Refinado:    " ++ show([refinado[mes, a]   | a in Aceites]) ++ "\n" ++
  "  Total refinado: " ++ show(sum(a in Aceites)(refinado[mes, a])) ++
  "\n\n"
  | mes in Meses
];
