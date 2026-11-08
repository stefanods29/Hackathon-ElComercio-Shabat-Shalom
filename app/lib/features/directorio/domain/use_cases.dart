import 'package:vecinal/core/submissions/submission.dart';
import 'package:vecinal/features/directorio/domain/directory.dart';
import 'package:vecinal/features/directorio/domain/service_directory_repository.dart';
import 'package:vecinal/features/solidaridad/domain/use_cases.dart' show LocalValidationError;

/// Same rules as the server (`directorio/servicios`), so nothing invalid is ever queued.
ServiceDraft _validated(ServiceDraft draft) {
  final title = draft.title.trim();
  if (title.length < 3 || title.length > 120) {
    throw const LocalValidationError('El título debe tener entre 3 y 120 caracteres.', 'title');
  }
  if (draft.categoryId.trim().isEmpty) {
    throw const LocalValidationError('Elige una categoría.', 'category');
  }
  final description = draft.description?.trim();
  if (description != null && description.length > 2000) {
    throw const LocalValidationError(
      'La descripción no puede pasar de 2000 caracteres.',
      'description',
    );
  }
  if (draft.coverageRadiusMeters < 100 || draft.coverageRadiusMeters > 20000) {
    throw const LocalValidationError(
      'El radio de atención debe estar entre 100 m y 20 km.',
      'coverage',
    );
  }
  final location = draft.location;
  if (location.lat < -90 || location.lat > 90 || location.lng < -180 || location.lng > 180) {
    throw const LocalValidationError('La ubicación no es válida.', 'location');
  }
  return ServiceDraft(
    categoryId: draft.categoryId.trim(),
    title: title,
    description: (description?.isEmpty ?? true) ? null : description,
    location: location,
    showExactLocation: draft.showExactLocation,
    coverageRadiusMeters: draft.coverageRadiusMeters,
    availableInEmergency: draft.availableInEmergency,
  );
}

/// "Ofrezco un servicio" (third tap of the publishing flow).
class PublishService {
  const PublishService(this._directory);

  final ServiceDirectoryRepository _directory;

  Future<Submission> execute(ServiceDraft draft) => _directory.publishService(_validated(draft));
}

/// Edits one of my services with the version I was looking at.
class UpdateService {
  const UpdateService(this._directory);

  final ServiceDirectoryRepository _directory;

  Future<Submission> execute(Service service, ServiceDraft changes) => _directory.updateService(
    serviceId: service.id,
    seenVersion: service.version,
    changes: _validated(changes),
  );
}

/// Creates or updates my provider profile.
class SaveProviderProfile {
  const SaveProviderProfile(this._directory);

  final ServiceDirectoryRepository _directory;

  Future<Submission> execute({required String publicName, String? description}) {
    final name = publicName.trim();
    if (name.length < 2 || name.length > 60) {
      throw const LocalValidationError('El nombre debe tener entre 2 y 60 caracteres.', 'name');
    }
    final about = description?.trim();
    if (about != null && about.length > 500) {
      throw const LocalValidationError(
        'La descripción no puede pasar de 500 caracteres.',
        'description',
      );
    }
    return _directory.upsertProvider(
      publicName: name,
      description: (about?.isEmpty ?? true) ? null : about,
    );
  }
}
