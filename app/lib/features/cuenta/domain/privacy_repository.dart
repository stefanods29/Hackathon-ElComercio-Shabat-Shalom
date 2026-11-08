enum DataPurpose {
  service('uso_del_servicio'),
  residencePresence('confirmacion_por_presencia');

  const DataPurpose(this.apiValue);
  final String apiValue;
}

class PrivacyData {
  const PrivacyData({
    required this.displayName,
    required this.values,
    required this.consents,
    this.consentVersions = const {},
    this.simulated = false,
  });
  final String displayName;
  final Map<String, Object?> values;
  final Map<DataPurpose, bool> consents;
  final Map<DataPurpose, String> consentVersions;
  final bool simulated;
  Map<String, Object?> toJson() => {
    ...values,
    'nombreVisible': displayName,
    'consentimientos': {
      for (final entry in consents.entries)
        entry.key.apiValue: {'aceptado': entry.value, 'versionTexto': consentVersions[entry.key]},
    },
    if (simulated) 'datosSimulados': true,
  };
}

class PrivacyFailure implements Exception {
  const PrivacyFailure(this.code, {this.field});
  final String code;
  final String? field;
}

/// B4 supplies the real implementation. No screen invents personal data or API routes.
abstract interface class PrivacyRepository {
  bool get available;
  Map<DataPurpose, String> get consentTextVersions;
  Stream<PrivacyData> watchData();
  Future<void> saveConsents(
    Map<DataPurpose, bool> consents, {
    required Map<DataPurpose, String> textVersions,
  });
  Future<void> updateDisplayName(String name);
  Future<Map<String, Object?>> exportData();
}

class UnavailablePrivacyRepository implements PrivacyRepository {
  const UnavailablePrivacyRepository();
  @override
  bool get available => false;
  @override
  Map<DataPurpose, String> get consentTextVersions => const {};
  @override
  Stream<PrivacyData> watchData() => const Stream.empty();
  @override
  Future<void> saveConsents(
    Map<DataPurpose, bool> consents, {
    required Map<DataPurpose, String> textVersions,
  }) async => throw const PrivacyFailure('not_available');
  @override
  Future<void> updateDisplayName(String name) async => throw const PrivacyFailure('not_available');
  @override
  Future<Map<String, Object?>> exportData() async => throw const PrivacyFailure('not_available');
}
