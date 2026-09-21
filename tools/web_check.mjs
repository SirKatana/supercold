// Loads a page in headless Chrome (no window), prints its console, saves a screenshot.
// Usage: node tools/web_check.mjs <url> <out.png> [seconds] [click]
import { spawn } from 'node:child_process';
import { writeFileSync, mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const [url, out, seconds = '40', click = ''] = process.argv.slice(2);
const port = 9300 + Math.floor(Math.random() * 500);
const profile = mkdtempSync(join(process.env.CLAUDE_JOB_DIR ? process.env.CLAUDE_JOB_DIR + '/tmp' : tmpdir(), 'chrome-'));
const chrome = spawn('google-chrome', ['--headless=new', '--no-sandbox', `--user-data-dir=${profile}`,
	'--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--mute-audio',
	'--autoplay-policy=no-user-gesture-required', '--window-size=1280,720', `--remote-debugging-port=${port}`, 'about:blank'],
	{ stdio: 'ignore' });
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
let target;
for (let i = 0; i < 50 && !target; i++) {
	await sleep(200);
	try { target = (await (await fetch(`http://127.0.0.1:${port}/json`)).json()).find((t) => t.type === 'page'); } catch {}
}
const ws = new WebSocket(target.webSocketDebuggerUrl);
await new Promise((r) => (ws.onopen = r));
let id = 0; const waiting = new Map();
const send = (method, params = {}) => new Promise((r) => { waiting.set(++id, r); ws.send(JSON.stringify({ id, method, params })); });
ws.onmessage = (m) => {
	const msg = JSON.parse(m.data);
	if (msg.id && waiting.has(msg.id)) { waiting.get(msg.id)(msg.result); waiting.delete(msg.id); }
	if (msg.method === 'Runtime.consoleAPICalled') console.log(`[${msg.params.type}]`, msg.params.args.map((a) => a.value ?? a.description ?? '').join(' ').slice(0, 300));
	if (msg.method === 'Runtime.exceptionThrown') console.log('[exception]', (msg.params.exceptionDetails.exception?.description || msg.params.exceptionDetails.text).slice(0, 400));
	if (msg.method === 'Log.entryAdded') console.log(`[log:${msg.params.entry.level}]`, msg.params.entry.text.slice(0, 300));
};
await send('Runtime.enable'); await send('Log.enable'); await send('Page.enable');
await send('Page.navigate', { url });
await sleep(Number(seconds) * 1000);
if (click) {
	for (const type of ['mousePressed', 'mouseReleased']) await send('Input.dispatchMouseEvent', { type, x: Number(process.env.CLICK_X || 640), y: Number(process.env.CLICK_Y || 360), button: 'left', clickCount: 1 });
	await send('Input.dispatchKeyEvent', { type: 'keyDown', key: 'Enter', code: 'Enter', windowsVirtualKeyCode: 13 });
	await send('Input.dispatchKeyEvent', { type: 'keyUp', key: 'Enter', code: 'Enter', windowsVirtualKeyCode: 13 });
	await sleep(Number(click) * 1000);
}
const shot = await send('Page.captureScreenshot', { format: 'png' });
writeFileSync(out, Buffer.from(shot.data, 'base64'));
chrome.kill();
process.exit(0);
