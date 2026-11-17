USE P02GuiasCupos;
GO
CREATE OR ALTER VIEW p02.v_certificaciones_en_riesgo AS
SELECT * FROM p02.fn_certificaciones_en_riesgo(CONVERT(date,GETDATE()),30);
GO
CREATE OR ALTER VIEW p02.v_grupos_con_exceso AS
SELECT g.grupo_id,g.codigo AS grupo,gu.codigo AS guia,o.codigo AS operador,
 s.nombre AS sector,v.fecha,r.turno,des.nombre AS destino,
 r.visitantes_autorizados,a.visitantes_ingresados,
 a.visitantes_ingresados-r.visitantes_autorizados AS exceso
FROM p02.grupo g JOIN p02.reserva r ON r.reserva_id=g.reserva_id
 JOIN p02.guia gu ON gu.guia_id=g.guia_id JOIN p02.operador o ON o.operador_id=r.operador_id
 JOIN p02.disponibilidad_diaria v ON v.disponibilidad_id=r.disponibilidad_id
 JOIN p02.sector s ON s.sector_id=v.sector_id JOIN p02.destino des ON des.destino_id=g.destino_id
 JOIN p02.acceso a ON a.grupo_id=g.grupo_id
WHERE a.visitantes_ingresados>r.visitantes_autorizados;
GO
CREATE OR ALTER VIEW p02.v_uso_cupos_diario AS
WITH uso AS (
 SELECT disponibilidad_id,operador_id,SUM(CONVERT(bigint,visitantes_autorizados)) AS cupos_reservados
 FROM p02.reserva WHERE estado='CONFIRMADA' GROUP BY disponibilidad_id,operador_id
)
SELECT v.disponibilidad_id,v.sector_id,s.nombre AS sector,v.fecha,o.operador_id,o.codigo AS operador,
 v.capacidad,l.porcentaje_maximo,
 CONVERT(int,FLOOR(CONVERT(decimal(18,2),v.capacidad)*l.porcentaje_maximo/100)) AS cupos_maximos,
 COALESCE(u.cupos_reservados,CONVERT(bigint,0)) AS cupos_reservados,
 CONVERT(decimal(7,2),100.0*COALESCE(u.cupos_reservados,0)/v.capacidad) AS porcentaje_utilizado,
 CONVERT(bigint,FLOOR(CONVERT(decimal(18,2),v.capacidad)*l.porcentaje_maximo/100))
  -COALESCE(u.cupos_reservados,0) AS saldo_operador
FROM p02.disponibilidad_diaria v JOIN p02.sector s ON s.sector_id=v.sector_id
 JOIN p02.limite_operador l ON l.sector_id=v.sector_id
  AND v.fecha BETWEEN l.vigente_desde AND l.vigente_hasta
 JOIN p02.operador o ON o.operador_id=l.operador_id
 LEFT JOIN uso u ON u.disponibilidad_id=v.disponibilidad_id AND u.operador_id=o.operador_id;
GO
CREATE OR ALTER VIEW p02.v_historial_incidencias AS
SELECT i.incidencia_id,i.fecha_hora,i.tipo,i.descripcion,i.origen,g.codigo AS grupo,
 gu.guia_id,gu.codigo AS guia,gu.nombre AS nombre_guia,
 o.operador_id,o.codigo AS operador,o.nombre AS nombre_operador,
 s.nombre AS sector,v.fecha AS fecha_visita
FROM p02.incidencia i JOIN p02.grupo g ON g.grupo_id=i.grupo_id
 JOIN p02.guia gu ON gu.guia_id=g.guia_id JOIN p02.reserva r ON r.reserva_id=g.reserva_id
 JOIN p02.operador o ON o.operador_id=r.operador_id
 JOIN p02.disponibilidad_diaria v ON v.disponibilidad_id=r.disponibilidad_id
 JOIN p02.sector s ON s.sector_id=v.sector_id;
GO
CREATE OR ALTER VIEW p02.v_tendencia_incidencias AS
SELECT CONVERT(date,SWITCHOFFSET(fecha_hora,'-05:00')) AS fecha_evento,tipo,
 COUNT_BIG(*) AS incidencias,COUNT(DISTINCT guia_id) AS guias,
 COUNT(DISTINCT operador_id) AS operadores
FROM p02.v_historial_incidencias
GROUP BY CONVERT(date,SWITCHOFFSET(fecha_hora,'-05:00')),tipo;
GO
