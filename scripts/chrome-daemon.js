const { spawn } = require('child_process');
const http = require('http');
const fs = require('fs');
const path = require('path');

const CHROME_PATH = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const USER_DATA = 'C:\\ChromeDevProfile';
const ACTIVE_PORT_FILE_1 = 'C:\\Users\\ASUS\\AppData\\Local\\Google\\Chrome\\User Data\\DevToolsActivePort';
const ACTIVE_PORT_FILE_2 = 'C:\\ChromeDevProfile\\DevToolsActivePort';

let chromeProcess = null;

function syncActivePort() {
  http.get('http://127.0.0.1:9222/json/version', (res) => {
    let data = '';
    res.on('data', chunk => data += chunk);
    res.on('end', () => {
      try {
        const parsed = JSON.parse(data);
        if (parsed.webSocketDebuggerUrl) {
          const wsUrl = new URL(parsed.webSocketDebuggerUrl);
          const wsPath = wsUrl.pathname;
          const content = `9222\n${wsPath}\n`;
          fs.writeFileSync(ACTIVE_PORT_FILE_1, content, 'utf8');
          fs.writeFileSync(ACTIVE_PORT_FILE_2, content, 'utf8');
          console.log(`[ChromeDaemon] DevToolsActivePort synced: 9222 -> ${wsPath}`);
        }
      } catch (e) {
        // ignore parse error during startup
      }
    });
  }).on('error', () => {
    // wait for chrome to listen
  });
}

function startChrome() {
  console.log('[ChromeDaemon] Starting isolated Chrome with remote debugging on port 9222...');
  chromeProcess = spawn(CHROME_PATH, [
    '--remote-debugging-port=9222',
    `--user-data-dir=${USER_DATA}`,
    '--no-first-run',
    '--no-default-browser-check',
    '--remote-allow-origins=*',
    'http://localhost:3000'
  ], {
    stdio: 'ignore'
  });

  chromeProcess.on('exit', (code, signal) => {
    console.log(`[ChromeDaemon] Chrome exited with code ${code}, signal ${signal}. Restarting in 2s...`);
    chromeProcess = null;
    setTimeout(startChrome, 2000);
  });
}

startChrome();
setInterval(syncActivePort, 3000);
