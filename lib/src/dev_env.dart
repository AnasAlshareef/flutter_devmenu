/// One selectable environment shown in the dev menu's Environment tab.
class DevEnv {
  const DevEnv(this.name, this.baseUrl);

  /// Short label, e.g. 'dev', 'staging', 'prod'.
  final String name;

  /// The API base URL this environment points at.
  final String baseUrl;
}
