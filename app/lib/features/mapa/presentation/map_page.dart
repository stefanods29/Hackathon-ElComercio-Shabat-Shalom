import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:vecinal/features/mapa/data/providers.dart';
import 'package:vecinal/features/mapa/domain/offline_region.dart';
import 'package:vecinal/features/mapa/presentation/map_download_controller.dart';
import 'package:vecinal/features/mapa/presentation/map_view.dart';
import 'package:vecinal/l10n/app_localizations.dart';

class MapPage extends ConsumerStatefulWidget {
  const MapPage({super.key, this.mapViewBuilder});
  final MapViewBuilder? mapViewBuilder;

  @override
  ConsumerState<MapPage> createState() => _MapPageState();
}

class _MapPageState extends ConsumerState<MapPage> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(ref.read(mapDownloadControllerProvider.notifier).refresh());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(mapDownloadControllerProvider.notifier).refresh());
    }
  }

  @override
  Widget build(BuildContext context) {
    final texts = AppLocalizations.of(context);
    final definition = ref.watch(mapRegionDefinitionProvider);
    final regions = ref.watch(offlineRegionsProvider);
    final controls = ref.watch(mapDownloadControllerProvider);
    final supported = ref.watch(offlineMapSupportedProvider);
    final MapViewBuilder buildMapView = widget.mapViewBuilder ?? ref.watch(mapViewBuilderProvider);
    return Scaffold(
      appBar: AppBar(title: Text(texts.mapTitle)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  SizedBox(
                    height: (MediaQuery.sizeOf(context).height * 0.4).clamp(220.0, 360.0),
                    child: Semantics(
                      label: texts.mapDistrictName,
                      child: buildMapView(context, definition),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(texts.mapDistrictName, style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 8),
                        Text(texts.mapDemoBoundary),
                        const SizedBox(height: 16),
                        regions.when(
                          data: (items) => _DownloadControls(
                            region: items.single,
                            controls: controls,
                            supported: supported,
                          ),
                          loading: () => Text(texts.mapCheckingDownload),
                          error: (error, stack) => Text(texts.mapStorageUnavailable),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Outside the scroll view: visible even when controls or 200% text need scrolling.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(texts.mapAttribution, textAlign: TextAlign.center),
            ),
          ],
        ),
      ),
    );
  }
}

class _DownloadControls extends ConsumerWidget {
  const _DownloadControls({required this.region, required this.controls, required this.supported});

  final OfflineRegion region;
  final MapDownloadState controls;
  final bool supported;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texts = AppLocalizations.of(context);
    final controller = ref.read(mapDownloadControllerProvider.notifier);
    final busy = controls.action != MapDownloadAction.none;
    final downloading = region.status == OfflineRegionStatus.downloading;
    final failure = controls.failure ?? region.failure;
    final downloadedMegabytes = NumberFormat(
      '0.0',
      texts.localeName,
    ).format(region.downloadedBytes / 1000000);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: true,
          child: Text(switch (region.status) {
            OfflineRegionStatus.checking => texts.mapCheckingDownload,
            OfflineRegionStatus.notDownloaded => texts.mapNotDownloaded,
            OfflineRegionStatus.downloading => texts.mapDownloading,
            OfflineRegionStatus.ready => texts.mapReadyOffline,
            OfflineRegionStatus.failed => texts.mapDownloadIncomplete,
          }),
        ),
        const SizedBox(height: 8),
        if (!supported) Text(texts.mapOfflineUnsupported),
        if (failure != null) ...[
          Semantics(liveRegion: true, child: Text(_failureMessage(texts, failure))),
          const SizedBox(height: 8),
        ],
        if (downloading) ...[
          LinearProgressIndicator(value: region.progress, semanticsLabel: texts.mapDownloading),
          const SizedBox(height: 8),
          Text(
            region.progress == null
                ? texts.mapDownloadSize(downloadedMegabytes)
                : texts.downloadProgress((region.progress! * 100).floor(), downloadedMegabytes),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: controls.action == MapDownloadAction.cancelling ? null : controller.cancel,
            child: Text(
              controls.action == MapDownloadAction.cancelling
                  ? texts.mapCancelling
                  : texts.cancelDownload,
            ),
          ),
        ] else if (region.status == OfflineRegionStatus.ready) ...[
          Text(texts.mapDownloadSize(downloadedMegabytes)),
          const SizedBox(height: 12),
          OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: busy ? null : () => _confirmDeletion(context, texts, controller),
            child: Text(texts.deleteDownloadedMap),
          ),
        ] else if (region.status != OfflineRegionStatus.checking) ...[
          const SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: !supported || busy ? null : controller.download,
            child: Text(texts.downloadDistrictMap, textAlign: TextAlign.center),
          ),
        ],
        const SizedBox(height: 12),
        Text(texts.downloadOnlyOnWifi),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(texts.allowMobileData),
          subtitle: Text(texts.mapMobileDataCost),
          value: controls.allowMobileData,
          onChanged: !supported || controls.action == MapDownloadAction.cancelling
              ? null
              : controller.setAllowMobileData,
        ),
        if (region.status == OfflineRegionStatus.failed) ...[
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: busy ? null : controller.refresh,
            child: Text(texts.mapCheckAgain),
          ),
        ],
      ],
    );
  }

  Future<void> _confirmDeletion(
    BuildContext context,
    AppLocalizations texts,
    MapDownloadController controller,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(texts.deleteDownloadedMap),
        content: Text(texts.mapDeleteWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(texts.mapKeepDownload),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(texts.mapConfirmDelete),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) await controller.delete();
  }

  String _failureMessage(AppLocalizations texts, MapFailure failure) => switch (failure) {
    MapFailure.wifiRequired => texts.mapWifiRequired,
    MapFailure.noConnection => texts.mapNoConnection,
    MapFailure.unsupported => texts.mapOfflineUnsupported,
    MapFailure.storageUnavailable => texts.mapStorageUnavailable,
    MapFailure.downloadFailed => texts.mapDownloadFailed,
    MapFailure.tileLimitExceeded => texts.mapTileLimitExceeded,
    MapFailure.interrupted => texts.mapDownloadInterrupted,
  };
}
