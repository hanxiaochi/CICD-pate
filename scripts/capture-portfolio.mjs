import { mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';

const cdpPort = process.env.CDP_PORT || '9223';
const baseUrl = process.env.PORTFOLIO_BASE_URL || 'http://127.0.0.1:3110';
const username = process.env.CICD_ADMIN_USERNAME;
const password = process.env.CICD_ADMIN_PASSWORD;
const outputDir = path.resolve(process.env.PORTFOLIO_SCREENSHOT_DIR || 'docs/screenshots');

if (!username || !password) {
  throw new Error('CICD_ADMIN_USERNAME and CICD_ADMIN_PASSWORD are required');
}

const targetResponse = await fetch(
  `http://127.0.0.1:${cdpPort}/json/new?${encodeURIComponent('about:blank')}`,
  { method: 'PUT' },
);
if (!targetResponse.ok) {
  throw new Error(`Unable to create Chrome target: HTTP ${targetResponse.status}`);
}

const target = await targetResponse.json();
const socket = new WebSocket(target.webSocketDebuggerUrl);
const pending = new Map();
let nextId = 1;

socket.onmessage = (event) => {
  const message = JSON.parse(event.data);
  if (!message.id) return;

  const request = pending.get(message.id);
  if (!request) return;

  pending.delete(message.id);
  if (message.error) {
    request.reject(new Error(message.error.message));
  } else {
    request.resolve(message.result);
  }
};

await new Promise((resolve, reject) => {
  socket.onopen = resolve;
  socket.onerror = () => reject(new Error('Unable to connect to Chrome DevTools'));
});

function send(method, params = {}) {
  const id = nextId;
  nextId += 1;

  return new Promise((resolve, reject) => {
    pending.set(id, { resolve, reject });
    socket.send(JSON.stringify({ id, method, params }));
  });
}

async function waitForPage() {
  await send('Runtime.evaluate', {
    expression: `new Promise((resolve) => {
      if (document.readyState === 'complete') return resolve(true);
      window.addEventListener('load', () => resolve(true), { once: true });
    })`,
    awaitPromise: true,
    returnByValue: true,
  });
  await new Promise((resolve) => setTimeout(resolve, 700));
}

async function navigate(url) {
  await send('Page.navigate', { url });
  await waitForPage();
}

async function capture(url, filename) {
  await navigate(url);
  const result = await send('Page.captureScreenshot', {
    format: 'png',
    fromSurface: true,
    captureBeyondViewport: false,
  });
  await writeFile(path.join(outputDir, filename), Buffer.from(result.data, 'base64'));
}

try {
  await send('Page.enable');
  await send('Runtime.enable');
  await send('Emulation.setDeviceMetricsOverride', {
    width: 1440,
    height: 900,
    deviceScaleFactor: 1,
    mobile: false,
  });
  await mkdir(outputDir, { recursive: true });

  await navigate(`${baseUrl}/login`);
  const loginResult = await send('Runtime.evaluate', {
    expression: `(async () => {
      const response = await fetch('/api/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(${JSON.stringify({ email: username, password })}),
      });
      const body = await response.json();
      if (!response.ok || !body.token) throw new Error('Portfolio login failed');
      localStorage.setItem('bearer_token', body.token);
      return response.status;
    })()`,
    awaitPromise: true,
    returnByValue: true,
  });

  if (loginResult.exceptionDetails) {
    throw new Error('Portfolio login failed in browser context');
  }

  await capture(`${baseUrl}/dashboard`, 'cicd-dashboard.png');
  await capture(`${baseUrl}/deployments/history`, 'cicd-deployment-history.png');
  console.log(`Portfolio screenshots written to ${outputDir}`);
} finally {
  socket.close();
  await fetch(`http://127.0.0.1:${cdpPort}/json/close/${target.id}`).catch(() => undefined);
}
