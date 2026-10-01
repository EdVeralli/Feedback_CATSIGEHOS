-- =====================================================================
-- Feedback CATSIGEHOS - Queries de exploración (Athena)
-- Orden en que se corrieron para llegar a la lógica del script.
-- Base: "caba-piba-consume-zone-db" | Workgroup: Production-caba-piba-athena-boti-group
-- Rol: PIBADataScientist
--
-- OJO: en boti_user_vars_metrics_2 las particiones year/month son VARCHAR
--      (year = '2026', month = '8'; con enteros da TYPE_MISMATCH).
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1) ¿En qué variable aparece SIGEHOS?
--    Resultado (ago-2026): ultimotemanps (159.300 ses.), ultimotema (22.164),
--    acumulativotemas, caerror, feedbacksugerencia, etc.
-- ---------------------------------------------------------------------
SELECT vars_name, count(distinct session_id) AS sesiones
FROM "caba-piba-consume-zone-db"."boti_user_vars_metrics_2"
WHERE year = '2026' AND month = '8'
  AND upper(vars_value) LIKE '%SIGEHOS%'
GROUP BY vars_name;


-- ---------------------------------------------------------------------
-- 2) Valores exactos de las variables de tema
--    ultimotemanps = 'CATSIGEHOS'                       <- la que se usa
--    ultimotema    = 'Derivación a agente de SIGEHOS'   (derivación a humano)
-- ---------------------------------------------------------------------
SELECT vars_name, vars_value, count(distinct session_id) AS sesiones
FROM "caba-piba-consume-zone-db"."boti_user_vars_metrics_2"
WHERE year = '2026' AND month = '8'
  AND vars_name IN ('ultimotema', 'ultimotemanps')
  AND upper(vars_value) LIKE '%SIGEHOS%'
GROUP BY 1, 2
ORDER BY 3 DESC;


-- ---------------------------------------------------------------------
-- 3) Variables de feedback / hospital presentes en sesiones CATSIGEHOS
--    Aparecen: ultimofeedback, especialidadturno, hospital, feedbackflujo,
--    feedbacknps, feedbackcomentario, feedbacksugerencia, ...
-- ---------------------------------------------------------------------
WITH ses AS (
  SELECT DISTINCT session_id
  FROM "caba-piba-consume-zone-db"."boti_user_vars_metrics_2"
  WHERE year = '2026' AND month = '8'
    AND vars_name = 'ultimotemanps' AND vars_value = 'CATSIGEHOS'
)
SELECT v.vars_name, count(distinct v.session_id) AS sesiones
FROM "caba-piba-consume-zone-db"."boti_user_vars_metrics_2" v
JOIN ses ON ses.session_id = v.session_id
WHERE v.year = '2026' AND v.month = '8'
  AND (lower(v.vars_name) LIKE '%feedback%' OR lower(v.vars_name) LIKE '%nps%'
       OR lower(v.vars_name) LIKE '%calific%' OR lower(v.vars_name) LIKE '%encuesta%'
       OR lower(v.vars_name) LIKE '%satisf%' OR lower(v.vars_name) LIKE '%cedetac%'
       OR lower(v.vars_name) LIKE '%efector%' OR lower(v.vars_name) LIKE '%hospital%'
       OR lower(v.vars_name) LIKE '%especialidad%')
GROUP BY 1
ORDER BY 2 DESC;


-- ---------------------------------------------------------------------
-- 4) Cómo figura CEDETAC en la variable "hospital"
--    'Cedetac' (21), 'CEDETAC' (18), 'Cedetac ministerio de salud gcaba' (2)
-- ---------------------------------------------------------------------
SELECT vars_value, count(distinct session_id) AS sesiones
FROM "caba-piba-consume-zone-db"."boti_user_vars_metrics_2"
WHERE year = '2026' AND month = '8'
  AND vars_name = 'hospital'
  AND (upper(vars_value) LIKE '%CEDETAC%' OR upper(vars_value) LIKE '%DETECC%')
GROUP BY 1
ORDER BY 2 DESC;


-- ---------------------------------------------------------------------
-- 5) Feedback de sesiones CEDETAC (jun-sep 2026), una fila por sesión
--    Resultado: 16 usuarios distintos, 0 respuestas de NPS / comentario /
--    sugerencia en el período. Las variables persisten por USUARIO
--    (se repiten en cada sesión posterior), no por sesión.
-- ---------------------------------------------------------------------
WITH ced AS (
  SELECT DISTINCT session_id, month
  FROM "caba-piba-consume-zone-db"."boti_user_vars_metrics_2"
  WHERE year = '2026' AND month IN ('6','7','8','9')
    AND vars_name = 'hospital'
    AND upper(vars_value) LIKE '%CEDETAC%'
)
SELECT c.month,
       c.session_id,
       CONCAT('https://go.botmaker.com/#/chats/', SUBSTR(c.session_id, 1, 20)) AS link,
       max(CASE WHEN v.vars_name = 'ultimotemanps'      THEN v.vars_value END) AS ultimotemanps,
       max(CASE WHEN v.vars_name = 'feedbacknps'        THEN v.vars_value END) AS nps,
       max(CASE WHEN v.vars_name = 'feedbackflujo'      THEN v.vars_value END) AS flujo,
       max(CASE WHEN v.vars_name = 'ultimofeedback'     THEN v.vars_value END) AS ultimofeedback,
       max(CASE WHEN v.vars_name = 'feedbackcomentario' THEN v.vars_value END) AS comentario,
       max(CASE WHEN v.vars_name = 'feedbacksugerencia' THEN v.vars_value END) AS sugerencia
FROM ced c
JOIN "caba-piba-consume-zone-db"."boti_user_vars_metrics_2" v
  ON v.session_id = c.session_id
WHERE v.year = '2026' AND v.month IN ('6','7','8','9')
GROUP BY 1, 2, 3
ORDER BY 1, 2;


-- ---------------------------------------------------------------------
-- 6) Reglas de la encuesta (CXF) en sesiones CATSIGEHOS  <- base del script
--    P1 = inicio encuesta, P2 = efectividad (Sí/No), P3 = satisfacción,
--    P4 = esfuerzo. Los totales de P2/P3/P4 coinciden con la suma de
--    sus respuestas.
-- ---------------------------------------------------------------------
WITH ses AS (
  SELECT DISTINCT session_id
  FROM "caba-piba-consume-zone-db"."boti_user_vars_metrics_2"
  WHERE year = '2026' AND month = '8'
    AND vars_name = 'ultimotemanps' AND vars_value = 'CATSIGEHOS'
)
SELECT m.rule_name,
       count(distinct m.session_id)              AS sesiones,
       count(distinct SUBSTR(m.session_id,1,20)) AS usuarios
FROM "caba-piba-consume-zone-db"."boti_message_metrics_2" m
JOIN ses ON ses.session_id = m.session_id
WHERE CAST(m.session_creation_time AS DATE) BETWEEN date '2026-08-01' AND date '2026-08-31'
  AND m.rule_name LIKE '%CXF%'
GROUP BY 1
ORDER BY 1;
