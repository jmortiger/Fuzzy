abstract base class Site {
  bool get usesCredentials;
  bool get usesPersistentCredentials;
  bool get mayRequireForegroundCredentialRefresh;
  bool get requiresForegroundCredentials;
  const Site();
}

abstract base class PersistentSite extends Site {
  @override
  bool get usesCredentials => true;
  @override
  bool get usesPersistentCredentials => true;
  @override
  bool get mayRequireForegroundCredentialRefresh;
  @override
  bool get requiresForegroundCredentials;
  const PersistentSite();
}
