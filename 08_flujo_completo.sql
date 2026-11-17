:ON ERROR EXIT
USE P02GuiasCupos;
GO
-- Demostración opcional persistente; ejecutar una sola vez en base de práctica.
INSERT p02.disponibilidad_diaria(sector_id,fecha,capacidad)
VALUES(1,'2026-12-01',100);
DECLARE @disp int=(SELECT disponibilidad_id FROM p02.disponibilidad_diaria
 WHERE sector_id=1 AND fecha='2026-12-01');
DECLARE @res bigint,@grupo bigint;
EXEC p02.sp_crear_reserva 'FLUJO-RES',1,@disp,'MANANA',20,@res OUTPUT;
EXEC p02.sp_asignar_grupo 'FLUJO-GRUPO',@res,1,1,@grupo OUTPUT;
EXEC p02.sp_cambiar_destino @grupo,2;
EXEC p02.sp_registrar_acceso @grupo,22,'2026-12-01 08:00:00 -05:00';
SELECT * FROM p02.v_grupos_con_exceso WHERE grupo_id=@grupo;
SELECT * FROM p02.v_historial_incidencias WHERE grupo='FLUJO-GRUPO'
 ORDER BY incidencia_id;
GO
