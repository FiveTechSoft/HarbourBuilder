// evidence.cjs — Captura evidencia visual de la rama 100% web en los 4 frontends.
// Flujo por frontend: login (admin/1234) → switch app "ferreteria" → pantalla Products (grid CRUD).
// Uso: node scripts/evidence.cjs
const { chromium } = require('playwright');
const path = require('path');

const BASE = 'http://127.0.0.1:2222';
const OUT = path.join(__dirname, '..', 'docs', 'evidencia');

const targets = [
  {
    name: 'web-vainilla',
    user: '#login-user', pass: '#login-pass', submit: '#login-form button[type=submit]',
    appSelect: { kind: 'select', sel: '#sel-app' },
  },
  {
    name: 'web-angular',
    user: 'input[name=user]', pass: 'input[name=pass]', submit: 'button[type=submit]',
    appSelect: { kind: 'primeng' },
  },
  {
    name: 'web-react',
    user: '.login-card input:not([type=password])', pass: '.login-card input[type=password]', submit: '.login-card button[type=submit]',
    appSelect: { kind: 'select', sel: '.topbar-right select' , nth: 1 },
  },
  {
    name: 'web-vue',
    user: '.login-card input:not([type=password])', pass: '.login-card input[type=password]', submit: '.login-card button[type=submit]',
    appSelect: { kind: 'select', sel: '.topbar-right select', nth: 1 },
  },
];

(async () => {
  const browser = await chromium.launch();
  const results = [];
  for (const t of targets) {
    const page = await browser.newPage({ viewport: { width: 1440, height: 900 } });
    const rec = { name: t.name };
    try {
      const t0 = Date.now();
      await page.goto(`${BASE}/${t.name}/index.html`, { waitUntil: 'networkidle' });
      await page.waitForSelector(t.user, { timeout: 15000 });
      await page.screenshot({ path: path.join(OUT, `${t.name}-login.png`) });
      await page.fill(t.user, 'admin');
      await page.fill(t.pass, '1234');
      await Promise.all([
        page.waitForSelector('.nav-item', { timeout: 20000 }),
        page.click(t.submit),
      ]);
      rec.loginMs = Date.now() - t0;

      // cambio de app a ferreteria (contiene Products con CRUD)
      if (t.appSelect.kind === 'select') {
        const sel = t.appSelect.nth
          ? page.locator(t.appSelect.sel).nth(t.appSelect.nth)
          : page.locator(t.appSelect.sel);
        await sel.selectOption('ferreteria');
      } else {
        const sel = page.locator('.topbar-right p-select').nth(1);
        await sel.click();
        await page.locator('.p-select-option', { hasText: /Ferreter/ }).first().click();
      }
      await page.waitForTimeout(1200);
      await page.waitForSelector('.nav-item', { timeout: 15000 });

      const prod = page.locator('.nav-item', { hasText: /Products|Productos|Artículos/ }).first();
      if (await prod.count()) {
        await prod.click();
        await page.waitForSelector('table', { timeout: 15000 });
        await page.waitForTimeout(600);
      }
      await page.screenshot({ path: path.join(OUT, `${t.name}-app.png`) });
      rec.ok = true;
    } catch (e) {
      rec.ok = false;
      rec.error = String(e.message || e).split('\n')[0];
      try { await page.screenshot({ path: path.join(OUT, `${t.name}-error.png`) }); } catch {}
    } finally {
      await page.close();
    }
    results.push(rec);
    console.log(`${rec.ok ? 'OK  ' : 'FAIL'} ${t.name}${rec.loginMs ? '  login+shell ' + rec.loginMs + ' ms' : ''}${rec.error ? '  ' + rec.error : ''}`);
  }
  await browser.close();
  const fails = results.filter((r) => !r.ok).length;
  console.log(fails === 0 ? 'EVIDENCIA COMPLETA' : 'FALLAS: ' + fails);
  process.exit(fails ? 1 : 0);
})();
