#!/usr/bin/python3
from z3 import *
import sys, io, ast

try:
    filenameIn = sys.argv[1]
except IndexError:
    filenameIn = "./z3_casos_prueba/0_data_ext.txt"
myinput = "".join(open(filenameIn, "r").readlines())
sys.stdin = io.StringIO(myinput)

LEXICOGRAPHIC = True   # Optimización lexicográfica: 1º max beneficio, 2º min aceites
#SOLO APLICAN SI LEXICOGRAPHIC = False
OPTIMIZE = True # Problema de optimización ?
SEARCH = True # Problema de optimización con búsqueda (en vez de pesos) ?
LINEAR = False # Búsqueda lineal (en vez de binaria) ?
WEIGTHS_VERSION = 1 # 1: pesos crecientes por número de aceites usados (ejemplo), 2: peso fijo por cada aceite usado (alternativa)

"""
======================================================================================================================
DATOS DE ENTRADA
======================================================================================================================
"""
VALOR = 150
DUREZA = [8.8, 6.1, 2.0, 4.2, 5.0]
PRECIOS = [[110, 120, 130, 110, 115],
           [130, 130, 110,  90, 115],
           [110, 140, 130, 100,  95],
           [120, 110, 120, 120, 125],
           [100, 120, 150, 110, 105],
           [ 90, 100, 140,  80, 135]]

MAXV = 200
MAXN = 250

PV = 10

MCAP = 1000

CA = 5

MIND = 3.0
MAXD = 6.0
MINB = 100000

INICIAL = [500, 500, 500, 500, 500]


K = [0, 0, 0, 0, 0, 0]

T = [[0, 0, 0, 0, 0],
     [0, 0, 0, 0, 0],
     [0, 0, 0, 0, 0],
     [0, 0, 0, 0, 0],
     [0, 0, 0, 0, 0],
     [0, 0, 0, 0, 0]]

REQUIERE = [[False, False, False, False, False],
            [False, False, False, False, False],
            [True,  False, False, False, False],
            [True,  False, False, False, False],
            [False, False, False, False, False]]

REEMPLAZO = [[False, False, False, False, False],
             [False, False, False, False, False],
             [False, False, False, False, False],
             [False, False, False, False, False],
             [True,  False, False, False, False]]

"""
======================================================================================================================
LECTURA DE DATOS
======================================================================================================================
"""

lineas = sys.stdin.read().strip().split('\n')

datos = []
buffer = ""

for linea in lineas:
    buffer += linea.strip() + " "
    try:
        valor = ast.literal_eval(buffer.strip())
        datos.append(valor)
        buffer = ""
    except (SyntaxError, ValueError):
        pass

VALOR       = datos[0]
DUREZA      = datos[1]
PRECIOS     = datos[2]
MAXV        = datos[3]
MAXN        = datos[4]
PV          = datos[5]
MCAP        = datos[6]
CA          = datos[7]
MIND        = datos[8]
MAXD        = datos[9]
MINB        = datos[10]
INICIAL     = datos[11]
K           = datos[12]
T           = datos[13]
REQUIERE    = datos[14]
REEMPLAZO   = datos[15]

MESES = 6
ACEITES = 5
VEGETALES = [0, 1]
NO_VEGETALES = [2, 3, 4]

FACTOR = 10
DUREZA_INT = [int(d * FACTOR) for d in DUREZA]
MIND_INT   = int(MIND * FACTOR)
MAXD_INT   = int(MAXD * FACTOR)

"""
======================================================================================================================
ASSERTS (Condiciones necesarias para una solución)
======================================================================================================================
"""

# --- Comunes ---
assert all(PRECIOS[m][a] >= 0 for m in range(MESES) for a in range(ACEITES)), \
    "Los precios no pueden ser negativos"
assert VALOR > 0, \
    "VALOR debe ser positivo"
assert CA >= 0, \
    "CA no puede ser negativo"

assert MAXV >= 0, \
    "MAXV no puede ser negativo"
assert MAXN >= 0, \
    "MAXN no puede ser negativo"
assert MCAP >= 0, \
    "MCAP no puede ser negativo"

assert PV > -100, \
    "PV debe ser > -100 para que la restricción sea coherente"

assert MIND <= MAXD, \
    "MIND debe ser <= MAXD"
assert all(DUREZA[a] > 0.0 for a in range(ACEITES)), \
    "Las durezas deben ser positivas"

assert all(0 <= INICIAL[a] <= MCAP for a in range(ACEITES)), \
    "INICIAL[a] debe estar en [0, MCAP]"

assert MIND <= max(DUREZA) and MAXD >= min(DUREZA), \
    "El rango [MIND, MAXD] no es alcanzable con las durezas dadas"

assert MINB <= 6 * (MAXV + MAXN) * VALOR, \
    "MINB es inalcanzable incluso con ingresos máximos sin costes"

# --- Específicos de las extensiones ---
assert all(0 <= K[m] <= ACEITES for m in range(MESES)), \
    "K[mes] debe estar en [0, |Aceites|]"

assert all(T[m][a] >= 0 for m in range(MESES) for a in range(ACEITES)), \
    "T[mes,aceite] no puede ser negativo"
assert all(T[m][a] <= MAXV for m in range(MESES) for a in VEGETALES), \
    "T[mes,aceite vegetal] excede MAXV"
assert all(T[m][a] <= MAXN for m in range(MESES) for a in NO_VEGETALES), \
    "T[mes,aceite no vegetal] excede MAXN"

assert all(not REQUIERE[a][a] for a in range(ACEITES)), \
    "requiere[a,a] debe ser false"
assert all(not REEMPLAZO[a][a] for a in range(ACEITES)), \
    "reemplazo[a,a] debe ser false"

assert all(not (REEMPLAZO[a][b] and REQUIERE[b][a])
           for a in range(ACEITES) for b in range(ACEITES)), \
    "Conflicto: reemplazo[a,b] y requiere[b,a] son incompatibles"

"""
======================================================================================================================
FUNCIONES AUXILIARES
======================================================================================================================
"""

def print_sol(model):
    for m in range(MESES):
            print(f"\n--- Mes {m+1} ---")
            for a in range(ACEITES):
                print(f"  comp_{m}_{a} = {model[comprado[m][a]]}, "
                    f"ref_{m}_{a} = {model[refinado[m][a]]}, "
                    f"alm_{m}_{a} = {model[almacenado[m][a]]}")

def print_num_aceites(num):
    for m in range(MESES):
        print(f"Mes {m+1}: {num[m]} aceites usados.")

def get_num_aceites_mes(model):
    num_aceites = []
    for m in range(MESES):
        count = 0
        for a in range(ACEITES):
            if model[refinado[m][a]] is not None and model[refinado[m][a]].as_long() > 0:
                count += 1
        num_aceites.append(count)
    return num_aceites

def contar_aceites():
    return Sum([If(refinado[m][a] > 0, 1, 0) for m in range(MESES) for a in range(ACEITES)])

def contar_aceites_mes(m):
    return Sum([If(refinado[m][a] > 0, 1, 0) for a in range(ACEITES)])

def busq_lin(s):
    cota = MESES * ACEITES
    mejor_modelo = None

    while cota >= 0:
        s.add(contar_aceites() <= cota)
        res = s.check()
        if res == sat:
            mejor_modelo = s.model()
            cota -= 1
            print(f"\tEncontrado modelo con {cota + 1} aceites usados. Buscando mejor...")
        elif res == unsat:
            break
        else:
            print("Error: resultado inesperado.")
            break

    return (mejor_modelo, cota + 1)

def busq_bin(s):
    hi = MESES * ACEITES
    lo = 0
    mejor_modelo = None

    while lo < hi:
        mid = (lo + hi) // 2
        s.push()
        s.add(contar_aceites() <= mid)
        res = s.check()
        if res == sat:
            mejor_modelo = s.model()
            hi = s.model().eval(contar_aceites()).as_long()
            print(f"\tSAT con cota {mid} → nuevo hi={hi}")
        elif res == unsat:
            lo = mid + 1
            print(f"\tUNSAT con cota {mid} → nuevo lo={lo}")
            s.pop()
        else:
            print("Error: resultado inesperado.")
            break

    return (mejor_modelo, lo)

def busq_bin_beneficio(s):
    lo = MINB
    hi = 6 * (MAXV + MAXN) * VALOR  # cota laxa: ingresos máximos sin restar costes
    mejor_modelo = None
    mejor_b = MINB

    while lo <= hi:
        mid = (lo + hi) // 2
        s.push()
        s.add(beneficio >= mid)
        res = s.check()
        if res == sat:
            mejor_modelo = s.model()
            mejor_b = mejor_modelo.eval(beneficio).as_long()
            lo = mejor_b + 1
            print(f"\tSAT con beneficio>={mid} → b*_actual={mejor_b}, nuevo lo={lo}")
            # No popeamos: la cota se vuelve permanente (el modelo ya cumple algo más fuerte)
        elif res == unsat:
            hi = mid - 1
            print(f"\tUNSAT con beneficio>={mid} → nuevo hi={hi}")
            s.pop()
        else:
            print("Error: resultado inesperado.")
            break

    return (mejor_modelo, mejor_b)

"""
======================================================================================================================
GENERACION SMT
======================================================================================================================
"""

# Variables
comprado   = [[Int(f"comp_{m}_{a}") for a in range(ACEITES)] for m in range(MESES)]
refinado   = [[Int(f"ref_{m}_{a}")  for a in range(ACEITES)] for m in range(MESES)]
almacenado = [[Int(f"alm_{m}_{a}") for a in range(ACEITES)] for m in range(MESES)]

# Selección de solver según el modo
if LEXICOGRAPHIC:
    print("Modo: optimización lexicográfica (max beneficio, min aceites)")
    s = SolverFor("QF_LIA")
elif OPTIMIZE and not SEARCH:
    s = Optimize()
    if WEIGTHS_VERSION == 1:
        print("Optimizando con pesos crecientes por número de aceites usados...")
        for m in range(MESES):
            for a in range(ACEITES):
                s.add_soft(contar_aceites_mes(m) <= a+1, weight=a+1)
    else:
        print("Optimizando con peso fijo por cada aceite usado...")
        for m in range(MESES):
            for a in range(ACEITES):
                s.add_soft(If(refinado[m][a] > 0, 1, 0) == 0, weight=1)
else:
    s = SolverFor("QF_LIA")

# Dominios
for m in range(MESES):
    for a in range(ACEITES):
        s.add(comprado[m][a]   >= 0, comprado[m][a]   <= MCAP + max(MAXV, MAXN))
        s.add(refinado[m][a]   >= 0, refinado[m][a]   <= max(MAXV, MAXN))
        s.add(almacenado[m][a] >= 0, almacenado[m][a] <= MCAP)


# R1/R2: capacidad de refinado
for m in range(MESES):
    s.add(Sum([refinado[m][a] for a in VEGETALES])    <= MAXV)
    s.add(Sum([refinado[m][a] for a in NO_VEGETALES]) <= MAXN)

# R3: variación PV
for m in range(MESES):
    veg  = Sum([refinado[m][a] for a in VEGETALES])
    nveg = Sum([refinado[m][a] for a in NO_VEGETALES])
    s.add(100 * veg <= (100 + PV) * nveg)

# R4: capacidad de almacenamiento -> Implícito en dominio

# R5: dureza
for m in range(MESES):
    nveg_total  = Sum([refinado[m][a] for a in NO_VEGETALES])
    total_ref   = Sum([refinado[m][a] for a in range(ACEITES)])
    dureza_pond = Sum([refinado[m][a] * DUREZA_INT[a] for a in range(ACEITES)])

    s.add(Implies(nveg_total > 0, And(dureza_pond >= MIND_INT * total_ref, dureza_pond <= MAXD_INT * total_ref)))

# R6: stock inicial
for a in range(ACEITES):
    s.add(almacenado[0][a] == INICIAL[a])

# R7: stock final = stock inicial
for a in range(ACEITES):
    s.add(almacenado[5][a] + comprado[5][a] - refinado[5][a] == INICIAL[a])

# R8: transición mes a mes
for m in range(MESES - 1):
    for a in range(ACEITES):
        s.add(almacenado[m+1][a] == almacenado[m][a] + comprado[m][a] - refinado[m][a])

# R9: beneficio mínimo (la expresión queda extraída como variable Z3 reutilizable)
ingresos      = Sum([refinado[m][a] * VALOR for m in range(MESES) for a in range(ACEITES)])
costes_compra = Sum([comprado[m][a] * PRECIOS[m][a] for m in range(MESES) for a in range(ACEITES)])
costes_almacen= Sum([almacenado[m][a] * CA for m in range(MESES) for a in range(ACEITES)])
beneficio = ingresos - costes_compra - costes_almacen
s.add(beneficio >= MINB)

"""
======================================================================================================================
EXTENSIONES
======================================================================================================================
"""

# E1: el producto debe hacerse con un mínimo de K[m] aceites cada mes
for m in range(MESES):
    s.add(Sum([If(refinado[m][a] > 0, 1, 0) for a in range(ACEITES)]) >= K[m])

# E2: si un mes se usa un aceite, debe usarse al menos T[m][a] toneladas
for m in range(MESES):
    for a in range(ACEITES):
        s.add(Implies(refinado[m][a] > 0, refinado[m][a] >= T[m][a]))

# E3: si REQUIERE[a][b], usar el aceite a obliga a usar el aceite b
for m in range(MESES):
    for a in range(ACEITES):
        for b in range(ACEITES):
            if a != b and REQUIERE[a][b]:
                s.add(Implies(refinado[m][a] > 0, refinado[m][b] > 0))

# E4: si REEMPLAZO[a][b], no usar el aceite a obliga a usar el aceite b
for m in range(MESES):
    for a in range(ACEITES):
        for b in range(ACEITES):
            if a != b and REEMPLAZO[a][b]:
                s.add(Implies(refinado[m][a] == 0, refinado[m][b] > 0))


"""
======================================================================================================================
RESOLUCIÓN Y OPTIMIZACIÓN
======================================================================================================================
"""

if s.check() == unsat:
    print("No hay solución factible (las restricciones base son insatisfacibles).")
elif LEXICOGRAPHIC:
    print("\n=== Fase 1: maximizar beneficio (búsqueda binaria incremental) ===")
    modelo_f1, b_estrella = busq_bin_beneficio(s)
    if modelo_f1 is None:
        print("No se ha encontrado ninguna solución en la fase 1.")
    else:
        print(f"\nBeneficio óptimo encontrado: {b_estrella}")

        print("\n=== Fase 2: minimizar nº de aceites manteniendo beneficio = b* ===")
        # Fijamos el beneficio óptimo como restricción dura para la fase 2
        s.add(beneficio >= b_estrella)
        modelo_f2, n_aceites = busq_bin(s)

        if modelo_f2 is None:
            # Si la fase 2 no mejora, el modelo final es el de la fase 1
            print("La fase 2 no ha mejorado: se reporta el modelo de la fase 1.")
            modelo_final = modelo_f1
        else:
            modelo_final = modelo_f2

        print(f"\nNº total de aceites usados (mínimo con b*={b_estrella}): {n_aceites}")
        print_num_aceites(get_num_aceites_mes(modelo_final))
        print(f"Beneficio final: {modelo_final.eval(beneficio).as_long()}")
        print_sol(modelo_final)
elif not OPTIMIZE:
    print_sol(s.model())
else:
    if SEARCH:
        if LINEAR:
            print("Optimización con búsqueda decremental...")
            mejor_modelo, min_usos = busq_lin(s)
            print_num_aceites(get_num_aceites_mes(mejor_modelo))
            print_sol(mejor_modelo)
        else:
            print("Optimización con búsqueda binaria...")
            mejor_modelo, min_usos = busq_bin(s)
            print_num_aceites(get_num_aceites_mes(mejor_modelo))
            print_sol(mejor_modelo)
    else:
        print("Optimización con pesos...")
        print_num_aceites(get_num_aceites_mes(s.model()))
        print_sol(s.model())
