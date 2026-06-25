import 'package:dcpl_shared/dcpl_shared.dart';

/// Resolves a stored attachment/bill object path to a short-lived signed read URL
/// (the backend `/uploads/download-url` endpoint) so the supervisor can review the
/// photos, audio, and bills attached to a request. Clients never touch Storage directly.
abstract class AttachmentRepository {
  Future<String> downloadUrl(String path);
}

/// Caches each path→URL resolution for [_ttl], so reopening the detail dialog (or the
/// same image showing as a thumbnail then enlarged) doesn't re-hit the backend each
/// time. The stable URL is also what lets `Image.network`/the browser reuse the
/// already-downloaded bytes instead of refetching on every open.
///
/// Backend read URLs are valid for 1 hour; [_ttl] expires our cache well short of that
/// so a cached link never strands a viewer on an expired URL. Registered as a session
/// singleton (`Get.lazyPut`), so the cache lives as long as the app does.
class ApiAttachmentRepository implements AttachmentRepository {
  ApiAttachmentRepository(this._api);

  final DcplApi _api;

  static const _ttl = Duration(minutes: 50);
  final Map<String, _CachedUrl> _cache = {};

  @override
  Future<String> downloadUrl(String path) {
    final now = DateTime.now();
    final hit = _cache[path];
    if (hit != null && now.difference(hit.at) < _ttl) return hit.future;

    // Cache the in-flight future (concurrent callers share one request). Drop it on
    // failure so a transient error isn't replayed on reopen.
    final future = _api.uploads.downloadUrl(path);
    final entry = _CachedUrl(future, now);
    _cache[path] = entry;
    future.then(
      (_) {},
      onError: (_) {
        if (identical(_cache[path], entry)) _cache.remove(path);
      },
    );
    return future;
  }
}

class _CachedUrl {
  _CachedUrl(this.future, this.at);

  final Future<String> future;
  final DateTime at;
}
