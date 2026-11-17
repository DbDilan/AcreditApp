USE P02GuiasCupos;
GO
CREATE SCHEMA p02;
GO
CREATE TABLE p02.sector (
 sector_id int IDENTITY(1,1) NOT NULL CONSTRAINT pk_sector PRIMARY KEY,
 nombre nvarchar(100) NOT NULL CONSTRAINT uq_sector_nombre UNIQUE,
 descripcion nvarchar(300) NOT NULL CONSTRAINT df_sector_descripcion DEFAULT N''
);
CREATE TABLE p02.destino (
 destino_id int IDENTITY(1,1) NOT NULL CONSTRAINT pk_destino PRIMARY KEY,
 sector_id int NOT NULL CONSTRAINT fk_destino_sector REFERENCES p02.sector(sector_id) ON DELETE NO ACTION,
 nombre nvarchar(100) NOT NULL,
 CONSTRAINT uq_destino_sector_nombre UNIQUE(sector_id,nombre)
);
CREATE TABLE p02.operador (
 operador_id int IDENTITY(1,1) NOT NULL CONSTRAINT pk_operador PRIMARY KEY,
 codigo varchar(20) NOT NULL CONSTRAINT uq_operador_codigo UNIQUE,
 nombre nvarchar(120) NOT NULL,
 nit varchar(25) NOT NULL CONSTRAINT uq_operador_nit UNIQUE,
 email varchar(160) NOT NULL,
 CONSTRAINT ck_operador_email CHECK (CHARINDEX('@',email)>1)
);
CREATE TABLE p02.guia (
 guia_id int IDENTITY(1,1) NOT NULL CONSTRAINT pk_guia PRIMARY KEY,
 codigo varchar(20) NOT NULL CONSTRAINT uq_guia_codigo UNIQUE,
 nombre nvarchar(120) NOT NULL,
 documento varchar(25) NOT NULL CONSTRAINT uq_guia_documento UNIQUE,
 activo bit NOT NULL CONSTRAINT df_guia_activo DEFAULT 1
);
CREATE TABLE p02.guia_operador (
 guia_id int NOT NULL CONSTRAINT fk_vinculo_guia REFERENCES p02.guia(guia_id) ON DELETE NO ACTION,
 operador_id int NOT NULL CONSTRAINT fk_vinculo_operador REFERENCES p02.operador(operador_id) ON DELETE NO ACTION,
 fecha_vinculacion date NOT NULL CONSTRAINT df_vinculo_fecha DEFAULT CONVERT(date,GETDATE()),
 CONSTRAINT pk_guia_operador PRIMARY KEY(guia_id,operador_id)
);
CREATE TABLE p02.certificacion (
 certificacion_id bigint IDENTITY(1,1) NOT NULL CONSTRAINT pk_certificacion PRIMARY KEY,
 guia_id int NOT NULL CONSTRAINT fk_certificacion_guia REFERENCES p02.guia(guia_id) ON DELETE NO ACTION,
 tipo varchar(80) NOT NULL,
 entidad_emisora nvarchar(160) NOT NULL,
 fecha_emision date NOT NULL,
 fecha_vencimiento date NOT NULL,
 CONSTRAINT ck_certificacion_fechas CHECK(fecha_vencimiento>=fecha_emision),
 CONSTRAINT ck_certificacion_tipo CHECK(LEN(TRIM(tipo))>0 AND tipo=UPPER(TRIM(tipo))),
 CONSTRAINT ck_certificacion_entidad CHECK(LEN(TRIM(entidad_emisora))>0),
 CONSTRAINT uq_certificacion_version UNIQUE(guia_id,tipo,fecha_emision)
);
CREATE TABLE p02.disponibilidad_diaria (
 disponibilidad_id int IDENTITY(1,1) NOT NULL CONSTRAINT pk_disponibilidad PRIMARY KEY,
 sector_id int NOT NULL CONSTRAINT fk_disponibilidad_sector REFERENCES p02.sector(sector_id) ON DELETE NO ACTION,
 fecha date NOT NULL,
 capacidad int NOT NULL CONSTRAINT ck_disponibilidad_capacidad CHECK(capacidad>0),
 CONSTRAINT uq_disponibilidad_sector_fecha UNIQUE(sector_id,fecha)
);
CREATE TABLE p02.limite_operador (
 limite_id bigint IDENTITY(1,1) NOT NULL CONSTRAINT pk_limite PRIMARY KEY,
 operador_id int NOT NULL CONSTRAINT fk_limite_operador REFERENCES p02.operador(operador_id) ON DELETE NO ACTION,
 sector_id int NOT NULL CONSTRAINT fk_limite_sector REFERENCES p02.sector(sector_id) ON DELETE NO ACTION,
 vigente_desde date NOT NULL,
 vigente_hasta date NOT NULL,
 porcentaje_maximo decimal(5,2) NOT NULL,
 registrado_en datetimeoffset(0) NOT NULL CONSTRAINT df_limite_registro DEFAULT SYSDATETIMEOFFSET(),
 CONSTRAINT ck_limite_fechas CHECK(vigente_hasta>=vigente_desde),
 CONSTRAINT ck_limite_porcentaje CHECK(porcentaje_maximo>0 AND porcentaje_maximo<=100),
 CONSTRAINT uq_limite_inicio UNIQUE(operador_id,sector_id,vigente_desde)
);
CREATE TABLE p02.reserva (
 reserva_id bigint IDENTITY(1,1) NOT NULL CONSTRAINT pk_reserva PRIMARY KEY,
 codigo varchar(30) NOT NULL CONSTRAINT uq_reserva_codigo UNIQUE,
 operador_id int NOT NULL CONSTRAINT fk_reserva_operador REFERENCES p02.operador(operador_id) ON DELETE NO ACTION,
 disponibilidad_id int NOT NULL CONSTRAINT fk_reserva_disponibilidad REFERENCES p02.disponibilidad_diaria(disponibilidad_id) ON DELETE NO ACTION,
 turno varchar(10) NOT NULL CONSTRAINT ck_reserva_turno CHECK(turno IN ('MANANA','TARDE')),
 visitantes_autorizados int NOT NULL CONSTRAINT ck_reserva_autorizados CHECK(visitantes_autorizados>0),
 estado varchar(12) NOT NULL CONSTRAINT df_reserva_estado DEFAULT 'CONFIRMADA'
  CONSTRAINT ck_reserva_estado CHECK(estado IN ('CONFIRMADA','CANCELADA')),
 creada_en datetimeoffset(0) NOT NULL CONSTRAINT df_reserva_creada DEFAULT SYSDATETIMEOFFSET()
);
CREATE TABLE p02.grupo (
 grupo_id bigint IDENTITY(1,1) NOT NULL CONSTRAINT pk_grupo PRIMARY KEY,
 codigo varchar(30) NOT NULL CONSTRAINT uq_grupo_codigo UNIQUE,
 reserva_id bigint NOT NULL CONSTRAINT uq_grupo_reserva UNIQUE
  CONSTRAINT fk_grupo_reserva REFERENCES p02.reserva(reserva_id) ON DELETE NO ACTION,
 guia_id int NOT NULL CONSTRAINT fk_grupo_guia REFERENCES p02.guia(guia_id) ON DELETE NO ACTION,
 destino_id int NOT NULL CONSTRAINT fk_grupo_destino REFERENCES p02.destino(destino_id) ON DELETE NO ACTION,
 creado_en datetimeoffset(0) NOT NULL CONSTRAINT df_grupo_creado DEFAULT SYSDATETIMEOFFSET()
);
CREATE TABLE p02.acceso (
 acceso_id bigint IDENTITY(1,1) NOT NULL CONSTRAINT pk_acceso PRIMARY KEY,
 grupo_id bigint NOT NULL CONSTRAINT uq_acceso_grupo UNIQUE
  CONSTRAINT fk_acceso_grupo REFERENCES p02.grupo(grupo_id) ON DELETE NO ACTION,
 fecha_hora datetimeoffset(0) NOT NULL CONSTRAINT df_acceso_fecha DEFAULT SYSDATETIMEOFFSET(),
 visitantes_ingresados int NOT NULL CONSTRAINT ck_acceso_ingresados CHECK(visitantes_ingresados>=0)
);
CREATE TABLE p02.incidencia (
 incidencia_id bigint IDENTITY(1,1) NOT NULL CONSTRAINT pk_incidencia PRIMARY KEY,
 grupo_id bigint NOT NULL CONSTRAINT fk_incidencia_grupo REFERENCES p02.grupo(grupo_id) ON DELETE NO ACTION,
 fecha_hora datetimeoffset(0) NOT NULL CONSTRAINT df_incidencia_fecha DEFAULT SYSDATETIMEOFFSET(),
 tipo varchar(20) NOT NULL CONSTRAINT ck_incidencia_tipo CHECK(tipo IN ('EXCESO_PERSONAS','CAMBIO_DESTINO','OTRA')),
 descripcion nvarchar(500) NOT NULL CONSTRAINT ck_incidencia_descripcion CHECK(LEN(TRIM(descripcion))>0),
 origen varchar(10) NOT NULL CONSTRAINT df_incidencia_origen DEFAULT 'MANUAL'
  CONSTRAINT ck_incidencia_origen CHECK(origen IN ('MANUAL','AUTOMATICO'))
);
CREATE INDEX ix_destino_sector ON p02.destino(sector_id);
CREATE INDEX ix_vinculo_operador ON p02.guia_operador(operador_id);
CREATE INDEX ix_certificacion_ultima ON p02.certificacion(guia_id,tipo,fecha_emision DESC);
CREATE INDEX ix_certificacion_vencimiento ON p02.certificacion(fecha_vencimiento);
CREATE INDEX ix_disponibilidad_fecha ON p02.disponibilidad_diaria(fecha,sector_id);
CREATE INDEX ix_limite_sector ON p02.limite_operador(sector_id,operador_id,vigente_desde,vigente_hasta);
CREATE INDEX ix_reserva_cupo ON p02.reserva(disponibilidad_id,operador_id)
 INCLUDE(visitantes_autorizados) WHERE estado='CONFIRMADA';
CREATE INDEX ix_reserva_operador ON p02.reserva(operador_id);
CREATE INDEX ix_grupo_guia ON p02.grupo(guia_id,destino_id);
CREATE INDEX ix_grupo_destino ON p02.grupo(destino_id);
CREATE INDEX ix_incidencia_grupo_fecha ON p02.incidencia(grupo_id,fecha_hora DESC);
CREATE UNIQUE INDEX uq_exceso_automatico ON p02.incidencia(grupo_id)
 WHERE tipo='EXCESO_PERSONAS' AND origen='AUTOMATICO';
GO
