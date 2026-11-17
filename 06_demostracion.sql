:ON ERROR EXIT
USE P02GuiasCupos;
GO
PRINT '1. Certificaciones vencidas o próximas a vencer, referencia fija: 20.';
SELECT codigo,tipo,fecha_vencimiento,estado
FROM p02.fn_certificaciones_en_riesgo('2026-11-11',30) ORDER BY codigo,tipo;
PRINT '2. Grupos con exceso: 66 grupos y 132 visitantes excedentes.';
SELECT COUNT(*) AS grupos,SUM(exceso) AS exceso_total FROM p02.v_grupos_con_exceso;
SELECT TOP (6) * FROM p02.v_grupos_con_exceso ORDER BY grupo_id;
PRINT '3. Sector 1: operadores 1 y 2, ambos días.';
SELECT sector,fecha,operador,capacidad,porcentaje_maximo,cupos_reservados,
 porcentaje_utilizado,saldo_operador FROM p02.v_uso_cupos_diario
 WHERE sector_id=1 ORDER BY fecha,operador;
PRINT '4. Historial por guía u operador.';
SELECT * FROM p02.v_historial_incidencias WHERE operador='OP-001'
 ORDER BY fecha_hora,incidencia_id;
PRINT '5. Tendencia por fecha local de ocurrencia y tipo.';
SELECT * FROM p02.v_tendencia_incidencias ORDER BY fecha_evento,tipo;
PRINT '6. Función de habilitación: vigente, vencido, próximo.';
SELECT v.guia_id,p02.fn_guia_habilitado(v.guia_id,'2026-11-15') AS habilitado
FROM (VALUES(1),(101),(111)) v(guia_id);
GO
