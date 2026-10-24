# ISO810 — Integración de Sistemas
## Práctica de Integración entre Bases de Datos mediante Triggers
### Caso: Facturación ➔ Cuentas por Cobrar (Farmacia Carol)

---

## 🎯 1. Objetivo de la Práctica

Demostrar de forma directa, limpia y sin pantallas innecesarias cómo un **Disparador (Trigger)** en la base de datos realiza la **integración automática entre dos tablas transaccionales**:
* Tabla de origen: **`FACTURAS`**
* Tabla de destino: **`CUENTAS_POR_COBRAR`**

---

## ⚡ 2. ¿Cómo Funciona la Integración?

La lógica es simple e infalible:

```
                      [ INSERT INTO FACTURAS ]
                                  │
                                  ▼
                    ¿condiciones_pago = 'CREDITO'?
                                ╱       ╲
                              SÍ         NO (Contado)
                             ╱             ╲
                            ▼               ▼
          [ TRIGGER SE DISPARA ]    [ TRIGGER NO HACE NADA ]
          Lee los datos de :NEW     No se guarda nada en
          e inserta la deuda en     Cuentas por Cobrar.
          CUENTAS_POR_COBRAR.       (Cero deuda generada)
```

1. Cuando el usuario registra una factura en la tabla `FACTURAS`, el disparador evalúa el campo **`condiciones_pago`**:
2. **Si la factura es a CRÉDITO:**
   - El trigger toma los datos directamente de la misma factura que se acaba de insertar (`:NEW.id_factura`, `:NEW.id_cliente`, `:NEW.fecha_emision`, `:NEW.monto_total`).
   - Inserta automáticamente un nuevo registro en la tabla `CUENTAS_POR_COBRAR` con estado `PENDIENTE`.
   - Se crea la deuda del cliente al instante y de forma atómica.
3. **Si la factura es al CONTADO:**
   - La venta ya fue pagada inmediatamente, por lo que **no genera ninguna deuda**.
   - El trigger evalúa la condición, ve que no es crédito, **ignora la operación y no guarda nada en Cuentas por Cobrar**.

---

## 📝 3. Código del Trigger para Defender en Clase

Este es el bloque PL/SQL exacto que gobierna la integración (ubicado en `farmacia_carol_db.sql`):

```sql
CREATE OR REPLACE TRIGGER TRG_FACTURA_A_CXC
AFTER INSERT ON FACTURAS
FOR EACH ROW
BEGIN
    -- Evaluamos si la factura es a crédito:
    IF UPPER(:NEW.condiciones_pago) = 'CREDITO' THEN

        -- El trigger lee los datos de la factura e inserta en Cuentas por Cobrar:
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

    -- Si es al CONTADO, el trigger no hace nada y finaliza sin insertar.
    END IF;
END;
/
```

### Argumentos de Defensa Técnica:
* **¿Por qué es `AFTER INSERT`?** Porque la tabla `CUENTAS_POR_COBRAR` tiene una clave foránea (`id_factura`) que apunta a `FACTURAS`. La factura debe existir ya registrada en la base de datos para garantizar la integridad referencial.
* **¿De dónde provienen los datos?** Se leen de la pseudo-fila `:NEW` en memoria generada por el motor de BD al momento del `INSERT`. No se requiere ninguna consulta `SELECT` adicional a la tabla.
* **¿Por qué en la Base de Datos y no en la Aplicación?** Porque si se cae el servidor o la red justo después de guardar la factura, **nunca quedará una factura a crédito huérfana sin su cuenta por cobrar**. La transacción en Oracle es 100% indivisible (ACID).

---

## 🖥️ 4. Estructura de la Interfaz Simplificada

La interfaz web en **`farmacia_carol.html`** se diseñó exclusivamente para hacer una demostración limpia:

1. **Formulario Sencillo:**
   - No. Factura (correlativo automático)
   - Cliente (ID y Nombre)
   - Fecha de emisión
   - Monto Total (RD$)
   - **Condiciones de Pago:** Selector claro entre `CRÉDITO` y `CONTADO`.
   - Botones rápidos: *"⚡ Ejemplo a Crédito"* y *"⚡ Ejemplo al Contado"* para demostrar ambos caminos en segundos.
2. **Consola Visual del Trigger:**
   - Muestra en tiempo real si el trigger se disparó o si se ignoró por ser al contado, junto a la sentencia `INSERT INTO CUENTAS_POR_COBRAR` ejecutada.
3. **Tablas Lado a Lado:**
   - **Tabla FACTURAS:** Lista todas las facturas insertadas.
   - **Tabla CUENTAS_POR_COBRAR:** Muestra únicamente las que fueron generadas por facturas a crédito.

---

## 🧪 5. Cómo Probar la Demostración

### En la Web (Local):
Abre tu navegador en:
👉 **[http://localhost:8080/farmacia_carol.html](http://localhost:8080/farmacia_carol.html)**

1. Haz clic en **"⚡ Ejemplo a Crédito"** y pulsa **"Guardar Factura"** ➔ Verás la cuenta por cobrar crearse inmediatamente en la tabla derecha y el evento en la consola.
2. Haz clic en **"⚡ Ejemplo al Contado"** y pulsa **"Guardar Factura"** ➔ Verás que la factura se guarda en la tabla izquierda, pero la tabla de Cuentas por Cobrar **NO agrega ninguna fila**.

### En Oracle SQL Developer / Live SQL:
Ejecuta el archivo **`farmacia_carol_db.sql`**:
```sql
@farmacia_carol_db.sql;
```
Verás la salida por pantalla (`DBMS_OUTPUT`) con las comprobaciones del trigger.

---

## 👨‍💻 Datos del Proyecto
* **Asignatura:** ISO810 — Integración de Sistemas
* **Autor:** Eithan
* **Repositorio:** [https://github.com/Eithandls/ISO810](https://github.com/Eithandls/ISO810)
