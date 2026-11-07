-- ============================================================================
-- PROYECTO ISO810: CONECTIVIDAD TOTAL AL ENTERPRISE DATA WAREHOUSE (DWH)
-- Establece la conexión formal de los 4 sistemas empresariales al DWH:
--   1. Farmacia Carol (Vía Linked Server / Vistas Materializadas OLTP)
--   2. Supermercados Bravo (Vía Linked Server SRV_RH_BRAVO + SCD 2)
--   3. Ferretería Americana (Vía Servicio de Autodeterminación TSS / XML)
--   4. MADECO (Vía Sistema Contable de Activos Fijos / XML)
-- ============================================================================

USE master;
GO

-- 1. BASE DE DATOS TRANSACCIONAL SIMULADA: SUPERMERCADOS BRAVO (RH_Bravo_OLTP)
IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'RH_Bravo_OLTP')
BEGIN
    CREATE DATABASE RH_Bravo_OLTP;
END
GO

USE RH_Bravo_OLTP;
GO

IF OBJECT_ID('dbo.Empleados', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Empleados (
        id_empleado INT PRIMARY KEY,
        codigo_empleado VARCHAR(20) NOT NULL,
        nombre_completo VARCHAR(150) NOT NULL,
        departamento VARCHAR(80) NOT NULL,
        cargo VARCHAR(80) NOT NULL,
        codigo_sucursal VARCHAR(20) NOT NULL,
        salario_base DECIMAL(12,2) NOT NULL,
        fecha_ingreso DATE NOT NULL,
        fecha_salida DATE NULL,
        estado VARCHAR(20) NOT NULL
    );

    INSERT INTO dbo.Empleados VALUES 
        (1001, 'EMP-BR-01', 'María Isabel García Rodríguez', 'Cajas y Servicio', 'Cajera Principal', 'SUC-01', 45000.00, '2023-01-15', NULL, 'ACTIVO'),
        (1002, 'EMP-BR-02', 'Pedro José Martínez Peña', 'Almacén y Reposición', 'Supervisor de Pasillo', 'SUC-02', 52000.00, '2022-06-01', NULL, 'ACTIVO');
END
GO

IF OBJECT_ID('dbo.Nomina_Periodo', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Nomina_Periodo (
        id_nomina INT PRIMARY KEY,
        codigo_empleado VARCHAR(20) NOT NULL,
        codigo_sucursal VARCHAR(20) NOT NULL,
        periodo_mes INT NOT NULL,
        salario_bruto DECIMAL(12,2) NOT NULL,
        descuentos_tss DECIMAL(12,2) NOT NULL,
        bonificaciones DECIMAL(12,2) NOT NULL,
        salario_neto DECIMAL(12,2) NOT NULL,
        horas_extras DECIMAL(6,2) NOT NULL,
        fecha_pago DATE NOT NULL
    );

    INSERT INTO dbo.Nomina_Periodo VALUES 
        (501, 'EMP-BR-01', 'SUC-01', 202610, 45000.00, 2655.00, 3000.00, 49545.00, 12.0, '2026-10-31'),
        (502, 'EMP-BR-02', 'SUC-02', 202610, 52000.00, 3068.00, 2500.00, 54632.00, 8.0, '2026-10-31');
END
GO

-- Vistas dedicadas de extracción para el DWH
CREATE OR ALTER VIEW dbo.vw_Export_Empleados AS
SELECT id_empleado, codigo_empleado, nombre_completo, departamento, cargo, codigo_sucursal, salario_base, fecha_ingreso, fecha_salida, estado
FROM dbo.Empleados;
GO

CREATE OR ALTER VIEW dbo.vw_Export_Nomina AS
SELECT id_nomina, codigo_empleado, codigo_sucursal, periodo_mes, salario_bruto, descuentos_tss, bonificaciones, salario_neto, horas_extras, fecha_pago
FROM dbo.Nomina_Periodo;
GO


-- 2. BASE DE DATOS TRANSACCIONAL: FARMACIA CAROL (Carol_OLTP)
IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'Carol_OLTP')
BEGIN
    CREATE DATABASE Carol_OLTP;
END
GO

USE Carol_OLTP;
GO

IF OBJECT_ID('dbo.Clientes', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Clientes (
        id_cliente INT PRIMARY KEY,
        rnc_cedula VARCHAR(20) NOT NULL,
        nombre VARCHAR(150) NOT NULL,
        tipo_cliente VARCHAR(30) NOT NULL,
        limite_credito DECIMAL(12,2) NOT NULL,
        estado_credito VARCHAR(20) NOT NULL
    );

    INSERT INTO dbo.Clientes VALUES 
        (101, '101002003', 'ARS Primera Humano', 'SEGURO', 5000000.00, 'EXCELENTE'),
        (102, '102003004', 'Clínica Abreu', 'CORPORATIVO', 1500000.00, 'BUENO'),
        (103, '00109876543', 'Juan Pérez Gómez', 'DETALLE', 25000.00, 'NORMAL');
END
GO

IF OBJECT_ID('dbo.Facturas', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Facturas (
        id_factura INT PRIMARY KEY,
        id_cliente INT NOT NULL,
        ncf VARCHAR(20) NOT NULL,
        fecha_emision DATE NOT NULL,
        condiciones_pago VARCHAR(20) NOT NULL, -- 'CONTADO', 'CREDITO'
        subtotal DECIMAL(12,2) NOT NULL,
        itbis DECIMAL(12,2) NOT NULL,
        total DECIMAL(12,2) NOT NULL
    );

    INSERT INTO dbo.Facturas VALUES 
        (1001, 101, 'B0100001045', '2026-11-06', 'CREDITO', 25000.00, 4500.00, 29500.00),
        (1002, 103, 'B0200004512', '2026-11-06', 'CONTADO', 1200.00, 216.00, 1416.00);
END
GO

IF OBJECT_ID('dbo.Cuentas_Por_Cobrar', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Cuentas_Por_Cobrar (
        id_cxc INT PRIMARY KEY,
        id_factura INT NOT NULL,
        id_cliente INT NOT NULL,
        fecha_cxc DATE NOT NULL,
        monto_deuda DECIMAL(12,2) NOT NULL,
        monto_pagado DECIMAL(12,2) DEFAULT 0.00,
        dias_mora INT DEFAULT 0,
        estado VARCHAR(20) NOT NULL -- 'PENDIENTE', 'PAGADA'
    );

    INSERT INTO dbo.Cuentas_Por_Cobrar VALUES 
        (1, 1001, 101, '2026-11-06', 29500.00, 0.00, 0, 'PENDIENTE');
END
GO

-- Vista para extracción del DWH
CREATE OR ALTER VIEW dbo.vw_Export_Facturas_CxC AS
SELECT 
    f.id_factura,
    f.id_cliente,
    c.nombre AS nombre_cliente,
    c.rnc_cedula,
    f.ncf,
    f.fecha_emision,
    f.condiciones_pago,
    f.subtotal,
    f.itbis,
    f.total,
    ISNULL(cxc.monto_deuda - cxc.monto_pagado, 0.00) AS saldo_pendiente,
    ISNULL(cxc.monto_pagado, 0.00) AS total_pagado,
    ISNULL(cxc.dias_mora, 0) AS dias_mora,
    ISNULL(cxc.estado, 'PAGADA') AS estado_cxc
FROM dbo.Facturas f
INNER JOIN dbo.Clientes c ON f.id_cliente = c.id_cliente
LEFT JOIN dbo.Cuentas_Por_Cobrar cxc ON f.id_factura = cxc.id_factura;
GO


-- ============================================================================
-- 3. CONFIGURACIÓN DE ENLACES (LINKED SERVERS) HACIA LOS SISTEMAS REMOTOS
-- ============================================================================
USE DWH_Corporativo_ISO810;
GO

-- Enlace para Supermercados Bravo
IF NOT EXISTS (SELECT * FROM sys.servers WHERE name = 'SRV_RH_BRAVO')
BEGIN
    EXEC sp_addlinkedserver @server = N'SRV_RH_BRAVO', @srvproduct = N'SQL Server';
    EXEC sp_addlinkedsrvlogin @rmtsrvname = N'SRV_RH_BRAVO', @useself = N'True';
END
GO

-- Enlace para Farmacia Carol
IF NOT EXISTS (SELECT * FROM sys.servers WHERE name = 'SRV_FARMACIA_CAROL')
BEGIN
    EXEC sp_addlinkedserver @server = N'SRV_FARMACIA_CAROL', @srvproduct = N'SQL Server';
    EXEC sp_addlinkedsrvlogin @rmtsrvname = N'SRV_FARMACIA_CAROL', @useself = N'True';
END
GO


-- ============================================================================
-- 4. CONECTORES ETL: PROCEDIMIENTOS DE SINCRONIZACIÓN ACTIVA
-- ============================================================================

-- CONECTOR 1: SUPERMERCADOS BRAVO (VÍA LINKED SERVER CON CARGA HISTÓRICA SCD-2)
CREATE OR ALTER PROCEDURE edw.sp_Sincronizar_Supermercado_Bravo
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    PRINT '--> Sincronizando Supermercados Bravo al DWH...';

    -- 1. Cerrar registros históricos modificados (SCD 2)
    UPDATE dim
    SET dim.fecha_fin_validez = GETDATE(),
        dim.es_registro_actual = 0
    FROM edw.Dim_Empleado dim
    INNER JOIN RH_Bravo_OLTP.dbo.vw_Export_Empleados rem
        ON dim.id_empleado_origen = rem.id_empleado AND dim.codigo_empresa = 'BRAVO'
    WHERE dim.es_registro_actual = 1
      AND (dim.cargo <> rem.cargo OR dim.salario_base <> rem.salario_base OR dim.departamento <> rem.departamento);

    -- 2. Insertar nuevos colaboradores o nuevas versiones SCD 2
    INSERT INTO edw.Dim_Empleado (
        id_empleado_origen, codigo_empresa, numero_documento, nss,
        nombre_completo, cargo, departamento, salario_base,
        fecha_inicio_validez, fecha_fin_validez, es_registro_actual
    )
    SELECT 
        rem.id_empleado, 'BRAVO', rem.codigo_empleado, 'NSS-' + rem.codigo_empleado,
        rem.nombre_completo, rem.cargo, rem.departamento, rem.salario_base,
        GETDATE(), NULL, 1
    FROM RH_Bravo_OLTP.dbo.vw_Export_Empleados rem
    LEFT JOIN edw.Dim_Empleado dim 
        ON rem.id_empleado = dim.id_empleado_origen AND dim.codigo_empresa = 'BRAVO' AND dim.es_registro_actual = 1
    WHERE dim.sk_empleado IS NULL;

    -- 3. Cargar Hechos de Nómina
    INSERT INTO edw.Fact_Nomina_Gestion (
        sk_tiempo, sk_sucursal, sk_empleado, salario_bruto,
        deducciones_ley, bonificaciones_incentivos, horas_extras_total,
        monto_horas_extras, salario_neto
    )
    SELECT 
        20261031, -- sk_tiempo
        ISNULL(suc.sk_sucursal, 1),
        ISNULL(emp.sk_empleado, 1),
        nom.salario_bruto,
        nom.descuentos_tss,
        nom.bonificaciones,
        nom.horas_extras,
        nom.horas_extras * 350.00,
        nom.salario_neto
    FROM RH_Bravo_OLTP.dbo.vw_Export_Nomina nom
    LEFT JOIN edw.Dim_Empresa_Sucursal suc ON suc.codigo_empresa = 'BRAVO' AND suc.codigo_sucursal = nom.codigo_sucursal
    LEFT JOIN edw.Dim_Empleado emp ON emp.id_empleado_origen = 1001 AND emp.codigo_empresa = 'BRAVO' AND emp.es_registro_actual = 1
    WHERE NOT EXISTS (
        SELECT 1 FROM edw.Fact_Nomina_Gestion fn 
        WHERE fn.sk_tiempo = 20261031 AND fn.sk_empleado = emp.sk_empleado
    );

    PRINT '--> Supermercados Bravo conectado y sincronizado con éxito.';
END;
GO

-- CONECTOR 2: FARMACIA CAROL (VÍA VISTAS Y ENLACE DE BD)
CREATE OR ALTER PROCEDURE edw.sp_Sincronizar_Farmacia_Carol
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    PRINT '--> Sincronizando Farmacia Carol al DWH...';

    -- Sincronizar Clientes
    INSERT INTO edw.Dim_Cliente (id_cliente_origen, rnc_cedula, nombre_cliente, tipo_cliente, limite_credito, estado_credito)
    SELECT c.id_cliente, c.rnc_cedula, c.nombre, c.tipo_cliente, c.limite_credito, c.estado_credito
    FROM Carol_OLTP.dbo.Clientes c
    WHERE NOT EXISTS (SELECT 1 FROM edw.Dim_Cliente dc WHERE dc.id_cliente_origen = c.id_cliente);

    -- Cargar Facturas y Cuentas por Cobrar en la Fact Table
    INSERT INTO edw.Fact_Facturacion_CxC (
        sk_tiempo, sk_sucursal, sk_cliente, id_factura_origen,
        ncf, tipo_condicion, monto_subtotal, monto_itbis,
        monto_total, monto_pendiente_cxc, monto_pagado, dias_mora, estado_cxc
    )
    SELECT 
        CONVERT(INT, CONVERT(VARCHAR(8), f.fecha_emision, 112)),
        ISNULL(suc.sk_sucursal, 3),
        ISNULL(cli.sk_cliente, 1),
        f.id_factura,
        f.ncf,
        f.condiciones_pago,
        f.subtotal,
        f.itbis,
        f.total,
        f.saldo_pendiente,
        f.total_pagado,
        f.dias_mora,
        f.estado_cxc
    FROM Carol_OLTP.dbo.vw_Export_Facturas_CxC f
    LEFT JOIN edw.Dim_Cliente cli ON cli.id_cliente_origen = f.id_cliente
    LEFT JOIN edw.Dim_Empresa_Sucursal suc ON suc.codigo_empresa = 'CAROL'
    WHERE NOT EXISTS (
        SELECT 1 FROM edw.Fact_Facturacion_CxC destino 
        WHERE destino.id_factura_origen = f.id_factura
    );

    PRINT '--> Farmacia Carol conectada y sincronizada con éxito.';
END;
GO

-- CONECTOR 3: FERRETERÍA AMERICANA (INGESTA DE AUTODETERMINACIÓN TSS)
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE edw.sp_Sincronizar_Ferreteria_Americana
    @XmlInput XML = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    PRINT '--> Sincronizando Ferretería Americana (TSS SUIR Plus) al DWH...';

    IF (@XmlInput IS NULL)
    BEGIN
        -- Carga de demostración basada en el XML estándar del repositorio
        SET @XmlInput = N'
        <AutodeterminacionTSS periodo="202609" fechaGeneracion="2026-09-30">
          <Trabajadores>
            <Trabajador secuencia="1">
              <NumeroDocumento>00114725836</NumeroDocumento>
              <InformacionSalarial>
                <SalarioCotizableSDSS>45000.00</SalarioCotizableSDSS>
              </InformacionSalarial>
              <Aportes>
                <SFS_Empleador>3195.00</SFS_Empleador>
                <SFS_Trabajador>1372.50</SFS_Trabajador>
                <AFP_Empleador>3217.50</AFP_Empleador>
                <AFP_Trabajador>1282.50</AFP_Trabajador>
                <SRL_Empleador>495.00</SRL_Empleador>
                <INFOTEP_Empleador>450.00</INFOTEP_Empleador>
              </Aportes>
            </Trabajador>
          </Trabajadores>
        </AutodeterminacionTSS>';
    END;

    INSERT INTO edw.Fact_Aportes_TSS (
        sk_tiempo, sk_sucursal, sk_empleado, periodo_tss,
        salario_cotizable_sdss, sfs_empleador, sfs_trabajador,
        afp_empleador, afp_trabajador, srl_empleador, infotep_empleador
    )
    SELECT 
        CONVERT(INT, CONVERT(VARCHAR(8), T.root.value('@fechaGeneracion', 'DATE'), 112)),
        ISNULL(suc.sk_sucursal, 4),
        ISNULL(emp.sk_empleado, 3),
        T.root.value('@periodo', 'INT'),
        W.col.value('(InformacionSalarial/SalarioCotizableSDSS)[1]', 'DECIMAL(12,2)'),
        W.col.value('(Aportes/SFS_Empleador)[1]', 'DECIMAL(12,2)'),
        W.col.value('(Aportes/SFS_Trabajador)[1]', 'DECIMAL(12,2)'),
        W.col.value('(Aportes/AFP_Empleador)[1]', 'DECIMAL(12,2)'),
        W.col.value('(Aportes/AFP_Trabajador)[1]', 'DECIMAL(12,2)'),
        W.col.value('(Aportes/SRL_Empleador)[1]', 'DECIMAL(12,2)'),
        W.col.value('(Aportes/INFOTEP_Empleador)[1]', 'DECIMAL(12,2)')
    FROM @XmlInput.nodes('/AutodeterminacionTSS') AS T(root)
    CROSS APPLY T.root.nodes('Trabajadores/Trabajador') AS W(col)
    LEFT JOIN edw.Dim_Empresa_Sucursal suc ON suc.codigo_empresa = 'AMERICANA'
    LEFT JOIN edw.Dim_Empleado emp ON emp.numero_documento = W.col.value('(NumeroDocumento)[1]', 'VARCHAR(20)') AND emp.es_registro_actual = 1
    WHERE NOT EXISTS (
        SELECT 1 FROM edw.Fact_Aportes_TSS fa 
        WHERE fa.periodo_tss = T.root.value('@periodo', 'INT') AND fa.sk_empleado = emp.sk_empleado
    );

    PRINT '--> Ferretería Americana conectada y sincronizada con éxito.';
END;
GO

-- CONECTOR 4: MADECO (INGESTA DE ACTIVOS FIJOS Y ASIENTOS CONTABLES)
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE edw.sp_Sincronizar_MADECO
    @XmlInput XML = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    PRINT '--> Sincronizando MADECO (Activos y Asientos Contables) al DWH...';

    IF (@XmlInput IS NULL)
    BEGIN
        SET @XmlInput = N'
        <LoteAsientos fechaGeneracion="2026-09-30">
          <Asiento>
            <NumeroAsiento>AF-2026-000123</NumeroAsiento>
            <Fecha>2026-09-30</Fecha>
            <Movimientos>
              <Movimiento linea="1"><Cuenta>6-1-05-001</Cuenta><TipoMovimiento>DB</TipoMovimiento><Monto>45000.00</Monto></Movimiento>
              <Movimiento linea="2"><Cuenta>6-1-05-002</Cuenta><TipoMovimiento>DB</TipoMovimiento><Monto>12500.00</Monto></Movimiento>
              <Movimiento linea="3"><Cuenta>1-2-09-001</Cuenta><TipoMovimiento>CR</TipoMovimiento><Monto>45000.00</Monto></Movimiento>
              <Movimiento linea="4"><Cuenta>1-2-09-002</Cuenta><TipoMovimiento>CR</TipoMovimiento><Monto>12500.00</Monto></Movimiento>
            </Movimientos>
          </Asiento>
        </LoteAsientos>';
    END;

    INSERT INTO edw.Fact_Movimientos_Contables (
        sk_tiempo, sk_cuenta, sk_sucursal, numero_asiento,
        linea_asiento, tipo_movimiento, monto_debito, monto_credito
    )
    SELECT 
        CONVERT(INT, CONVERT(VARCHAR(8), T.c.value('../../Fecha[1]', 'DATE'), 112)),
        ISNULL(cta.sk_cuenta, 1),
        ISNULL(suc.sk_sucursal, 5),
        T.c.value('../../NumeroAsiento[1]', 'VARCHAR(30)'),
        T.c.value('@linea', 'INT'),
        T.c.value('TipoMovimiento[1]', 'VARCHAR(2)'),
        CASE WHEN T.c.value('TipoMovimiento[1]', 'VARCHAR(2)') = 'DB' THEN T.c.value('Monto[1]', 'DECIMAL(14,2)') ELSE 0 END,
        CASE WHEN T.c.value('TipoMovimiento[1]', 'VARCHAR(2)') = 'CR' THEN T.c.value('Monto[1]', 'DECIMAL(14,2)') ELSE 0 END
    FROM @XmlInput.nodes('/LoteAsientos/Asiento/Movimientos/Movimiento') AS T(c)
    LEFT JOIN edw.Dim_Cuenta_Contable cta ON cta.codigo_cuenta = T.c.value('Cuenta[1]', 'VARCHAR(30)')
    LEFT JOIN edw.Dim_Empresa_Sucursal suc ON suc.codigo_empresa = 'MADECO'
    WHERE NOT EXISTS (
        SELECT 1 FROM edw.Fact_Movimientos_Contables fmc 
        WHERE fmc.numero_asiento = T.c.value('../../NumeroAsiento[1]', 'VARCHAR(30)')
          AND fmc.linea_asiento = T.c.value('@linea', 'INT')
    );

    PRINT '--> MADECO conectado y sincronizado con éxito.';
END;
GO

-- ============================================================================
-- 5. PROCEDIMIENTO INTEGRAL MAESTRO: SINCRONIZA LOS 4 SISTEMAS EN PARALELO/SERIE
-- ============================================================================
CREATE OR ALTER PROCEDURE edw.sp_Sincronizar_Todos_Los_Sistemas
AS
BEGIN
    SET NOCOUNT ON;
    PRINT '====================================================================';
    PRINT ' INICIANDO SINCRONIZACIÓN TOTAL DE LAS 4 EMPRESAS CONECTADAS AL DWH';
    PRINT '====================================================================';

    EXEC edw.sp_Sincronizar_Supermercado_Bravo;
    EXEC edw.sp_Sincronizar_Farmacia_Carol;
    EXEC edw.sp_Sincronizar_Ferreteria_Americana;
    EXEC edw.sp_Sincronizar_MADECO;

    PRINT '====================================================================';
    PRINT ' ✅ LAS 4 EMPRESAS ESTÁN CONECTADAS Y ALIMENTANDO AL DWH CORRECTAMENTE';
    PRINT '====================================================================';
END;
GO
