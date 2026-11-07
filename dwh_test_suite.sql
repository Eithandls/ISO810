-- ============================================================================
-- SCRIPT DE AUDITORÍA, TESTS UNITARIOS Y CERTIFICACIÓN DEL DWH CONSOLIDADO
-- Verifica los 4 proyectos: Farmacia Carol, Supermercados Bravo, 
-- Ferretería Americana (TSS) y MADECO (Contabilidad y Activos).
-- ============================================================================

USE DWH_Corporativo_ISO810;
GO

SET NOCOUNT ON;

-- 1. Ejecutar población de semillas si la base de datos está recién creada
EXEC edw.sp_Poblar_Datos_Semilla_DWH;

-- 2. Tabla temporal de resultados
IF OBJECT_ID('tempdb..#TestResultados') IS NOT NULL DROP TABLE #TestResultados;

CREATE TABLE #TestResultados (
    id_test INT IDENTITY(1,1) PRIMARY KEY,
    proyecto VARCHAR(50),
    nombre_prueba VARCHAR(100),
    criterio_evaluado VARCHAR(150),
    resultado VARCHAR(20),
    observacion NVARCHAR(250)
);

-- TEST 1: Supermercados Bravo - Unicidad SCD2 en Dim_Empleado
DECLARE @DuplicadosSCD INT = 0;
SELECT @DuplicadosSCD = COUNT(*) FROM (
    SELECT id_empleado_origen, codigo_empresa 
    FROM edw.Dim_Empleado 
    WHERE es_registro_actual = 1 
    GROUP BY id_empleado_origen, codigo_empresa 
    HAVING COUNT(*) > 1
) t;

INSERT INTO #TestResultados (proyecto, nombre_prueba, criterio_evaluado, resultado, observacion)
VALUES ('Supermercados Bravo', 'Consistencia SCD Tipo 2', 'Un solo registro activo por empleado', 
        CASE WHEN @DuplicadosSCD = 0 THEN 'APROBADO' ELSE 'RECHAZADO' END, 
        CAST(@DuplicadosSCD AS VARCHAR(10)) + ' registros duplicados activos encontrados.');

-- TEST 2: Supermercados Bravo - Regla de Salario Neto en Nómina
DECLARE @ViolacionNomina INT = 0;
SELECT @ViolacionNomina = COUNT(*) 
FROM edw.Fact_Nomina_Gestion
WHERE salario_neto > (salario_bruto + bonificaciones_incentivos + monto_horas_extras);

INSERT INTO #TestResultados (proyecto, nombre_prueba, criterio_evaluado, resultado, observacion)
VALUES ('Supermercados Bravo', 'Coherencia Financiera Nómina', 'Salario neto coherente con ingresos brutos', 
        CASE WHEN @ViolacionNomina = 0 THEN 'APROBADO' ELSE 'RECHAZADO' END, 
        CAST(@ViolacionNomina AS VARCHAR(10)) + ' violaciones salariales.');

-- TEST 3: Farmacia Carol - Ausencia de Claves Huérfanas en Facturación y CxC
DECLARE @HuerfanosCarol INT = 0;
SELECT @HuerfanosCarol = COUNT(*) 
FROM edw.Fact_Facturacion_CxC
WHERE sk_cliente NOT IN (SELECT sk_cliente FROM edw.Dim_Cliente)
   OR sk_cliente IS NULL OR sk_cliente = -1;

INSERT INTO #TestResultados (proyecto, nombre_prueba, criterio_evaluado, resultado, observacion)
VALUES ('Farmacia Carol', 'Integridad Referencial CxC', 'Toda factura debe apuntar a un cliente válido', 
        CASE WHEN @HuerfanosCarol = 0 THEN 'APROBADO' ELSE 'RECHAZADO' END, 
        CAST(@HuerfanosCarol AS VARCHAR(10)) + ' facturas huérfanas.');

-- TEST 4: Farmacia Carol - Cuadratura de Ventas (Monto Total = Subtotal + ITBIS)
DECLARE @DescuadreITBIS INT = 0;
SELECT @DescuadreITBIS = COUNT(*) 
FROM edw.Fact_Facturacion_CxC
WHERE ABS((monto_subtotal + monto_itbis) - monto_total) > 0.05;

INSERT INTO #TestResultados (proyecto, nombre_prueba, criterio_evaluado, resultado, observacion)
VALUES ('Farmacia Carol', 'Cálculo Impositivo ITBIS 18%', 'Subtotal + ITBIS igual a Total Facturado', 
        CASE WHEN @DescuadreITBIS = 0 THEN 'APROBADO' ELSE 'RECHAZADO' END, 
        CAST(@DescuadreITBIS AS VARCHAR(10)) + ' facturas con descuadre en ITBIS.');

-- TEST 5: Ferretería Americana - Reglas de Aportes a la Seguridad Social (TSS)
DECLARE @ErrorTSS INT = 0;
SELECT @ErrorTSS = COUNT(*)
FROM edw.Fact_Aportes_TSS
WHERE sfs_empleador <= 0 OR afp_empleador <= 0;

INSERT INTO #TestResultados (proyecto, nombre_prueba, criterio_evaluado, resultado, observacion)
VALUES ('Ferretería Americana', 'Aportes Patronales TSS', 'Aportes SFS y AFP deben ser estrictamente positivos', 
        CASE WHEN @ErrorTSS = 0 THEN 'APROBADO' ELSE 'RECHAZADO' END, 
        CAST(@ErrorTSS AS VARCHAR(10)) + ' anomalías de aportes patronales.');

-- TEST 6: MADECO - Balance Contable Cuadrado (Partida Doble Débito = Crédito)
DECLARE @TotalDebito DECIMAL(14,2) = 0.00;
DECLARE @TotalCredito DECIMAL(14,2) = 0.00;
SELECT 
    @TotalDebito = SUM(monto_debito),
    @TotalCredito = SUM(monto_credito)
FROM edw.Fact_Movimientos_Contables;

DECLARE @DifContable DECIMAL(14,2) = ABS(@TotalDebito - @TotalCredito);

INSERT INTO #TestResultados (proyecto, nombre_prueba, criterio_evaluado, resultado, observacion)
VALUES ('MADECO', 'Principio de Partida Doble', 'Suma de Débitos igual a Suma de Créditos en Asientos', 
        CASE WHEN @DifContable = 0.00 THEN 'APROBADO' ELSE 'RECHAZADO' END, 
        'Diferencia: RD$ ' + CAST(@DifContable AS VARCHAR(20)));

-- TEST 7: MADECO - Depreciación de Activos Fijos (Valor en Libros > 0)
DECLARE @ActivosNegativos INT = 0;
SELECT @ActivosNegativos = COUNT(*)
FROM edw.Fact_Depreciacion_Activos
WHERE valor_en_libros < 0;

INSERT INTO #TestResultados (proyecto, nombre_prueba, criterio_evaluado, resultado, observacion)
VALUES ('MADECO', 'No Negatividad de Activos Fijos', 'Valor en libros no puede ser negativo', 
        CASE WHEN @ActivosNegativos = 0 THEN 'APROBADO' ELSE 'RECHAZADO' END, 
        CAST(@ActivosNegativos AS VARCHAR(10)) + ' activos con saldo negativo.');

-- TEST 8: Capa Semántica y BI - Rendimiento Corporativo (Vista BI)
DECLARE @CantFilasBI INT = 0;
SELECT @CantFilasBI = COUNT(*) FROM rpt.vw_Dashboard_Rendimiento_Corporativo;

INSERT INTO #TestResultados (proyecto, nombre_prueba, criterio_evaluado, resultado, observacion)
VALUES ('Capa Analítica (BI)', 'Disponibilidad de Dashboard Ejecutivo', 'La vista ejecutiva 360° debe generar datos analíticos', 
        CASE WHEN @CantFilasBI > 0 THEN 'APROBADO' ELSE 'RECHAZADO' END, 
        CAST(@CantFilasBI AS VARCHAR(10)) + ' períodos analizados.');

-- ============================================================================
-- EMISIÓN DEL CERTIFICADO FINAL DE CONTROL DE CALIDAD
-- ============================================================================
SELECT 
    id_test AS [#],
    proyecto AS [Proyecto / Dominio],
    nombre_prueba AS [Prueba Evaluada],
    criterio_evaluado AS [Criterio de Aceptación],
    resultado AS [Resultado],
    observacion AS [Detalle / Métrica]
FROM #TestResultados
ORDER BY id_test;

DECLARE @Aprobados INT, @Total INT;
SELECT @Aprobados = COUNT(*) FROM #TestResultados WHERE resultado = 'APROBADO';
SELECT @Total = COUNT(*) FROM #TestResultados;

PRINT '============================================================';
PRINT 'CERTIFICACIÓN: ' + CAST(@Aprobados AS VARCHAR(5)) + ' de ' + CAST(@Total AS VARCHAR(5)) + ' pruebas aprobadas.';
IF (@Aprobados = @Total)
    PRINT 'DICTAMEN FINAL: ✅ DWH CORPORATIVO ISO810 CERTIFICADO Y LISTO.';
ELSE
    PRINT 'DICTAMEN FINAL: ❌ CORREGIR ANOMALÍAS ANTES DEL DESPLIEGUE.';
PRINT '============================================================';
GO
