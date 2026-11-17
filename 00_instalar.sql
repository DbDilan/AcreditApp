:ON ERROR EXIT
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
IF DB_ID(N'P02GuiasCupos') IS NULL CREATE DATABASE P02GuiasCupos;
GO
ALTER DATABASE P02GuiasCupos SET READ_COMMITTED_SNAPSHOT OFF;
ALTER DATABASE P02GuiasCupos SET ALLOW_SNAPSHOT_ISOLATION OFF;
GO
USE P02GuiasCupos;
GO
IF SCHEMA_ID(N'p02') IS NOT NULL THROW 51000, 'El esquema p02 ya existe. Use una base vacía.', 1;
GO
:r /proyecto/sql/01_estructura.sql
:r /proyecto/sql/02_reglas.sql
:r /proyecto/sql/03_programabilidad.sql
:r /proyecto/sql/04_datos.sql
:r /proyecto/sql/05_consultas.sql
PRINT 'Instalación SQL Server terminada.';
GO
