-- ============================================================================
-- PROYECTO: INTEGRACIÓN DE FACTURACIÓN Y CUENTAS POR COBRAR — FARMACIA CAROL
-- ASIGNATURA: ISO810 - INTEGRACIÓN DE SISTEMAS / BASES DE DATOS
-- TECNOLOGÍA: ORACLE 19c / 21c (PL/SQL, TRIGGERS, PACKAGES, VIEWS, SCHEDULER)
-- DESCRIPCIÓN: Script integral de base de datos que demuestra la integración
--              automática de Facturación con Cuentas por Cobrar mediante
--              tecnología propietaria de BD (Triggers, Sequences, Procedures,
--              Packages, Vistas Materializadas y Jobs Programados).
-- ============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED;
WHENEVER SQLERROR CONTINUE;

-- ----------------------------------------------------------------------------
-- 1. LIMPIEZA DE OBJETOS PREVIOS (DROP IF EXISTS)
-- ----------------------------------------------------------------------------
PROMPT >> Limpiando objetos existentes...;

BEGIN
    FOR cur_job IN (SELECT job_name FROM user_scheduler_jobs WHERE job_name = 'JOB_ACTUALIZAR_MORA') LOOP
        DBMS_SCHEDULER.DROP_JOB(cur_job.job_name, force => TRUE);
    END LOOP;
END;
/

DROP MATERIALIZED VIEW MV_AGING_CARTERA_RESUMEN;
DROP VIEW VW_ESTADO_CREDITO_CLIENTES;
DROP VIEW VW_FACTURAS_INTEGRADAS_CXC;

DROP TRIGGER TRG_BI_FACTURAS;
DROP TRIGGER TRG_AI_FACTURAS;
DROP TRIGGER TRG_AI_PAGOS_CXC;
DROP TRIGGER TRG_AI_NOTAS_CREDITO;
DROP TRIGGER TRG_BU_CUENTAS_POR_COBRAR;

DROP PACKAGE BODY PKG_FARMACIA_CAROL;
DROP PACKAGE PKG_FARMACIA_CAROL;

DROP PROCEDURE SP_CREAR_FACTURA_CREDITO;
DROP PROCEDURE SP_REGISTRAR_PAGO_CXC;
DROP PROCEDURE SP_ACTUALIZAR_MORA;
DROP PROCEDURE SP_GENERAR_NCF;
DROP PROCEDURE SP_LOG_AUDITORIA_AUTONOMA;

DROP TABLE AUDITORIA_TRIGGERS CASCADE CONSTRAINTS;
DROP TABLE CONTROL_NCF CASCADE CONSTRAINTS;
DROP TABLE PAGOS_CXC CASCADE CONSTRAINTS;
DROP TABLE NOTAS_CREDITO CASCADE CONSTRAINTS;
DROP TABLE CUENTAS_POR_COBRAR CASCADE CONSTRAINTS;
DROP TABLE FACTURA_DETALLE CASCADE CONSTRAINTS;
DROP TABLE FACTURAS CASCADE CONSTRAINTS;
DROP TABLE PRODUCTOS CASCADE CONSTRAINTS;
DROP TABLE CATEGORIAS_PRODUCTO CASCADE CONSTRAINTS;
DROP TABLE CLIENTES CASCADE CONSTRAINTS;

DROP SEQUENCE SEQ_CLIENTE;
DROP SEQUENCE SEQ_PRODUCTO;
DROP SEQUENCE SEQ_FACTURA;
DROP SEQUENCE SEQ_FACTURA_DETALLE;
DROP SEQUENCE SEQ_CXC;
DROP SEQUENCE SEQ_PAGO;
DROP SEQUENCE SEQ_NOTA_CREDITO;
DROP SEQUENCE SEQ_AUDITORIA;

WHENEVER SQLERROR EXIT FAILURE ROLLBACK;

-- ----------------------------------------------------------------------------
-- 2. SECUENCIAS (SEQUENCES) — GENERACIÓN CONCURRENTE Y SIN BLOQUEOS
-- ----------------------------------------------------------------------------
PROMPT >> Creando Secuencias...;

CREATE SEQUENCE SEQ_CLIENTE         START WITH 10 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_PRODUCTO        START WITH 100 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_FACTURA         START WITH 1045 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_FACTURA_DETALLE START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_CXC             START WITH 3020 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_PAGO            START WITH 5010 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_NOTA_CREDITO    START WITH 200 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_AUDITORIA       START WITH 1 INCREMENT BY 1 NOCACHE;

-- ----------------------------------------------------------------------------
-- 3. MODELO RELACIONAL DE TABLAS
-- ----------------------------------------------------------------------------
PROMPT >> Creando Tablas del Sistema...;

-- Tabla de Clientes con Política de Crédito
CREATE TABLE CLIENTES (
    id              NUMBER(10)          PRIMARY KEY,
    rnc             VARCHAR2(11)        NOT NULL UNIQUE,
    nombre          VARCHAR2(150)       NOT NULL,
    tipo            VARCHAR2(15)        DEFAULT 'CONTADO' NOT NULL,
    limite_credito  NUMBER(12,2)        DEFAULT 0.00 NOT NULL,
    dias_credito    NUMBER(4)           DEFAULT 0 NOT NULL,
    balance         NUMBER(12,2)        DEFAULT 0.00 NOT NULL,
    contacto        VARCHAR2(100),
    telefono        VARCHAR2(20),
    email           VARCHAR2(100),
    estado          VARCHAR2(15)        DEFAULT 'ACTIVO' NOT NULL,
    CONSTRAINT CHK_CLI_TIPO CHECK (tipo IN ('CONTADO', 'CREDITO')),
    CONSTRAINT CHK_CLI_ESTADO CHECK (estado IN ('ACTIVO', 'BLOQUEADO', 'INACTIVO')),
    CONSTRAINT CHK_CLI_LIMITE CHECK (limite_credito >= 0),
    CONSTRAINT CHK_CLI_BALANCE CHECK (balance >= 0)
);

-- Tabla de Categorías de Medicamentos e Insumos
CREATE TABLE CATEGORIAS_PRODUCTO (
    id              NUMBER(5)           PRIMARY KEY,
    nombre          VARCHAR2(60)        NOT NULL UNIQUE,
    descripcion     VARCHAR2(200)
);

-- Tabla de Productos Farmacéuticos
CREATE TABLE PRODUCTOS (
    id              NUMBER(10)          PRIMARY KEY,
    codigo          VARCHAR2(20)        NOT NULL UNIQUE,
    categoria_id    NUMBER(5)           REFERENCES CATEGORIAS_PRODUCTO(id),
    nombre          VARCHAR2(150)       NOT NULL,
    precio          NUMBER(10,2)        NOT NULL,
    costo           NUMBER(10,2)        NOT NULL,
    stock           NUMBER(8)           DEFAULT 0 NOT NULL,
    aplica_itbis    CHAR(1)             DEFAULT 'S' NOT NULL,
    estado          VARCHAR2(15)        DEFAULT 'ACTIVO' NOT NULL,
    CONSTRAINT CHK_PROD_ITBIS CHECK (aplica_itbis IN ('S', 'N')),
    CONSTRAINT CHK_PROD_PRECIO CHECK (precio >= 0),
    CONSTRAINT CHK_PROD_STOCK CHECK (stock >= 0)
);

-- Tabla de Facturas (Módulo de Facturación)
CREATE TABLE FACTURAS (
    id              NUMBER(10)          PRIMARY KEY,
    ncf             VARCHAR2(19)        NOT NULL UNIQUE,
    fecha           DATE                DEFAULT SYSDATE NOT NULL,
    cliente_id      NUMBER(10)          NOT NULL REFERENCES CLIENTES(id),
    subtotal        NUMBER(12,2)        DEFAULT 0.00 NOT NULL,
    itbis           NUMBER(12,2)        DEFAULT 0.00 NOT NULL,
    total           NUMBER(12,2)        DEFAULT 0.00 NOT NULL,
    tipo_pago       VARCHAR2(15)        NOT NULL,
    estado          VARCHAR2(20)        DEFAULT 'PENDIENTE' NOT NULL,
    notas           VARCHAR2(250),
    creado_por      VARCHAR2(50)        DEFAULT USER,
    fecha_creacion  TIMESTAMP           DEFAULT SYSTIMESTAMP,
    CONSTRAINT CHK_FACT_PAGO CHECK (tipo_pago IN ('CONTADO', 'CREDITO')),
    CONSTRAINT CHK_FACT_ESTADO CHECK (estado IN ('PENDIENTE', 'PARCIAL', 'PAGADA', 'VENCIDA', 'ANULADA')),
    CONSTRAINT CHK_FACT_TOTAL CHECK (total >= 0)
);

-- Tabla de Detalle de Factura
CREATE TABLE FACTURA_DETALLE (
    id              NUMBER(12)          PRIMARY KEY,
    factura_id      NUMBER(10)          NOT NULL REFERENCES FACTURAS(id) ON DELETE CASCADE,
    producto_id     NUMBER(10)          NOT NULL REFERENCES PRODUCTOS(id),
    cantidad        NUMBER(6)           NOT NULL,
    precio_unitario NUMBER(10,2)        NOT NULL,
    itbis_monto     NUMBER(10,2)        DEFAULT 0.00 NOT NULL,
    total_linea     NUMBER(12,2)        NOT NULL,
    CONSTRAINT CHK_DET_CANT CHECK (cantidad > 0)
);

-- Tabla de Cuentas por Cobrar (Módulo de Cuentas x Cobrar — CxC)
CREATE TABLE CUENTAS_POR_COBRAR (
    id                  NUMBER(10)      PRIMARY KEY,
    factura_id          NUMBER(10)      NOT NULL UNIQUE REFERENCES FACTURAS(id),
    cliente_id          NUMBER(10)      NOT NULL REFERENCES CLIENTES(id),
    monto_original      NUMBER(12,2)    NOT NULL,
    monto_pagado        NUMBER(12,2)    DEFAULT 0.00 NOT NULL,
    saldo               NUMBER(12,2)    NOT NULL,
    fecha_emision       DATE            NOT NULL,
    fecha_vencimiento   DATE            NOT NULL,
    estado              VARCHAR2(20)    DEFAULT 'PENDIENTE' NOT NULL,
    dias_mora           NUMBER(5)       DEFAULT 0 NOT NULL,
    fecha_actualizacion TIMESTAMP       DEFAULT SYSTIMESTAMP,
    CONSTRAINT CHK_CXC_ESTADO CHECK (estado IN ('PENDIENTE', 'PARCIAL', 'PAGADA', 'VENCIDA', 'INCOBRABLE')),
    CONSTRAINT CHK_CXC_PAGADO CHECK (monto_pagado >= 0),
    CONSTRAINT CHK_CXC_SALDO CHECK (saldo >= 0),
    CONSTRAINT CHK_CXC_FECHAS CHECK (fecha_vencimiento >= fecha_emision)
);

-- Tabla de Pagos de Cuentas por Cobrar
CREATE TABLE PAGOS_CXC (
    id              NUMBER(10)          PRIMARY KEY,
    cxc_id          NUMBER(10)          NOT NULL REFERENCES CUENTAS_POR_COBRAR(id),
    monto           NUMBER(12,2)        NOT NULL,
    fecha           DATE                DEFAULT SYSDATE NOT NULL,
    metodo          VARCHAR2(25)        NOT NULL,
    referencia      VARCHAR2(60)        NOT NULL,
    banco           VARCHAR2(60),
    registrado_por  VARCHAR2(50)        DEFAULT USER,
    fecha_registro  TIMESTAMP           DEFAULT SYSTIMESTAMP,
    CONSTRAINT CHK_PAGO_METODO CHECK (metodo IN ('EFECTIVO', 'TRANSFERENCIA', 'CHEQUE', 'TARJETA')),
    CONSTRAINT CHK_PAGO_MONTO CHECK (monto > 0)
);

-- Tabla de Notas de Crédito
CREATE TABLE NOTAS_CREDITO (
    id              NUMBER(10)          PRIMARY KEY,
    ncf             VARCHAR2(19)        NOT NULL UNIQUE,
    factura_id      NUMBER(10)          NOT NULL REFERENCES FACTURAS(id),
    monto           NUMBER(12,2)        NOT NULL,
    motivo          VARCHAR2(200)       NOT NULL,
    fecha           DATE                DEFAULT SYSDATE NOT NULL,
    creado_por      VARCHAR2(50)        DEFAULT USER,
    CONSTRAINT CHK_NC_MONTO CHECK (monto > 0)
);

-- Tabla de Auditoría Autónoma para Triggers (Garantiza trazabilidad forense)
CREATE TABLE AUDITORIA_TRIGGERS (
    id              NUMBER(12)          PRIMARY KEY,
    trigger_name    VARCHAR2(60)        NOT NULL,
    evento          VARCHAR2(20)        NOT NULL,
    tabla_afectada  VARCHAR2(40)        NOT NULL,
    registro_id     NUMBER(10),
    detalles        VARCHAR2(4000),
    usuario         VARCHAR2(50)        DEFAULT USER,
    ip_origen       VARCHAR2(60),
    fecha           TIMESTAMP           DEFAULT SYSTIMESTAMP
);

-- Tabla de Control Fiscal DGII para Secuencias de NCF
CREATE TABLE CONTROL_NCF (
    id              NUMBER(10)          GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    serie           VARCHAR2(3)         NOT NULL,
    secuencia       NUMBER(8)           NOT NULL,
    ncf             VARCHAR2(19)        NOT NULL UNIQUE,
    fecha_uso       DATE                DEFAULT SYSDATE NOT NULL,
    factura_id      NUMBER(10)
);

-- ----------------------------------------------------------------------------
-- 4. PROCEDIMIENTO AUTÓNOMO DE AUDITORÍA (PRAGMA AUTONOMOUS_TRANSACTION)
-- ----------------------------------------------------------------------------
PROMPT >> Creando Procedimiento Autónomo de Auditoría...;

CREATE OR REPLACE PROCEDURE SP_LOG_AUDITORIA_AUTONOMA (
    p_trigger_name    IN VARCHAR2,
    p_evento          IN VARCHAR2,
    p_tabla_afectada  IN VARCHAR2,
    p_registro_id     IN NUMBER,
    p_detalles        IN VARCHAR2
) AS
    PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
    INSERT INTO AUDITORIA_TRIGGERS (
        id, trigger_name, evento, tabla_afectada, registro_id, detalles, usuario, ip_origen, fecha
    ) VALUES (
        SEQ_AUDITORIA.NEXTVAL,
        p_trigger_name,
        p_evento,
        p_tabla_afectada,
        p_registro_id,
        p_detalles,
        USER,
        SYS_CONTEXT('USERENV', 'IP_ADDRESS'),
        SYSTIMESTAMP
    );
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
END SP_LOG_AUDITORIA_AUTONOMA;
/

-- ----------------------------------------------------------------------------
-- 5. PROCEDIMIENTOS ALMACENADOS (STORED PROCEDURES)
-- ----------------------------------------------------------------------------
PROMPT >> Creando Procedimientos Almacenados...;

-- Procedimiento para Formatear y Asignar NCF (DGII República Dominicana)
CREATE OR REPLACE PROCEDURE SP_GENERAR_NCF (
    p_serie         IN  VARCHAR2,
    p_secuencia     IN  NUMBER,
    p_ncf           OUT VARCHAR2
) AS
BEGIN
    p_ncf := p_serie || LPAD(p_secuencia, 8, '0');
END SP_GENERAR_NCF;
/

-- Procedimiento por Lote: Recalcular Días de Mora con CURSOR EXPLÍCITO y FOR UPDATE
CREATE OR REPLACE PROCEDURE SP_ACTUALIZAR_MORA (
    p_fecha_corte   IN DATE DEFAULT SYSDATE,
    p_afectados     OUT NUMBER
) AS
    CURSOR c_cxc IS
        SELECT id, factura_id, fecha_vencimiento, estado
        FROM   CUENTAS_POR_COBRAR
        WHERE  estado NOT IN ('PAGADA', 'INCOBRABLE')
        FOR UPDATE OF dias_mora, estado;

    v_dias_mora NUMBER;
    v_contador  NUMBER := 0;
BEGIN
    FOR r IN c_cxc LOOP
        v_dias_mora := GREATEST(0, TRUNC(p_fecha_corte) - TRUNC(r.fecha_vencimiento));

        IF v_dias_mora > 0 THEN
            UPDATE CUENTAS_POR_COBRAR
            SET    dias_mora = v_dias_mora,
                   estado    = 'VENCIDA',
                   fecha_actualizacion = SYSTIMESTAMP
            WHERE CURRENT OF c_cxc;

            UPDATE FACTURAS
            SET    estado = 'VENCIDA'
            WHERE  id = r.factura_id
              AND  estado NOT IN ('PAGADA', 'ANULADA');

            v_contador := v_contador + 1;
        ELSE
            UPDATE CUENTAS_POR_COBRAR
            SET    dias_mora = 0,
                   fecha_actualizacion = SYSTIMESTAMP
            WHERE CURRENT OF c_cxc;
        END IF;
    END LOOP;

    p_afectados := v_contador;

    SP_LOG_AUDITORIA_AUTONOMA(
        p_trigger_name   => 'BATCH_JOB',
        p_evento         => 'EXECUTE',
        p_tabla_afectada => 'CUENTAS_POR_COBRAR',
        p_registro_id    => NULL,
        p_detalles       => 'SP_ACTUALIZAR_MORA ejecutado. Cuentas en mora actualizadas: ' || v_contador
    );

    COMMIT;
END SP_ACTUALIZAR_MORA;
/

-- ----------------------------------------------------------------------------
-- 6. DISPARADORES (TRIGGERS) — NÚCLEO DE LA INTEGRACIÓN PROPIETARIA
-- ----------------------------------------------------------------------------
PROMPT >> Creando Disparadores (Triggers)...;

-- TRIGGER 1: BEFORE INSERT en FACTURAS
-- Valida límite de crédito, cuentas vencidas y auto-asigna NCF/ID si no vienen dados.
CREATE OR REPLACE TRIGGER TRG_BI_FACTURAS
BEFORE INSERT ON FACTURAS
FOR EACH ROW
DECLARE
    v_limite        CLIENTES.limite_credito%TYPE;
    v_balance       CLIENTES.balance%TYPE;
    v_tipo_cli      CLIENTES.tipo%TYPE;
    v_estado_cli    CLIENTES.estado%TYPE;
    v_vencidas      NUMBER := 0;
    v_ncf_seq       NUMBER;
BEGIN
    -- 1. Asignar ID de factura por secuencia si viene nulo
    IF :NEW.id IS NULL THEN
        :NEW.id := SEQ_FACTURA.NEXTVAL;
    END IF;

    -- 2. Consultar políticas del cliente
    SELECT tipo, limite_credito, balance, estado
    INTO   v_tipo_cli, v_limite, v_balance, v_estado_cli
    FROM   CLIENTES
    WHERE  id = :NEW.cliente_id;

    -- Validar estado del cliente
    IF v_estado_cli <> 'ACTIVO' THEN
        RAISE_APPLICATION_ERROR(-20001, 'CLIENTE BLOQUEADO: El cliente #' || :NEW.cliente_id || ' se encuentra en estado ' || v_estado_cli);
    END IF;

    -- 3. Reglas de Negocio para Facturación a CRÉDITO
    IF :NEW.tipo_pago = 'CREDITO' THEN
        IF v_tipo_cli <> 'CREDITO' THEN
            RAISE_APPLICATION_ERROR(-20002, 'POLITICA DE CREDITO: El cliente #' || :NEW.cliente_id || ' está configurado como CONTADO.');
        END IF;

        -- Verificar si tiene facturas vencidas impagas
        SELECT COUNT(*)
        INTO   v_vencidas
        FROM   CUENTAS_POR_COBRAR
        WHERE  cliente_id = :NEW.cliente_id
          AND  estado = 'VENCIDA'
          AND  saldo > 0;

        IF v_vencidas > 0 THEN
            RAISE_APPLICATION_ERROR(-20003, 'CREDITO SUSPENDIDO: El cliente tiene ' || v_vencidas || ' factura(s) vencida(s) pendiente(s) de cobro.');
        END IF;

        -- Verificar límite de crédito disponible
        IF (v_balance + :NEW.total) > v_limite THEN
            RAISE_APPLICATION_ERROR(-20004, 'LIMITE EXCEDIDO: La factura por RD$ ' || :NEW.total ||
                                    ' excede el límite disponible (Límite: ' || v_limite || ', Balance actual: ' || v_balance || ').');
        END IF;
    END IF;

    -- 4. Asignación automática de NCF Fiscal si no viene especificado
    IF :NEW.ncf IS NULL OR :NEW.ncf = '' THEN
        v_ncf_seq := :NEW.id;
        SP_GENERAR_NCF('B01', v_ncf_seq, :NEW.ncf);
    END IF;
END TRG_BI_FACTURAS;
/

-- TRIGGER 2: AFTER INSERT en FACTURAS
-- Si la venta es a CRÉDITO, automáticamente crea la CUENTA POR COBRAR y ajusta el balance del cliente.
CREATE OR REPLACE TRIGGER TRG_AI_FACTURAS
AFTER INSERT ON FACTURAS
FOR EACH ROW
DECLARE
    v_cxc_id        NUMBER;
    v_dias_credito  NUMBER;
    v_fecha_venc    DATE;
BEGIN
    -- Solo si la factura es a crédito se integra automáticamente con CxC
    IF :NEW.tipo_pago = 'CREDITO' THEN
        v_cxc_id := SEQ_CXC.NEXTVAL;

        -- Obtener los días de crédito pactados con el cliente
        SELECT dias_credito
        INTO   v_dias_credito
        FROM   CLIENTES
        WHERE  id = :NEW.cliente_id;

        v_fecha_venc := :NEW.fecha + NVL(v_dias_credito, 30);

        -- A) Generar registro en CUENTAS_POR_COBRAR
        INSERT INTO CUENTAS_POR_COBRAR (
            id,
            factura_id,
            cliente_id,
            monto_original,
            monto_pagado,
            saldo,
            fecha_emision,
            fecha_vencimiento,
            estado,
            dias_mora,
            fecha_actualizacion
        ) VALUES (
            v_cxc_id,
            :NEW.id,
            :NEW.cliente_id,
            :NEW.total,
            0.00,
            :NEW.total,
            :NEW.fecha,
            v_fecha_venc,
            'PENDIENTE',
            0,
            SYSTIMESTAMP
        );

        -- B) Incrementar balance adeudado del cliente
        UPDATE CLIENTES
        SET    balance = balance + :NEW.total
        WHERE  id = :NEW.cliente_id;

        -- C) Auditoría Autónoma
        SP_LOG_AUDITORIA_AUTONOMA(
            p_trigger_name   => 'TRG_AI_FACTURAS',
            p_evento         => 'INSERT',
            p_tabla_afectada => 'CUENTAS_POR_COBRAR',
            p_registro_id    => v_cxc_id,
            p_detalles       => 'Factura #' || :NEW.id || ' (' || :NEW.ncf || ') a crédito generó CxC #' || v_cxc_id ||
                                ' por RD$ ' || :NEW.total || ' con vencimiento al ' || TO_CHAR(v_fecha_venc, 'YYYY-MM-DD')
        );
    END IF;
END TRG_AI_FACTURAS;
/

-- TRIGGER 3: AFTER INSERT en PAGOS_CXC
-- Cuando se registra un abono o cancelación de cuenta, actualiza CxC, Factura y Balance del Cliente.
CREATE OR REPLACE TRIGGER TRG_AI_PAGOS_CXC
AFTER INSERT ON PAGOS_CXC
FOR EACH ROW
DECLARE
    v_cxc_id        CUENTAS_POR_COBRAR.id%TYPE;
    v_factura_id    CUENTAS_POR_COBRAR.factura_id%TYPE;
    v_cliente_id    CUENTAS_POR_COBRAR.cliente_id%TYPE;
    v_original      CUENTAS_POR_COBRAR.monto_original%TYPE;
    v_pagado_prev   CUENTAS_POR_COBRAR.monto_pagado%TYPE;
    v_nuevo_pagado  NUMBER(12,2);
    v_nuevo_saldo   NUMBER(12,2);
    v_nuevo_estado  VARCHAR2(20);
BEGIN
    -- 1. Obtener datos actuales de la CxC con bloqueo pesimista
    SELECT id, factura_id, cliente_id, monto_original, monto_pagado
    INTO   v_cxc_id, v_factura_id, v_cliente_id, v_original, v_pagado_prev
    FROM   CUENTAS_POR_COBRAR
    WHERE  id = :NEW.cxc_id
    FOR UPDATE;

    v_nuevo_pagado := v_pagado_prev + :NEW.monto;
    v_nuevo_saldo  := v_original - v_nuevo_pagado;

    IF v_nuevo_saldo < 0 THEN
        RAISE_APPLICATION_ERROR(-20005, 'SOBREPAGO: El abono de RD$ ' || :NEW.monto || ' excede el saldo pendiente de RD$ ' || (v_original - v_pagado_prev));
    END IF;

    -- 2. Determinar nuevo estado de la CxC
    IF v_nuevo_saldo = 0 THEN
        v_nuevo_estado := 'PAGADA';
    ELSE
        v_nuevo_estado := 'PARCIAL';
    END IF;

    -- 3. Actualizar la Cuenta por Cobrar
    UPDATE CUENTAS_POR_COBRAR
    SET    monto_pagado = v_nuevo_pagado,
           saldo        = v_nuevo_saldo,
           estado       = v_nuevo_estado,
           fecha_actualizacion = SYSTIMESTAMP
    WHERE  id = :NEW.cxc_id;

    -- 4. Propagar estado a la FACTURA
    UPDATE FACTURAS
    SET    estado = v_nuevo_estado
    WHERE  id = v_factura_id;

    -- 5. Disminuir el balance del Cliente
    UPDATE CLIENTES
    SET    balance = GREATEST(0, balance - :NEW.monto)
    WHERE  id = v_cliente_id;

    -- 6. Auditoría de integración
    SP_LOG_AUDITORIA_AUTONOMA(
        p_trigger_name   => 'TRG_AI_PAGOS_CXC',
        p_evento         => 'INSERT',
        p_tabla_afectada => 'PAGOS_CXC',
        p_registro_id    => :NEW.id,
        p_detalles       => 'Pago #' || :NEW.id || ' de RD$ ' || :NEW.monto || ' (' || :NEW.metodo || ') aplicado a CxC #' ||
                            :NEW.cxc_id || '. Nuevo saldo: RD$ ' || v_nuevo_saldo || ' [' || v_nuevo_estado || ']'
    );
END TRG_AI_PAGOS_CXC;
/

-- TRIGGER 4: AFTER INSERT en NOTAS_CREDITO
-- Aplica nota de crédito a la factura y a la CxC vinculada.
CREATE OR REPLACE TRIGGER TRG_AI_NOTAS_CREDITO
AFTER INSERT ON NOTAS_CREDITO
FOR EACH ROW
DECLARE
    v_cxc_id        NUMBER;
    v_cliente_id    NUMBER;
    v_saldo_act     NUMBER(12,2);
    v_nuevo_saldo   NUMBER(12,2);
    v_nuevo_estado  VARCHAR2(20);
BEGIN
    SELECT id, cliente_id, saldo
    INTO   v_cxc_id, v_cliente_id, v_saldo_act
    FROM   CUENTAS_POR_COBRAR
    WHERE  factura_id = :NEW.factura_id
    FOR UPDATE;

    v_nuevo_saldo := GREATEST(0, v_saldo_act - :NEW.monto);

    IF v_nuevo_saldo = 0 THEN
        v_nuevo_estado := 'PAGADA';
    ELSE
        v_nuevo_estado := 'PARCIAL';
    END IF;

    UPDATE CUENTAS_POR_COBRAR
    SET    saldo = v_nuevo_saldo,
           estado = v_nuevo_estado,
           fecha_actualizacion = SYSTIMESTAMP
    WHERE  id = v_cxc_id;

    UPDATE FACTURAS
    SET    estado = v_nuevo_estado
    WHERE  id = :NEW.factura_id;

    UPDATE CLIENTES
    SET    balance = GREATEST(0, balance - :NEW.monto)
    WHERE  id = v_cliente_id;

    SP_LOG_AUDITORIA_AUTONOMA(
        p_trigger_name   => 'TRG_AI_NOTAS_CREDITO',
        p_evento         => 'INSERT',
        p_tabla_afectada => 'NOTAS_CREDITO',
        p_registro_id    => :NEW.id,
        p_detalles       => 'Nota de Crédito #' || :NEW.id || ' de RD$ ' || :NEW.monto || ' aplicada a Factura #' || :NEW.factura_id
    );
END TRG_AI_NOTAS_CREDITO;
/

-- TRIGGER 5: BEFORE UPDATE en CUENTAS_POR_COBRAR
-- Control de integridad defensivo para evitar inconsistencias de montos
CREATE OR REPLACE TRIGGER TRG_BU_CUENTAS_POR_COBRAR
BEFORE UPDATE ON CUENTAS_POR_COBRAR
FOR EACH ROW
BEGIN
    IF :NEW.saldo < 0 THEN
        RAISE_APPLICATION_ERROR(-20006, 'ERROR INTEGRIDAD: El saldo de una cuenta por cobrar no puede ser negativo.');
    END IF;

    IF :NEW.monto_pagado > :NEW.monto_original THEN
        RAISE_APPLICATION_ERROR(-20007, 'ERROR INTEGRIDAD: El monto pagado supera el monto original facturado.');
    END IF;
END TRG_BU_CUENTAS_POR_COBRAR;
/

-- ----------------------------------------------------------------------------
-- 7. PAQUETES (PACKAGES) — ENCAPSULAMIENTO Y RENDIMIENTO EN MEMORIA (SGA)
-- ----------------------------------------------------------------------------
PROMPT >> Creando Paquete PL/SQL (PKG_FARMACIA_CAROL)...;

CREATE OR REPLACE PACKAGE PKG_FARMACIA_CAROL AS
    -- Constantes Institucionales
    C_TASA_ITBIS            CONSTANT NUMBER(4,2) := 0.18;
    C_RNC_FARMACIA          CONSTANT VARCHAR2(11) := '130987654';
    C_RAZON_SOCIAL          CONSTANT VARCHAR2(100) := 'Farmacia Carol, S.R.L.';

    -- Tipos Compuestos PL/SQL
    TYPE r_aging_bracket IS RECORD (
        rango       VARCHAR2(30),
        cantidad    NUMBER,
        monto_total NUMBER(14,2)
    );
    TYPE t_aging_brackets IS TABLE OF r_aging_bracket;

    -- Funciones Públicas
    FUNCTION FN_CALCULAR_ITBIS(
        p_monto     IN NUMBER,
        p_gravado   IN CHAR DEFAULT 'S'
    ) RETURN NUMBER;

    FUNCTION FN_VERIFICAR_CREDITO(
        p_cliente_id IN NUMBER,
        p_monto      IN NUMBER
    ) RETURN BOOLEAN;

    FUNCTION FN_OBTENER_SALDO_CLIENTE(
        p_cliente_id IN NUMBER
    ) RETURN NUMBER;

    -- Procedimientos Públicos
    PROCEDURE SP_CREAR_FACTURA_CREDITO (
        p_cliente_id    IN  NUMBER,
        p_subtotal      IN  NUMBER,
        p_itbis         IN  NUMBER,
        p_notas         IN  VARCHAR2,
        p_factura_id    OUT NUMBER,
        p_ncf           OUT VARCHAR2,
        p_cxc_id        OUT NUMBER
    );

    PROCEDURE SP_REGISTRAR_PAGO_CXC (
        p_cxc_id        IN  NUMBER,
        p_monto         IN  NUMBER,
        p_metodo        IN  VARCHAR2,
        p_referencia    IN  VARCHAR2,
        p_banco         IN  VARCHAR2,
        p_pago_id       OUT NUMBER
    );
END PKG_FARMACIA_CAROL;
/

CREATE OR REPLACE PACKAGE BODY PKG_FARMACIA_CAROL AS

    FUNCTION FN_CALCULAR_ITBIS(
        p_monto     IN NUMBER,
        p_gravado   IN CHAR DEFAULT 'S'
    ) RETURN NUMBER IS
    BEGIN
        IF p_gravado = 'S' THEN
            RETURN ROUND(p_monto * C_TASA_ITBIS, 2);
        ELSE
            RETURN 0.00;
        END IF;
    END FN_CALCULAR_ITBIS;

    FUNCTION FN_VERIFICAR_CREDITO(
        p_cliente_id IN NUMBER,
        p_monto      IN NUMBER
    ) RETURN BOOLEAN IS
        v_limite    NUMBER;
        v_balance   NUMBER;
        v_tipo      VARCHAR2(15);
        v_vencidas  NUMBER;
    BEGIN
        SELECT tipo, limite_credito, balance
        INTO   v_tipo, v_limite, v_balance
        FROM   CLIENTES
        WHERE  id = p_cliente_id;

        IF v_tipo <> 'CREDITO' THEN
            RETURN FALSE;
        END IF;

        SELECT COUNT(*)
        INTO   v_vencidas
        FROM   CUENTAS_POR_COBRAR
        WHERE  cliente_id = p_cliente_id
          AND  estado = 'VENCIDA'
          AND  saldo > 0;

        IF v_vencidas > 0 THEN
            RETURN FALSE;
        END IF;

        IF (v_balance + p_monto) > v_limite THEN
            RETURN FALSE;
        END IF;

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN FALSE;
    END FN_VERIFICAR_CREDITO;

    FUNCTION FN_OBTENER_SALDO_CLIENTE(
        p_cliente_id IN NUMBER
    ) RETURN NUMBER IS
        v_balance NUMBER := 0;
    BEGIN
        SELECT NVL(balance, 0)
        INTO   v_balance
        FROM   CLIENTES
        WHERE  id = p_cliente_id;
        RETURN v_balance;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN 0;
    END FN_OBTENER_SALDO_CLIENTE;

    PROCEDURE SP_CREAR_FACTURA_CREDITO (
        p_cliente_id    IN  NUMBER,
        p_subtotal      IN  NUMBER,
        p_itbis         IN  NUMBER,
        p_notas         IN  VARCHAR2,
        p_factura_id    OUT NUMBER,
        p_ncf           OUT VARCHAR2,
        p_cxc_id        OUT NUMBER
    ) IS
        v_total NUMBER(12,2) := p_subtotal + p_itbis;
    BEGIN
        p_factura_id := SEQ_FACTURA.NEXTVAL;
        SP_GENERAR_NCF('B01', p_factura_id, p_ncf);

        -- Al insertar en FACTURAS, los triggers TRG_BI_FACTURAS y TRG_AI_FACTURAS se disparan automáticamente
        INSERT INTO FACTURAS (
            id, ncf, fecha, cliente_id, subtotal, itbis, total, tipo_pago, estado, notas
        ) VALUES (
            p_factura_id, p_ncf, SYSDATE, p_cliente_id, p_subtotal, p_itbis, v_total, 'CREDITO', 'PENDIENTE', p_notas
        );

        -- Recuperar la CxC que el trigger TRG_AI_FACTURAS generó
        SELECT id
        INTO   p_cxc_id
        FROM   CUENTAS_POR_COBRAR
        WHERE  factura_id = p_factura_id;

        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END SP_CREAR_FACTURA_CREDITO;

    PROCEDURE SP_REGISTRAR_PAGO_CXC (
        p_cxc_id        IN  NUMBER,
        p_monto         IN  NUMBER,
        p_metodo        IN  VARCHAR2,
        p_referencia    IN  VARCHAR2,
        p_banco         IN  VARCHAR2,
        p_pago_id       OUT NUMBER
    ) IS
    BEGIN
        p_pago_id := SEQ_PAGO.NEXTVAL;

        -- Al insertar en PAGOS_CXC, el trigger TRG_AI_PAGOS_CXC recalcula CxC, Factura y Balance
        INSERT INTO PAGOS_CXC (
            id, cxc_id, monto, fecha, metodo, referencia, banco
        ) VALUES (
            p_pago_id, p_cxc_id, p_monto, SYSDATE, p_metodo, p_referencia, p_banco
        );

        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END SP_REGISTRAR_PAGO_CXC;

END PKG_FARMACIA_CAROL;
/

-- ----------------------------------------------------------------------------
-- 8. VISTAS Y VISTAS MATERIALIZADAS (REPORTES Y AGREGACIONES)
-- ----------------------------------------------------------------------------
PROMPT >> Creando Vistas y Vista Materializada...;

-- Vista 1: Análisis Integrado de Facturas y Cuentas por Cobrar
CREATE OR REPLACE VIEW VW_FACTURAS_INTEGRADAS_CXC AS
SELECT
    f.id                AS factura_id,
    f.ncf,
    f.fecha             AS fecha_factura,
    c.id                AS cliente_id,
    c.nombre            AS cliente_nombre,
    c.rnc               AS cliente_rnc,
    f.tipo_pago,
    f.total             AS monto_facturado,
    NVL(cx.monto_pagado, 0) AS monto_cobrado,
    NVL(cx.saldo, 0)    AS saldo_pendiente,
    cx.fecha_vencimiento,
    NVL(cx.dias_mora, 0) AS dias_mora,
    f.estado            AS estado_factura,
    cx.estado           AS estado_cxc
FROM FACTURAS f
JOIN CLIENTES c ON c.id = f.cliente_id
LEFT JOIN CUENTAS_POR_COBRAR cx ON cx.factura_id = f.id;

-- Vista 2: Estado de Crédito y Utilización de Cartera por Cliente
CREATE OR REPLACE VIEW VW_ESTADO_CREDITO_CLIENTES AS
SELECT
    c.id,
    c.nombre,
    c.rnc,
    c.limite_credito,
    c.balance,
    ROUND((c.balance / NULLIF(c.limite_credito, 0)) * 100, 1) AS pct_uso_credito,
    c.dias_credito,
    (SELECT COUNT(*) FROM CUENTAS_POR_COBRAR cx WHERE cx.cliente_id = c.id AND cx.estado = 'VENCIDA' AND cx.saldo > 0) AS facturas_vencidas,
    (SELECT NVL(SUM(cx.saldo), 0) FROM CUENTAS_POR_COBRAR cx WHERE cx.cliente_id = c.id AND cx.estado IN ('PENDIENTE', 'PARCIAL', 'VENCIDA')) AS total_adeudado,
    c.estado AS estado_cliente
FROM CLIENTES c
WHERE c.tipo = 'CREDITO';

-- Vista Materializada: Aging Report (Antigüedad de Saldos 0-30, 31-60, 61-90, 90+)
-- Optimizada para Dashboards Gerenciales sin sobrecargar las tablas transaccionales.
CREATE MATERIALIZED VIEW MV_AGING_CARTERA_RESUMEN
BUILD IMMEDIATE
REFRESH COMPLETE ON DEMAND
AS
SELECT
    c.id                AS cliente_id,
    c.nombre            AS cliente_nombre,
    c.limite_credito,
    COUNT(cx.id)        AS total_cuentas_activas,
    SUM(CASE WHEN cx.dias_mora = 0 THEN cx.saldo ELSE 0 END) AS corriente_0_dias,
    SUM(CASE WHEN cx.dias_mora BETWEEN 1 AND 30 THEN cx.saldo ELSE 0 END) AS mora_1_30_dias,
    SUM(CASE WHEN cx.dias_mora BETWEEN 31 AND 60 THEN cx.saldo ELSE 0 END) AS mora_31_60_dias,
    SUM(CASE WHEN cx.dias_mora > 60 THEN cx.saldo ELSE 0 END) AS mora_mas_60_dias,
    SUM(cx.saldo)       AS total_cartera
FROM CLIENTES c
JOIN CUENTAS_POR_COBRAR cx ON cx.cliente_id = c.id
WHERE cx.estado NOT IN ('PAGADA', 'INCOBRABLE')
GROUP BY c.id, c.nombre, c.limite_credito;

-- ----------------------------------------------------------------------------
-- 9. PROGRAMACIÓN AUTOMÁTICA CON DBMS_SCHEDULER (JOB NOCTURNO)
-- ----------------------------------------------------------------------------
PROMPT >> Configurando DBMS_SCHEDULER Job Nocturno...;

BEGIN
    DBMS_SCHEDULER.CREATE_JOB (
        job_name        => 'JOB_ACTUALIZAR_MORA',
        job_type        => 'PLSQL_BLOCK',
        job_action      => 'DECLARE v_afectados NUMBER; BEGIN SP_ACTUALIZAR_MORA(SYSDATE, v_afectados); DBMS_MVIEW.REFRESH(''MV_AGING_CARTERA_RESUMEN''); END;',
        start_date      => SYSTIMESTAMP,
        repeat_interval => 'FREQ=DAILY; BYHOUR=23; BYMINUTE=00; BYSECOND=0',
        enabled         => TRUE,
        comments        => 'Job diario de Farmacia Carol: recalcula mora en CxC y refresca Vista Materializada de Aging'
    );
END;
/

-- ----------------------------------------------------------------------------
-- 10. DATOS MAESTROS Y TRANSACCIONALES DE PRUEBA
-- ----------------------------------------------------------------------------
PROMPT >> Insertando Datos Maestros y de Semilla...;

-- Clientes
INSERT INTO CLIENTES (id, rnc, nombre, tipo, limite_credito, dias_credito, balance, contacto, telefono, estado)
VALUES (1, '401234567', 'Centro Médico Nacional', 'CREDITO', 500000.00, 30, 0, 'Dr. Ramón García', '(809) 555-3001', 'ACTIVO');

INSERT INTO CLIENTES (id, rnc, nombre, tipo, limite_credito, dias_credito, balance, contacto, telefono, estado)
VALUES (2, '131567890', 'Clínica Abreu', 'CREDITO', 350000.00, 45, 0, 'Lic. Ana Matos', '(809) 555-3002', 'ACTIVO');

INSERT INTO CLIENTES (id, rnc, nombre, tipo, limite_credito, dias_credito, balance, contacto, telefono, estado)
VALUES (3, '101234890', 'Hospital Dr. Moscoso Puello', 'CREDITO', 800000.00, 60, 0, 'Ing. Carlos Vargas', '(809) 555-3003', 'ACTIVO');

INSERT INTO CLIENTES (id, rnc, nombre, tipo, limite_credito, dias_credito, balance, contacto, telefono, estado)
VALUES (4, '402345678', 'Farmacia Popular (Sucursal)', 'CREDITO', 150000.00, 15, 0, 'Sra. María López', '(809) 555-3004', 'ACTIVO');

INSERT INTO CLIENTES (id, rnc, nombre, tipo, limite_credito, dias_credito, balance, contacto, telefono, estado)
VALUES (5, '001234567', 'Juan Pérez Almonte (Cliente Particular)', 'CONTADO', 0.00, 0, 0, 'Juan Pérez', '(809) 555-9090', 'ACTIVO');

-- Categorías
INSERT INTO CATEGORIAS_PRODUCTO (id, nombre, descripcion) VALUES (1, 'Antibióticos', 'Medicamentos antimicrobianos');
INSERT INTO CATEGORIAS_PRODUCTO (id, nombre, descripcion) VALUES (2, 'Cardiovascular', 'Tratamiento de hipertensión y corazón');
INSERT INTO CATEGORIAS_PRODUCTO (id, nombre, descripcion) VALUES (3, 'Metabólico', 'Tratamiento de diabetes y colesterol');
INSERT INTO CATEGORIAS_PRODUCTO (id, nombre, descripcion) VALUES (4, 'Analgésicos', 'Alivio de dolor e inflamación');
INSERT INTO CATEGORIAS_PRODUCTO (id, nombre, descripcion) VALUES (5, 'Insumos Médicos', 'Material gastable y mascarillas');

-- Productos
INSERT INTO PRODUCTOS (id, codigo, categoria_id, nombre, precio, costo, stock, aplica_itbis)
VALUES (1, 'MED-001', 1, 'Amoxicilina 500mg (caja x 21)', 450.00, 280.00, 150, 'S');
INSERT INTO PRODUCTOS (id, codigo, categoria_id, nombre, precio, costo, stock, aplica_itbis)
VALUES (2, 'MED-002', 2, 'Losartán 50mg (caja x 30)', 380.00, 220.00, 200, 'S');
INSERT INTO PRODUCTOS (id, codigo, categoria_id, nombre, precio, costo, stock, aplica_itbis)
VALUES (3, 'MED-003', 3, 'Metformina 850mg (caja x 30)', 320.00, 190.00, 180, 'S');
INSERT INTO PRODUCTOS (id, codigo, categoria_id, nombre, precio, costo, stock, aplica_itbis)
VALUES (4, 'MED-004', 4, 'Omeprazol 20mg (caja x 14)', 280.00, 165.00, 250, 'S');
INSERT INTO PRODUCTOS (id, codigo, categoria_id, nombre, precio, costo, stock, aplica_itbis)
VALUES (5, 'MED-005', 4, 'Ibuprofeno 400mg (caja x 20)', 220.00, 130.00, 300, 'S');
INSERT INTO PRODUCTOS (id, codigo, categoria_id, nombre, precio, costo, stock, aplica_itbis)
VALUES (6, 'MED-006', 5, 'Vitamina C 1000mg (frasco x 60)', 550.00, 320.00, 120, 'N');
INSERT INTO PRODUCTOS (id, codigo, categoria_id, nombre, precio, costo, stock, aplica_itbis)
VALUES (7, 'MED-007', 5, 'Alcohol Isopropílico 70% 500ml', 180.00, 95.00, 400, 'S');
INSERT INTO PRODUCTOS (id, codigo, categoria_id, nombre, precio, costo, stock, aplica_itbis)
VALUES (8, 'MED-008', 3, 'Atorvastatina 20mg (caja x 30)', 650.00, 380.00, 90, 'S');

COMMIT;

-- ----------------------------------------------------------------------------
-- 11. DEMOSTRACIÓN DE DISPARADORES EN ACCIÓN
-- ----------------------------------------------------------------------------
PROMPT >> Insertando Facturas a Crédito (Disparo de TRG_BI_FACTURAS y TRG_AI_FACTURAS)...;

-- Factura 1040: Cliente 1 (Crédito)
INSERT INTO FACTURAS (id, ncf, fecha, cliente_id, subtotal, itbis, total, tipo_pago, estado, notas)
VALUES (1040, 'B0100001040', DATE '2026-09-15', 1, 5400.00, 972.00, 6372.00, 'CREDITO', 'PENDIENTE', 'Pedido mensual septiembre');

-- Factura 1041: Cliente 2 (Crédito)
INSERT INTO FACTURAS (id, ncf, fecha, cliente_id, subtotal, itbis, total, tipo_pago, estado, notas)
VALUES (1041, 'B0100001041', DATE '2026-09-18', 2, 3800.00, 684.00, 4484.00, 'CREDITO', 'PENDIENTE', 'Reposición de inventario');

-- Factura 1042: Cliente 3 (Crédito)
INSERT INTO FACTURAS (id, ncf, fecha, cliente_id, subtotal, itbis, total, tipo_pago, estado, notas)
VALUES (1042, 'B0100001042', DATE '2026-09-22', 3, 12600.00, 2268.00, 14868.00, 'CREDITO', 'PENDIENTE', 'Suministros trimestrales');

-- Factura 1043: Cliente 1 (Crédito — fecha anterior para prueba de mora)
INSERT INTO FACTURAS (id, ncf, fecha, cliente_id, subtotal, itbis, total, tipo_pago, estado, notas)
VALUES (1043, 'B0100001043', DATE '2026-08-10', 1, 7200.00, 1296.00, 8496.00, 'CREDITO', 'PENDIENTE', 'Pedido agosto');

-- Factura 1044: Cliente 4 (Crédito)
INSERT INTO FACTURAS (id, ncf, fecha, cliente_id, subtotal, itbis, total, tipo_pago, estado, notas)
VALUES (1044, 'B0100001044', DATE '2026-10-01', 4, 4100.00, 738.00, 4838.00, 'CREDITO', 'PENDIENTE', 'Pedido urgente octubre');

COMMIT;

PROMPT >> Registrando Pagos (Disparo de TRG_AI_PAGOS_CXC)...;

-- Pago de la Factura 1041 completa (cancelación)
DECLARE
    v_cxc_1041 NUMBER;
BEGIN
    SELECT id INTO v_cxc_1041 FROM CUENTAS_POR_COBRAR WHERE factura_id = 1041;
    INSERT INTO PAGOS_CXC (id, cxc_id, monto, fecha, metodo, referencia, banco)
    VALUES (5008, v_cxc_1041, 4484.00, DATE '2026-10-10', 'TRANSFERENCIA', 'TRF-CLN-20261010-001', 'Banco Popular');
END;
/

-- Pago parcial de la Factura 1044 (RD$ 2,000 de abono)
DECLARE
    v_cxc_1044 NUMBER;
BEGIN
    SELECT id INTO v_cxc_1044 FROM CUENTAS_POR_COBRAR WHERE factura_id = 1044;
    INSERT INTO PAGOS_CXC (id, cxc_id, monto, fecha, metodo, referencia, banco)
    VALUES (5009, v_cxc_1044, 2000.00, DATE '2026-10-12', 'CHEQUE', 'CHQ-FP-20261012-001', 'Banco BHD');
END;
/

COMMIT;

-- Ejecución manual del procedimiento de cálculo de mora
PROMPT >> Ejecutando procedimiento SP_ACTUALIZAR_MORA...;
DECLARE
    v_total NUMBER;
BEGIN
    SP_ACTUALIZAR_MORA(DATE '2026-10-23', v_total);
    DBMS_OUTPUT.PUT_LINE('>> Cuentas en mora actualizadas: ' || v_total);
    DBMS_MVIEW.REFRESH('MV_AGING_CARTERA_RESUMEN');
END;
/

-- ----------------------------------------------------------------------------
-- 12. COMPROBACIÓN DE RESULTADOS
-- ----------------------------------------------------------------------------
PROMPT >> ==================== COMPROBACIÓN: CUENTAS POR COBRAR ====================;
SELECT id AS cxc_id, factura_id, cliente_id, monto_original, monto_pagado, saldo, estado, dias_mora
FROM CUENTAS_POR_COBRAR
ORDER BY id;

PROMPT >> ==================== COMPROBACIÓN: ESTADO DE CLIENTES ====================;
SELECT id, nombre, rnc, limite_credito, balance, estado
FROM CLIENTES
WHERE tipo = 'CREDITO'
ORDER BY id;

PROMPT >> ==================== COMPROBACIÓN: AUDITORÍA DE TRIGGERS =================;
SELECT id, trigger_name, evento, tabla_afectada, SUBSTR(detalles, 1, 75) AS resumen
FROM AUDITORIA_TRIGGERS
ORDER BY id;

PROMPT >> ==================== COMPROBACIÓN: AGING MATERIALIZED VIEW ===============;
SELECT cliente_nombre, corriente_0_dias, mora_1_30_dias, mora_31_60_dias, mora_mas_60_dias, total_cartera
FROM MV_AGING_CARTERA_RESUMEN;

PROMPT >> INSTALACIÓN Y VERIFICACIÓN COMPLETADA EXITOSAMENTE.
