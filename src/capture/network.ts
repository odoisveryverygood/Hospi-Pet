/** Development page fetch/XHR observation, not a browser/OS network monitor. No URLs or payloads retained. */
export function observePageRequests(capturing: () => boolean, changed: () => void) {
  const originalFetch = window.fetch;
  const originalSend = XMLHttpRequest.prototype.send;
  let fetchCalls = 0;
  let xhrCalls = 0;
  window.fetch = function (input, init) {
    const url = typeof input === 'string' ? input : input instanceof URL ? input.href : input.url;
    if (capturing() && !url.startsWith('blob:') && !url.startsWith('data:')) { fetchCalls++; changed(); }
    return originalFetch.call(this, input, init);
  };
  XMLHttpRequest.prototype.send = function (body) {
    if (capturing()) { xhrCalls++; changed(); }
    return originalSend.call(this, body);
  };
  return { snapshot: () => ({ fetchCalls, xhrCalls }), dispose: () => { window.fetch = originalFetch; XMLHttpRequest.prototype.send = originalSend; } };
}
