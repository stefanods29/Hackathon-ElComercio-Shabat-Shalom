import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vecinal/core/content/public_content.dart';

enum TutorialDestination { directory, publish, review, actions, emergency, privacy }

class TutorialStep {
  const TutorialStep(this.destination, {this.title, this.body});
  final TutorialDestination destination;
  final String? title;
  final String? body;
}

class TutorialContent {
  const TutorialContent(this.steps);
  final List<TutorialStep> steps;
  factory TutorialContent.parse(Object? json) {
    if (json is! Map || json['version'] != 1 || json['steps'] is! List)
      throw const FormatException('Invalid tutorial');
    final values = json['steps'] as List;
    final destinations = <TutorialDestination>{};
    final steps = values
        .map((value) {
          if (value is! Map) throw const FormatException('Invalid tutorial step');
          final destination = TutorialDestination.values
              .where((d) => d.name == value['destination'])
              .firstOrNull;
          if (destination == null || !destinations.add(destination))
            throw const FormatException('Invalid tutorial destination');
          final title = value['title'];
          final body = value['body'];
          if (title != null && (title is! String || title.trim().isEmpty || title.length > 160))
            throw const FormatException('Invalid tutorial title');
          if (body != null && (body is! String || body.trim().isEmpty || body.length > 2000))
            throw const FormatException('Invalid tutorial text');
          return TutorialStep(destination, title: title as String?, body: body as String?);
        })
        .toList(growable: false);
    if (!TutorialDestination.values.every(destinations.contains))
      throw const FormatException('Incomplete pilot tutorial');
    return TutorialContent(steps);
  }
}

final tutorialContentUrlProvider = Provider<Uri?>((ref) {
  const url = String.fromEnvironment('PUBLIC_TUTORIAL_URL');
  return url.isEmpty ? null : Uri.tryParse(url);
});
final tutorialContentProvider = StreamProvider<TutorialContent>(
  (ref) => watchPublicContent(
    source: ref.watch(publicContentSourceProvider),
    key: 'tutorial.v1',
    asset: 'assets/public/tutorial.json',
    uri: ref.watch(tutorialContentUrlProvider),
    parse: TutorialContent.parse,
  ),
);
