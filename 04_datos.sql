USE P02GuiasCupos;
GO
-- Muestra fija, completamente ficticia; referencia 2026-11-11.
-- Se insertan filas individuales para conservar IDs demostrativos y someter
-- todas las operaciones a los triggers de SQL Server.
SET XACT_ABORT ON;
SET NOCOUNT ON;
BEGIN TRAN;
DECLARE @i int=1,@j int,@op int,@guia int,@sector int,@dia int,@id int;
WHILE @i<=50
BEGIN
 INSERT p02.sector(nombre,descripcion)
 VALUES(CONCAT(N'Sector ficticio ',FORMAT(@i,'00')),N'Unidad de prueba académica, sin equivalencia oficial.');
 SET @i+=1;
END;
SET @i=1;
WHILE @i<=50
BEGIN
 INSERT p02.destino(sector_id,nombre) VALUES(@i,N'Ruta ficticia 1');
 INSERT p02.destino(sector_id,nombre) VALUES(@i,N'Ruta ficticia 2');
 SET @i+=1;
END;
SET @i=1;
WHILE @i<=50
BEGIN
 INSERT p02.operador(codigo,nombre,nit,email)
 VALUES(CONCAT('OP-',FORMAT(@i,'000')),CONCAT(N'Operador ficticio ',@i),
  CONCAT('DEMO-',FORMAT(@i,'0000')),CONCAT('operador',@i,'@example.invalid'));
 SET @i+=1;
END;
SET @i=1;
WHILE @i<=120
BEGIN
 INSERT p02.guia(codigo,nombre,documento)
 VALUES(CONCAT('GUI-',FORMAT(@i,'000')),CONCAT(N'Guía ficticio ',@i),
  CONCAT('DOC-DEMO-',FORMAT(@i,'0000')));
 SET @i+=1;
END;
SET @i=1;
WHILE @i<=120
BEGIN
 SET @op=CASE WHEN @i<=50 THEN @i WHEN @i<=100 THEN (@i-50)%50+1 ELSE @i-100 END;
 INSERT p02.guia_operador(guia_id,operador_id,fecha_vinculacion)
 VALUES(@i,@op,'2025-11-11');
 SET @i+=1;
END;
SET @i=1;
WHILE @i<=50
BEGIN
 INSERT p02.guia_operador(guia_id,operador_id,fecha_vinculacion)
 VALUES(@i,@i%50+1,'2025-11-11');
 SET @i+=1;
END;
SET @i=1;
WHILE @i<=120
BEGIN
 INSERT p02.certificacion(guia_id,tipo,entidad_emisora,fecha_emision,fecha_vencimiento)
 VALUES(@i,'GUIANZA',N'Entidad académica ficticia A','2025-11-11',
  CASE WHEN @i BETWEEN 101 AND 110 THEN '2026-11-01'
   WHEN @i BETWEEN 111 AND 120 THEN '2026-11-20' ELSE '2027-11-11' END);
 INSERT p02.certificacion(guia_id,tipo,entidad_emisora,fecha_emision,fecha_vencimiento)
 VALUES(@i,'PRIMEROS_AUXILIOS',N'Entidad académica ficticia B','2025-11-11','2027-11-11');
 SET @i+=1;
END;
SET @dia=0;
WHILE @dia<=1
BEGIN
 SET @i=1;
 WHILE @i<=50
 BEGIN
  INSERT p02.disponibilidad_diaria(sector_id,fecha,capacidad)
  VALUES(@i,DATEADD(day,@dia,CONVERT(date,'2026-11-15')),100);
  SET @i+=1;
 END;
 SET @dia+=1;
END;
SET @i=1;
WHILE @i<=50
BEGIN
 INSERT p02.limite_operador(operador_id,sector_id,vigente_desde,vigente_hasta,porcentaje_maximo)
 VALUES(@i,@i,'2026-10-12','2027-11-11',60);
 INSERT p02.limite_operador(operador_id,sector_id,vigente_desde,vigente_hasta,porcentaje_maximo)
 VALUES(@i%50+1,@i,'2026-10-12','2027-11-11',40);
 SET @i+=1;
END;
SET @i=1;
WHILE @i<=100
BEGIN
 SET @sector=(@i-1)%50+1;
 INSERT p02.reserva(codigo,operador_id,disponibilidad_id,turno,visitantes_autorizados)
 VALUES(CONCAT('RES-',FORMAT(2*@i-1,'0000')),@sector,@i,'MANANA',40);
 INSERT p02.reserva(codigo,operador_id,disponibilidad_id,turno,visitantes_autorizados)
 VALUES(CONCAT('RES-',FORMAT(2*@i,'0000')),@sector%50+1,@i,'TARDE',20);
 SET @i+=1;
END;
SET @i=1;
WHILE @i<=200
BEGIN
 SET @sector=((@i-1)/2)%50+1;
 SET @guia=@sector+CASE WHEN @i%2=1 THEN 0 ELSE 50 END;
 INSERT p02.grupo(codigo,reserva_id,guia_id,destino_id)
 VALUES(CONCAT('GRP-',FORMAT(@i,'0000')),@i,@guia,2*@sector-1);
 SET @i+=1;
END;
UPDATE p02.grupo SET destino_id=destino_id+1 WHERE grupo_id BETWEEN 101 AND 150;
SET @i=1;
WHILE @i<=200
BEGIN
 SET @dia=CASE WHEN @i<=100 THEN 15 ELSE 16 END;
 INSERT p02.acceso(grupo_id,fecha_hora,visitantes_ingresados)
 VALUES(@i,TODATETIMEOFFSET(DATETIMEFROMPARTS(2026,11,@dia,8,0,0,0),-300),
  CASE WHEN @i%3=0 THEN CASE WHEN @i%2=1 THEN 42 ELSE 22 END
    ELSE CASE WHEN @i%2=1 THEN 39 ELSE 19 END END);
 SET @i+=1;
END;
COMMIT TRAN;
SET NOCOUNT OFF;
GO
