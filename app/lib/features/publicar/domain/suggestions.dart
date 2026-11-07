import 'package:vecinal/features/solidaridad/domain/post.dart';

/// Sugerencia de título y categoría para un tipo de publicación.
///
/// Se usa para prellenar el formulario y permitir publicar en exactamente
/// tres toques sin escribir nada.
final class PublishSuggestion {
  const PublishSuggestion({required this.type, required this.category, required this.title});

  final PostType type;
  final String category;
  final String title;
}

/// Sugerencias predefinidas para cada tipo de publicación.
const List<PublishSuggestion> publishSuggestions = [
  PublishSuggestion(
    type: PostType.offer,
    category: 'servicios',
    title: 'Ofrezco ayuda a mis vecinos',
  ),
  PublishSuggestion(type: PostType.need, category: 'ayuda', title: 'Necesito ayuda en mi cuadra'),
  PublishSuggestion(type: PostType.lend, category: 'herramientas', title: 'Presto herramientas'),
  PublishSuggestion(type: PostType.donate, category: 'ropa', title: 'Dono ropa en buen estado'),
  PublishSuggestion(
    type: PostType.exchange,
    category: 'intercambio',
    title: 'Intercambio cosas que ya no uso',
  ),
  PublishSuggestion(type: PostType.ride, category: 'movilidad', title: 'Ofrezco movilidad'),
];

/// Busca la sugerencia para un tipo de publicación.
PublishSuggestion suggestionForType(PostType type) {
  return publishSuggestions.firstWhere(
    (s) => s.type == type,
    orElse: () => throw ArgumentError('No hay sugerencia para el tipo $type'),
  );
}
