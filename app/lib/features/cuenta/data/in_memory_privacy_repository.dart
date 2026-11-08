import 'dart:async';

import 'package:vecinal/features/cuenta/domain/privacy_repository.dart';

/// Explicit simulated account; never used as the fallback of a real signed-in account.
class InMemoryPrivacyRepository implements PrivacyRepository {
  InMemoryPrivacyRepository({
    String displayName = 'Beto (práctica)',
    Map<String, Object?> values = const {'zona': 'Zona de práctica'},
  }) : _data = PrivacyData(
         displayName: displayName,
         values: values,
         consents: const {DataPurpose.service: false, DataPurpose.residencePresence: false},
         simulated: true,
       );
  PrivacyData _data;
  final _changes = StreamController<PrivacyData>.broadcast();
  @override
  bool get available => true;
  @override
  Map<DataPurpose, String> get consentTextVersions => const {
    DataPurpose.service: 'piloto-2026-11-07',
    DataPurpose.residencePresence: 'piloto-2026-11-07',
  };
  @override
  Stream<PrivacyData> watchData() async* {
    yield _data;
    yield* _changes.stream;
  }

  @override
  Future<void> saveConsents(
    Map<DataPurpose, bool> consents, {
    required Map<DataPurpose, String> textVersions,
  }) async {
    if (consents[DataPurpose.service] != true) throw const PrivacyFailure('required_consent');
    if (DataPurpose.values.any((purpose) => textVersions[purpose] != consentTextVersions[purpose]))
      throw const PrivacyFailure('version_de_consentimiento_desactualizada');
    _data = PrivacyData(
      displayName: _data.displayName,
      values: _data.values,
      consents: {for (final purpose in DataPurpose.values) purpose: consents[purpose] == true},
      consentVersions: Map.unmodifiable(textVersions),
      simulated: true,
    );
    _changes.add(_data);
  }

  @override
  Future<void> updateDisplayName(String name) async {
    final trimmed = name.trim();
    if (trimmed.length < 2 || trimmed.length > 60)
      throw const PrivacyFailure('invalid_name', field: 'displayName');
    _data = PrivacyData(
      displayName: trimmed,
      values: _data.values,
      consents: _data.consents,
      consentVersions: _data.consentVersions,
      simulated: true,
    );
    _changes.add(_data);
  }

  @override
  Future<Map<String, Object?>> exportData() async => _data.toJson();
  Future<void> close() => _changes.close();
}
