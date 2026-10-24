-- ============================================================================
-- ASIGNATURA: ISO810 - INTEGRACIÓN DE SISTEMAS / BASES DE DATOS
-- PRÁCTICA: INTEGRACIÓN ENTRE TABLAS MEDIANTE DISPARADORES (TRIGGERS)
-- CASO: FACTURACIÓN ➔ CUENTAS POR COBRAR (FARMACIA CAROL)
-- MOTOR: ORACLE DATABASE (PL/SQL)
-- ============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED;

-- ----------------------------------------------------------------------------
-- 1. LIMPIEZA DE OBJETOS PREVIOS
-- ----------------------------------------------------------------------------
DROP TRIGGER TRG_FACTURA_A_CXC;
DROP TABLE CUENTAS_POR_COBRAR CASCADE CONSTRAINTS;
DROP TABLE FACTURAS CASCADE CONSTRAINTS;
DROP TABLE CLIENTES CASCADE CONSTRAINTS;
DROP SEQUENCE SEQ_CXC;

-- ----------------------------------------------------------------------------
-- 2. SECUENCIA PARA CUENTAS POR COBRAR
-- ----------------------------------------------------------------------------
CREATE SEQUENCE SEQ_CXC
    START WITH 3001
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;

-- ----------------------------------------------------------------------------
-- 3. TABLAS DEL MODELO DE INTEGRACIÓN
-- ----------------------------------------------------------------------------

-- A) Tabla de Clientes
CREATE TABLE CLIENTES (
    id_cliente      NUMBER(6)       PRIMARY KEY,
    nombre          VARCHAR2(100)   NOT NULL,
    rnc             VARCHAR2(15)    NOT NULL,
    telefono        VARCHAR2(20)
);

-- B) Tabla de Facturas (Módulo de Facturación)
CREATE TABLE FACTURAS (
    id_factura          VARCHAR2(20)    PRIMARY KEY,
    id_cliente          NUMBER(6)       NOT NULL REFERENCES CLIENTES(id_cliente),
    fecha_emision       DATE            DEFAULT SYSDATE NOT NULL,
    monto_total         NUMBER(12,2)    NOT NULL,
    condiciones_pago    VARCHAR2(15)    NOT NULL, -- 'CREDITO' o 'CONTADO'
    concepto            VARCHAR2(200),
    CONSTRAINT CHK_COND_PAGO CHECK (UPPER(condiciones_pago) IN ('CREDITO', 'CONTADO')),
    CONSTRAINT CHK_MONTO_POS CHECK (monto_total > 0)
);

-- C) Tabla de Cuentas por Cobrar (Módulo de Cuentas x Cobrar)
-- Esta tabla es alimentada automáticamente por el Trigger cuando la factura es a crédito
CREATE TABLE CUENTAS_POR_COBRAR (
    id_cxc          NUMBER(10)      PRIMARY KEY,
    id_factura      VARCHAR2(20)    NOT NULL REFERENCES FACTURAS(id_factura),
    id_cliente      NUMBER(6)       NOT NULL REFERENCES CLIENTES(id_cliente),
    fecha_cxc       DATE            NOT NULL,
    monto_deuda     NUMBER(12,2)    NOT NULL,
    estado          VARCHAR2(15)    DEFAULT 'PENDIENTE' NOT NULL,
    CONSTRAINT CHK_ESTADO_CXC CHECK (estado IN ('PENDIENTE', 'PAGADA', 'ANULADA'))
);

-- ----------------------------------------------------------------------------
-- 4. EL DISPARADOR (TRIGGER) DE INTEGRACIÓN
-- ----------------------------------------------------------------------------
-- DESCRIPCIÓN:
-- Cuando se inserta una fila en FACTURAS, el trigger lee el campo condiciones_pago:
-- - Si es 'CREDITO': toma el ID del cliente, fecha y monto de la factura (:NEW),
--   y genera automáticamente la deuda en CUENTAS_POR_COBRAR.
-- - Si es 'CONTADO': no genera ninguna deuda, obvia el registro y finaliza.

CREATE OR REPLACE TRIGGER TRG_FACTURA_A_CXC
AFTER INSERT ON FACTURAS
FOR EACH ROW
BEGIN
    -- Evaluamos si las condiciones de pago son a CRÉDITO:
    IF UPPER(:NEW.condiciones_pago) = 'CREDITO' THEN

        -- Tomamos los datos de la factura e insertamos en Cuentas por Cobrar:
        INSERT INTO CUENTAS_POR_COBRAR (
            id_cxc,
            id_factura,
            id_cliente,
            fecha_cxc,
            monto_deuda,
            estado
        ) VALUES (
            SEQ_CXC.NEXTVAL,
            :NEW.id_factura,
            :NEW.id_cliente,
            :NEW.fecha_emision,
            :NEW.monto_total,
            'PENDIENTE'
        );

        DBMS_OUTPUT.PUT_LINE('>> [TRIGGER DISPARADO] Factura ' || :NEW.id_factura ||
                             ' es a CREDITO. Deuda generada en CxC por RD$ ' || :NEW.monto_total);

    ELSE
        -- Si es CONTADO, no se crea deuda en Cuentas por Cobrar
        DBMS_OUTPUT.PUT_LINE('>> [TRIGGER IGNORADO] Factura ' || :NEW.id_factura ||
                             ' es al CONTADO. No se genera deuda.');
    END IF;
END TRG_FACTURA_A_CXC;
/

-- ----------------------------------------------------------------------------
-- 5. DATOS MAESTROS DE PRUEBA
-- ----------------------------------------------------------------------------
INSERT INTO CLIENTES (id_cliente, nombre, rnc, telefono)
VALUES (101, 'Centro Médico Nacional', '401-23456-7', '(809) 555-3001');

INSERT INTO CLIENTES (id_cliente, nombre, rnc, telefono)
VALUES (102, 'Clínica Abreu', '131-56789-0', '(809) 555-3002');

INSERT INTO CLIENTES (id_cliente, nombre, rnc, telefono)
VALUES (103, 'Hospital Dr. Moscoso Puello', '101-23489-0', '(809) 555-3003');

INSERT INTO CLIENTES (id_cliente, nombre, rnc, telefono)
VALUES (104, 'Farmacia Popular Sucursal', '402-34567-8', '(809) 555-3004');

INSERT INTO CLIENTES (id_cliente, nombre, rnc, telefono)
VALUES (105, 'Juan Pérez Almonte', '001-23456-7', '(809) 555-9090');

COMMIT;

-- ----------------------------------------------------------------------------
-- 6. DEMOSTRACIÓN PRÁCTICA DEL TRIGGER EN ACCIÓN
-- ----------------------------------------------------------------------------

PROMPT =========================================================================;
PROMPT CASO 1: INSERTANDO FACTURA A CREDITO (FAC-1001) -> DEBE GENERAR CXC;
PROMPT =========================================================================;
INSERT INTO FACTURAS (id_factura, id_cliente, fecha_emision, monto_total, condiciones_pago, concepto)
VALUES ('FAC-1001', 101, DATE '2026-10-20', 12500.00, 'CREDITO', 'Antibioticos e insumos quirurgicos');

PROMPT =========================================================================;
PROMPT CASO 2: INSERTANDO FACTURA AL CONTADO (FAC-1002) -> NO DEBE GENERAR CXC;
PROMPT =========================================================================;
INSERT INTO FACTURAS (id_factura, id_cliente, fecha_emision, monto_total, condiciones_pago, concepto)
VALUES ('FAC-1002', 105, DATE '2026-10-21', 1850.00, 'CONTADO', 'Analgesicos venta libre');

PROMPT =========================================================================;
PROMPT CASO 3: INSERTANDO OTRA FACTURA A CREDITO (FAC-1003) -> DEBE GENERAR CXC;
PROMPT =========================================================================;
INSERT INTO FACTURAS (id_factura, id_cliente, fecha_emision, monto_total, condiciones_pago, concepto)
VALUES ('FAC-1003', 102, DATE '2026-10-22', 24700.00, 'CREDITO', 'Lote de sueros y soluciones');

COMMIT;

-- ----------------------------------------------------------------------------
-- 7. CONSULTAS DE COMPROBACIÓN FINAL
-- ----------------------------------------------------------------------------
PROMPT;
PROMPT >> RESULTADOS EN LA TABLA [FACTURAS]:;
SELECT id_factura, id_cliente, TO_CHAR(fecha_emision, 'YYYY-MM-DD') AS fecha, condiciones_pago, monto_total
FROM FACTURAS
ORDER BY id_factura;

PROMPT;
PROMPT >> RESULTADOS EN LA TABLA [CUENTAS_POR_COBRAR] (ALIMENTADA POR EL TRIGGER):;
SELECT id_cxc, id_factura, id_cliente, TO_CHAR(fecha_cxc, 'YYYY-MM-DD') AS fecha, monto_deuda, estado
FROM CUENTAS_POR_COBRAR
ORDER BY id_cxc;

PROMPT;
PROMPT >> OBSERVACION: Solo las facturas FAC-1001 y FAC-1003 (a CREDITO) tienen registro en CUENTAS_POR_COBRAR.;
PROMPT >> La factura FAC-1002 (al CONTADO) fue obviada por el trigger y no genero deuda.;
