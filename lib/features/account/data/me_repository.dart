import 'package:dcpl_shared/dcpl_shared.dart';

/// Port for the supervisor's own profile (`/me`) plus resolving a stored photo path to a
/// signed read URL.
abstract class MeRepository {
  Future<User> get();
  Future<User> update({String? name, String? photoUrl});

  /// Resolves a stored object path (e.g. the profile `photoUrl`) to a short-lived signed URL.
  Future<String> downloadUrl(String path);
}

class ApiMeRepository implements MeRepository {
  ApiMeRepository(this._api);

  final DcplApi _api;

  @override
  Future<User> get() => _api.me.get();

  @override
  Future<User> update({String? name, String? photoUrl}) =>
      _api.me.update(name: name, photoUrl: photoUrl);

  @override
  Future<String> downloadUrl(String path) => _api.uploads.downloadUrl(path);
}
