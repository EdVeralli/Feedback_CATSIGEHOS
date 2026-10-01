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

**Gobierno de la Ciudad de Buenos Aires — Data Analytics**
