#!/usr/bin/env python3
"""Folds a Godot web export into ONE self-contained index.html.

Usage: tools/inline_web.py <export_dir> <out.html>

The engine script is inlined as it is. The wasm, the pck and the two audio worklets are stored
as base64 inside the page, and a small shim hands them to the engine when it asks for them by
name (it patches fetch and AudioWorklet.addModule). Icons become data URIs. Nothing is loaded
from the network, so the file also works when opened straight from disk.
"""
import base64, pathlib, re, sys

src = pathlib.Path(sys.argv[1])
out = pathlib.Path(sys.argv[2])
html = (src / "index.html").read_text()

BINARY = {"index.wasm": "application/wasm", "index.pck": "application/octet-stream"}
MODULES = ["index.audio.worklet.js", "index.audio.position.worklet.js"]


def b64(name: str) -> str:
    return base64.b64encode((src / name).read_bytes()).decode()


# Pictures: data URIs.
for png in ["index.icon.png", "index.apple-touch-icon.png", "index.png"]:
    if (src / png).exists():
        html = html.replace('"%s"' % png, '"data:image/png;base64,%s"' % b64(png))

stores = "\n".join('<script type="application/octet-stream" id="packed:%s">%s</script>' % (n, b64(n))
                   for n in list(BINARY) + MODULES)

shim = """<script>
// Everything the engine would download is already in this page.
(function () {
	const types = %s;
	const modules = %s;
	const urls = {};
	function bytes(name) {
		const node = document.getElementById('packed:' + name);
		const text = node.textContent;
		node.textContent = '';      // let the browser drop the base64 once it is decoded
		const step = 4 * 1024 * 1024;
		const parts = [];
		for (let i = 0; i < text.length; i += step) {
			const bin = atob(text.slice(i, i + step));
			const arr = new Uint8Array(bin.length);
			for (let j = 0; j < bin.length; j++) arr[j] = bin.charCodeAt(j);
			parts.push(arr);
		}
		return parts;
	}
	function urlFor(name) {
		if (!urls[name]) {
			const type = types[name] || 'text/javascript';
			urls[name] = { blob: new Blob(bytes(name), { type: type }), type: type };
			urls[name].href = URL.createObjectURL(urls[name].blob);
		}
		return urls[name];
	}
	function packedName(resource) {
		const path = String(resource && resource.url ? resource.url : resource).split('?')[0];
		const name = path.substring(path.lastIndexOf('/') + 1);
		return (name in types || modules.indexOf(name) >= 0) ? name : null;
	}
	const realFetch = window.fetch.bind(window);
	window.fetch = function (resource, init) {
		const name = packedName(resource);
		if (name === null) return realFetch(resource, init);
		const entry = urlFor(name);
		return Promise.resolve(new Response(entry.blob, { status: 200, headers: { 'Content-Type': entry.type, 'Content-Length': String(entry.blob.size) } }));
	};
	if (window.AudioWorklet) {
		const realAdd = AudioWorklet.prototype.addModule;
		AudioWorklet.prototype.addModule = function (path, options) {
			const name = packedName(path);
			if (name === null) return realAdd.call(this, path, options);
			// A data URL, not a blob: a page opened from disk may not load blob: worklets.
			const node = document.getElementById('packed:' + name);
			return realAdd.call(this, 'data:text/javascript;base64,' + node.textContent, options);
		};
	}
})();
</script>
""" % (repr(BINARY).replace("'", '"'), repr(MODULES).replace("'", '"'))

engine = (src / "index.js").read_text().replace("</script", "<\\/script")
tag = '<script src="index.js"></script>'
assert tag in html, "export shell changed: no engine script tag"
html = html.replace(tag, stores + "\n" + shim + "<script>\n" + engine + "\n</script>")

# The loading bar in the game's pink, on the game's white.
html = html.replace("</style>", "#status-progress { accent-color: #ff2d95; }\nbody { background-color: #f0f3f8; }\n</style>", 1)

left = re.findall(r'(?:src|href)="(index\.[^"]+)"', html)
assert not left, "still loaded from outside: %s" % left
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(html)
print("%s  %.1f MB, self-contained" % (out, out.stat().st_size / 1e6))
