'use strict';
fetch('/downloads/latest.json', {cache: 'no-store'})
  .then(response => {if (!response.ok) throw new Error('Unavailable'); return response.json();})
  .then(release => {
    for (const platform of ['windows-x86_64', 'android-arm64']) {
      const file = release.downloads?.[platform];
      if (!file || typeof file.path !== 'string' || !/^\/downloads\/[A-Za-z0-9_./-]+$/.test(file.path) || file.path.includes('..')) continue;
      const link = document.querySelector(`[data-platform="${platform}"]`);
      link.href = file.path;
      const size = document.querySelector(`[data-size="${platform}"]`);
      size.textContent = `${platform === 'android-arm64' ? 'APK' : 'ZIP'} · v${release.version} · ${(file.bytes / 1048576).toFixed(0)} MB`;
    }
  }).catch(() => { /* The first release's static links remain usable offline. */ });
