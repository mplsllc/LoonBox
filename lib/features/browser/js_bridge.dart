/// JavaScript bridge script injected into trusted pages.
///
/// Defines `window.loonbox` with promise-based methods that communicate
/// with the Flutter host via `window.chrome.webview.postMessage()`.
const String jsBridgeScript = r'''
(function() {
  if (window.loonbox) return;

  let nextId = 1;
  const pending = new Map();

  window.chrome.webview.addEventListener('message', function(event) {
    const data = event.data;
    if (data && data.type === 'response' && pending.has(data.id)) {
      const { resolve, reject } = pending.get(data.id);
      pending.delete(data.id);
      if (data.error) {
        reject(new Error(data.error));
      } else {
        resolve(data.result);
      }
    }
  });

  function send(cmd, args) {
    return new Promise(function(resolve, reject) {
      const id = nextId++;
      pending.set(id, { resolve, reject });
      window.chrome.webview.postMessage({ id, cmd, args });
    });
  }

  window.loonbox = {
    play: function() { return send('player.play'); },
    pause: function() { return send('player.pause'); },
    stop: function() { return send('player.stop'); },
    seek: function(position) { return send('player.seek', { position }); },
    getState: function() { return send('player.getState'); },
    getPosition: function() { return send('player.getPosition'); },
    loadUrl: function(url) { return send('browser.loadUrl', { url }); },
  };
})();
''';
