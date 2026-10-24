/* ============================================================
   Farmacia Carol — Facturación + Cuentas x Cobrar
   Integración con Triggers y Tecnología Propietaria de BD
   Lógica de la Aplicación
   ============================================================ */

// ======================== DATOS MAESTROS ========================

const FARMACIA = {
  rnc: '130987654',
  razonSocial: 'Farmacia Carol, S.R.L.',
  nombreComercial: 'Farmacia Carol',
  direccion: 'Av. 27 de Febrero #142, Santo Domingo, DN',
  telefono: '(809) 555-2200',
  ncf_serie: 'B01',
  ncf_secuencia: 1045,
  itbis_rate: 0.18,
  moneda: 'DOP'
};

// Secuencia Oracle simulada
let SEQ_FACTURA = { current: 1045, next() { return ++this.current; } };
let SEQ_CXC = { current: 3020, next() { return ++this.current; } };
let SEQ_PAGO = { current: 5010, next() { return ++this.current; } };
let SEQ_NOTA_CREDITO = { current: 200, next() { return ++this.current; } };

// Clientes
const CLIENTES = [
  { id: 1, rnc: '401234567', nombre: 'Centro Médico Nacional', tipo: 'CREDITO', limite_credito: 500000.00, dias_credito: 30, contacto: 'Dr. Ramón García', telefono: '(809) 555-3001', balance: 78500.00 },
  { id: 2, rnc: '131567890', nombre: 'Clínica Abreu', tipo: 'CREDITO', limite_credito: 350000.00, dias_credito: 45, contacto: 'Lic. Ana Matos', telefono: '(809) 555-3002', balance: 45200.00 },
  { id: 3, rnc: '101234890', nombre: 'Hospital Dr. Moscoso Puello', tipo: 'CREDITO', limite_credito: 800000.00, dias_credito: 60, contacto: 'Ing. Carlos Vargas', telefono: '(809) 555-3003', balance: 156800.00 },
  { id: 4, rnc: '402345678', nombre: 'Farmacia Popular (Sucursal)', tipo: 'CREDITO', limite_credito: 150000.00, dias_credito: 15, contacto: 'Sra. María López', telefono: '(809) 555-3004', balance: 12400.00 },
  { id: 5, rnc: '001234567', nombre: 'Juan Pérez Almonte', tipo: 'CONTADO', limite_credito: 0, dias_credito: 0, contacto: 'Juan Pérez', telefono: '(809) 555-9090', balance: 0 }
];

// Productos farmacéuticos
const PRODUCTOS = [
  { id: 1, codigo: 'MED-001', nombre: 'Amoxicilina 500mg (caja x 21)', categoria: 'Antibiótico', precio: 450.00, costo: 280.00, stock: 150, itbis: true },
  { id: 2, codigo: 'MED-002', nombre: 'Losartán 50mg (caja x 30)', categoria: 'Antihipertensivo', precio: 380.00, costo: 220.00, stock: 200, itbis: true },
  { id: 3, codigo: 'MED-003', nombre: 'Metformina 850mg (caja x 30)', categoria: 'Antidiabético', precio: 320.00, costo: 190.00, stock: 180, itbis: true },
  { id: 4, codigo: 'MED-004', nombre: 'Omeprazol 20mg (caja x 14)', categoria: 'Antiácido', precio: 280.00, costo: 165.00, stock: 250, itbis: true },
  { id: 5, codigo: 'MED-005', nombre: 'Ibuprofeno 400mg (caja x 20)', categoria: 'Antiinflamatorio', precio: 220.00, costo: 130.00, stock: 300, itbis: true },
  { id: 6, codigo: 'MED-006', nombre: 'Vitamina C 1000mg (frasco x 60)', categoria: 'Suplemento', precio: 550.00, costo: 320.00, stock: 120, itbis: false },
  { id: 7, codigo: 'MED-007', nombre: 'Alcohol Isopropílico 70% 500ml', categoria: 'Insumo', precio: 180.00, costo: 95.00, stock: 400, itbis: true },
  { id: 8, codigo: 'MED-008', nombre: 'Atorvastatina 20mg (caja x 30)', categoria: 'Hipolipemiante', precio: 650.00, costo: 380.00, stock: 90, itbis: true },
  { id: 9, codigo: 'MED-009', nombre: 'Diclofenaco Gel 1% (tubo 60g)', categoria: 'Antiinflamatorio', precio: 290.00, costo: 170.00, stock: 175, itbis: true },
  { id: 10, codigo: 'MED-010', nombre: 'Mascarilla KN95 (caja x 50)', categoria: 'Insumo', precio: 750.00, costo: 420.00, stock: 80, itbis: false }
];

// ======================== BASES DE DATOS SIMULADAS ========================

// Tabla: FACTURAS
let FACTURAS = [
  {
    id: 1040, ncf: 'B0100001040', fecha: '2026-09-15', cliente_id: 1,
    subtotal: 5400.00, itbis: 972.00, total: 6372.00, tipo_pago: 'CREDITO',
    estado: 'PENDIENTE', notas: 'Pedido mensual septiembre',
    items: [
      { producto_id: 1, cantidad: 8, precio: 450.00, itbis: 648.00, total: 4248.00 },
      { producto_id: 4, cantidad: 4, precio: 280.00, itbis: 201.60, total: 1321.60 }
    ]
  },
  {
    id: 1041, ncf: 'B0100001041', fecha: '2026-09-18', cliente_id: 2,
    subtotal: 3800.00, itbis: 684.00, total: 4484.00, tipo_pago: 'CREDITO',
    estado: 'PAGADA', notas: 'Reposición de inventario',
    items: [
      { producto_id: 2, cantidad: 10, precio: 380.00, itbis: 684.00, total: 4484.00 }
    ]
  },
  {
    id: 1042, ncf: 'B0100001042', fecha: '2026-09-22', cliente_id: 3,
    subtotal: 12600.00, itbis: 2268.00, total: 14868.00, tipo_pago: 'CREDITO',
    estado: 'PENDIENTE', notas: 'Suministros trimestrales',
    items: [
      { producto_id: 3, cantidad: 15, precio: 320.00, itbis: 864.00, total: 5664.00 },
      { producto_id: 5, cantidad: 20, precio: 220.00, itbis: 792.00, total: 5192.00 },
      { producto_id: 8, cantidad: 6, precio: 650.00, itbis: 702.00, total: 4602.00 }
    ]
  },
  {
    id: 1043, ncf: 'B0100001043', fecha: '2026-08-10', cliente_id: 1,
    subtotal: 7200.00, itbis: 1296.00, total: 8496.00, tipo_pago: 'CREDITO',
    estado: 'VENCIDA', notas: 'Pedido agosto — vencido',
    items: [
      { producto_id: 1, cantidad: 10, precio: 450.00, itbis: 810.00, total: 5310.00 },
      { producto_id: 7, cantidad: 10, precio: 180.00, itbis: 324.00, total: 2124.00 }
    ]
  },
  {
    id: 1044, ncf: 'B0100001044', fecha: '2026-10-01', cliente_id: 4,
    subtotal: 4100.00, itbis: 738.00, total: 4838.00, tipo_pago: 'CREDITO',
    estado: 'PARCIAL', notas: 'Pedido urgente octubre',
    items: [
      { producto_id: 6, cantidad: 4, precio: 550.00, itbis: 0, total: 2200.00 },
      { producto_id: 9, cantidad: 5, precio: 290.00, itbis: 261.00, total: 1711.00 },
      { producto_id: 10, cantidad: 1, precio: 750.00, itbis: 0, total: 750.00 }
    ]
  }
];

// Tabla: CUENTAS_POR_COBRAR (generada por triggers)
let CUENTAS_POR_COBRAR = [
  { id: 3015, factura_id: 1040, cliente_id: 1, monto_original: 6372.00, monto_pagado: 0, saldo: 6372.00, fecha_emision: '2026-09-15', fecha_vencimiento: '2026-10-15', estado: 'PENDIENTE', dias_mora: 8 },
  { id: 3016, factura_id: 1041, cliente_id: 2, monto_original: 4484.00, monto_pagado: 4484.00, saldo: 0, fecha_emision: '2026-09-18', fecha_vencimiento: '2026-11-02', estado: 'PAGADA', dias_mora: 0 },
  { id: 3017, factura_id: 1042, cliente_id: 3, monto_original: 14868.00, monto_pagado: 0, saldo: 14868.00, fecha_emision: '2026-09-22', fecha_vencimiento: '2026-11-21', estado: 'PENDIENTE', dias_mora: 0 },
  { id: 3018, factura_id: 1043, cliente_id: 1, monto_original: 8496.00, monto_pagado: 0, saldo: 8496.00, fecha_emision: '2026-08-10', fecha_vencimiento: '2026-09-09', estado: 'VENCIDA', dias_mora: 44 },
  { id: 3019, factura_id: 1044, cliente_id: 4, monto_original: 4838.00, monto_pagado: 2000.00, saldo: 2838.00, fecha_emision: '2026-10-01', fecha_vencimiento: '2026-10-16', estado: 'PARCIAL', dias_mora: 7 }
];

// Tabla: PAGOS_CXC
let PAGOS_CXC = [
  { id: 5008, cxc_id: 3016, monto: 4484.00, fecha: '2026-10-10', metodo: 'TRANSFERENCIA', referencia: 'TRF-CLN-20261010-001', banco: 'Banco Popular' },
  { id: 5009, cxc_id: 3019, monto: 2000.00, fecha: '2026-10-12', metodo: 'CHEQUE', referencia: 'CHQ-FP-20261012-001', banco: 'Banco BHD' }
];

// Tabla: NOTAS_CREDITO
let NOTAS_CREDITO = [];

// Log del trigger
let triggerLog = [];

// ======================== ENGINE DE TRIGGERS ========================

function fireTrigger(triggerName, operation, tableName, oldRow, newRow) {
  const timestamp = new Date().toISOString().slice(11, 19);

  const entry = {
    timestamp,
    trigger: triggerName,
    operation,
    table: tableName,
    details: '',
    subEntries: []
  };

  switch (triggerName) {
    case 'TRG_AFTER_INSERT_FACTURA':
      // Trigger AFTER INSERT en FACTURAS → crea registro en CUENTAS_POR_COBRAR
      if (newRow.tipo_pago === 'CREDITO') {
        const cxcId = SEQ_CXC.next();
        const cliente = CLIENTES.find(c => c.id === newRow.cliente_id);
        const diasCredito = cliente ? cliente.dias_credito : 30;
        const fechaVenc = calcFechaVencimiento(newRow.fecha, diasCredito);

        const nuevaCxC = {
          id: cxcId,
          factura_id: newRow.id,
          cliente_id: newRow.cliente_id,
          monto_original: newRow.total,
          monto_pagado: 0,
          saldo: newRow.total,
          fecha_emision: newRow.fecha,
          fecha_vencimiento: fechaVenc,
          estado: 'PENDIENTE',
          dias_mora: 0
        };

        CUENTAS_POR_COBRAR.push(nuevaCxC);

        // Actualizar balance del cliente
        if (cliente) {
          cliente.balance += newRow.total;
        }

        entry.details = `Factura ${newRow.ncf} → CxC #${cxcId} creada automáticamente`;
        entry.subEntries.push({
          type: 'seq', msg: `SEQ_CXC.NEXTVAL = ${cxcId}`
        });
        entry.subEntries.push({
          type: 'insert', msg: `INSERT INTO cuentas_por_cobrar (id, factura_id, monto, vencimiento) VALUES (${cxcId}, ${newRow.id}, ${fmt(newRow.total)}, '${fechaVenc}')`
        });
        entry.subEntries.push({
          type: 'update', msg: `UPDATE clientes SET balance = balance + ${fmt(newRow.total)} WHERE id = ${newRow.cliente_id}`
        });

        // Verificar límite de crédito (trigger encadenado)
        if (cliente && cliente.balance > cliente.limite_credito) {
          entry.subEntries.push({
            type: 'trigger', msg: `⚠ ALERTA: Cliente "${cliente.nombre}" excede límite de crédito (Balance: ${fmt(cliente.balance)} / Límite: ${fmt(cliente.limite_credito)})`
          });
        }
      }
      break;

    case 'TRG_AFTER_INSERT_PAGO':
      // Trigger AFTER INSERT en PAGOS_CXC → actualiza CxC y puede cambiar estado
      {
        const cxc = CUENTAS_POR_COBRAR.find(c => c.id === newRow.cxc_id);
        if (cxc) {
          cxc.monto_pagado += newRow.monto;
          cxc.saldo = +(cxc.monto_original - cxc.monto_pagado).toFixed(2);

          const oldEstado = cxc.estado;

          if (cxc.saldo <= 0) {
            cxc.saldo = 0;
            cxc.estado = 'PAGADA';
            cxc.dias_mora = 0;

            // Actualizar factura asociada
            const factura = FACTURAS.find(f => f.id === cxc.factura_id);
            if (factura) factura.estado = 'PAGADA';
          } else {
            cxc.estado = 'PARCIAL';
            const factura = FACTURAS.find(f => f.id === cxc.factura_id);
            if (factura) factura.estado = 'PARCIAL';
          }

          // Actualizar balance del cliente
          const cliente = CLIENTES.find(c => c.id === cxc.cliente_id);
          if (cliente) {
            cliente.balance = Math.max(0, cliente.balance - newRow.monto);
          }

          entry.details = `Pago ${fmt(newRow.monto)} → CxC #${cxc.id} (${oldEstado} → ${cxc.estado})`;
          entry.subEntries.push({
            type: 'update', msg: `UPDATE cuentas_por_cobrar SET monto_pagado = ${fmt(cxc.monto_pagado)}, saldo = ${fmt(cxc.saldo)}, estado = '${cxc.estado}' WHERE id = ${cxc.id}`
          });
          entry.subEntries.push({
            type: 'update', msg: `UPDATE facturas SET estado = '${cxc.estado}' WHERE id = ${cxc.factura_id}`
          });
          if (cliente) {
            entry.subEntries.push({
              type: 'update', msg: `UPDATE clientes SET balance = ${fmt(cliente.balance)} WHERE id = ${cxc.cliente_id}`
            });
          }
        }
      }
      break;

    case 'TRG_BEFORE_INSERT_FACTURA':
      // Trigger BEFORE INSERT → asigna NCF automático (secuencia)
      {
        const seqVal = SEQ_FACTURA.current;
        entry.details = `NCF asignado: ${newRow.ncf} (SEQ_FACTURA = ${seqVal})`;
        entry.subEntries.push({
          type: 'seq', msg: `SEQ_FACTURA.NEXTVAL = ${seqVal}`
        });
        entry.subEntries.push({
          type: 'proc', msg: `CALL sp_generar_ncf('${FARMACIA.ncf_serie}', ${seqVal}) → '${newRow.ncf}'`
        });
      }
      break;

    case 'TRG_AFTER_INSERT_NOTA_CREDITO':
      // Trigger para notas de crédito → ajusta CxC
      {
        const cxc = CUENTAS_POR_COBRAR.find(c => c.factura_id === newRow.factura_id);
        if (cxc) {
          cxc.monto_original -= newRow.monto;
          cxc.saldo = +(cxc.monto_original - cxc.monto_pagado).toFixed(2);
          if (cxc.saldo <= 0) {
            cxc.saldo = 0;
            cxc.estado = 'PAGADA';
          }

          entry.details = `Nota de Crédito ${fmt(newRow.monto)} aplicada a CxC #${cxc.id}`;
          entry.subEntries.push({
            type: 'update', msg: `UPDATE cuentas_por_cobrar SET monto_original = ${fmt(cxc.monto_original)}, saldo = ${fmt(cxc.saldo)} WHERE id = ${cxc.id}`
          });
        }
      }
      break;

    case 'TRG_CHECK_VENCIMIENTO':
      // Job/Procedure que recalcula días de mora
      {
        const hoy = new Date();
        let vencidas = 0;
        CUENTAS_POR_COBRAR.forEach(cxc => {
          if (cxc.estado !== 'PAGADA') {
            const fVenc = new Date(cxc.fecha_vencimiento);
            const diff = Math.floor((hoy - fVenc) / (1000 * 60 * 60 * 24));
            if (diff > 0) {
              cxc.dias_mora = diff;
              if (cxc.estado !== 'VENCIDA') {
                cxc.estado = 'VENCIDA';
                const factura = FACTURAS.find(f => f.id === cxc.factura_id);
                if (factura && factura.estado !== 'PAGADA') factura.estado = 'VENCIDA';
                vencidas++;
              }
            }
          }
        });

        entry.details = `Procedimiento sp_actualizar_mora ejecutado: ${vencidas} cuentas actualizadas`;
        entry.subEntries.push({
          type: 'proc', msg: `EXEC sp_actualizar_mora(SYSDATE) — Recalculando días de mora para ${CUENTAS_POR_COBRAR.length} cuentas`
        });
      }
      break;
  }

  triggerLog.unshift(entry);
  renderTriggerLog();
  return entry;
}

// ======================== UTILIDADES ========================

function fmt(n) {
  return Number(n).toLocaleString('es-DO', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}

function calcFechaVencimiento(fecha, dias) {
  const d = new Date(fecha);
  d.setDate(d.getDate() + dias);
  return d.toISOString().slice(0, 10);
}

function getClienteNombre(id) {
  const c = CLIENTES.find(cl => cl.id === id);
  return c ? c.nombre : 'Desconocido';
}

function getEstadoPill(estado) {
  const map = {
    'PENDIENTE': 'pending',
    'PAGADA': 'paid',
    'VENCIDA': 'overdue',
    'PARCIAL': 'partial',
    'CREDITO': 'credit',
    'ANULADA': 'cancelled'
  };
  return `<span class="status-pill ${map[estado] || 'pending'}">${estado}</span>`;
}

// ======================== NAVEGACIÓN ========================

document.addEventListener('DOMContentLoaded', () => {
  initNavigation();
  renderDashboard();
  renderFacturas();
  renderCxC();
  renderClientes();
  renderTriggerLog();
  initNewInvoiceForm();
});

function initNavigation() {
  const navItems = document.querySelectorAll('.nav-item');
  navItems.forEach(item => {
    item.addEventListener('click', (e) => {
      e.preventDefault();
      const section = item.dataset.section;
      navItems.forEach(n => n.classList.remove('active'));
      item.classList.add('active');
      document.querySelectorAll('.content-section').forEach(s => s.classList.remove('active'));
      const target = document.getElementById(`section-${section}`);
      if (target) target.classList.add('active');
      document.querySelector('.breadcrumb-current').textContent =
        item.querySelector('span').textContent;
      document.getElementById('sidebar').classList.remove('open');
    });
  });

  document.getElementById('menuToggle').addEventListener('click', () => {
    document.getElementById('sidebar').classList.toggle('open');
  });
}

// ======================== DASHBOARD ========================

function renderDashboard() {
  const totalFacturado = FACTURAS.reduce((s, f) => s + f.total, 0);
  const totalPendiente = CUENTAS_POR_COBRAR.filter(c => c.estado !== 'PAGADA').reduce((s, c) => s + c.saldo, 0);
  const totalVencido = CUENTAS_POR_COBRAR.filter(c => c.estado === 'VENCIDA').reduce((s, c) => s + c.saldo, 0);
  const totalCobrado = PAGOS_CXC.reduce((s, p) => s + p.monto, 0);
  const facturasPendientes = FACTURAS.filter(f => f.estado !== 'PAGADA' && f.estado !== 'ANULADA').length;
  const cxcVencidas = CUENTAS_POR_COBRAR.filter(c => c.estado === 'VENCIDA').length;

  document.getElementById('statTotalFacturado').textContent = `RD$ ${fmt(totalFacturado)}`;
  document.getElementById('statTotalPendiente').textContent = `RD$ ${fmt(totalPendiente)}`;
  document.getElementById('statTotalVencido').textContent = `RD$ ${fmt(totalVencido)}`;
  document.getElementById('statTotalCobrado').textContent = `RD$ ${fmt(totalCobrado)}`;
  document.getElementById('statFacturasPend').textContent = facturasPendientes;
  document.getElementById('statCxcVencidas').textContent = cxcVencidas;

  // Aging bar
  const current = CUENTAS_POR_COBRAR.filter(c => c.estado === 'PENDIENTE' && c.dias_mora === 0).reduce((s, c) => s + c.saldo, 0);
  const d30 = CUENTAS_POR_COBRAR.filter(c => c.dias_mora > 0 && c.dias_mora <= 30).reduce((s, c) => s + c.saldo, 0);
  const d60 = CUENTAS_POR_COBRAR.filter(c => c.dias_mora > 30 && c.dias_mora <= 60).reduce((s, c) => s + c.saldo, 0);
  const d90 = CUENTAS_POR_COBRAR.filter(c => c.dias_mora > 60).reduce((s, c) => s + c.saldo, 0);
  const totalAging = current + d30 + d60 + d90 || 1;

  document.getElementById('agingCurrent').style.width = `${(current / totalAging) * 100}%`;
  document.getElementById('agingD30').style.width = `${(d30 / totalAging) * 100}%`;
  document.getElementById('agingD60').style.width = `${(d60 / totalAging) * 100}%`;
  document.getElementById('agingD90').style.width = `${(d90 / totalAging) * 100}%`;

  document.getElementById('agingCurrentAmt').textContent = `RD$ ${fmt(current)}`;
  document.getElementById('agingD30Amt').textContent = `RD$ ${fmt(d30)}`;
  document.getElementById('agingD60Amt').textContent = `RD$ ${fmt(d60)}`;
  document.getElementById('agingD90Amt').textContent = `RD$ ${fmt(d90)}`;
}

// ======================== FACTURAS ========================

function renderFacturas() {
  const tbody = document.getElementById('tbodyFacturas');
  let totalFacturas = 0;

  tbody.innerHTML = FACTURAS.map(f => {
    totalFacturas += f.total;
    return `<tr>
      <td><code>${f.ncf}</code></td>
      <td>${f.fecha}</td>
      <td><strong>${getClienteNombre(f.cliente_id)}</strong></td>
      <td>RD$ ${fmt(f.subtotal)}</td>
      <td>RD$ ${fmt(f.itbis)}</td>
      <td><strong>RD$ ${fmt(f.total)}</strong></td>
      <td>${getEstadoPill(f.estado)}</td>
      <td>
        <button class="btn btn-sm btn-outline" onclick="verFactura(${f.id})" title="Ver detalle">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg>
        </button>
      </td>
    </tr>`;
  }).join('');

  document.getElementById('tfootFacturas').innerHTML = `<tr>
    <td colspan="5"><strong>TOTAL FACTURADO</strong></td>
    <td><strong>RD$ ${fmt(totalFacturas)}</strong></td>
    <td colspan="2"></td>
  </tr>`;
}

function verFactura(id) {
  const f = FACTURAS.find(fac => fac.id === id);
  if (!f) return;
  const cliente = CLIENTES.find(c => c.id === f.cliente_id);

  const modal = document.getElementById('modalOverlay');
  document.getElementById('modalTitle').textContent = `Factura ${f.ncf}`;

  document.getElementById('modalBody').innerHTML = `
    <div class="detail-grid" style="margin-bottom:20px;">
      <div class="detail-item">
        <span class="detail-label">NCF</span>
        <span class="detail-value"><code>${f.ncf}</code></span>
      </div>
      <div class="detail-item">
        <span class="detail-label">Fecha</span>
        <span class="detail-value">${f.fecha}</span>
      </div>
      <div class="detail-item">
        <span class="detail-label">Cliente</span>
        <span class="detail-value">${cliente ? cliente.nombre : ''}</span>
      </div>
      <div class="detail-item">
        <span class="detail-label">RNC Cliente</span>
        <span class="detail-value">${cliente ? cliente.rnc : ''}</span>
      </div>
      <div class="detail-item">
        <span class="detail-label">Tipo Pago</span>
        <span class="detail-value">${f.tipo_pago}</span>
      </div>
      <div class="detail-item">
        <span class="detail-label">Estado</span>
        <span class="detail-value">${getEstadoPill(f.estado)}</span>
      </div>
    </div>

    <h4 style="margin-bottom:12px; font-size:0.9rem;">Detalle de Productos</h4>
    <div class="table-responsive">
      <table class="data-table">
        <thead>
          <tr>
            <th>Producto</th>
            <th>Cant.</th>
            <th>Precio</th>
            <th>ITBIS</th>
            <th>Total</th>
          </tr>
        </thead>
        <tbody>
          ${f.items.map(item => {
            const prod = PRODUCTOS.find(p => p.id === item.producto_id);
            return `<tr>
              <td>${prod ? prod.nombre : 'N/A'}</td>
              <td>${item.cantidad}</td>
              <td>RD$ ${fmt(item.precio)}</td>
              <td>RD$ ${fmt(item.itbis)}</td>
              <td><strong>RD$ ${fmt(item.total)}</strong></td>
            </tr>`;
          }).join('')}
        </tbody>
        <tfoot>
          <tr>
            <td colspan="3"><strong>TOTALES</strong></td>
            <td><strong>RD$ ${fmt(f.itbis)}</strong></td>
            <td><strong>RD$ ${fmt(f.total)}</strong></td>
          </tr>
        </tfoot>
      </table>
    </div>

    ${f.notas ? `<p style="margin-top:16px; font-size:0.85rem; color:var(--text-muted);"><strong>Notas:</strong> ${f.notas}</p>` : ''}
  `;

  modal.classList.add('active');
}

function closeModal() {
  document.getElementById('modalOverlay').classList.remove('active');
}

// ======================== NUEVA FACTURA ========================

let invoiceLines = [];

function initNewInvoiceForm() {
  const clienteSelect = document.getElementById('newFacturaCliente');
  clienteSelect.innerHTML = '<option value="">-- Seleccionar Cliente --</option>' +
    CLIENTES.map(c => `<option value="${c.id}">${c.nombre} (${c.rnc})</option>`).join('');

  const prodSelect = document.getElementById('lineProducto');
  prodSelect.innerHTML = '<option value="">-- Seleccionar Producto --</option>' +
    PRODUCTOS.map(p => `<option value="${p.id}">${p.codigo} — ${p.nombre} (RD$ ${fmt(p.precio)})</option>`).join('');

  invoiceLines = [];
  renderInvoiceLines();
}

function agregarLinea() {
  const prodId = parseInt(document.getElementById('lineProducto').value);
  const cantidad = parseInt(document.getElementById('lineCantidad').value);

  if (!prodId || !cantidad || cantidad <= 0) {
    showToast('Seleccione un producto y cantidad válida', 'warning');
    return;
  }

  const prod = PRODUCTOS.find(p => p.id === prodId);
  if (!prod) return;

  if (cantidad > prod.stock) {
    showToast(`Stock insuficiente: ${prod.nombre} (disponible: ${prod.stock})`, 'error');
    return;
  }

  const subtotal = prod.precio * cantidad;
  const itbis = prod.itbis ? +(subtotal * FARMACIA.itbis_rate).toFixed(2) : 0;
  const total = +(subtotal + itbis).toFixed(2);

  invoiceLines.push({
    producto_id: prod.id,
    nombre: prod.nombre,
    codigo: prod.codigo,
    cantidad,
    precio: prod.precio,
    subtotal,
    itbis,
    total
  });

  renderInvoiceLines();
  document.getElementById('lineProducto').value = '';
  document.getElementById('lineCantidad').value = '1';

  showToast(`${prod.nombre} x${cantidad} agregado`, 'info');
}

function removerLinea(index) {
  invoiceLines.splice(index, 1);
  renderInvoiceLines();
}

function renderInvoiceLines() {
  const tbody = document.getElementById('tbodyNewLines');
  const totalsDiv = document.getElementById('newInvoiceTotals');

  if (invoiceLines.length === 0) {
    tbody.innerHTML = '<tr><td colspan="6" style="text-align:center; color:var(--text-muted); padding:24px;">Agregue productos a la factura</td></tr>';
    totalsDiv.innerHTML = '';
    return;
  }

  tbody.innerHTML = invoiceLines.map((line, i) => `<tr>
    <td><code>${line.codigo}</code></td>
    <td>${line.nombre}</td>
    <td>${line.cantidad}</td>
    <td>RD$ ${fmt(line.precio)}</td>
    <td>RD$ ${fmt(line.itbis)}</td>
    <td><strong>RD$ ${fmt(line.total)}</strong></td>
    <td><button class="btn btn-sm btn-danger" onclick="removerLinea(${i})">✕</button></td>
  </tr>`).join('');

  const subtotal = invoiceLines.reduce((s, l) => s + l.subtotal, 0);
  const itbis = invoiceLines.reduce((s, l) => s + l.itbis, 0);
  const total = invoiceLines.reduce((s, l) => s + l.total, 0);

  totalsDiv.innerHTML = `
    <div style="display:flex; justify-content:flex-end; gap:32px; padding:16px 0; font-size:0.9rem;">
      <div><span style="color:var(--text-muted);">Subtotal:</span> <strong>RD$ ${fmt(subtotal)}</strong></div>
      <div><span style="color:var(--text-muted);">ITBIS (18%):</span> <strong>RD$ ${fmt(itbis)}</strong></div>
      <div style="font-size:1.1rem;"><span style="color:var(--primary);">Total:</span> <strong style="color:var(--primary);">RD$ ${fmt(total)}</strong></div>
    </div>
  `;
}

function procesarFactura() {
  const clienteId = parseInt(document.getElementById('newFacturaCliente').value);
  if (!clienteId) {
    showToast('Seleccione un cliente', 'warning');
    return;
  }
  if (invoiceLines.length === 0) {
    showToast('Agregue al menos un producto', 'warning');
    return;
  }

  const cliente = CLIENTES.find(c => c.id === clienteId);
  const btn = document.getElementById('btnProcesarFactura');
  btn.innerHTML = '<span class="loading-spinner"></span> Procesando...';
  btn.disabled = true;

  setTimeout(() => {
    // 1. BEFORE INSERT TRIGGER → genera NCF
    const seqVal = SEQ_FACTURA.next();
    const ncf = `B01${String(seqVal).padStart(8, '0')}`;

    const subtotal = invoiceLines.reduce((s, l) => s + l.subtotal, 0);
    const itbis = invoiceLines.reduce((s, l) => s + l.itbis, 0);
    const total = invoiceLines.reduce((s, l) => s + l.total, 0);

    const nuevaFactura = {
      id: seqVal,
      ncf,
      fecha: new Date().toISOString().slice(0, 10),
      cliente_id: clienteId,
      subtotal,
      itbis,
      total,
      tipo_pago: cliente.tipo === 'CONTADO' ? 'CONTADO' : 'CREDITO',
      estado: cliente.tipo === 'CONTADO' ? 'PAGADA' : 'PENDIENTE',
      notas: document.getElementById('newFacturaNotas').value || '',
      items: invoiceLines.map(l => ({
        producto_id: l.producto_id,
        cantidad: l.cantidad,
        precio: l.precio,
        itbis: l.itbis,
        total: l.total
      }))
    };

    // Disparar BEFORE INSERT trigger
    showToast('⚡ TRIGGER: TRG_BEFORE_INSERT_FACTURA disparado', 'trigger');
    fireTrigger('TRG_BEFORE_INSERT_FACTURA', 'INSERT', 'FACTURAS', null, nuevaFactura);

    FACTURAS.push(nuevaFactura);

    setTimeout(() => {
      // Disparar AFTER INSERT trigger → Crea CxC automáticamente
      if (nuevaFactura.tipo_pago === 'CREDITO') {
        showToast('⚡ TRIGGER: TRG_AFTER_INSERT_FACTURA disparado → Creando CxC', 'trigger');
        fireTrigger('TRG_AFTER_INSERT_FACTURA', 'INSERT', 'FACTURAS', null, nuevaFactura);
      }

      // Actualizar stock via stored procedure
      invoiceLines.forEach(line => {
        const prod = PRODUCTOS.find(p => p.id === line.producto_id);
        if (prod) prod.stock -= line.cantidad;
      });

      // Refrescar vistas
      renderFacturas();
      renderCxC();
      renderClientes();
      renderDashboard();

      // Reset form
      invoiceLines = [];
      renderInvoiceLines();
      document.getElementById('newFacturaCliente').value = '';
      document.getElementById('newFacturaNotas').value = '';

      btn.innerHTML = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="12" y1="18" x2="12" y2="12"/><line x1="9" y1="15" x2="15" y2="15"/></svg> Procesar Factura`;
      btn.disabled = false;

      showToast(`✓ Factura ${ncf} procesada exitosamente. Total: RD$ ${fmt(total)}`, 'success');
    }, 800);
  }, 600);
}

// ======================== CUENTAS POR COBRAR ========================

function renderCxC() {
  const tbody = document.getElementById('tbodyCxC');
  let totalSaldo = 0;

  tbody.innerHTML = CUENTAS_POR_COBRAR.map(cxc => {
    totalSaldo += cxc.saldo;
    return `<tr>
      <td><code>CXC-${String(cxc.id).padStart(6, '0')}</code></td>
      <td><code>${FACTURAS.find(f => f.id === cxc.factura_id)?.ncf || 'N/A'}</code></td>
      <td><strong>${getClienteNombre(cxc.cliente_id)}</strong></td>
      <td>RD$ ${fmt(cxc.monto_original)}</td>
      <td>RD$ ${fmt(cxc.monto_pagado)}</td>
      <td><strong>RD$ ${fmt(cxc.saldo)}</strong></td>
      <td>${cxc.fecha_vencimiento}</td>
      <td>${cxc.dias_mora > 0 ? `<span style="color:var(--error); font-weight:700;">${cxc.dias_mora}d</span>` : '—'}</td>
      <td>${getEstadoPill(cxc.estado)}</td>
      <td>
        ${cxc.estado !== 'PAGADA' ? `<button class="btn btn-sm btn-primary" onclick="abrirPago(${cxc.id})">Registrar Pago</button>` : ''}
      </td>
    </tr>`;
  }).join('');

  document.getElementById('tfootCxC').innerHTML = `<tr>
    <td colspan="5"><strong>TOTAL SALDO PENDIENTE</strong></td>
    <td><strong>RD$ ${fmt(totalSaldo)}</strong></td>
    <td colspan="4"></td>
  </tr>`;
}

function abrirPago(cxcId) {
  const cxc = CUENTAS_POR_COBRAR.find(c => c.id === cxcId);
  if (!cxc) return;

  const modal = document.getElementById('modalOverlay');
  document.getElementById('modalTitle').textContent = `Registrar Pago — CxC #${cxc.id}`;

  document.getElementById('modalBody').innerHTML = `
    <div class="detail-grid" style="margin-bottom:24px;">
      <div class="detail-item">
        <span class="detail-label">Cliente</span>
        <span class="detail-value">${getClienteNombre(cxc.cliente_id)}</span>
      </div>
      <div class="detail-item">
        <span class="detail-label">Monto Original</span>
        <span class="detail-value">RD$ ${fmt(cxc.monto_original)}</span>
      </div>
      <div class="detail-item">
        <span class="detail-label">Ya Pagado</span>
        <span class="detail-value">RD$ ${fmt(cxc.monto_pagado)}</span>
      </div>
      <div class="detail-item">
        <span class="detail-label">Saldo Pendiente</span>
        <span class="detail-value big">RD$ ${fmt(cxc.saldo)}</span>
      </div>
    </div>

    <div class="form-grid">
      <div class="form-group">
        <label for="pagoMonto">Monto del Pago (RD$)</label>
        <input type="number" id="pagoMonto" value="${cxc.saldo}" step="0.01" min="0.01" max="${cxc.saldo}">
      </div>
      <div class="form-group">
        <label for="pagoMetodo">Método de Pago</label>
        <select id="pagoMetodo">
          <option value="TRANSFERENCIA">Transferencia Bancaria</option>
          <option value="CHEQUE">Cheque</option>
          <option value="EFECTIVO">Efectivo</option>
          <option value="TARJETA">Tarjeta de Crédito</option>
        </select>
      </div>
      <div class="form-group">
        <label for="pagoBanco">Banco</label>
        <select id="pagoBanco">
          <option value="Banco Popular">Banco Popular</option>
          <option value="Banco BHD">Banco BHD</option>
          <option value="Banreservas">Banreservas</option>
          <option value="Scotiabank">Scotiabank</option>
          <option value="N/A">No aplica</option>
        </select>
      </div>
      <div class="form-group">
        <label for="pagoRef">Referencia</label>
        <input type="text" id="pagoRef" placeholder="No. transferencia / cheque">
      </div>
    </div>

    <div class="action-bar" style="margin-top:24px;">
      <button class="btn btn-primary btn-lg" onclick="registrarPago(${cxc.id})">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/></svg>
        Confirmar Pago
      </button>
      <button class="btn btn-outline btn-lg" onclick="closeModal()">Cancelar</button>
    </div>
  `;

  modal.classList.add('active');
}

function registrarPago(cxcId) {
  const monto = parseFloat(document.getElementById('pagoMonto').value);
  const metodo = document.getElementById('pagoMetodo').value;
  const banco = document.getElementById('pagoBanco').value;
  const ref = document.getElementById('pagoRef').value || `AUTO-${Date.now()}`;

  const cxc = CUENTAS_POR_COBRAR.find(c => c.id === cxcId);
  if (!cxc || monto <= 0 || monto > cxc.saldo) {
    showToast('Monto inválido', 'error');
    return;
  }

  const pagoId = SEQ_PAGO.next();

  const nuevoPago = {
    id: pagoId,
    cxc_id: cxcId,
    monto,
    fecha: new Date().toISOString().slice(0, 10),
    metodo,
    referencia: ref,
    banco
  };

  PAGOS_CXC.push(nuevoPago);

  // Disparar AFTER INSERT trigger
  showToast('⚡ TRIGGER: TRG_AFTER_INSERT_PAGO disparado', 'trigger');
  fireTrigger('TRG_AFTER_INSERT_PAGO', 'INSERT', 'PAGOS_CXC', null, nuevoPago);

  closeModal();

  // Refrescar todo
  renderCxC();
  renderFacturas();
  renderClientes();
  renderDashboard();

  showToast(`✓ Pago RD$ ${fmt(monto)} registrado exitosamente (${metodo})`, 'success');
}

// ======================== CLIENTES ========================

function renderClientes() {
  const tbody = document.getElementById('tbodyClientes');

  tbody.innerHTML = CLIENTES.filter(c => c.tipo === 'CREDITO').map(c => {
    const pct = c.limite_credito > 0 ? ((c.balance / c.limite_credito) * 100).toFixed(1) : 0;
    const colorClass = pct > 90 ? 'overdue' : pct > 70 ? 'pending' : 'paid';

    return `<tr>
      <td><strong>${c.nombre}</strong></td>
      <td><code>${c.rnc}</code></td>
      <td>${c.dias_credito} días</td>
      <td>RD$ ${fmt(c.limite_credito)}</td>
      <td><strong>RD$ ${fmt(c.balance)}</strong></td>
      <td>
        <div style="display:flex; align-items:center; gap:8px;">
          <div style="flex:1; height:6px; background:var(--bg-dark); border-radius:3px; overflow:hidden;">
            <div style="width:${Math.min(pct, 100)}%; height:100%; background:${pct > 90 ? 'var(--error)' : pct > 70 ? 'var(--warning)' : 'var(--success)'}; border-radius:3px;"></div>
          </div>
          <span class="status-pill ${colorClass}" style="min-width:50px; text-align:center;">${pct}%</span>
        </div>
      </td>
    </tr>`;
  }).join('');
}

// ======================== TRIGGER LOG ========================

function renderTriggerLog() {
  const container = document.getElementById('triggerLogContainer');
  if (!container) return;

  if (triggerLog.length === 0) {
    container.innerHTML = '<div style="text-align:center; padding:32px; color:var(--text-muted);">No hay eventos de trigger registrados. Cree una factura o registre un pago para ver los triggers en acción.</div>';
    return;
  }

  container.innerHTML = triggerLog.map(entry => {
    let html = `<div class="trigger-entry">
      <span class="log-time">${entry.timestamp}</span>
      <span class="log-type trigger">TRIGGER</span>
      <span class="log-msg"><span class="sql-keyword">${entry.trigger}</span> ON <span class="highlight">${entry.table}</span> — ${entry.details}</span>
    </div>`;

    entry.subEntries.forEach(sub => {
      html += `<div class="trigger-entry" style="padding-left:40px;">
        <span class="log-time">  └─</span>
        <span class="log-type ${sub.type}">${sub.type.toUpperCase()}</span>
        <span class="log-msg">${sub.msg}</span>
      </div>`;
    });

    return html;
  }).join('');
}

// ======================== TABS ========================

function switchTab(tabGroup, tabId) {
  document.querySelectorAll(`[data-tab-group="${tabGroup}"] .tab-btn`).forEach(t => t.classList.remove('active'));
  document.querySelectorAll(`[data-tab-content="${tabGroup}"]`).forEach(c => c.classList.remove('active'));

  document.querySelector(`[data-tab-group="${tabGroup}"] .tab-btn[data-tab="${tabId}"]`).classList.add('active');
  document.getElementById(tabId).classList.add('active');
}

// ======================== SIMULACIONES ========================

function ejecutarJobVencimientos() {
  const btn = event.target;
  btn.innerHTML = '<span class="loading-spinner"></span> Ejecutando...';
  btn.disabled = true;

  setTimeout(() => {
    showToast('⚡ PROCEDURE: sp_actualizar_mora ejecutándose...', 'trigger');
    fireTrigger('TRG_CHECK_VENCIMIENTO', 'PROCEDURE', 'CUENTAS_POR_COBRAR', null, {});

    renderCxC();
    renderDashboard();

    btn.innerHTML = '🔄 Ejecutar Job de Vencimientos';
    btn.disabled = false;

    showToast('✓ Job de vencimientos ejecutado. Días de mora recalculados.', 'success');
  }, 1500);
}

function emitirNotaCredito() {
  // Find first overdue CxC
  const cxcOverdue = CUENTAS_POR_COBRAR.find(c => c.estado === 'VENCIDA' && c.saldo > 0);
  if (!cxcOverdue) {
    showToast('No hay cuentas vencidas para aplicar nota de crédito', 'info');
    return;
  }

  const descuento = +(cxcOverdue.saldo * 0.05).toFixed(2); // 5% descuento
  const ncId = SEQ_NOTA_CREDITO.next();

  const nota = {
    id: ncId,
    factura_id: cxcOverdue.factura_id,
    monto: descuento,
    motivo: 'Descuento por pronto pago — negociación de mora',
    fecha: new Date().toISOString().slice(0, 10)
  };

  NOTAS_CREDITO.push(nota);

  showToast(`⚡ TRIGGER: TRG_AFTER_INSERT_NOTA_CREDITO disparado`, 'trigger');
  fireTrigger('TRG_AFTER_INSERT_NOTA_CREDITO', 'INSERT', 'NOTAS_CREDITO', null, nota);

  renderCxC();
  renderDashboard();

  showToast(`✓ Nota de Crédito NC-${ncId} emitida por RD$ ${fmt(descuento)}`, 'success');
}

// ======================== TOAST ========================

function showToast(message, type = 'info') {
  const container = document.getElementById('toastContainer');
  const toast = document.createElement('div');
  toast.className = `toast ${type}`;

  const icons = {
    success: '✓',
    error: '✗',
    warning: '⚠',
    info: 'ℹ',
    trigger: '⚡'
  };

  toast.innerHTML = `
    <span style="font-size:1.15rem;">${icons[type] || icons.info}</span>
    <span>${message}</span>
  `;
  container.appendChild(toast);

  setTimeout(() => {
    toast.style.opacity = '0';
    toast.style.transform = 'translateX(50px)';
    toast.style.transition = 'all 0.3s ease';
    setTimeout(() => toast.remove(), 300);
  }, 5000);
}
