/* ============================================================
   Integración BD: Facturación y Cuentas por Cobrar
   Lógica Simplificada, Profesional y sin Emojis
   ============================================================ */

// Secuencias simuladas
let SEQ_FACTURA = 1004;
let SEQ_CXC = 3001;

// Tabla: FACTURAS
let FACTURAS = [
  {
    id_factura: 'FAC-1001',
    id_cliente: 101,
    cliente_nombre: 'Centro Médico Nacional',
    fecha_emision: '2026-10-20',
    monto_total: 12500.00,
    condiciones_pago: 'CREDITO',
    concepto: 'Antibióticos e insumos quirúrgicos'
  },
  {
    id_factura: 'FAC-1002',
    id_cliente: 105,
    cliente_nombre: 'Juan Pérez Almonte',
    fecha_emision: '2026-10-21',
    monto_total: 1850.00,
    condiciones_pago: 'CONTADO',
    concepto: 'Analgésicos y vitaminas venta directa'
  },
  {
    id_factura: 'FAC-1003',
    id_cliente: 102,
    cliente_nombre: 'Clínica Abreu',
    fecha_emision: '2026-10-22',
    monto_total: 24700.00,
    condiciones_pago: 'CREDITO',
    concepto: 'Lote de sueros y soluciones estériles'
  }
];

// Tabla: CUENTAS_POR_COBRAR (Alimentada exclusivamente por el trigger)
let CUENTAS_POR_COBRAR = [
  {
    id_cxc: 3001,
    id_factura: 'FAC-1001',
    id_cliente: 101,
    cliente_nombre: 'Centro Médico Nacional',
    fecha_cxc: '2026-10-20',
    monto_deuda: 12500.00,
    estado: 'PENDIENTE'
  },
  {
    id_cxc: 3002,
    id_factura: 'FAC-1003',
    id_cliente: 102,
    cliente_nombre: 'Clínica Abreu',
    fecha_cxc: '2026-10-22',
    monto_deuda: 24700.00,
    estado: 'PENDIENTE'
  }
];

// Inicialización
document.addEventListener('DOMContentLoaded', () => {
  const hoy = new Date().toISOString().slice(0, 10);
  document.getElementById('fechaEmision').value = hoy;
  document.getElementById('numFactura').value = `FAC-${SEQ_FACTURA}`;

  renderFacturas();
  renderCxC();
});

// Guardar Factura
function guardarFactura(event) {
  event.preventDefault();

  const id_factura = document.getElementById('numFactura').value;
  const selectCliente = document.getElementById('clienteSelect');
  const id_cliente = parseInt(selectCliente.value);
  const cliente_nombre = selectCliente.options[selectCliente.selectedIndex].getAttribute('data-nombre');
  const fecha_emision = document.getElementById('fechaEmision').value;
  const monto_total = parseFloat(document.getElementById('montoTotal').value);
  const condiciones_pago = document.getElementById('condicionesPago').value;
  const concepto = document.getElementById('conceptoFactura').value;

  if (isNaN(monto_total) || monto_total <= 0) {
    alert('Ingrese un monto válido.');
    return;
  }

  // Inserción en FACTURAS
  const nuevaFactura = {
    id_factura,
    id_cliente,
    cliente_nombre,
    fecha_emision,
    monto_total,
    condiciones_pago,
    concepto
  };

  FACTURAS.unshift(nuevaFactura);

  // Ejecución del Trigger
  ejecutarTriggerOracle(nuevaFactura);

  // Renderizar
  renderFacturas(id_factura);
  renderCxC(condiciones_pago === 'CREDITO' ? nuevaFactura.id_factura : null);

  // Siguiente correlativo
  SEQ_FACTURA++;
  document.getElementById('numFactura').value = `FAC-${SEQ_FACTURA}`;
  document.getElementById('montoTotal').value = '';
  document.getElementById('conceptoFactura').value = '';
}

// Lógica del Trigger
function ejecutarTriggerOracle(rowNew) {
  const consoleBody = document.getElementById('consoleBody');
  const hora = new Date().toLocaleTimeString();

  if (rowNew.condiciones_pago === 'CREDITO') {
    SEQ_CXC++;
    const nuevoIdCxC = SEQ_CXC;

    const nuevaCxC = {
      id_cxc: nuevoIdCxC,
      id_factura: rowNew.id_factura,
      id_cliente: rowNew.id_cliente,
      cliente_nombre: rowNew.cliente_nombre,
      fecha_cxc: rowNew.fecha_emision,
      monto_deuda: rowNew.monto_total,
      estado: 'PENDIENTE'
    };

    CUENTAS_POR_COBRAR.unshift(nuevaCxC);

    consoleBody.innerHTML = `
      <div class="log-entry credit">
        <div class="log-header">
          <span>TRIGGER EJECUTADO: TRG_FACTURA_A_CXC (AFTER INSERT)</span>
          <span class="tag">CRÉDITO</span>
          <span class="log-time">${hora}</span>
        </div>
        <div class="log-detail">
          Factura <strong>${rowNew.id_factura}</strong> es a CRÉDITO. El trigger leyó los datos e insertó automáticamente en <code>CUENTAS_POR_COBRAR</code> el registro <strong>#${nuevoIdCxC}</strong> por <strong>RD$ ${fmt(rowNew.monto_total)}</strong> para el cliente <strong>${rowNew.cliente_nombre}</strong>.
        </div>
        <div class="log-sql">
          INSERT INTO CUENTAS_POR_COBRAR (id_cxc, id_factura, id_cliente, fecha_cxc, monto_deuda, estado)<br>
          VALUES (${nuevoIdCxC}, '${rowNew.id_factura}', ${rowNew.id_cliente}, '${rowNew.fecha_emision}', ${rowNew.monto_total}, 'PENDIENTE');
        </div>
      </div>
    ` + consoleBody.innerHTML;

    showToast(`Cuenta por cobrar #${nuevoIdCxC} generada para ${rowNew.cliente_nombre}`, 'credit');

  } else {
    consoleBody.innerHTML = `
      <div class="log-entry cash">
        <div class="log-header">
          <span>TRIGGER EVALUADO: TRG_FACTURA_A_CXC</span>
          <span class="tag">CONTADO</span>
          <span class="log-time">${hora}</span>
        </div>
        <div class="log-detail">
          Factura <strong>${rowNew.id_factura}</strong> es al CONTADO. La condición <code>IF :NEW.condiciones_pago = 'CREDITO'</code> no se cumple. El trigger no inserta registros en <code>CUENTAS_POR_COBRAR</code>.
        </div>
      </div>
    ` + consoleBody.innerHTML;

    showToast(`Factura ${rowNew.id_factura} al contado: no genera deuda`, 'cash');
  }
}

// Renders
function renderFacturas(highlightId = null) {
  const tbody = document.getElementById('tbodyFacturas');
  const countBadge = document.getElementById('countFacturas');
  countBadge.textContent = `${FACTURAS.length} registros`;

  if (FACTURAS.length === 0) {
    tbody.innerHTML = '<tr class="empty-row"><td colspan="5">No hay facturas registradas</td></tr>';
    return;
  }

  tbody.innerHTML = FACTURAS.map(f => {
    const isNew = f.id_factura === highlightId ? 'highlight-row' : '';
    const pillClass = f.condiciones_pago === 'CREDITO' ? 'credito' : 'contado';

    return `
      <tr class="${isNew}">
        <td><strong>${f.id_factura}</strong></td>
        <td>
          <div>${f.cliente_nombre}</div>
          <small style="color:var(--text-dim); font-size:0.75rem;">ID: ${f.id_cliente}</small>
        </td>
        <td>${f.fecha_emision}</td>
        <td><span class="pill ${pillClass}">${f.condiciones_pago}</span></td>
        <td><strong>RD$ ${fmt(f.monto_total)}</strong></td>
      </tr>
    `;
  }).join('');
}

function renderCxC(highlightFacturaId = null) {
  const tbody = document.getElementById('tbodyCxC');
  const countBadge = document.getElementById('countCxC');
  countBadge.textContent = `${CUENTAS_POR_COBRAR.length} deudas`;

  if (CUENTAS_POR_COBRAR.length === 0) {
    tbody.innerHTML = '<tr class="empty-row"><td colspan="6">No hay cuentas por cobrar generadas</td></tr>';
    return;
  }

  tbody.innerHTML = CUENTAS_POR_COBRAR.map(c => {
    const isNew = c.id_factura === highlightFacturaId ? 'highlight-row' : '';

    return `
      <tr class="${isNew}">
        <td><span style="color:var(--primary-light); font-weight:600;">#${c.id_cxc}</span></td>
        <td><strong>${c.id_factura}</strong></td>
        <td>${c.id_cliente}</td>
        <td>${c.fecha_cxc}</td>
        <td><strong>RD$ ${fmt(c.monto_deuda)}</strong></td>
        <td><span class="pill pendiente">${c.estado}</span></td>
      </tr>
    `;
  }).join('');
}

// Botones rápidos
function cargarEjemplo(tipo) {
  const selectCliente = document.getElementById('clienteSelect');
  const inputMonto = document.getElementById('montoTotal');
  const selectCondicion = document.getElementById('condicionesPago');
  const inputConcepto = document.getElementById('conceptoFactura');

  if (tipo === 'CREDITO') {
    selectCliente.value = '101';
    inputMonto.value = '18500.00';
    selectCondicion.value = 'CREDITO';
    inputConcepto.value = 'Lote de antibióticos y analgésicos hospitalarios';
    showToast('Ejemplo a crédito cargado. Presione Guardar Factura.', 'credit');
  } else {
    selectCliente.value = '105';
    inputMonto.value = '2350.00';
    selectCondicion.value = 'CONTADO';
    inputConcepto.value = 'Medicamentos de venta libre y vitaminas';
    showToast('Ejemplo al contado cargado. Presione Guardar Factura.', 'cash');
  }
}

// Utilidades
function fmt(n) {
  return Number(n).toLocaleString('es-DO', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}

function showToast(message, type = 'credit') {
  const container = document.getElementById('toastContainer');
  const toast = document.createElement('div');
  toast.className = `toast toast-${type}`;
  toast.textContent = message;
  container.appendChild(toast);

  setTimeout(() => {
    toast.style.opacity = '0';
    toast.style.transform = 'translateY(6px)';
    toast.style.transition = 'all 0.2s ease';
    setTimeout(() => toast.remove(), 250);
  }, 3500);
}
