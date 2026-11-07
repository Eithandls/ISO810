-- ============================================================================
-- PROYECTO ISO810: ENTERPRISE DATA WAREHOUSE (EDW CORPORATIVO CONSOLIDADO)
-- Integra los 4 proyectos anteriores:
--   1. Farmacia Carol (Facturación & Cuentas por Cobrar - Triggers)
--   2. Supermercados Bravo (Recursos Humanos & Nómina - Linked Servers)
--   3. Ferretería Americana (Seguridad Social TSS - XML / SUIR Plus)
--   4. MADECO (Activos Fijos & Contabilidad - XML)
-- ============================================================================

-- 1. BASE DE DATOS Y ESQUEMAS
IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'DWH_Corporativo_ISO810')
BEGIN
    CREATE DATABASE DWH_Corporativo_ISO810;
END
GO

USE DWH_Corporativo_ISO810;
GO

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'stg') EXEC('CREATE SCHEMA stg');
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'edw') EXEC('CREATE SCHEMA edw');
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'rpt') EXEC('CREATE SCHEMA rpt');
GO

-- 2. TABLA DE AUDITORÍA
IF OBJECT_ID('edw.Auditoria_ETL', 'U') IS NULL
BEGIN
    CREATE TABLE edw.Auditoria_ETL (
        id_log BIGINT IDENTITY(1,1) PRIMARY KEY,
        nombre_proceso VARCHAR(100),
        origen VARCHAR(100),
        destino VARCHAR(100),
        filas_afectadas INT,
        fecha_inicio DATETIME,
        fecha_fin DATETIME,
        estado VARCHAR(20),     -- 'EXITOSO', 'FALLIDO', 'EN_PROCESO'
        mensaje_error NVARCHAR(MAX) NULL
    );
END
GO

-- 3. DIMENSIONES CONFORMADAS
IF OBJECT_ID('edw.Dim_Tiempo', 'U') IS NULL
BEGIN
    CREATE TABLE edw.Dim_Tiempo (
        sk_tiempo INT PRIMARY KEY, -- YYYYMMDD
        fecha DATE NOT NULL,
        anio INT NOT NULL,
        trimestre INT NOT NULL,
        mes INT NOT NULL,
        nombre_mes VARCHAR(20) NOT NULL,
        quincena INT NOT NULL,
        dia_semana VARCHAR(15) NOT NULL,
        es_fin_de_semana BIT NOT NULL,
        es_feriado BIT DEFAULT 0
    );
END
GO

IF OBJECT_ID('edw.Dim_Empresa_Sucursal', 'U') IS NULL
BEGIN
    CREATE TABLE edw.Dim_Empresa_Sucursal (
        sk_sucursal INT IDENTITY(1,1) PRIMARY KEY,
        codigo_empresa VARCHAR(20) NOT NULL, -- 'BRAVO', 'CAROL', 'AMERICANA', 'MADECO'
        rnc_empresa VARCHAR(20) NOT NULL,
        nombre_empresa VARCHAR(100) NOT NULL,
        codigo_sucursal VARCHAR(20) NOT NULL,
        nombre_sucursal VARCHAR(100) NOT NULL,
        ciudad VARCHAR(50) NOT NULL,
        region VARCHAR(50) NOT NULL
    );
END
GO

IF OBJECT_ID('edw.Dim_Cliente', 'U') IS NULL
BEGIN
    CREATE TABLE edw.Dim_Cliente (
        sk_cliente INT IDENTITY(1,1) PRIMARY KEY,
        id_cliente_origen INT NOT NULL,
        rnc_cedula VARCHAR(20) NOT NULL,
        nombre_cliente VARCHAR(150) NOT NULL,
        tipo_cliente VARCHAR(30) NOT NULL,
        limite_credito DECIMAL(12,2) NOT NULL,
        estado_credito VARCHAR(20) NOT NULL
    );
END
GO

IF OBJECT_ID('edw.Dim_Empleado', 'U') IS NULL
BEGIN
    CREATE TABLE edw.Dim_Empleado (
        sk_empleado INT IDENTITY(1,1) PRIMARY KEY,
        id_empleado_origen INT NOT NULL,
        codigo_empresa VARCHAR(20) NOT NULL,
        numero_documento VARCHAR(20) NOT NULL,
        nss VARCHAR(20) NOT NULL,
        nombre_completo VARCHAR(150) NOT NULL,
        cargo VARCHAR(80) NOT NULL,
        departamento VARCHAR(80) NOT NULL,
        salario_base DECIMAL(12,2) NOT NULL,
        fecha_inicio_validez DATETIME NOT NULL,
        fecha_fin_validez DATETIME NULL,
        es_registro_actual BIT DEFAULT 1
    );
END
GO

IF OBJECT_ID('edw.Dim_Cuenta_Contable', 'U') IS NULL
BEGIN
    CREATE TABLE edw.Dim_Cuenta_Contable (
        sk_cuenta INT IDENTITY(1,1) PRIMARY KEY,
        codigo_cuenta VARCHAR(30) NOT NULL,
        nombre_cuenta VARCHAR(150) NOT NULL,
        tipo_cuenta VARCHAR(30) NOT NULL,
        nivel INT NOT NULL
    );
END
GO

-- 4. TABLAS DE HECHOS (FACT TABLES)
IF OBJECT_ID('edw.Fact_Facturacion_CxC', 'U') IS NULL
BEGIN
    CREATE TABLE edw.Fact_Facturacion_CxC (
        sk_fact_cxc BIGINT IDENTITY(1,1) PRIMARY KEY,
        sk_tiempo INT FOREIGN KEY REFERENCES edw.Dim_Tiempo(sk_tiempo),
        sk_sucursal INT FOREIGN KEY REFERENCES edw.Dim_Empresa_Sucursal(sk_sucursal),
        sk_cliente INT FOREIGN KEY REFERENCES edw.Dim_Cliente(sk_cliente),
        id_factura_origen INT NOT NULL,
        ncf VARCHAR(20) NOT NULL,
        tipo_condicion VARCHAR(10) NOT NULL, -- 'CONTADO', 'CREDITO'
        monto_subtotal DECIMAL(12,2) NOT NULL,
        monto_itbis DECIMAL(12,2) NOT NULL,
        monto_total DECIMAL(12,2) NOT NULL,
        monto_pendiente_cxc DECIMAL(12,2) NOT NULL,
        monto_pagado DECIMAL(12,2) NOT NULL,
        dias_mora INT DEFAULT 0,
        estado_cxc VARCHAR(20) NOT NULL
    );
END
GO

IF OBJECT_ID('edw.Fact_Nomina_Gestion', 'U') IS NULL
BEGIN
    CREATE TABLE edw.Fact_Nomina_Gestion (
        sk_fact_nomina BIGINT IDENTITY(1,1) PRIMARY KEY,
        sk_tiempo INT FOREIGN KEY REFERENCES edw.Dim_Tiempo(sk_tiempo),
        sk_sucursal INT FOREIGN KEY REFERENCES edw.Dim_Empresa_Sucursal(sk_sucursal),
        sk_empleado INT FOREIGN KEY REFERENCES edw.Dim_Empleado(sk_empleado),
        salario_bruto DECIMAL(12,2) NOT NULL,
        deducciones_ley DECIMAL(12,2) NOT NULL,
        bonificaciones_incentivos DECIMAL(12,2) NOT NULL,
        horas_extras_total DECIMAL(6,2) NOT NULL,
        monto_horas_extras DECIMAL(12,2) NOT NULL,
        salario_neto DECIMAL(12,2) NOT NULL,
        fecha_carga DATETIME DEFAULT GETDATE()
    );
END
GO

IF OBJECT_ID('edw.Fact_Aportes_TSS', 'U') IS NULL
BEGIN
    CREATE TABLE edw.Fact_Aportes_TSS (
        sk_fact_tss BIGINT IDENTITY(1,1) PRIMARY KEY,
        sk_tiempo INT FOREIGN KEY REFERENCES edw.Dim_Tiempo(sk_tiempo),
        sk_sucursal INT FOREIGN KEY REFERENCES edw.Dim_Empresa_Sucursal(sk_sucursal),
        sk_empleado INT FOREIGN KEY REFERENCES edw.Dim_Empleado(sk_empleado),
        periodo_tss INT NOT NULL,
        salario_cotizable_sdss DECIMAL(12,2) NOT NULL,
        sfs_empleador DECIMAL(12,2) NOT NULL,
        sfs_trabajador DECIMAL(12,2) NOT NULL,
        afp_empleador DECIMAL(12,2) NOT NULL,
        afp_trabajador DECIMAL(12,2) NOT NULL,
        srl_empleador DECIMAL(12,2) NOT NULL,
        infotep_empleador DECIMAL(12,2) NOT NULL,
        total_aporte_sdss AS (sfs_empleador + sfs_trabajador + afp_empleador + afp_trabajador + srl_empleador + infotep_empleador)
    );
END
GO

IF OBJECT_ID('edw.Fact_Depreciacion_Activos', 'U') IS NULL
BEGIN
    CREATE TABLE edw.Fact_Depreciacion_Activos (
        sk_fact_activo BIGINT IDENTITY(1,1) PRIMARY KEY,
        sk_tiempo INT FOREIGN KEY REFERENCES edw.Dim_Tiempo(sk_tiempo),
        sk_sucursal INT FOREIGN KEY REFERENCES edw.Dim_Empresa_Sucursal(sk_sucursal),
        codigo_activo VARCHAR(30) NOT NULL,
        categoria_activo VARCHAR(50) NOT NULL,
        costo_adquisicion DECIMAL(14,2) NOT NULL,
        depreciacion_mensual DECIMAL(12,2) NOT NULL,
        depreciacion_acumulada DECIMAL(14,2) NOT NULL,
        valor_en_libros DECIMAL(14,2) NOT NULL
    );
END
GO

IF OBJECT_ID('edw.Fact_Movimientos_Contables', 'U') IS NULL
BEGIN
    CREATE TABLE edw.Fact_Movimientos_Contables (
        sk_fact_asiento BIGINT IDENTITY(1,1) PRIMARY KEY,
        sk_tiempo INT FOREIGN KEY REFERENCES edw.Dim_Tiempo(sk_tiempo),
        sk_cuenta INT FOREIGN KEY REFERENCES edw.Dim_Cuenta_Contable(sk_cuenta),
        sk_sucursal INT FOREIGN KEY REFERENCES edw.Dim_Empresa_Sucursal(sk_sucursal),
        numero_asiento VARCHAR(30) NOT NULL,
        linea_asiento INT NOT NULL,
        tipo_movimiento VARCHAR(2) NOT NULL,
        monto_debito DECIMAL(14,2) NOT NULL,
        monto_credito DECIMAL(14,2) NOT NULL
    );
END
GO

-- 5. PROCEDIMIENTOS ALMACENADOS DE INTEGRACIÓN Y CARGA
CREATE OR ALTER PROCEDURE edw.sp_Poblar_Datos_Semilla_DWH
AS
BEGIN
    SET NOCOUNT ON;

    -- Poblar Dim_Tiempo si está vacía
    IF NOT EXISTS (SELECT 1 FROM edw.Dim_Tiempo)
    BEGIN
        INSERT INTO edw.Dim_Tiempo (sk_tiempo, fecha, anio, trimestre, mes, nombre_mes, quincena, dia_semana, es_fin_de_semana)
        VALUES 
            (20260930, '2026-09-30', 2026, 3, 9, 'Septiembre', 2, 'Miércoles', 0),
            (20261015, '2026-10-15', 2026, 4, 10, 'Octubre', 1, 'Jueves', 0),
            (20261031, '2026-10-31', 2026, 4, 10, 'Octubre', 2, 'Sábado', 1),
            (20261106, '2026-11-06', 2026, 4, 11, 'Noviembre', 1, 'Viernes', 0);
    END;

    -- Poblar Dim_Empresa_Sucursal
    IF NOT EXISTS (SELECT 1 FROM edw.Dim_Empresa_Sucursal)
    BEGIN
        INSERT INTO edw.Dim_Empresa_Sucursal (codigo_empresa, rnc_empresa, nombre_empresa, codigo_sucursal, nombre_sucursal, ciudad, region)
        VALUES 
            ('BRAVO', '101889901', 'Supermercados Bravo, S.A.', 'SUC-01', 'Bravo Churchill', 'Santo Domingo', 'Metropolitana'),
            ('BRAVO', '101889901', 'Supermercados Bravo, S.A.', 'SUC-02', 'Bravo Núñez de Cáceres', 'Santo Domingo', 'Metropolitana'),
            ('CAROL', '130987654', 'Farmacia Carol, S.R.L.', 'SUC-C01', 'Carol 27 de Febrero', 'Santo Domingo', 'Metropolitana'),
            ('AMERICANA', '131456789', 'Ferretería Americana, S.R.L.', 'SUC-A01', 'Americana San Martín', 'Santo Domingo', 'Metropolitana'),
            ('MADECO', '102345678', 'Maderas y Derivados (MADECO)', 'SUC-M01', 'MADECO Haina Industrial', 'San Cristóbal', 'Sur');
    END;

    -- Poblar Dim_Cliente (Carol)
    IF NOT EXISTS (SELECT 1 FROM edw.Dim_Cliente)
    BEGIN
        INSERT INTO edw.Dim_Cliente (id_cliente_origen, rnc_cedula, nombre_cliente, tipo_cliente, limite_credito, estado_credito)
        VALUES 
            (101, '101002003', 'ARS Primera Humano', 'SEGURO', 5000000.00, 'EXCELENTE'),
            (102, '102003004', 'Clínica Abreu', 'CORPORATIVO', 1500000.00, 'BUENO'),
            (103, '00109876543', 'Juan Pérez Gómez', 'DETALLE', 25000.00, 'NORMAL');
    END;

    -- Poblar Dim_Empleado SCD 2 (Bravo y Americana)
    IF NOT EXISTS (SELECT 1 FROM edw.Dim_Empleado)
    BEGIN
        INSERT INTO edw.Dim_Empleado (id_empleado_origen, codigo_empresa, numero_documento, nss, nombre_completo, cargo, departamento, salario_base, fecha_inicio_validez, fecha_fin_validez, es_registro_actual)
        VALUES 
            (1001, 'BRAVO', '00114725836', '201456789', 'María Isabel García Rodríguez', 'Cajera Principal', 'Cajas y Servicio', 45000.00, '2026-01-01', NULL, 1),
            (1002, 'BRAVO', '00125836914', '201456790', 'Pedro José Martínez Peña', 'Supervisor de Pasillo', 'Almacén y Reposición', 52000.00, '2026-01-01', NULL, 1),
            (2001, 'AMERICANA', '00114725836', '201456789', 'María Isabel García Rodríguez', 'Contadora Auxiliar', 'Finanzas', 45000.00, '2026-01-01', NULL, 1);
    END;

    -- Poblar Dim_Cuenta_Contable (MADECO)
    IF NOT EXISTS (SELECT 1 FROM edw.Dim_Cuenta_Contable)
    BEGIN
        INSERT INTO edw.Dim_Cuenta_Contable (codigo_cuenta, nombre_cuenta, tipo_cuenta, nivel)
        VALUES 
            ('6-1-05-001', 'Gasto depreciación maquinaria', 'GASTO', 4),
            ('6-1-05-002', 'Gasto depreciación vehículos', 'GASTO', 4),
            ('1-2-09-001', 'Depreciación acumulada maquinaria', 'ACTIVO_CONTRA', 4),
            ('1-2-09-002', 'Depreciación acumulada vehículos', 'ACTIVO_CONTRA', 4);
    END;

    -- Poblar Hechos iniciales de demostración
    IF NOT EXISTS (SELECT 1 FROM edw.Fact_Facturacion_CxC)
    BEGIN
        INSERT INTO edw.Fact_Facturacion_CxC (sk_tiempo, sk_sucursal, sk_cliente, id_factura_origen, ncf, tipo_condicion, monto_subtotal, monto_itbis, monto_total, monto_pendiente_cxc, monto_pagado, dias_mora, estado_cxc)
        VALUES 
            (20261106, 3, 1, 1001, 'B0100001045', 'CREDITO', 25000.00, 4500.00, 29500.00, 29500.00, 0.00, 0, 'PENDIENTE'),
            (20261106, 3, 3, 1002, 'B0200004512', 'CONTADO', 1200.00, 216.00, 1416.00, 0.00, 1416.00, 0, 'PAGADA');
    END;

    IF NOT EXISTS (SELECT 1 FROM edw.Fact_Nomina_Gestion)
    BEGIN
        INSERT INTO edw.Fact_Nomina_Gestion (sk_tiempo, sk_sucursal, sk_empleado, salario_bruto, deducciones_ley, bonificaciones_incentivos, horas_extras_total, monto_horas_extras, salario_neto)
        VALUES 
            (20261031, 1, 1, 45000.00, 2655.00, 3000.00, 12.0, 4200.00, 49545.00),
            (20261031, 2, 2, 52000.00, 3068.00, 2500.00, 8.0, 3200.00, 54632.00);
    END;

    IF NOT EXISTS (SELECT 1 FROM edw.Fact_Aportes_TSS)
    BEGIN
        INSERT INTO edw.Fact_Aportes_TSS (sk_tiempo, sk_sucursal, sk_empleado, periodo_tss, salario_cotizable_sdss, sfs_empleador, sfs_trabajador, afp_empleador, afp_trabajador, srl_empleador, infotep_empleador)
        VALUES 
            (20260930, 4, 3, 202609, 45000.00, 3195.00, 1372.50, 3217.50, 1282.50, 495.00, 450.00);
    END;

    IF NOT EXISTS (SELECT 1 FROM edw.Fact_Depreciacion_Activos)
    BEGIN
        INSERT INTO edw.Fact_Depreciacion_Activos (sk_tiempo, sk_sucursal, codigo_activo, categoria_activo, costo_adquisicion, depreciacion_mensual, depreciacion_acumulada, valor_en_libros)
        VALUES 
            (20260930, 5, 'ACT-MAQ-001', 'MAQUINARIA', 2700000.00, 45000.00, 540000.00, 2160000.00),
            (20260930, 5, 'ACT-VEH-002', 'VEHICULOS', 750000.00, 12500.00, 150000.00, 600000.00);
    END;

    IF NOT EXISTS (SELECT 1 FROM edw.Fact_Movimientos_Contables)
    BEGIN
        INSERT INTO edw.Fact_Movimientos_Contables (sk_tiempo, sk_cuenta, sk_sucursal, numero_asiento, linea_asiento, tipo_movimiento, monto_debito, monto_credito)
        VALUES 
            (20260930, 1, 5, 'AF-2026-000123', 1, 'DB', 45000.00, 0.00),
            (20260930, 2, 5, 'AF-2026-000123', 2, 'DB', 12500.00, 0.00),
            (20260930, 3, 5, 'AF-2026-000123', 3, 'CR', 0.00, 45000.00),
            (20260930, 4, 5, 'AF-2026-000123', 4, 'CR', 0.00, 12500.00);
    END;

    PRINT 'Semillas y datos maestros de demostración cargados exitosamente.';
END;
GO

-- 6. VISTAS ANALÍTICAS Y DE BI
CREATE OR ALTER VIEW rpt.vw_Dashboard_Costo_Laboral_Integral
AS
SELECT 
    t.anio,
    t.nombre_mes,
    emp.codigo_empresa,
    emp.nombre_completo AS empleado,
    emp.cargo,
    emp.departamento,
    ISNULL(nom.salario_bruto, 0) AS salario_bruto_pagado,
    ISNULL(nom.monto_horas_extras, 0) AS horas_extras_costo,
    ISNULL(tss.sfs_empleador, 0) AS seguro_salud_patronal,
    ISNULL(tss.afp_empleador, 0) AS pensiones_patronal,
    ISNULL(tss.srl_empleador, 0) AS riesgos_laborales,
    ISNULL(tss.infotep_empleador, 0) AS infotep_1pct,
    ISNULL(nom.salario_bruto, 0) + 
    ISNULL(tss.sfs_empleador + tss.afp_empleador + tss.srl_empleador + tss.infotep_empleador, 0) AS costo_empresa_total
FROM edw.Dim_Empleado emp
INNER JOIN edw.Dim_Tiempo t ON t.es_fin_de_semana = 0
LEFT JOIN edw.Fact_Nomina_Gestion nom 
    ON emp.sk_empleado = nom.sk_empleado AND t.sk_tiempo = nom.sk_tiempo
LEFT JOIN edw.Fact_Aportes_TSS tss 
    ON emp.sk_empleado = tss.sk_empleado AND t.sk_tiempo = tss.sk_tiempo
WHERE emp.es_registro_actual = 1;
GO

CREATE OR ALTER VIEW rpt.vw_Dashboard_Rendimiento_Corporativo
AS
SELECT 
    t.anio,
    t.nombre_mes,
    SUM(ISNULL(vta.monto_total, 0)) AS ventas_totales_grupo,
    SUM(ISNULL(vta.monto_pendiente_cxc, 0)) AS cartera_vencida_por_cobrar,
    SUM(ISNULL(nom.salario_bruto, 0)) AS gasto_nomina_operativa,
    SUM(ISNULL(tss.total_aporte_sdss, 0)) AS carga_social_tss,
    SUM(ISNULL(dep.depreciacion_mensual, 0)) AS gasto_depreciacion_activos,
    SUM(ISNULL(vta.monto_total, 0)) - (
        SUM(ISNULL(nom.salario_bruto, 0)) + 
        SUM(ISNULL(tss.total_aporte_sdss, 0)) + 
        SUM(ISNULL(dep.depreciacion_mensual, 0))
    ) AS utilidad_operativa_estimada
FROM edw.Dim_Tiempo t
LEFT JOIN edw.Fact_Facturacion_CxC vta ON t.sk_tiempo = vta.sk_tiempo
LEFT JOIN edw.Fact_Nomina_Gestion nom ON t.sk_tiempo = nom.sk_tiempo
LEFT JOIN edw.Fact_Aportes_TSS tss ON t.sk_tiempo = tss.sk_tiempo
LEFT JOIN edw.Fact_Depreciacion_Activos dep ON t.sk_tiempo = dep.sk_tiempo
GROUP BY t.anio, t.nombre_mes;
GO
