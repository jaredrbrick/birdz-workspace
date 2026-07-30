// Viewer-request function: map extensionless paths to their prerendered
// index.html (e.g. /guide -> /guide/index.html). Paths with no prerendered
// file miss in S3 and fall through to the 403 -> /index.html SPA fallback,
// so behavior for app routes is unchanged.
function handler(event) {
  var request = event.request;
  var uri = request.uri;
  if (uri.endsWith('/')) {
    request.uri = uri + 'index.html';
  } else if (!uri.split('/').pop().includes('.')) {
    request.uri = uri + '/index.html';
  }
  return request;
}
