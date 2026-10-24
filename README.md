# ISO810 — Integración de Sistemas & Tecnologías de Bases de Datos
## Proyecto: Integración de Facturación con Cuentas por Cobrar (Farmacia Carol)
### Implementación mediante Disparadores (Triggers) y Tecnología Propietaria de Base de Datos

---

## 📌 1. Introducción y Propósito del Proyecto

El presente proyecto implementa la integración crítica entre el **Módulo de Facturación** y el **Módulo de Cuentas por Cobrar (CxC)** para la empresa farmacéutica **Farmacia Carol, S.R.L.** (RNC 130-98765-4), bajo la asignatura **ISO810**.

El objetivo central es demostrar cómo resolver un desafío empresarial de alta concurrencia y estricto control financiero mediante **tecnología nativa y propietaria de Base de Datos (Oracle 19c/21c)**, centrando la sincronización en **Disparadores (Triggers)** y componentes avanzados de BD, en lugar de delegar la lógica a la capa de aplicación.

---

## 🛡️ 2. Defensa Técnica: ¿Por qué Triggers y Tecnología Propietaria de BD?

Al defender este diseño frente a la alternativa tradicional de integrar en la capa de software (backend/APIs), se sustentan los siguientes pilares de ingeniería de software y bases de datos:

```
┌────────────────────────────────────────────────────────────────────────┐
│                   CAPA DE APLICACIÓN / MÚLTIPLES CLIENTES              │
│       [Web Portal]       [Cajas POS Sucursal]       [App Móvil]       │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ SQL INSERT
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                     MOTOR DE BASE DE DATOS ORACLE                      │
│                                                                        │
│   1. BEFORE INSERT Trigger ──► [Valida Crédito / Asigna NCF]          │
│   2. Transacción Atómica   ──► [Inserta en FACTURAS]                   │
│   3. AFTER INSERT Trigger  ──► [Crea CxC + Actualiza Balance Cliente]  │
│   4. Transacción Autónoma  ──► [Auditoría inalterable]                 │
│                                                                        │
│   ✔ Cero registros huérfanos      ✔ Cero condiciones de carrera       │
│   ✔ ACID al 100%                   ✔ Cumplimiento DGII garantizado     │
└────────────────────────────────────────────────────────────────────────┘
```

### 2.1. Integridad Referencial Activa Indivisible
* **El problema en la aplicación:** Si la aplicación web inserta una factura a crédito y justo después se interrumpe la conexión, se cae el servidor o falla la segunda llamada HTTP, la factura queda registrada pero la cuenta por cobrar nunca se genera (**registro huérfano**). Esto causaría pérdidas financieras severas y descuadre contable.
* **La solución con Triggers:** El trigger `TRG_AI_FACTURAS` se ejecuta dentro del **mismo contexto transaccional ACID**. Es físicamente imposible que una factura a crédito exista en la tabla `FACTURAS` sin su registro correspondiente en `CUENTAS_POR_COBRAR`. Si la CxC no se crea, la factura tampoco, ejecutándose un `ROLLBACK` atómico integral.

### 2.2. Prevención Total de Condiciones de Carrera (*Race Conditions*)
* **El problema en la aplicación:** Si dos cajeros o procesos intentan facturarle a crédito al mismo cliente simultáneamente, ambos leen un balance disponible suficiente en memoria y ambos autorizan la venta, superando el límite de crédito real del cliente.
* **La solución con Triggers:** El trigger `TRG_BI_FACTURAS` intercepta la fila antes de consolidarla (`BEFORE INSERT`), consulta el balance en tiempo real con las tablas transaccionales bloqueadas por la propia transacción, y aborta con `RAISE_APPLICATION_ERROR(-20004)` si la suma supera el límite permitido.

### 2.3. Agnosticismo de Canal e Inviolabilidad de Reglas
* En una cadena como Farmacia Carol, existen múltiples puntos de entrada de datos: cajas registradoras en sucursales físicas, tienda en línea, app de entregas a domicilio y cargas masivas nocturnas.
* Al ubicar los triggers en la base de datos, **ninguna aplicación ni usuario puede puentear las reglas de negocio**, independientemente de la tecnología del cliente que ejecute el `INSERT`.

### 2.4. Rendimiento Óptimo y Reducción del Tráfico de Red
* La lógica ocurre en la memoria compartida del motor (*System Global Area - SGA*), reduciendo drásticamente los viajes de ida y vuelta de red (*network roundtrips*) entre el servidor de aplicaciones y el servidor de datos.

---

## ⚡ 3. Estructura y Funcionamiento de los Disparadores (Triggers)

El sistema cuenta con un ecosistema de **5 triggers complementarios** organizados según el momento de disparo (`BEFORE` vs `AFTER`) y el evento (`INSERT` / `UPDATE`):

| Trigger | Evento | Tabla Objetivo | Responsabilidad y Mecanismo |
| :--- | :--- | :--- | :--- |
| **`TRG_BI_FACTURAS`** | `BEFORE INSERT` | `FACTURAS` | **Validación preventiva y asignación fiscal:** Comprueba estado del cliente, verifica facturas vencidas impagas, valida límite de crédito y auto-genera el NCF DGII (`B010000XXXX`). |
| **`TRG_AI_FACTURAS`** | `AFTER INSERT` | `FACTURAS` | **Propagación automática a CxC:** Si es a crédito, calcula fecha de vencimiento (`fecha + dias_credito`), crea la fila en `CUENTAS_POR_COBRAR`, suma al balance del cliente y audita. |
| **`TRG_AI_PAGOS_CXC`** | `AFTER INSERT` | `PAGOS_CXC` | **Cascada de pagos:** Bloquea pesimistamente (`FOR UPDATE`) la CxC, actualiza montos, cambia estados a `PARCIAL` o `PAGADA`, propaga a `FACTURAS` y reduce el balance del cliente. |
| **`TRG_AI_NOTAS_CREDITO`**| `AFTER INSERT` | `NOTAS_CREDITO` | **Ajustes y devoluciones:** Aplica notas de crédito comerciales o descuentos directamente al saldo adeudado de la factura y de la CxC. |
| **`TRG_BU_CUENTAS_POR_COBRAR`** | `BEFORE UPDATE` | `CUENTAS_POR_COBRAR` | **Integridad defensiva:** Rechaza a nivel de motor cualquier valor de saldo negativo o monto pagado superior al facturado. |

---

### 3.1. Detalle del Trigger de Validación: `TRG_BI_FACTURAS`

```sql
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
    -- 1. Asignar ID mediante secuencia Oracle si no fue provisto
    IF :NEW.id IS NULL THEN
        :NEW.id := SEQ_FACTURA.NEXTVAL;
    END IF;

    -- 2. Consultar políticas de crédito del cliente
    SELECT tipo, limite_credito, balance, estado
    INTO   v_tipo_cli, v_limite, v_balance, v_estado_cli
    FROM   CLIENTES
    WHERE  id = :NEW.cliente_id;

    -- Validar que el cliente no esté bloqueado
    IF v_estado_cli <> 'ACTIVO' THEN
        RAISE_APPLICATION_ERROR(-20001, 'CLIENTE BLOQUEADO: El cliente #' || :NEW.cliente_id || ' está ' || v_estado_cli);
    END IF;

    -- 3. Reglas específicas para ventas a CRÉDITO
    IF :NEW.tipo_pago = 'CREDITO' THEN
        IF v_tipo_cli <> 'CREDITO' THEN
            RAISE_APPLICATION_ERROR(-20002, 'CLIENTE CONTADO: El cliente no cuenta con línea de crédito habilitada.');
        END IF;

        -- Regla de Negocio: No facturar si tiene facturas vencidas impagas
        SELECT COUNT(*)
        INTO   v_vencidas
        FROM   CUENTAS_POR_COBRAR
        WHERE  cliente_id = :NEW.cliente_id
          AND  estado = 'VENCIDA'
          AND  saldo > 0;

        IF v_vencidas > 0 THEN
            RAISE_APPLICATION_ERROR(-20003, 'CRÉDITO SUSPENDIDO: El cliente tiene ' || v_vencidas || ' factura(s) vencida(s).');
        END IF;

        -- Regla de Negocio: Límite de crédito disponible
        IF (v_balance + :NEW.total) > v_limite THEN
            RAISE_APPLICATION_ERROR(-20004, 'LÍMITE EXCEDIDO: La venta por RD$ ' || :NEW.total || 
                                    ' supera el límite disponible de RD$ ' || (v_limite - v_balance));
        END IF;
    END IF;

    -- 4. Generación fiscal automática del NCF (DGII República Dominicana)
    IF :NEW.ncf IS NULL OR :NEW.ncf = '' THEN
        v_ncf_seq := :NEW.id;
        SP_GENERAR_NCF('B01', v_ncf_seq, :NEW.ncf);
    END IF;
END TRG_BI_FACTURAS;
/
```

> **Por qué `BEFORE INSERT`:**  
> Porque debe operar **antes** de que los datos se escriban en disco. Si cualquier validación de negocio falla, se cancela la operación antes de consumir recursos de almacenamiento, impidiendo datos corruptos.

---

### 3.2. Detalle del Trigger de Integración: `TRG_AI_FACTURAS`

```sql
CREATE OR REPLACE TRIGGER TRG_AI_FACTURAS
AFTER INSERT ON FACTURAS
FOR EACH ROW
DECLARE
    v_cxc_id        NUMBER;
    v_dias_credito  NUMBER;
    v_fecha_venc    DATE;
BEGIN
    IF :NEW.tipo_pago = 'CREDITO' THEN
        v_cxc_id := SEQ_CXC.NEXTVAL;

        -- Extraer los días de crédito del cliente
        SELECT dias_credito
        INTO   v_dias_credito
        FROM   CLIENTES
        WHERE  id = :NEW.cliente_id;

        v_fecha_venc := :NEW.fecha + NVL(v_dias_credito, 30);

        -- Inserción automática de la Cuenta por Cobrar
        INSERT INTO CUENTAS_POR_COBRAR (
            id, factura_id, cliente_id, monto_original, monto_pagado, saldo,
            fecha_emision, fecha_vencimiento, estado, dias_mora, fecha_actualizacion
        ) VALUES (
            v_cxc_id, :NEW.id, :NEW.cliente_id, :NEW.total, 0.00, :NEW.total,
            :NEW.fecha, v_fecha_venc, 'PENDIENTE', 0, SYSTIMESTAMP
        );

        -- Incrementar balance deudor del cliente
        UPDATE CLIENTES
        SET    balance = balance + :NEW.total
        WHERE  id = :NEW.cliente_id;

        -- Auditoría autónoma
        SP_LOG_AUDITORIA_AUTONOMA(
            'TRG_AI_FACTURAS', 'INSERT', 'CUENTAS_POR_COBRAR', v_cxc_id,
            'Factura #' || :NEW.id || ' (' || :NEW.ncf || ') generó CxC #' || v_cxc_id || ' por RD$ ' || :NEW.total
        );
    END IF;
END TRG_AI_FACTURAS;
/
```

> **Por qué `AFTER INSERT`:**  
> Porque la Cuenta por Cobrar tiene una clave foránea (`factura_id`) apuntando a `FACTURAS(id)`. Si se usara `BEFORE`, la clave foránea violaría la integridad referencial porque la factura aún no existiría oficialmente en la tabla padre.

---

### 3.3. Detalle del Trigger de Cobros: `TRG_AI_PAGOS_CXC`

```sql
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
    -- Bloqueo pesimista de fila para evitar condiciones de carrera en pagos concurrentes
    SELECT id, factura_id, cliente_id, monto_original, monto_pagado
    INTO   v_cxc_id, v_factura_id, v_cliente_id, v_original, v_pagado_prev
    FROM   CUENTAS_POR_COBRAR
    WHERE  id = :NEW.cxc_id
    FOR UPDATE;

    v_nuevo_pagado := v_pagado_prev + :NEW.monto;
    v_nuevo_saldo  := v_original - v_nuevo_pagado;

    IF v_nuevo_saldo < 0 THEN
        RAISE_APPLICATION_ERROR(-20005, 'SOBREPAGO: El abono supera el saldo pendiente adeudado.');
    END IF;

    -- Máquina de estados: ¿Quedó saldada o parcial?
    IF v_nuevo_saldo = 0 THEN
        v_nuevo_estado := 'PAGADA';
    ELSE
        v_nuevo_estado := 'PARCIAL';
    END IF;

    -- Actualizar CxC
    UPDATE CUENTAS_POR_COBRAR
    SET    monto_pagado = v_nuevo_pagado,
           saldo        = v_nuevo_saldo,
           estado       = v_nuevo_estado,
           fecha_actualizacion = SYSTIMESTAMP
    WHERE  id = :NEW.cxc_id;

    -- Propagar estado a la FACTURA original
    UPDATE FACTURAS
    SET    estado = v_nuevo_estado
    WHERE  id = v_factura_id;

    -- Reducir balance del cliente
    UPDATE CLIENTES
    SET    balance = GREATEST(0, balance - :NEW.monto)
    WHERE  id = v_cliente_id;

    -- Auditoría
    SP_LOG_AUDITORIA_AUTONOMA(
        'TRG_AI_PAGOS_CXC', 'INSERT', 'PAGOS_CXC', :NEW.id,
        'Pago de RD$ ' || :NEW.monto || ' aplicado a CxC #' || :NEW.cxc_id || '. Nuevo saldo: RD$ ' || v_nuevo_saldo
    );
END TRG_AI_PAGOS_CXC;
/
```

---

## 🗄️ 4. Tecnologías Propietarias de BD Complementarias

Para robustecer la arquitectura más allá de los disparadores, se aprovecharon los siguientes componentes nativos de Oracle:

1. **Paquete PL/SQL (`PKG_FARMACIA_CAROL`):**  
   Agrupa en un solo *namespace* compilado la lógica fiscal del ITBIS (18%), la verificación de crédito y la emisión de reportes. Al ejecutarse la primera vez, el código completo queda residente en la memoria **SGA**, reduciendo lecturas a disco en ejecuciones posteriores.

2. **Secuencias Oracle (`SEQUENCE` con `NOCACHE` y `NOCYCLE`):**  
   `SEQ_FACTURA`, `SEQ_CXC`, `SEQ_PAGO`. Garantizan claves primarias y comprobantes fiscales NCF estrictamente correlativos y consecutivos, requisito indispensable exigido por la **DGII** en auditorías tributarias.

3. **Transacciones Autónomas (`PRAGMA AUTONOMOUS_TRANSACTION`):**  
   Implementadas en el procedimiento `SP_LOG_AUDITORIA_AUTONOMA`. Permiten escribir en la tabla `AUDITORIA_TRIGGERS` y hacer `COMMIT` independiente del hilo principal. Si una factura es rechazada por límite de crédito, el log de auditoría se conserva para análisis de riesgo.

4. **Cursores Explícitos con Bloqueo de Fila (`FOR UPDATE OF` y `WHERE CURRENT OF`):**  
   Utilizados en el procedimiento `SP_ACTUALIZAR_MORA`. Recorre las cuentas por cobrar y bloquea cada fila durante el recálculo de días de mora, evitando colisiones con pagos entrantes en ese milisegundo.

5. **Vista Materializada (`MV_AGING_CARTERA_RESUMEN`):**  
   Pre-agrega y clasifica la cartera por franjas de antigüedad (Corriente 0 días, 1-30 días, 31-60 días, >60 días). Esto permite que el Dashboard consulte saldos millonarios en microsegundos sin sobrecargar las tablas transaccionales activas.

6. **Programador de Tareas (`DBMS_SCHEDULER`):**  
   Se programó el job `JOB_ACTUALIZAR_MORA` para ejecutarse diariamente a las 23:00, recalculando moras y refrescando la vista materializada con `DBMS_MVIEW.REFRESH`.

---

## 🚀 5. Cómo Probar y Ejecutar el Proyecto

### Opción 1: Aplicación Web Interactiva
1. Con el servidor local activo, ingresa a:  
   👉 **`http://localhost:8080/farmacia_carol.html`**
2. **Probar emisión con trigger:** Entra a *"Nueva Factura"*, escoge *Centro Médico Nacional*, añade renglones y pulsa *"Emitir Factura"*. Observa los toasts en vivo que muestran los triggers ejecutándose.
3. **Probar cobro en cascada:** Entra a *"Cuentas x Cobrar"*, pulsa *"Registrar Pago"*, ingresa un abono y confirma para ver la transición de estados en tiempo real.
4. **Inspeccionar bitácora:** Ve a *"Triggers & Logs"* para auditar cada evento generado.

### Opción 2: Base de Datos Oracle (SQL / PL/SQL)
1. Abre el archivo **[`farmacia_carol_db.sql`](farmacia_carol_db.sql)** en **Oracle SQL Developer** o cópialo a **[Oracle Live SQL](https://livesql.oracle.com)**.
2. Ejecuta el script completo:
   ```sql
   @farmacia_carol_db.sql;
   ```
3. El script creará todo el esquema, las secuencias, triggers, packages, vista materializada, insertará los datos de prueba y emitirá automáticamente las consultas de comprobación de los triggers en acción.

---

## 👨‍💻 Créditos & Materia
* **Asignatura:** ISO810 — Integración de Sistemas
* **Autor:** Eithan
* **Repositorio:** [https://github.com/Eithandls/ISO810](https://github.com/Eithandls/ISO810)
