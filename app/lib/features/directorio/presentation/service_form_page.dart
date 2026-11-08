import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal/core/router/routes.dart';
import 'package:vecinal/core/theme/accessible_theme.dart';
import 'package:vecinal/core/ui/spaced.dart';
import 'package:vecinal/core/ui/wrapping_app_bar.dart';
import 'package:vecinal/features/directorio/data/providers.dart';
import 'package:vecinal/features/directorio/domain/directory.dart';
import 'package:vecinal/features/directorio/domain/use_cases.dart';
import 'package:vecinal/features/directorio/presentation/directory_page.dart';
import 'package:vecinal/features/mapa/presentation/map_view.dart';
import 'package:vecinal/features/onboarding/demo_profiles.dart';
import 'package:vecinal/l10n/app_localizations.dart';

class ServiceFormPage extends ConsumerStatefulWidget {
  const ServiceFormPage({super.key, this.serviceId});
  final String? serviceId;
  @override
  ConsumerState<ServiceFormPage> createState() => _ServiceFormPageState();
}

class _ServiceFormPageState extends ConsumerState<ServiceFormPage> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _name = TextEditingController();
  final _description = TextEditingController();
  GeoPoint? _location;
  String? _category;
  bool _emergency = false;
  bool _initialized = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_title, _name, _description]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save(Service? original) async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final t = AppLocalizations.of(context);
    try {
      final repository = ref.read(serviceDirectoryRepositoryProvider);
      final draft = ServiceDraft(
        categoryId: _category!,
        title: _title.text,
        description: _description.text,
        location: _location!.approximate(),
        availableInEmergency: _emergency,
      );
      if (original == null) {
        // Profile must be in the queue before its first service.
        await SaveProviderProfile(repository).execute(publicName: _name.text);
        final submission = await PublishService(repository).execute(draft);
        if (mounted && ModalRoute.isCurrentOf(context) == true) {
          context.pushReplacement('/servicios/${submission.resourceId}');
        }
      } else {
        await UpdateService(repository).execute(original, draft);
        if (mounted && ModalRoute.isCurrentOf(context) == true) {
          if (context.canPop()) {
            context.pop();
          } else {
            context.pushReplacement('/servicios/${original.id}');
          }
        }
      }
    } catch (_) {
      if (mounted) setState(() => _error = t.actionFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final categories = ref.watch(categoriesProvider).value ?? const <Category>[];
    final service = widget.serviceId == null
        ? null
        : ref.watch(serviceProvider(widget.serviceId!)).value;
    if (widget.serviceId != null && service == null) {
      return Scaffold(
        appBar: AppBar(title: Text(t.editService)),
        body: Center(child: Text(t.serviceUnavailable)),
      );
    }
    if (!_initialized && categories.isNotEmpty) {
      _initialized = true;
      final GeoPoint point = service?.location ?? ref.read<GeoPoint>(directoryOriginProvider);
      _title.text = service?.title ?? t.serviceTitleSuggested;
      _name.text = ref.read(effectiveSessionProvider).displayName;
      _description.text = service?.description ?? '';
      _location = point.approximate();
      _category = service?.categoryId ?? categories.first.id;
      _emergency = service?.availableInEmergency ?? false;
    }
    return Scaffold(
      appBar: wrappingAppBar(context, service == null ? t.offerService : t.editService),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: spaced([
              if (service == null)
                TextFormField(
                  controller: _name,
                  decoration: InputDecoration(labelText: t.serviceNameLabel),
                  validator: (v) =>
                      (v!.trim().length < 2 || v.trim().length > 60) ? t.invalidProviderName : null,
                ),
              TextFormField(
                controller: _title,
                decoration: InputDecoration(labelText: t.titleLabel),
                validator: (v) =>
                    (v!.trim().length < 3 || v.trim().length > 120) ? t.invalidServiceTitle : null,
              ),
              ButtonTheme(
                alignedDropdown: true,
                child: DropdownButtonFormField<String>(
                  initialValue: _category,
                  isExpanded: true,
                  isDense: false,
                  itemHeight: null,
                  menuMaxHeight: 320,
                  borderRadius: BorderRadius.circular(AccessibleTheme.radiusMedium),
                  decoration: InputDecoration(labelText: t.categoryLabel),
                  items: [
                    for (final category in categories)
                      DropdownMenuItem(
                        value: category.id,
                        child: Row(
                          spacing: 8,
                          children: [
                            Icon(categoryIcon(category.icon), size: 20),
                            Flexible(child: Text(category.name)),
                          ],
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() => _category = value),
                  validator: (v) => v == null ? t.categoryLabel : null,
                ),
              ),
              TextFormField(
                controller: _description,
                maxLines: 3,
                decoration: InputDecoration(labelText: t.descriptionLabel),
                validator: (v) => v!.length > 2000 ? t.invalidDescription : null,
              ),
              const SizedBox(height: 12),
              Text(t.serviceLocationSuggested),
              OutlinedButton.icon(
                onPressed: _location == null
                    ? null
                    : () => context.push(
                        Routes.map,
                        extra: MapFocus([MapMarker(label: _title.text, location: _location!)]),
                      ),
                icon: const Icon(Icons.map_outlined),
                label: Text(t.openOnMap),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(t.usefulInEmergency),
                value: _emergency,
                onChanged: (v) => setState(() => _emergency = v),
              ),
              if (_error != null) Text(_error!),
              FilledButton(
                onPressed: !_initialized || _busy ? null : () => _save(service),
                child: Text(
                  _busy
                      ? t.loadingAction
                      : service == null
                      ? t.publishButton
                      : t.saveChanges,
                ),
              ),
              TextButton(
                onPressed: () => context.go(Routes.directory),
                child: Text(t.directoryTitle),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
