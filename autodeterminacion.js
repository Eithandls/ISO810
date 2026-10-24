/* ============================================================
   Ferretería Americana — Sistema RH / Auto-determinación TSS
   Lógica de la Aplicación
   ============================================================ */

// ======================== DATOS ========================

const EMPLEADOR = {
  rnc: '131456789',
  razonSocial: 'Ferretería Americana, S.R.L.',
  nombreComercial: 'Ferretería Americana',
  sectorEconomico: 'Comercio al por menor de artículos de ferretería',
  representanteLegal: 'Carlos Antonio Méndez Reyes'
};

const TASAS = {
  SFS_EMPLEADOR: 0.0709,
  SFS_TRABAJADOR: 0.0304,
  AFP_EMPLEADOR: 0.0710, // Se usa 0.0715 en algunos cálculos
  AFP_TRABAJADOR: 0.0287, // Se usa 0.0285 en algunos cálculos
  SRL_EMPLEADOR: 0.0118
};

const TRABAJADORES = [
  {
    secuencia: 1,
    tipoDocumento: 'C',
    numeroDocumento: '00114725836',
    nss: '201456789',
    nombres: 'María Isabel',
    apellido1: 'García',
    apellido2: 'Rodríguez',
    sexo: 'F',
    fechaNacimiento: '1988-05-14',
    fechaIngreso: '2019-03-01',
    fechaSalida: null,
    tipoNovedad: 'NR',
    tipoIngreso: 'F',
    salarioCotizable: 45000.00,
    salarioISR: 45000.00,
    salarioINFOTEP: 45000.00,
    otrasRemuneraciones: 0,
    horasExtra: 0,
    comisiones: 0,
    incentivos: 0,
    vacaciones: 0,
    regalia: 0,
    ingresosExentos: 0
  },
  {
    secuencia: 2,
    tipoDocumento: 'C',
    numeroDocumento: '40212345678',
    nss: '201987654',
    nombres: 'José Miguel',
    apellido1: 'Pérez',
    apellido2: 'Santos',
    sexo: 'M',
    fechaNacimiento: '1995-11-20',
    fechaIngreso: '2026-09-15',
    fechaSalida: null,
    tipoNovedad: 'IN',
    tipoIngreso: 'F',
    salarioCotizable: 30000.00,
    salarioISR: 30000.00,
    salarioINFOTEP: 30000.00,
    otrasRemuneraciones: 0,
    horasExtra: 0,
    comisiones: 0,
    incentivos: 0,
    vacaciones: 0,
    regalia: 0,
    ingresosExentos: 0
  },
  {
    secuencia: 3,
    tipoDocumento: 'C',
    numeroDocumento: '22300678901',
    nss: '201234567',
    nombres: 'Ana Luisa',
    apellido1: 'Marte',
    apellido2: 'Féliz',
    sexo: 'F',
    fechaNacimiento: '1990-02-10',
    fechaIngreso: '2020-06-01',
    fechaSalida: '2026-09-20',
    tipoNovedad: 'SA',
    tipoIngreso: 'F',
    salarioCotizable: 35000.00,
    salarioISR: 35000.00,
    salarioINFOTEP: 35000.00,
    otrasRemuneraciones: 0,
    horasExtra: 2500.00,
    comisiones: 0,
    incentivos: 0,
    vacaciones: 0,
    regalia: 0,
    ingresosExentos: 58333.33
  },
  {
    secuencia: 4,
    tipoDocumento: 'C',
    numeroDocumento: '05600123456',
    nss: '201567890',
    nombres: 'Roberto Carlos',
    apellido1: 'Fernández',
    apellido2: 'De la Cruz',
    sexo: 'M',
    fechaNacimiento: '1985-08-25',
    fechaIngreso: '2018-01-15',
    fechaSalida: null,
    tipoNovedad: 'NR',
    tipoIngreso: 'V',
    salarioCotizable: 55000.00,
    salarioISR: 68000.00,
    salarioINFOTEP: 55000.00,
    otrasRemuneraciones: 0,
    horasExtra: 0,
    comisiones: 13000.00,
    incentivos: 0,
    vacaciones: 0,
    regalia: 0,
    ingresosExentos: 0
  },
  {
    secuencia: 5,
    tipoDocumento: 'P',
    numeroDocumento: 'AB1234567',
    nss: '201345678',
    nombres: 'Jean Pierre',
    apellido1: 'Duvalier',
    apellido2: '',
    sexo: 'M',
    fechaNacimiento: '1992-07-03',
    fechaIngreso: '2022-04-10',
    fechaSalida: null,
    tipoNovedad: 'NR',
    tipoIngreso: 'F',
    salarioCotizable: 60000.00,
    salarioISR: 60000.00,
    salarioINFOTEP: 60000.00,
    otrasRemuneraciones: 0,
    horasExtra: 3500.00,
    comisiones: 0,
    incentivos: 5000.00,
    vacaciones: 0,
    regalia: 0,
    ingresosExentos: 0
  }
];

// Calcular aportes para cada trabajador
function calcularAportes(t) {
  const sfs_e = +(t.salarioCotizable * TASAS.SFS_EMPLEADOR).toFixed(2);
  const sfs_t = +(t.salarioCotizable * TASAS.SFS_TRABAJADOR).toFixed(2);
  const afp_e = +(t.salarioCotizable * TASAS.AFP_EMPLEADOR).toFixed(2);
  const afp_t = +(t.salarioCotizable * TASAS.AFP_TRABAJADOR).toFixed(2);
  const srl_e = +(t.salarioCotizable * TASAS.SRL_EMPLEADOR).toFixed(2);
  return {
    sfs_e, sfs_t, sfs_total: +(sfs_e + sfs_t).toFixed(2),
    afp_e, afp_t, afp_total: +(afp_e + afp_t).toFixed(2),
    srl_e,
    total_empleador: +(sfs_e + afp_e + srl_e).toFixed(2),
    total_trabajador: +(sfs_t + afp_t).toFixed(2),
    total_sdss: +(sfs_e + sfs_t + afp_e + afp_t + srl_e).toFixed(2)
  };
}

// Estado de la app
let xmlGenerado = null;
let xmlValidado = false;

// ======================== NAVEGACIÓN ========================

document.addEventListener('DOMContentLoaded', () => {
  initNavigation();
  renderEmpleados();
  initSOAPRequest();
  initRESTRequest();
});

function initNavigation() {
  const navItems = document.querySelectorAll('.nav-item');
  navItems.forEach(item => {
    item.addEventListener('click', (e) => {
      e.preventDefault();
      const section = item.dataset.section;
      // Update nav
      navItems.forEach(n => n.classList.remove('active'));
      item.classList.add('active');
      // Switch section
      document.querySelectorAll('.content-section').forEach(s => s.classList.remove('active'));
      const target = document.getElementById(`section-${section}`);
      if (target) target.classList.add('active');
      // Update breadcrumb
      document.querySelector('.breadcrumb-current').textContent =
        item.querySelector('span').textContent;
      // Close sidebar on mobile
      document.getElementById('sidebar').classList.remove('open');
    });
  });

  // Mobile menu toggle
  document.getElementById('menuToggle').addEventListener('click', () => {
    document.getElementById('sidebar').classList.toggle('open');
  });
}

// ======================== TABLA EMPLEADOS ========================

function renderEmpleados() {
  const tbody = document.getElementById('tbodyEmpleados');
  const tfoot = document.getElementById('tfootEmpleados');

  let totales = {
    salario: 0, sfs: 0, afp: 0, srl: 0, totalSDSS: 0
  };

  const novedadLabels = {
    'NR': '<span class="status-pill accepted">Sin novedad</span>',
    'IN': '<span class="status-pill" style="background:rgba(34,197,94,0.12);color:#22c55e">Ingreso</span>',
    'SA': '<span class="status-pill" style="background:rgba(239,68,68,0.12);color:#ef4444">Salida</span>',
    'LM': '<span class="status-pill" style="background:rgba(234,179,8,0.12);color:#eab308">No laboró mes</span>',
    'VC': '<span class="status-pill" style="background:rgba(168,85,247,0.12);color:#a855f7">Ocasional</span>',
    'AU': '<span class="status-pill" style="background:rgba(59,130,246,0.12);color:#3b82f6">Aumento</span>'
  };

  tbody.innerHTML = TRABAJADORES.map(t => {
    const a = calcularAportes(t);
    totales.salario += t.salarioCotizable;
    totales.sfs += a.sfs_total;
    totales.afp += a.afp_total;
    totales.srl += a.srl_e;
    totales.totalSDSS += a.total_sdss;

    return `<tr>
      <td>${t.secuencia}</td>
      <td>${t.tipoDocumento}</td>
      <td><code>${t.numeroDocumento}</code></td>
      <td><strong>${t.nombres} ${t.apellido1}</strong> ${t.apellido2}</td>
      <td>${novedadLabels[t.tipoNovedad] || t.tipoNovedad}</td>
      <td>${t.tipoIngreso === 'F' ? 'Fijo' : 'Variable'}</td>
      <td>RD$ ${fmt(t.salarioCotizable)}</td>
      <td>RD$ ${fmt(a.sfs_total)}</td>
      <td>RD$ ${fmt(a.afp_total)}</td>
      <td>RD$ ${fmt(a.srl_e)}</td>
      <td><strong>RD$ ${fmt(a.total_sdss)}</strong></td>
    </tr>`;
  }).join('');

  tfoot.innerHTML = `<tr>
    <td colspan="6"><strong>TOTALES</strong></td>
    <td><strong>RD$ ${fmt(totales.salario)}</strong></td>
    <td><strong>RD$ ${fmt(totales.sfs)}</strong></td>
    <td><strong>RD$ ${fmt(totales.afp)}</strong></td>
    <td><strong>RD$ ${fmt(totales.srl)}</strong></td>
    <td><strong>RD$ ${fmt(totales.totalSDSS)}</strong></td>
  </tr>`;
}

function fmt(n) {
  return n.toLocaleString('es-DO', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}

function exportarTabla() {
  showToast('Exportación iniciada: empleados_202609.xlsx', 'info');
}

// ======================== GENERAR XML ========================

function generarXML() {
  const btn = document.getElementById('btnGenerar');
  btn.innerHTML = '<span class="loading-spinner"></span> Generando...';
  btn.disabled = true;

  setTimeout(() => {
    const now = new Date().toISOString().slice(0, 19);

    let xml = `<?xml version="1.0" encoding="UTF-8"?>
<AutodeterminacionTSS
    xmlns="http://www.ferreteriaamericana.com.do/rh/autodeterminacion"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://www.ferreteriaamericana.com.do/rh/autodeterminacion AutodeterminacionTSS.xsd"
    sistemaOrigen="RRHH_FERRETERIA_AMERICANA"
    periodo="202609"
    fechaGeneracion="${now}"
    moneda="DOP"
    version="1.0"
    estado="PENDIENTE">

  <Empleador>
    <RNC>${EMPLEADOR.rnc}</RNC>
    <RazonSocial>${EMPLEADOR.razonSocial}</RazonSocial>
    <NombreComercial>${EMPLEADOR.nombreComercial}</NombreComercial>
    <SectorEconomico>${EMPLEADOR.sectorEconomico}</SectorEconomico>
    <RepresentanteLegal>${EMPLEADOR.representanteLegal}</RepresentanteLegal>
  </Empleador>

  <Trabajadores>`;

    let totalSalarios = 0, totalSFS = 0, totalAFP = 0, totalSRL = 0;
    let totalEmpleador = 0, totalTrabajador = 0;

    TRABAJADORES.forEach(t => {
      const a = calcularAportes(t);
      totalSalarios += t.salarioCotizable;
      totalSFS += a.sfs_total;
      totalAFP += a.afp_total;
      totalSRL += a.srl_e;
      totalEmpleador += a.total_empleador;
      totalTrabajador += a.total_trabajador;

      xml += `
    <Trabajador secuencia="${t.secuencia}">
      <TipoDocumento>${t.tipoDocumento}</TipoDocumento>
      <NumeroDocumento>${t.numeroDocumento}</NumeroDocumento>
      <NSS>${t.nss}</NSS>
      <Nombres>${t.nombres}</Nombres>
      <Apellido1>${t.apellido1}</Apellido1>${t.apellido2 ? `
      <Apellido2>${t.apellido2}</Apellido2>` : ''}
      <Sexo>${t.sexo}</Sexo>
      <FechaNacimiento>${t.fechaNacimiento}</FechaNacimiento>
      <FechaIngreso>${t.fechaIngreso}</FechaIngreso>${t.fechaSalida ? `
      <FechaSalida>${t.fechaSalida}</FechaSalida>` : ''}
      <TipoNovedad>${t.tipoNovedad}</TipoNovedad>
      <TipoIngreso>${t.tipoIngreso}</TipoIngreso>
      <InformacionSalarial>
        <SalarioCotizableSDSS>${t.salarioCotizable.toFixed(2)}</SalarioCotizableSDSS>
        <SalarioISR>${t.salarioISR.toFixed(2)}</SalarioISR>
        <SalarioINFOTEP>${t.salarioINFOTEP.toFixed(2)}</SalarioINFOTEP>
        <OtrasRemuneraciones>${t.otrasRemuneraciones.toFixed(2)}</OtrasRemuneraciones>
        <HorasExtraordinarias>${t.horasExtra.toFixed(2)}</HorasExtraordinarias>
        <Comisiones>${t.comisiones.toFixed(2)}</Comisiones>
        <Incentivos>${t.incentivos.toFixed(2)}</Incentivos>
        <Vacaciones>${t.vacaciones.toFixed(2)}</Vacaciones>
        <RegaliaPascual>${t.regalia.toFixed(2)}</RegaliaPascual>
        <IngresosExentos>${t.ingresosExentos.toFixed(2)}</IngresosExentos>
      </InformacionSalarial>
      <Aportes>
        <SFS_Empleador>${a.sfs_e.toFixed(2)}</SFS_Empleador>
        <SFS_Trabajador>${a.sfs_t.toFixed(2)}</SFS_Trabajador>
        <SFS_Total>${a.sfs_total.toFixed(2)}</SFS_Total>
        <AFP_Empleador>${a.afp_e.toFixed(2)}</AFP_Empleador>
        <AFP_Trabajador>${a.afp_t.toFixed(2)}</AFP_Trabajador>
        <AFP_Total>${a.afp_total.toFixed(2)}</AFP_Total>
        <SRL_Empleador>${a.srl_e.toFixed(2)}</SRL_Empleador>
      </Aportes>
    </Trabajador>`;
    });

    const montoTotalSDSS = +(totalEmpleador + totalTrabajador).toFixed(2);

    xml += `
  </Trabajadores>

  <TotalesControl>
    <CantidadTrabajadores>${TRABAJADORES.length}</CantidadTrabajadores>
    <TotalSalariosCotizables>${totalSalarios.toFixed(2)}</TotalSalariosCotizables>
    <TotalAporteSFS>${totalSFS.toFixed(2)}</TotalAporteSFS>
    <TotalAporteAFP>${totalAFP.toFixed(2)}</TotalAporteAFP>
    <TotalAporteSRL>${totalSRL.toFixed(2)}</TotalAporteSRL>
    <TotalAporteEmpleador>${totalEmpleador.toFixed(2)}</TotalAporteEmpleador>
    <TotalAporteTrabajador>${totalTrabajador.toFixed(2)}</TotalAporteTrabajador>
    <MontoTotalSDSS>${montoTotalSDSS.toFixed(2)}</MontoTotalSDSS>
  </TotalesControl>

</AutodeterminacionTSS>`;

    xmlGenerado = xml;

    // Show preview
    document.getElementById('xmlPreviewCard').style.display = 'block';
    document.getElementById('xmlPreview').textContent = xml;
    document.getElementById('btnValidar').disabled = false;

    // Update workflow
    document.getElementById('step2').classList.remove('active');
    document.getElementById('step2').classList.add('completed');
    document.getElementById('step3').classList.add('active');

    btn.innerHTML = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="20" height="20"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/></svg> XML Generado`;
    btn.disabled = false;

    showToast('XML de Auto-determinación generado exitosamente para el período 202609', 'success');
    updateSOAPWithXML();
  }, 1200);
}

// ======================== VALIDAR XML ========================

function validarXML() {
  if (!xmlGenerado) {
    showToast('Debe generar el XML primero', 'warning');
    return;
  }

  const btnValidar = document.getElementById('btnValidar');
  btnValidar.innerHTML = '<span class="loading-spinner"></span> Validando...';
  btnValidar.disabled = true;

  setTimeout(() => {
    const validationCard = document.getElementById('validationCard');
    const validationResults = document.getElementById('validationResults');

    // Simulate validation
    const checks = [
      { name: 'Estructura del documento raíz', status: 'ok' },
      { name: 'Formato RNC empleador (9 dígitos)', status: 'ok' },
      { name: 'Documentos de identidad válidos', status: 'ok' },
      { name: 'Tipos de novedad reconocidos (NR, IN, SA)', status: 'ok' },
      { name: 'Salarios cotizables > 0', status: 'ok' },
      { name: 'Cálculo SFS (7.09% + 3.04%)', status: 'ok' },
      { name: 'Cálculo AFP (7.10% + 2.87%)', status: 'ok' },
      { name: 'Cálculo SRL (1.18%)', status: 'ok' },
      { name: 'Totales de control cuadran', status: 'ok' },
      { name: 'Secuencias únicas', status: 'ok' },
      { name: 'Período formato AAAAMM', status: 'ok' },
      { name: 'Fechas de ingreso/salida coherentes', status: 'ok' }
    ];

    validationResults.innerHTML = `
      <div class="validation-success">
        <div class="v-icon">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="20 6 9 17 4 12"/></svg>
        </div>
        <div>
          <h4>✓ Validación Exitosa contra AutodeterminacionTSS.xsd</h4>
          <p>${checks.length} validaciones pasadas — 0 errores — 0 advertencias</p>
        </div>
      </div>
      <div style="margin-top:20px;">
        <table class="data-table">
          <thead>
            <tr>
              <th>Validación</th>
              <th>Estado</th>
            </tr>
          </thead>
          <tbody>
            ${checks.map(c => `<tr>
              <td>${c.name}</td>
              <td><span class="status-pill accepted">✓ OK</span></td>
            </tr>`).join('')}
          </tbody>
        </table>
      </div>`;

    validationCard.style.display = 'block';
    xmlValidado = true;

    // Update workflow
    document.getElementById('step3').classList.remove('active');
    document.getElementById('step3').classList.add('completed');
    document.getElementById('step4').classList.add('active');

    btnValidar.innerHTML = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="20" height="20"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/></svg> Validado ✓`;

    showToast('Validación exitosa: El XML cumple con el esquema XSD de la TSS', 'success');
  }, 1500);
}

// ======================== SOAP REQUEST ========================

function initSOAPRequest() {
  const soapRequest = document.getElementById('soapRequest');
  soapRequest.textContent = `<?xml version="1.0" encoding="UTF-8"?>
<soapenv:Envelope
    xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
    xmlns:ws="http://www.ferreteriaamericana.com.do/rh/ws/autodeterminacion"
    xmlns:fa="http://www.ferreteriaamericana.com.do/rh/autodeterminacion">
  <soapenv:Header>
    <wsse:Security xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd">
      <wsse:UsernameToken>
        <wsse:Username>FERRAM_RH</wsse:Username>
        <wsse:Password Type="PasswordDigest">****</wsse:Password>
        <wsse:Nonce>dGVzdA==</wsse:Nonce>
        <wsu:Created>2026-09-30T23:59:00Z</wsu:Created>
      </wsse:UsernameToken>
    </wsse:Security>
  </soapenv:Header>
  <soapenv:Body>
    <ws:EnviarAutodeterminacionRequest>
      <ws:Credenciales>
        <ws:Usuario>FERRAM_RH</ws:Usuario>
        <ws:Clave>****</ws:Clave>
        <ws:RNC>131456789</ws:RNC>
      </ws:Credenciales>
      <!-- El XML de AutodeterminacionTSS va aquí -->
      <fa:AutodeterminacionTSS
          sistemaOrigen="RRHH_FERRETERIA_AMERICANA"
          periodo="202609"
          fechaGeneracion="2026-09-30T23:59:00"
          moneda="DOP" version="1.0" estado="PENDIENTE">
        <!-- ... contenido completo ... -->
      </fa:AutodeterminacionTSS>
    </ws:EnviarAutodeterminacionRequest>
  </soapenv:Body>
</soapenv:Envelope>`;

  document.getElementById('soapResponse').textContent = '<!-- Ejecute el envío para ver la respuesta SOAP -->';
}

function updateSOAPWithXML() {
  // SOAP request is already shown; no need to re-render full XML in it
}

function enviarSOAP() {
  const btn = document.getElementById('btnEnviarSOAP');
  btn.innerHTML = '<span class="loading-spinner"></span> Enviando vía SOAP...';
  btn.disabled = true;

  // Simulate network delay
  setTimeout(() => {
    const confirmNum = 'TSS-2026-09-00512';
    const now = new Date().toISOString();

    const response = `<?xml version="1.0" encoding="UTF-8"?>
<soapenv:Envelope
    xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
    xmlns:ws="http://www.ferreteriaamericana.com.do/rh/ws/autodeterminacion">
  <soapenv:Header/>
  <soapenv:Body>
    <ws:EnviarAutodeterminacionResponse>
      <ws:Exitoso>true</ws:Exitoso>
      <ws:CodigoRespuesta>200</ws:CodigoRespuesta>
      <ws:Mensaje>Autodeterminación recibida y procesada exitosamente.
        El monto será cargado a la cuenta del empleador RNC 131456789
        en la próxima fecha de corte.</ws:Mensaje>
      <ws:NumeroConfirmacion>${confirmNum}</ws:NumeroConfirmacion>
      <ws:FechaRecepcion>${now}</ws:FechaRecepcion>
    </ws:EnviarAutodeterminacionResponse>
  </soapenv:Body>
</soapenv:Envelope>`;

    document.getElementById('soapResponse').textContent = response;

    // Update workflow
    document.getElementById('step4').classList.remove('active');
    document.getElementById('step4').classList.add('completed');
    document.getElementById('step5').classList.add('active');
    document.getElementById('step5').classList.add('completed');

    // Update status
    document.getElementById('statEstado').textContent = 'Enviado ✓';

    // Add to history
    addHistorialEntry(confirmNum, 'SOAP');

    btn.innerHTML = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="20" height="20"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/></svg> Enviado ✓`;

    showToast(`✓ Autodeterminación enviada. Confirmación: ${confirmNum}`, 'success');
  }, 2500);
}

// ======================== REST REQUEST ========================

function initRESTRequest() {
  const restRequest = document.getElementById('restRequest');

  const jsonPayload = {
    empleador: {
      rnc: EMPLEADOR.rnc,
      razonSocial: EMPLEADOR.razonSocial,
      nombreComercial: EMPLEADOR.nombreComercial
    },
    periodo: "202609",
    moneda: "DOP",
    trabajadores: TRABAJADORES.map(t => {
      const a = calcularAportes(t);
      return {
        secuencia: t.secuencia,
        tipoDocumento: t.tipoDocumento,
        numeroDocumento: t.numeroDocumento,
        nss: t.nss,
        nombreCompleto: `${t.nombres} ${t.apellido1} ${t.apellido2}`.trim(),
        tipoNovedad: t.tipoNovedad,
        salarioCotizable: t.salarioCotizable,
        aportes: {
          sfs: a.sfs_total,
          afp: a.afp_total,
          srl: a.srl_e,
          total: a.total_sdss
        }
      };
    }),
    totalesControl: {
      cantidadTrabajadores: TRABAJADORES.length,
      totalSalarios: TRABAJADORES.reduce((s, t) => s + t.salarioCotizable, 0)
    }
  };

  restRequest.textContent = JSON.stringify(jsonPayload, null, 2);
  document.getElementById('restResponse').textContent = '// Ejecute el envío para ver la respuesta REST';
}

function enviarREST() {
  showToast('Enviando via REST API...', 'info');

  setTimeout(() => {
    const confirmNum = 'TSS-2026-09-00513';
    const response = {
      success: true,
      statusCode: 201,
      message: "Autodeterminación recibida y procesada exitosamente.",
      data: {
        numeroConfirmacion: confirmNum,
        fechaRecepcion: new Date().toISOString(),
        periodo: "202609",
        montoTotal: 47992.50,
        estado: "ACEPTADO"
      },
      _links: {
        self: `/v1/autodeterminacion/${confirmNum}`,
        estado: `/v1/autodeterminacion/${confirmNum}/estado`,
        recibo: `/v1/autodeterminacion/${confirmNum}/recibo`
      }
    };

    document.getElementById('restResponse').textContent = JSON.stringify(response, null, 2);
    addHistorialEntry(confirmNum, 'REST');

    showToast(`✓ REST API: Confirmación ${confirmNum}`, 'success');
  }, 2000);
}

// ======================== PROTOCOL SWITCH ========================

function switchProtocol(protocol) {
  document.querySelectorAll('.protocol-tab').forEach(t => t.classList.remove('active'));
  document.querySelector(`.protocol-tab[data-protocol="${protocol}"]`).classList.add('active');

  document.querySelectorAll('.protocol-panel').forEach(p => p.classList.remove('active'));
  document.getElementById(`panel-${protocol}`).classList.add('active');
}

// ======================== HISTORIAL ========================

function addHistorialEntry(confirmNum, protocol) {
  const tbody = document.getElementById('tbodyHistorial');
  const now = new Date();
  const fecha = `${now.getFullYear()}-${String(now.getMonth()+1).padStart(2,'0')}-${String(now.getDate()).padStart(2,'0')} ${String(now.getHours()).padStart(2,'0')}:${String(now.getMinutes()).padStart(2,'0')}`;

  const protoBadge = protocol === 'SOAP'
    ? '<span class="badge badge-primary">SOAP</span>'
    : '<span class="badge badge-success">REST</span>';

  const newRow = document.createElement('tr');
  newRow.style.animation = 'fadeInSection 0.4s ease';
  newRow.innerHTML = `
    <td><code>${confirmNum}</code></td>
    <td>202609</td>
    <td>${fecha}</td>
    <td>${protoBadge}</td>
    <td>5</td>
    <td>RD$ 47,992.50</td>
    <td><span class="status-pill accepted">Aceptado</span></td>
  `;
  tbody.insertBefore(newRow, tbody.firstChild);
}

// ======================== UTILITIES ========================

function copiarXML() {
  if (xmlGenerado) {
    navigator.clipboard.writeText(xmlGenerado).then(() => {
      showToast('XML copiado al portapapeles', 'success');
    });
  }
}

function descargarXML() {
  if (xmlGenerado) {
    const blob = new Blob([xmlGenerado], { type: 'application/xml' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'AutodeterminacionTSS_202609.xml';
    a.click();
    URL.revokeObjectURL(url);
    showToast('Archivo descargado: AutodeterminacionTSS_202609.xml', 'info');
  }
}

function showToast(message, type = 'info') {
  const container = document.getElementById('toastContainer');
  const toast = document.createElement('div');
  toast.className = `toast ${type}`;

  const icons = {
    success: '✓',
    error: '✗',
    warning: '⚠',
    info: 'ℹ'
  };

  toast.innerHTML = `
    <span style="font-size:1.2rem;">${icons[type] || icons.info}</span>
    <span>${message}</span>
  `;
  container.appendChild(toast);

  setTimeout(() => {
    toast.style.opacity = '0';
    toast.style.transform = 'translateX(50px)';
    toast.style.transition = 'all 0.3s ease';
    setTimeout(() => toast.remove(), 300);
  }, 4500);
}
