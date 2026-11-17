:ON ERROR EXIT
USE P02GuiasCupos;
GO
-- SQL Server: SHOWPLAN_TEXT es el equivalente de EXPLAIN; STATISTICS IO/TIME
-- mide la ejecución. La transacción revierte los 60.000 datos sintéticos y
-- la modificación temporal del índice al finalizar.
BEGIN TRAN;
;WITH numeros AS (
 SELECT TOP (60000) ROW_NUMBER() OVER(ORDER BY a.object_id,b.object_id) AS n
 FROM sys.all_objects a CROSS JOIN sys.all_objects b
)
INSERT p02.incidencia(grupo_id,fecha_hora,tipo,descripcion,origen)
SELECT 1+(n%200),DATEADD(minute,CONVERT(int,n),TODATETIMEOFFSET(CONVERT(datetime2,'2026-11-11T10:00:00'),-300)),
 'OTRA',N'Incidencia sintética para medir el índice.','MANUAL' FROM numeros;
UPDATE STATISTICS p02.incidencia WITH FULLSCAN;
DROP INDEX ix_incidencia_grupo_fecha ON p02.incidencia;
PRINT 'SIN INDICE - PLAN ESTIMADO';
GO
SET SHOWPLAN_TEXT ON;
GO
SELECT TOP (20) incidencia_id,fecha_hora,tipo FROM p02.incidencia
 WHERE grupo_id=1 ORDER BY fecha_hora DESC;
GO
SET SHOWPLAN_TEXT OFF;
GO
PRINT 'SIN INDICE - EJECUCION REAL';
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
SELECT TOP (20) incidencia_id,fecha_hora,tipo FROM p02.incidencia
 WHERE grupo_id=1 ORDER BY fecha_hora DESC;
SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
CREATE INDEX ix_incidencia_grupo_fecha ON p02.incidencia(grupo_id,fecha_hora DESC);
UPDATE STATISTICS p02.incidencia WITH FULLSCAN;
PRINT 'CON INDICE - PLAN ESTIMADO';
GO
SET SHOWPLAN_TEXT ON;
GO
SELECT TOP (20) incidencia_id,fecha_hora,tipo FROM p02.incidencia
 WHERE grupo_id=1 ORDER BY fecha_hora DESC;
GO
SET SHOWPLAN_TEXT OFF;
GO
PRINT 'CON INDICE - EJECUCION REAL';
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
SELECT TOP (20) incidencia_id,fecha_hora,tipo FROM p02.incidencia
 WHERE grupo_id=1 ORDER BY fecha_hora DESC;
SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
ROLLBACK TRAN;
GO
