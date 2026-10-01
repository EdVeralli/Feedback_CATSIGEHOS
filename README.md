# Feedback CATSIGEHOS

Pedido **excepcional** (no forma parte de las métricas mensuales de Boti).

## El pedido

> *Consulta BOTI CEDETAC* — "¿Se puede ver y cómo accedo a las estadísticas que
> los pacientes dan acerca del CEDETAC? Al finalizar una conversación Boti les
> hace una encuesta de satisfacción y sugerencias."

Se respondió con el **feedback de la encuesta de CATs** para las sesiones cuyo
último tema es `CATSIGEHOS` (turnos de salud vía SIGEHOS).

## Resultado (jul–sep 2026)

| Período | Total_Usuarios | TasaEfectividad | Esfuerzo | Satisfacción % |
|---|---:|---:|---:|---:|
| Últimos 3 meses | 12.977 | 76,37 % | 1,77 | 82,94 % |
| Julio | 3.630 | 77,63 % | 1,83 | 83,34 % |
| Agosto | 4.109 | 79,19 % | 1,69 | 85,53 % |
| Septiembre | 5.238 | 73,29 % | 1,78 | 80,57 % |

Coincide con la tabla de referencia (diferencias de ~0,1 pp). Septiembre de la
referencia es menor porque se calculó antes de que terminara el mes.

> **Alcance:** son **todos** los turnos de salud que pasan por SIGEHOS en Boti,
> no solo CEDETAC. Filtrando solo CEDETAC (variable `hospital`) hubo 16 usuarios
> en jun–sep y **ninguna** respuesta de encuesta.

## Cómo se llegó

Las consultas están en [`queries_exploracion.sql`](queries_exploracion.sql), en orden.

1. `boti_user_vars_metrics_2`: el valor `CATSIGEHOS` está en la variable
   **`ultimotemanps`** ("último tema para NPS"). `ultimotema` tiene otro valor
   (`Derivación a agente de SIGEHOS`).
2. `boti_message_metrics_2`: las respuestas de la encuesta son las reglas
   **`CXF01CUX04 … CATs`**. Se cruzan por `session_id` con las sesiones del paso 1.

### Reglas usadas

| Pregunta | Reglas |
|---|---|
| P2 – Efectividad | `Sí CATs`, `No CATs` |
| P3 – Satisfacción | `Muy conforme`, `Conforme`, `Inconforme`, `Muy inconforme`, `No sé` |
| P4 – Esfuerzo | `Muy fácil`, `Fácil`, `Ni fácil ni difícil`, `Difícil`, `Muy difícil` |

(todas con prefijo `CXF01CUX04` y sufijo `CATs`)

## Fórmulas

```
Total_Usuarios  = sesiones Sí + No
TasaEfectividad = Sí / (Sí + No)
Satisfacción %  = (Muy conforme + Conforme) /
                  (Muy conforme + Conforme + Inconforme + Muy inconforme + No sé)
Esfuerzo        = (1·Muy fácil + 2·Fácil + 4·Difícil + 5·Muy difícil) /
                  (Muy fácil + Fácil + Difícil + Muy difícil)
```

> **Esfuerzo excluye "Ni fácil ni difícil"** para replicar la tabla de
> referencia. Incluyéndola (peso 3), agosto da **1,86** en vez de 1,69.
> "No sé" cuenta como negativa en Satisfacción, igual que el CSAT mensual.

## Uso

```powershell
aws-azure-login --profile default --mode=gui    # rol PIBADataScientist
cd C:\GCBA\Feedback_CATSIGEHOS
python Feedback_CATSIGEHOS.py --anio 2026 --meses 7 8 9 --sin-sugerencias
```

| Parámetro | Descripción |
|---|---|
| `--anio` | Año (obligatorio) |
| `--meses` | Uno o más meses del mismo año |
| `--tema` | Valor de `ultimotemanps` (default `CATSIGEHOS`); sirve para otras CATs, ej. `CATSoporteMiBA` |
| `--sin-sugerencias` | No baja el texto libre |

Requisitos: `pip install boto3 awswrangler pandas openpyxl`

### Salida (`output/`, no versionada)

- `feedback_<tema>_<año>_<meses>.xlsx` — hojas *Resumen*, *Detalle reglas*, *Sugerencias*
- `feedback_<tema>_<año>_<meses>_reglas.csv`

## Advertencias

- **Nombres de reglas:** si Botmaker renombra una regla, el script imprime
  `[ADVERTENCIA] no se encontró la regla` y la cuenta como 0 → porcentajes mal.
- **Sugerencias infladas:** las variables (`feedbacksugerencia`,
  `feedbackcomentario`, `hospital`, …) persisten **por usuario** y se repiten en
  cada sesión posterior. La hoja *Sugerencias* trae duplicados (≈16 mil filas en
  jul–sep). Para usarla habría que filtrar por la sesión con la regla
  `CXF01CUX00 Cierre Con sugerencia` y deduplicar usuario + texto.
- **Particiones:** en `boti_user_vars_metrics_2`, `year`/`month` son VARCHAR.

---

## Guía para pedidos similares

Esta sección resume lo aprendido para resolver pedidos del tipo *"¿qué opinan
los usuarios de Boti sobre X?"* (otra CAT, otro organismo, otro centro).

### Receta rápida

1. **Ir directo a la pista que dan.** Si dicen "el último tema es X", buscar
   `X` en `ultimotemanps`. No reinterpretar el pedido antes de probar eso:
   acá se perdió tiempo filtrando por `hospital` (CEDETAC) cuando la pista
   era `CATSIGEHOS`.
2. **Ver qué valores de tema existen** (query 0 de abajo) y elegir el exacto.
3. **Correr el script con `--tema`**:
   `python Feedback_CATSIGEHOS.py --anio 2026 --meses 7 8 9 --tema <VALOR> --sin-sugerencias`
4. **Si hay tabla de referencia, pedirla al principio** y comparar mes a mes
   antes de entregar. Es lo que confirma la fórmula (ver Esfuerzo).
5. **Aclarar el alcance al entregar**: un tema de CAT puede abarcar mucho más
   que lo que pregunta el solicitante (CATSIGEHOS = todos los turnos de salud,
   no solo CEDETAC).

```sql
-- Query 0: valores de ultimotemanps disponibles en un mes
SELECT vars_value AS tema, count(distinct session_id) AS sesiones
FROM "caba-piba-consume-zone-db"."boti_user_vars_metrics_2"
WHERE year = '2026' AND month = '8'
  AND vars_name = 'ultimotemanps'
GROUP BY 1
ORDER BY 2 DESC;
```

### Cómo está armada la encuesta en Botmaker

| Regla | Qué es |
|---|---|
| `CXF01CUX00 Preapertura` | Inicio del flujo de feedback |
| `CXF01CUX00 Cierre Con sugerencia` / `Sin Sugerencia` | Si el usuario dejó texto libre |
| `CXF01CUX04 P1 CATs` | Arranque de la encuesta de CATs |
| `CXF01CUX04 P2 CATs` → `Sí` / `No` | Efectividad (¿resolvió?) |
| `CXF01CUX04 P3 CATs` → `Muy conforme` … `No sé` | Satisfacción |
| `CXF01CUX04 P4 CATs` → `Muy fácil` … `Muy difícil` | Esfuerzo |

- Los totales de P2, P3 y P4 coinciden exactamente con la suma de sus
  respuestas: sirven como control.
- `CXF01CUX01` = Integraciones, `CXF01CUX02` = Estáticos, `CXF01CUX03` = Pushes
  (las que usan los módulos mensuales de Feedback). Para CATs es `CXF01CUX04`.
- En CATs la opción neutra de esfuerzo se llama **"Ni fácil ni difícil"**; en
  Integraciones/Estáticos es "Más o menos". Un script que busque el nombre
  equivocado la cuenta como 0 sin fallar (probable origen del 1,69 de la
  referencia).

### Variables útiles (`boti_user_vars_metrics_2`)

| Variable | Contenido |
|---|---|
| `ultimotemanps` | Tema asociado a la encuesta (ej. `CATSIGEHOS`, `CATSoporteMiBA`, `CAT147`). **Es la clave para filtrar.** |
| `ultimotema` | Último tema en texto (ej. `Derivación a agente de SIGEHOS`) |
| `hospital`, `especialidadturno` | Datos del turno SIGEHOS. Texto inconsistente (`Cedetac`, `CEDETAC`, …): usar `upper(...) LIKE` |
| `feedbacksugerencia`, `feedbackcomentario` | Texto libre de la encuesta |
| `feedbacknps`, `feedbackflujo` | Otras variables de feedback (no usadas en el cálculo) |
| `ultimofeedback` | Timestamp en **milisegundos** de la última encuesta respondida |

### Trampas conocidas

- **Las variables son del usuario, no de la sesión.** Quedan cargadas y se
  repiten en todas las sesiones siguientes (`session_id` = `IDUSUARIO_fecha`).
  Contar filas de la tabla de variables infla todo. Las **métricas** se
  cuentan desde las reglas `CXF` de `boti_message_metrics_2`; las variables
  solo se usan para filtrar.
- **`ultimotemanps` cambia** a lo largo de las sesiones del mismo usuario
  (CATSIGEHOS → CATSoporteMiBA): vale el de la sesión donde respondió.
- **Filtrar por efector/centro da muy poco volumen.** CEDETAC: 16 usuarios en
  4 meses y 0 respuestas. Si el pedido es de un centro puntual, avisar antes
  de prometer un reporte.
- **Fecha de corte:** al comparar con otra tabla, confirmar hasta qué día se
  calculó (septiembre difería por eso).
- **Particiones VARCHAR:** `year = '2026' AND month = '8'` (sin cero adelante).

### El Manual de Métricas BOTI

Sirvió para ubicar la tabla de variables y el patrón de JOIN
mensajes↔variables, pero **no documenta** `ultimotemanps`, la encuesta
`CXF01CUX04` ni la persistencia de variables por usuario. La sección de
satisfacción (`calificaratencionwa`) es de la época BigQuery y no aplica acá.
Para estos pedidos, este README y los módulos `Feedback_*` de
`Metricas_Boti_Mensual` son mejor referencia.

---

**Gobierno de la Ciudad de Buenos Aires — Data Analytics**
