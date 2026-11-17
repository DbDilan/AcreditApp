USE P02GuiasCupos;
GO
CREATE OR ALTER PROCEDURE p02.sp_bloqueo @recurso nvarchar(30)
AS
BEGIN
 SET NOCOUNT ON;
 DECLARE @resultado int;
 EXEC @resultado = sys.sp_getapplock @Resource=@recurso,@LockMode='Exclusive',
   @LockOwner='Transaction',@LockTimeout=15000,@DbPrincipal='public';
 IF @resultado<0 THROW 51001,'No se obtuvo el bloqueo transaccional; reintente la operación completa.',1;
END;
GO
CREATE OR ALTER FUNCTION p02.fn_guia_habilitado(@guia_id int,@fecha date)
RETURNS bit
AS
BEGIN
 DECLARE @resultado bit=0;
 IF EXISTS(SELECT 1 FROM p02.guia WHERE guia_id=@guia_id AND activo=1)
  AND EXISTS(SELECT 1 FROM p02.certificacion WHERE guia_id=@guia_id AND fecha_emision<=@fecha)
  AND NOT EXISTS(
   SELECT 1 FROM (
    SELECT fecha_vencimiento,ROW_NUMBER() OVER(PARTITION BY tipo
      ORDER BY fecha_emision DESC,certificacion_id DESC) AS rn
    FROM p02.certificacion WHERE guia_id=@guia_id AND fecha_emision<=@fecha
   ) AS c WHERE rn=1 AND fecha_vencimiento<@fecha
  ) SET @resultado=1;
 RETURN @resultado;
END;
GO
CREATE OR ALTER FUNCTION p02.fn_certificaciones_en_riesgo(@fecha date,@dias int)
RETURNS TABLE
AS
RETURN
 WITH ultimas AS (
  SELECT c.*,ROW_NUMBER() OVER(PARTITION BY c.guia_id,c.tipo
    ORDER BY c.fecha_emision DESC,c.certificacion_id DESC) AS rn
  FROM p02.certificacion c WHERE c.fecha_emision<=@fecha
 )
 SELECT g.guia_id,g.codigo,g.nombre,c.tipo,c.entidad_emisora,c.fecha_vencimiento,
  DATEDIFF(day,@fecha,c.fecha_vencimiento) AS dias_restantes,
  CASE WHEN c.fecha_vencimiento<@fecha THEN 'VENCIDA' ELSE 'PROXIMA_A_VENCER' END AS estado
 FROM ultimas c JOIN p02.guia g ON g.guia_id=c.guia_id
 WHERE c.rn=1 AND @dias>=0 AND c.fecha_vencimiento<=DATEADD(day,@dias,@fecha);
GO
-- SQL Server no dispone de triggers BEFORE de tabla. AFTER valida dentro de
-- la misma transacción: THROW revierte también la fila que disparó el trigger.
CREATE OR ALTER TRIGGER p02.tg_limite ON p02.limite_operador
AFTER INSERT,UPDATE,DELETE AS
BEGIN
 SET NOCOUNT ON;
 EXEC p02.sp_bloqueo N'P02_CUPO';
 IF EXISTS(SELECT 1 FROM deleted d LEFT JOIN inserted i ON i.limite_id=d.limite_id
  WHERE (i.limite_id IS NULL OR i.operador_id<>d.operador_id OR i.sector_id<>d.sector_id)
    AND EXISTS(SELECT 1 FROM p02.reserva r JOIN p02.disponibilidad_diaria v
      ON v.disponibilidad_id=r.disponibilidad_id WHERE r.operador_id=d.operador_id
      AND v.sector_id=d.sector_id AND v.fecha BETWEEN d.vigente_desde AND d.vigente_hasta))
  THROW 51002,'Un parámetro usado conserva su identidad e historial.',1;
 IF EXISTS(SELECT 1 FROM deleted d JOIN inserted i ON i.limite_id=d.limite_id
   WHERE EXISTS(SELECT 1 FROM p02.reserva r JOIN p02.disponibilidad_diaria v
    ON v.disponibilidad_id=r.disponibilidad_id WHERE r.operador_id=d.operador_id
     AND v.sector_id=d.sector_id AND v.fecha BETWEEN d.vigente_desde AND d.vigente_hasta)
   AND (i.vigente_desde<>d.vigente_desde OR i.vigente_hasta<>d.vigente_hasta
    OR i.porcentaje_maximo<>d.porcentaje_maximo OR i.registrado_en<>d.registrado_en))
  THROW 51002,'Un porcentaje usado no se modifica; registre una nueva vigencia futura.',1;
 IF EXISTS(SELECT 1 FROM p02.limite_operador a JOIN p02.limite_operador b
   ON a.operador_id=b.operador_id AND a.sector_id=b.sector_id AND a.limite_id<b.limite_id
   AND a.vigente_desde<=b.vigente_hasta AND b.vigente_desde<=a.vigente_hasta)
  THROW 51003,'Las vigencias de un operador y sector no pueden superponerse.',1;
END;
GO
CREATE OR ALTER TRIGGER p02.tg_disponibilidad ON p02.disponibilidad_diaria
AFTER UPDATE AS
BEGIN
 SET NOCOUNT ON;
 EXEC p02.sp_bloqueo N'P02_CUPO';
 IF EXISTS(SELECT 1 FROM inserted i JOIN deleted d ON d.disponibilidad_id=i.disponibilidad_id
  WHERE (i.sector_id<>d.sector_id OR i.fecha<>d.fecha OR i.capacidad<>d.capacidad)
   AND EXISTS(SELECT 1 FROM p02.reserva r WHERE r.disponibilidad_id=i.disponibilidad_id))
  THROW 51004,'La fecha, el sector y la capacidad se fijan antes de la primera compra.',1;
END;
GO
CREATE OR ALTER TRIGGER p02.tg_reserva ON p02.reserva
AFTER INSERT,UPDATE,DELETE AS
BEGIN
 SET NOCOUNT ON;
 EXEC p02.sp_bloqueo N'P02_CUPO';
 IF EXISTS(SELECT 1 FROM deleted d LEFT JOIN inserted i ON i.reserva_id=d.reserva_id
   WHERE i.reserva_id IS NULL)
  THROW 51005,'Una reserva histórica se cancela; no se elimina.',1;
 IF EXISTS(SELECT 1 FROM inserted i JOIN deleted d ON d.reserva_id=i.reserva_id
  WHERE i.codigo<>d.codigo OR i.operador_id<>d.operador_id OR i.disponibilidad_id<>d.disponibilidad_id
    OR i.turno<>d.turno OR i.visitantes_autorizados<>d.visitantes_autorizados
    OR i.creada_en<>d.creada_en OR d.estado='CANCELADA' AND i.estado<>'CANCELADA')
  THROW 51005,'La compra es inmutable; una reserva cancelada no se reactiva.',1;
 IF EXISTS(SELECT 1 FROM inserted i LEFT JOIN deleted d ON d.reserva_id=i.reserva_id
    WHERE d.reserva_id IS NULL AND i.estado<>'CONFIRMADA')
  THROW 51005,'Toda nueva reserva debe estar confirmada.',1;
 IF EXISTS(SELECT 1 FROM inserted i JOIN deleted d ON d.reserva_id=i.reserva_id
   WHERE d.estado='CONFIRMADA' AND i.estado='CANCELADA'
    AND EXISTS(SELECT 1 FROM p02.grupo g JOIN p02.acceso a ON a.grupo_id=g.grupo_id
     WHERE g.reserva_id=i.reserva_id))
  THROW 51005,'No se cancela una reserva con acceso registrado.',1;
 IF EXISTS(SELECT 1 FROM inserted i JOIN p02.disponibilidad_diaria v
   ON v.disponibilidad_id=i.disponibilidad_id
   OUTER APPLY(SELECT TOP (1) l.porcentaje_maximo FROM p02.limite_operador l
    WHERE l.operador_id=i.operador_id AND l.sector_id=v.sector_id
     AND v.fecha BETWEEN l.vigente_desde AND l.vigente_hasta) AS lim
   WHERE i.estado='CONFIRMADA' AND lim.porcentaje_maximo IS NULL)
  THROW 51006,'Falta porcentaje autorizado para el operador, sector y fecha.',1;
 IF EXISTS(
  SELECT 1 FROM p02.reserva r JOIN p02.disponibilidad_diaria v
   ON v.disponibilidad_id=r.disponibilidad_id
   JOIN p02.limite_operador l ON l.operador_id=r.operador_id AND l.sector_id=v.sector_id
    AND v.fecha BETWEEN l.vigente_desde AND l.vigente_hasta
   WHERE r.estado='CONFIRMADA' AND r.disponibilidad_id IN
    (SELECT disponibilidad_id FROM inserted UNION SELECT disponibilidad_id FROM deleted)
   GROUP BY r.disponibilidad_id,r.operador_id,v.capacidad,l.porcentaje_maximo
   HAVING SUM(CONVERT(bigint,r.visitantes_autorizados))>
      FLOOR(CONVERT(decimal(18,2),v.capacidad)*l.porcentaje_maximo/100)
 ) THROW 51007,'El operador supera su porcentaje de cupos autorizado.',1;
 IF EXISTS(
  SELECT 1 FROM p02.reserva r JOIN p02.disponibilidad_diaria v
   ON v.disponibilidad_id=r.disponibilidad_id
   WHERE r.estado='CONFIRMADA' AND r.disponibilidad_id IN
    (SELECT disponibilidad_id FROM inserted UNION SELECT disponibilidad_id FROM deleted)
   GROUP BY r.disponibilidad_id,v.capacidad
   HAVING SUM(CONVERT(bigint,r.visitantes_autorizados))>v.capacidad
 ) THROW 51008,'La reserva supera la capacidad diaria del sector.',1;
END;
GO
CREATE OR ALTER TRIGGER p02.tg_certificacion ON p02.certificacion
AFTER INSERT,UPDATE,DELETE AS
BEGIN
 SET NOCOUNT ON;
 EXEC p02.sp_bloqueo N'P02_GUIA';
 IF EXISTS(SELECT 1 FROM deleted)
  THROW 51009,'Las certificaciones son históricas; una renovación se inserta.',1;
END;
GO
CREATE OR ALTER TRIGGER p02.tg_vinculo ON p02.guia_operador
AFTER INSERT,UPDATE,DELETE AS
BEGIN
 SET NOCOUNT ON;
 EXEC p02.sp_bloqueo N'P02_GUIA';
 IF EXISTS(SELECT 1 FROM deleted)
  THROW 51010,'Los vínculos históricos no se modifican en este alcance.',1;
END;
GO
CREATE OR ALTER TRIGGER p02.tg_guia ON p02.guia
AFTER UPDATE AS
BEGIN
 SET NOCOUNT ON;
 EXEC p02.sp_bloqueo N'P02_GUIA';
END;
GO
CREATE OR ALTER TRIGGER p02.tg_grupo ON p02.grupo
AFTER INSERT,UPDATE,DELETE AS
BEGIN
 SET NOCOUNT ON;
 EXEC p02.sp_bloqueo N'P02_GUIA';
 IF EXISTS(SELECT 1 FROM deleted d LEFT JOIN inserted i ON i.grupo_id=d.grupo_id
   WHERE i.grupo_id IS NULL)
  THROW 51011,'No se elimina un grupo histórico.',1;
 IF EXISTS(SELECT 1 FROM inserted i JOIN deleted d ON d.grupo_id=i.grupo_id
  WHERE i.codigo<>d.codigo OR i.reserva_id<>d.reserva_id OR i.guia_id<>d.guia_id
    OR i.creado_en<>d.creado_en)
  THROW 51011,'Solo se permite cambiar el destino antes del acceso.',1;
 IF EXISTS(SELECT 1 FROM inserted i JOIN deleted d ON d.grupo_id=i.grupo_id
   WHERE i.destino_id<>d.destino_id
    AND EXISTS(SELECT 1 FROM p02.acceso a WHERE a.grupo_id=i.grupo_id))
  THROW 51011,'No se cambia el destino después del acceso.',1;
 IF EXISTS(SELECT 1 FROM inserted i JOIN p02.reserva r ON r.reserva_id=i.reserva_id
    JOIN p02.disponibilidad_diaria v ON v.disponibilidad_id=r.disponibilidad_id
    JOIN p02.destino des ON des.destino_id=i.destino_id
    WHERE r.estado<>'CONFIRMADA' OR des.sector_id<>v.sector_id
      OR p02.fn_guia_habilitado(i.guia_id,v.fecha)=0
      OR NOT EXISTS(SELECT 1 FROM p02.guia_operador go2
       WHERE go2.guia_id=i.guia_id AND go2.operador_id=r.operador_id))
  THROW 51012,'Grupo inválido: reserva, sector, vínculo o certificación del guía.',1;
 IF EXISTS(SELECT 1 FROM inserted i JOIN p02.reserva r ON r.reserva_id=i.reserva_id
   JOIN p02.disponibilidad_diaria v ON v.disponibilidad_id=r.disponibilidad_id
   JOIN p02.grupo otro ON otro.guia_id=i.guia_id AND otro.grupo_id<>i.grupo_id
   JOIN p02.reserva r2 ON r2.reserva_id=otro.reserva_id AND r2.estado='CONFIRMADA'
   JOIN p02.disponibilidad_diaria v2 ON v2.disponibilidad_id=r2.disponibilidad_id
      AND v2.fecha=v.fecha
   WHERE otro.destino_id<>i.destino_id)
  THROW 51013,'El guía ya tiene otro destino el mismo día, incluso en otro turno.',1;
 INSERT INTO p02.incidencia(grupo_id,tipo,descripcion,origen)
 SELECT i.grupo_id,'CAMBIO_DESTINO',
  CONCAT(N'Destino cambiado de ',d.destino_id,N' a ',i.destino_id,N' antes del acceso.'),'AUTOMATICO'
 FROM inserted i JOIN deleted d ON d.grupo_id=i.grupo_id
 WHERE i.destino_id<>d.destino_id;
END;
GO
CREATE OR ALTER TRIGGER p02.tg_acceso ON p02.acceso
AFTER INSERT,UPDATE,DELETE AS
BEGIN
 SET NOCOUNT ON;
 IF EXISTS(SELECT 1 FROM deleted)
  THROW 51014,'El conteo final de acceso es histórico e inmutable.',1;
 IF EXISTS(SELECT 1 FROM inserted i JOIN p02.grupo g ON g.grupo_id=i.grupo_id
    JOIN p02.reserva r ON r.reserva_id=g.reserva_id
    JOIN p02.disponibilidad_diaria v ON v.disponibilidad_id=r.disponibilidad_id
   WHERE r.estado<>'CONFIRMADA'
    OR CONVERT(date,SWITCHOFFSET(i.fecha_hora,'-05:00'))<>v.fecha)
  THROW 51014,'Acceso inválido: reserva cancelada o fecha local distinta de la visita.',1;
 INSERT INTO p02.incidencia(grupo_id,fecha_hora,tipo,descripcion,origen)
 SELECT i.grupo_id,i.fecha_hora,'EXCESO_PERSONAS',
  CONCAT(N'Autorizados: ',r.visitantes_autorizados,N'; ingresados: ',i.visitantes_ingresados,
   N'; exceso: ',i.visitantes_ingresados-r.visitantes_autorizados,N'.'),'AUTOMATICO'
 FROM inserted i JOIN p02.grupo g ON g.grupo_id=i.grupo_id
 JOIN p02.reserva r ON r.reserva_id=g.reserva_id
 WHERE i.visitantes_ingresados>r.visitantes_autorizados;
END;
GO
CREATE OR ALTER TRIGGER p02.tg_incidencia ON p02.incidencia
AFTER UPDATE,DELETE AS
BEGIN
 SET NOCOUNT ON;
 IF EXISTS(SELECT 1 FROM deleted)
  THROW 51015,'Una incidencia es evidencia histórica y no se modifica ni elimina.',1;
END;
GO
