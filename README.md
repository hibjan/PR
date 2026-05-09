# Programación con Restricciones

Prácticas de la asignatura **Programación con Restricciones** (Ingeniería Informática).

Cada laboratorio incluye su enunciado, la memoria con el desarrollo y los casos de prueba utilizados.

## Contenido

- **lab1/** — _Planificación de turnos en una fábrica que no para la producción_: asignar trabajadores a los tres turnos diarios durante D días respetando restricciones laborales (máximos de días consecutivos trabajados/libres, descansos tras turnos de noche, afinidades entre trabajadores, presencia de encargados, etc.). Modelado en MiniZinc en versiones de satisfacción (`satisfaccion.mzn`) y optimización (`optimizacion.mzn`), con sus casos de prueba (`.dzn`).
- **lab2/** — _Producción de alimentos_: planificar durante seis meses las compras, el almacenamiento y el refinado de cinco aceites (vegetales y no vegetales) para fabricar un producto que cumpla restricciones de capacidad, dureza y stock final, maximizando el beneficio. Resuelto con dos tecnologías: MiniZinc (`mzn_sol/`) y SMT con Z3 en Python (`z3_sol/`), con una versión base y dos extensiones.
