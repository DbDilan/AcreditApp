USE P02GuiasCupos;
GO
CREATE OR ALTER PROCEDURE p02.sp_crear_reserva
 @codigo varchar(30),@operador_id int,@disponibilidad_id int,
 @turno varchar(10),@visitantes_autorizados int,@reserva_id bigint OUTPUT
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 BEGIN TRY
  BEGIN TRAN;
  INSERT INTO p02.reserva(codigo,operador_id,disponibilidad_id,turno,visitantes_autorizados)
  VALUES(@codigo,@operador_id,@disponibilidad_id,@turno,@visitantes_autorizados);
  SET @reserva_id=CONVERT(bigint,SCOPE_IDENTITY());
  COMMIT TRAN;
 END TRY
 BEGIN CATCH
  IF XACT_STATE()<>0 ROLLBACK TRAN;
  THROW;
 END CATCH
END;
GO
CREATE OR ALTER PROCEDURE p02.sp_asignar_grupo
 @codigo varchar(30),@reserva_id bigint,@guia_id int,@destino_id int,@grupo_id bigint OUTPUT
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 BEGIN TRY
  BEGIN TRAN;
  INSERT INTO p02.grupo(codigo,reserva_id,guia_id,destino_id)
  VALUES(@codigo,@reserva_id,@guia_id,@destino_id);
  SET @grupo_id=CONVERT(bigint,SCOPE_IDENTITY());
  COMMIT TRAN;
 END TRY
 BEGIN CATCH
  IF XACT_STATE()<>0 ROLLBACK TRAN;
  THROW;
 END CATCH
END;
GO
CREATE OR ALTER PROCEDURE p02.sp_registrar_acceso
 @grupo_id bigint,@visitantes_ingresados int,@fecha_hora datetimeoffset(0)=NULL
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @fecha_hora IS NULL SET @fecha_hora=SYSDATETIMEOFFSET();
 BEGIN TRY
  BEGIN TRAN;
  INSERT INTO p02.acceso(grupo_id,fecha_hora,visitantes_ingresados)
  VALUES(@grupo_id,@fecha_hora,@visitantes_ingresados);
  COMMIT TRAN;
 END TRY
 BEGIN CATCH
  IF XACT_STATE()<>0 ROLLBACK TRAN;
  THROW;
 END CATCH
END;
GO
CREATE OR ALTER PROCEDURE p02.sp_cambiar_destino @grupo_id bigint,@destino_id int
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 BEGIN TRY
  BEGIN TRAN;
  UPDATE p02.grupo SET destino_id=@destino_id WHERE grupo_id=@grupo_id;
  IF @@ROWCOUNT=0 THROW 51016,'Grupo inexistente.',1;
  COMMIT TRAN;
 END TRY
 BEGIN CATCH
  IF XACT_STATE()<>0 ROLLBACK TRAN;
  THROW;
 END CATCH
END;
GO
CREATE OR ALTER PROCEDURE p02.sp_cancelar_reserva @reserva_id bigint
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 BEGIN TRY
  BEGIN TRAN;
  UPDATE p02.reserva SET estado='CANCELADA' WHERE reserva_id=@reserva_id;
  IF @@ROWCOUNT=0 THROW 51017,'Reserva inexistente.',1;
  COMMIT TRAN;
 END TRY
 BEGIN CATCH
  IF XACT_STATE()<>0 ROLLBACK TRAN;
  THROW;
 END CATCH
END;
GO
