// Detección de rama/contenedor — el MISMO bundle corre en las 3 ramas.
// La rama solo cambia el contenedor que hospeda el SPA; el contrato HTTP es idéntico.
//   pc      → WebView2 (window.chrome.webview) dentro del exe desktop
//   hibrida → WebView2 + pantallas nativas conviviendo (bridge SendToFWH presente)
//   web     → navegador real (cualquier dispositivo)
(function () {
  const hasWebView = !!(window.chrome && window.chrome.webview);
  const hasNativeBridge = typeof window.SendToFWH === 'function';
  let branch = 'web';
  if (hasWebView) branch = hasNativeBridge ? 'hibrida' : 'pc';
  window.__RAMA__ = {
    branch,
    webview: hasWebView,
    nativeBridge: hasNativeBridge,
    capabilities: {
      fkeys: branch !== 'web',
      nativePrint: hasNativeBridge,
      touch: matchMedia('(pointer: coarse)').matches,
    },
  };
  document.documentElement.setAttribute('data-rama', branch);

  // Navegador por defecto del SO (ShellExecute nativo). No toca la rama embebida.
  // En WebView2 NUNCA window.open (NewWindowRequested → Navigate in-place).
  function absUrl(u) {
    try { return new URL(u, location.href).href; } catch (e) { return String(u || ''); }
  }
  window.__openExternal = function openExternal(url) {
    url = absUrl(url);
    if (!url) return false;
    if (hasWebView) {
      try { window.chrome.webview.postMessage(JSON.stringify({ cmd: 'open', url: url })); } catch (e1) {}
      try { window.chrome.webview.postMessage('open:' + url); } catch (e2) {}
    }
    try {
      fetch('/api/open-browser', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: 'url=' + encodeURIComponent(url),
        credentials: 'same-origin',
      }).catch(function () {});
    } catch (e3) {}
    if (!hasWebView) {
      try { window.open(url, '_blank', 'noopener'); } catch (e4) {}
    }
    return false;
  };
})();
