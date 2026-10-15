/// A message that can be shown directly to the person using Forgemusic.
class AppFailure implements Exception {
  AppFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
