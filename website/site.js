'use strict';
let releaseVersion = '1.0.4';
fetch('/downloads/latest.json', {cache: 'no-store'})
  .then(response => {if (!response.ok) throw new Error('Unavailable'); return response.json();})
  .then(release => {
    releaseVersion = release.version;
    for (const platform of ['windows-x86_64', 'android-arm64']) {
      const file = release.downloads?.[platform];
      if (!file || typeof file.path !== 'string' || !/^\/downloads\/[A-Za-z0-9_./-]+$/.test(file.path) || file.path.includes('..')) continue;
      const link = document.querySelector(`[data-platform="${platform}"]`);
      link.href = file.path;
      const size = document.querySelector(`[data-size="${platform}"]`);
      size.textContent = `${platform === 'android-arm64' ? 'APK' : 'ZIP'} · v${release.version} · ${(file.bytes / 1048576).toFixed(0)} MB`;
    }
  }).catch(() => { /* The first release's static links remain usable offline. */ });

// Optional counts only. No install identifier, fingerprint or third-party script.
const privacyKey = 'ralphwolf-statistics-v1';
let consent = 'unknown';
try { consent = localStorage.getItem(privacyKey) || 'unknown'; } catch (_) {}
const privacy = document.createElement('dialog');
privacy.className = 'privacy-dialog';
privacy.innerHTML = '<h2>Estadísticas opcionales</h2><p>¿Quieres ayudarnos a mejorar el proyecto? Si aceptas, contaremos las solicitudes de descarga desde esta web y su plataforma (Windows o Android), con la versión. No enviamos nombres, IP ni identificadores del dispositivo en estas estadísticas. Son solicitudes, no descargas completadas ni personas únicas.</p><p>El juego te pedirá permiso por separado para contar sus sesiones. Rechazar no limita la descarga ni las actualizaciones. Puedes cambiar tu decisión aquí en Privacidad.</p><div class="privacy-actions"><button class="button primary" data-consent="accepted">Aceptar</button><button class="button secondary" data-consent="declined" autofocus>Rechazar</button></div>';
document.body.append(privacy);
let pendingDownload = null;
function download(link) {
  if (consent === 'accepted') {
    const bytes = crypto.getRandomValues(new Uint8Array(16));
    const event = [...bytes].map(v => v.toString(16).padStart(2,'0')).join('');
    fetch('/api/stats/events', {method:'POST',keepalive:true,headers:{'Content-Type':'application/json'},body:JSON.stringify({kind:'download',platform:link.dataset.platform==='android-arm64'?'android':'windows',version:releaseVersion,event,consent:'v1'})}).catch(()=>{});
  }
  window.location.assign(link.href);
}
for (const link of document.querySelectorAll('a.download')) link.addEventListener('click', event => {
  if (event.ctrlKey || event.metaKey || event.shiftKey || event.altKey) return;
  event.preventDefault();
  if (consent === 'accepted' || consent === 'declined') download(link);
  else { pendingDownload = link; privacy.showModal(); }
});
for (const button of privacy.querySelectorAll('[data-consent]')) button.addEventListener('click', () => {
  consent = button.dataset.consent;
  try { localStorage.setItem(privacyKey,consent); } catch (_) {}
  privacy.close();
  if (pendingDownload) { const link=pendingDownload; pendingDownload=null; download(link); }
});
privacy.addEventListener('cancel', () => { pendingDownload=null; });
document.getElementById('privacy-settings').addEventListener('click',()=>{ pendingDownload=null; privacy.showModal(); });
