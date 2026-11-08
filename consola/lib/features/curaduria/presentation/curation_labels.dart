import 'package:vecinal_consola/features/curaduria/domain/directory.dart';
import 'package:vecinal_consola/l10n/app_localizations.dart';

String entryTypeLabel(AppLocalizations l10n, EntryType type) => switch (type) {
  EntryType.number => l10n.entryTypeNumber,
  EntryType.meetingPoint => l10n.entryTypeMeetingPoint,
  EntryType.healthCenter => l10n.entryTypeHealthCenter,
  EntryType.shelter => l10n.entryTypeShelter,
};

String entryProblemText(AppLocalizations l10n, EntryProblemKind kind) => switch (kind) {
  EntryProblemKind.idFormat => l10n.entryProblemIdFormat,
  EntryProblemKind.idRepeated => l10n.entryProblemIdRepeated,
  EntryProblemKind.nameLength => l10n.entryProblemNameLength,
  EntryProblemKind.phoneRequired => l10n.entryProblemPhoneRequired,
  EntryProblemKind.phoneFormat => l10n.entryProblemPhoneFormat,
  EntryProblemKind.locationRequired => l10n.entryProblemLocationRequired,
  EntryProblemKind.latitudeRange => l10n.entryProblemLatitude,
  EntryProblemKind.longitudeRange => l10n.entryProblemLongitude,
  EntryProblemKind.addressLength => l10n.entryProblemAddressLength,
  EntryProblemKind.descriptionLength => l10n.entryProblemDescriptionLength,
  EntryProblemKind.sourceNameLength => l10n.entryProblemSourceNameLength,
  EntryProblemKind.sourceUrlHttps => l10n.entryProblemSourceUrl,
  EntryProblemKind.verifiedFormat => l10n.entryProblemVerifiedFormat,
  EntryProblemKind.verifiedFuture => l10n.entryProblemVerifiedFuture,
};

/// Field name of a dotted path, for the messages of the API (`telefono` → "Teléfono").
String entryFieldLabel(AppLocalizations l10n, String field) => switch (field) {
  'id' => l10n.entryFieldId,
  'tipo' => l10n.entryFieldType,
  'nombre' => l10n.entryFieldName,
  'telefono' => l10n.entryFieldPhone,
  'ubicacion' || 'ubicacion.lat' || 'ubicacion.lng' => l10n.entryFieldLocation,
  'direccion' => l10n.entryFieldAddress,
  'descripcion' => l10n.entryFieldDescription,
  'fuente' || 'fuente.nombre' => l10n.entryFieldSourceName,
  'fuente.url' => l10n.entryFieldSourceUrl,
  'verificadoEn' => l10n.entryFieldVerified,
  _ => field,
};
