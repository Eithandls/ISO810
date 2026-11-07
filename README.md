# ISO810 — Integración de Sistemas
## Repositorio Oficial de Prácticas y Enterprise Data Warehouse (EDW)
### Autor: Eithan | Repositorio: [https://github.com/Eithandls/ISO810](https://github.com/Eithandls/ISO810)

---

## 🏛️ 1. Arquitectura Consolidada del Data Warehouse (EDW)

El **Data Warehouse Corporativo (`DWH_Corporativo_ISO810`)** integra en un único modelo dimensional (**Esquema de Constelación / Bus Matrix de Kimball**) todos los sistemas y prácticas del portafolio:

```
┌────────────────────────────────────────────────────────────────────────┐
│                   FUENTES TRANSACCIONALES (OLTP)                       │
├───────────────────────┬───────────────────────┬────────────────────────┤
│ 1. Farmacia Carol     │ 2. Supermercado Bravo │ 3. Ferretería          │ 4. MADECO
│    Facturación & CxC  │    Recursos Humanos   │    Americana           │    Activos Fijos &
│    (Triggers Oracle)  │    (Linked Server)    │    (TSS SUIR XML)      │    Asientos (XML)
└──────────┬────────────┴──────────┬────────────┴──────────┬─────────────┴──────────┬─────────────┘
           │                       │                       │                        │
           ▼                       ▼                       ▼                        ▼
┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│                          ÁREA DE STAGING & TRANSFORMACIÓN (ELT)                                 │
│          stg.stg_carol  |  stg.stg_bravo  |  stg.stg_tss  |  stg.stg_madeco                     │
└──────────────────────────────────────────┬──────────────────────────────────────────────────────┘
                                           │
                                           ▼
┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│                         DATA WAREHOUSE CORPORATIVO DIMENSIONAL                                  │
├──────────────────────────────────────────┬──────────────────────────────────────────────────────┤
│ DIMENSIONES CONFORMADAS:                 │ TABLAS DE HECHOS (FACT TABLES):                      │
│ - Dim_Tiempo (Día, Mes, Quincena, Año)   │ - Fact_Facturacion_CxC (Ventas, ITBIS, Deuda Carol)  │
│ - Dim_Empresa_Sucursal (4 Compañías)     │ - Fact_Nomina_Gestion (Sueldos y Horas Extras Bravo) │
│ - Dim_Empleado (SCD Tipo 2 con Historial)│ - Fact_Aportes_TSS (SFS, AFP, SRL, INFOTEP)          │
│ - Dim_Cliente (Segmento y Crédito)       │ - Fact_Depreciacion_Activos (Valor Libros MADECO)    │
│ - Dim_Cuenta_Contable (NIIF)             │ - Fact_Movimientos_Contables (Débito = Crédito)      │
└──────────────────────────────────────────┬──────────────────────────────────────────────────────┤
                                           │
                                           ▼
┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│                        CAPA SEMÁNTICA Y REPORTES (Power BI / Excel)                             │
│ - rpt.vw_Dashboard_Costo_Laboral_Integral (Sueldo + Cargas Patronales TSS)                      │
│ - rpt.vw_Dashboard_Rendimiento_Corporativo (Ventas vs. Nómina vs. Desgaste de Activos)           │
└─────────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 🛠️ 2. Herramientas y Tecnologías Utilizadas

| Componente | Tecnología Propietaria / Estándar | Justificación en la Arquitectura |
| :--- | :--- | :--- |
| **Motor RDBMS / DWH** | Microsoft SQL Server / Oracle 19c/21c | Soporte ACID, almacenamiento en columnas, particionamiento y vistas materializadas. |
| **Enlaces de BD** | **Linked Servers / DB-Links** | Conexión directa y autenticada entre la BD de RH de Supermercados Bravo y el DWH. |
| **Integración Activa** | **Disparadores (Triggers)** | Automatización indivisible entre Facturas y Cuentas por Cobrar en Farmacia Carol. |
| **Procesamiento XML** | **XQuery / OPENXML / WSDL** | Ingesta nativa de nómina TSS de Ferretería Americana y asientos de MADECO. |
| **Historial Dinámico**| **SCD Tipo 2 (Slowly Changing Dimensions)** | Mantenimiento del historial de cargos y traslados de empleados en el DWH. |
| **Orquestación** | **SQL Server Agent / DBMS_SCHEDULER** | Automatización nocturna desatendida del ETL. |
| **Capa de Negocio** | **Power BI / DAX / Vistas SQL** | Visualización de KPIs ejecutivos de rentabilidad y costo laboral. |

---

## ⚙️ 3. Cómo Funciona el Data Warehouse

1. **Extracción y Desacoplamiento:**
   * Las bases transaccionales no se consultan directamente para reportes.
   * Se extraen datos mediante vistas dedicadas (`OPENQUERY` y DB-Links) hacia el esquema `stg` para evitar bloqueos en horario comercial.
2. **Dimensiones SCD Tipo 2:**
   * La tabla `edw.Dim_Empleado` almacena los cambios de puesto, sucursal o sueldo cerrando la fecha de fin de validez (`fecha_fin_validez = GETDATE()`, `es_registro_actual = 0`) e insertando la nueva versión.
3. **Cruce de Negocio (Cross-Domain Analytics):**
   * El DWH permite cruzar por primera vez dominios que antes estaban aislados:
     * **Carol + Bravo:** Compara la venta generada en caja con el costo de la nómina por sucursal.
     * **Bravo + Americana:** Combina el salario contractual con la liquidación legal de aportes al SDSS (TSS).
     * **MADECO + Finanzas:** Valida que el desgaste de maquinaria en el módulo de activos coincida con el libro diario contable (partida doble).

---

## 🧪 4. Cómo Poner a Prueba el Data Warehouse

Para validar que todo el DWH esté correctamente estructurado, íntegro y sin errores, se proporcionan dos scripts SQL listos para ejecutar en **SQL Server Management Studio (SSMS)**, **Azure Data Studio** o mediante **sqlcmd**:

### Paso 1: Creación del Modelo y Datos Semilla
Ejecuta el archivo [`dwh_corporativo_setup.sql`](file:///c:/Users/Eitha/OneDrive/Desktop/ISO810/dwh_corporativo_setup.sql):
```sql
-- Ejecutar en SSMS o consola
:r dwh_corporativo_setup.sql
```
* Crea la base de datos `DWH_Corporativo_ISO810`.
* Crea los esquemas `stg`, `edw` y `rpt`.
* Construye las 5 dimensiones y las 5 tablas de hechos.
* Ejecuta `edw.sp_Poblar_Datos_Semilla_DWH` con registros de prueba representativos de los 4 proyectos.

---

### Paso 2: Ejecución de la Batería de Pruebas Automatizadas
Ejecuta el archivo [`dwh_test_suite.sql`](file:///c:/Users/Eitha/OneDrive/Desktop/ISO810/dwh_test_suite.sql):
```sql
:r dwh_test_suite.sql
```

El script ejecuta automáticamente **8 pruebas unitarias y de integridad**:
1. **Consistencia SCD Tipo 2:** Verifica que ningún empleado tenga más de un registro marcado como activo.
2. **Coherencia Salarial:** Comprueba que el salario neto no exceda el sueldo bruto más bonos e incentivos.
3. **Integridad Referencial CxC:** Garantiza que no existan facturas huérfanas sin cliente asignado.
4. **Validación Impositiva (ITBIS 18%):** Confirma que `monto_total = monto_subtotal + monto_itbis`.
5. **Reglas de Seguridad Social (TSS):** Verifica que las cotizaciones a SFS y AFP sean positivas.
6. **Partida Doble Contable (MADECO):** Comprueba que la suma de Débitos sea exactamente igual a la suma de Créditos (`Diferencia = RD$ 0.00`).
7. **No Negatividad de Activos:** Verifica que el valor en libros de maquinarias y vehículos sea mayor o igual a cero.
8. **Disponibilidad de la Capa de BI:** Asegura que las vistas consolidadas devuelvan datos analíticos listos para Power BI.

#### Resultado Esperado en Pantalla:
```text
============================================================
CERTIFICACIÓN: 8 de 8 pruebas aprobadas.
DICTAMEN FINAL: ✅ DWH CORPORATIVO ISO810 CERTIFICADO Y LISTO.
============================================================
```

---

## 💻 5. Proyectos Integrados en este Repositorio

1. **Farmacia Carol (Facturación ➔ Cuentas por Cobrar):**
   * Código de la BD: [`farmacia_carol_db.sql`](file:///c:/Users/Eitha/OneDrive/Desktop/ISO810/farmacia_carol_db.sql)
   * Demostración Web interactiva: [`farmacia_carol.html`](file:///c:/Users/Eitha/OneDrive/Desktop/ISO810/farmacia_carol.html)
   * Documentación técnica de Triggers: [`DOCUMENTACION_INTEGRACION_BD.md`](file:///c:/Users/Eitha/OneDrive/Desktop/ISO810/DOCUMENTACION_INTEGRACION_BD.md)
2. **Supermercados Bravo (Recursos Humanos ➔ DWH):**
   * Integración mediante **Linked Server / DB-Link**.
   * Historial con **SCD Tipo 2** y tabla de hechos `Fact_Nomina_Gestion`.
3. **Ferretería Americana (Autodeterminación TSS):**
   * Esquema XSD: [`AutodeterminacionTSS.xsd`](file:///c:/Users/Eitha/OneDrive/Desktop/ISO810/AutodeterminacionTSS.xsd)
   * Ejemplo XML: [`AutodeterminacionTSS_ejemplo.xml`](file:///c:/Users/Eitha/OneDrive/Desktop/ISO810/AutodeterminacionTSS_ejemplo.xml)
   * Servicio Web: [`AutodeterminacionTSS_service.wsdl`](file:///c:/Users/Eitha/OneDrive/Desktop/ISO810/AutodeterminacionTSS_service.wsdl)
4. **MADECO (Activos Fijos y Contabilidad):**
   * Esquema XSD: [`AsientoActivosFijos.xsd`](file:///c:/Users/Eitha/OneDrive/Desktop/ISO810/AsientoActivosFijos.xsd)
   * Ejemplo XML: [`AsientoActivosFijos_ejemplo.xml`](file:///c:/Users/Eitha/OneDrive/Desktop/ISO810/AsientoActivosFijos_ejemplo.xml)
