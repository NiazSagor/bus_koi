import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import 'package:bus_koi/core/constants/app_constants.dart';
import 'package:bus_koi/core/localization/gen/app_localizations.dart';
import 'package:bus_koi/core/services/connectivity_service.dart';
import 'package:bus_koi/core/services/identity_service.dart';
import 'package:bus_koi/core/services/location_service.dart';
import 'package:bus_koi/core/theme/app_theme.dart';
import 'package:bus_koi/core/utils/relative_time_formatter.dart';
import 'package:bus_koi/features/community/data/community_repository.dart';
import 'package:bus_koi/features/community/presentation/community_view_model.dart';
import 'package:bus_koi/shared/models/location_report.dart';

class CommunityScreenArgs {
  const CommunityScreenArgs({required this.communityId, required this.displayName});
  final String communityId;
  final String displayName;
}

class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key, required this.args});

  final CommunityScreenArgs args;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => CommunityViewModel(
        communityId: args.communityId,
        displayName: args.displayName,
        repository: context.read<CommunityRepository>(),
        identity: context.read<IdentityService>(),
        locationService: context.read<LocationService>(),
      )..initialize(),
      child: const _CommunityView(),
    );
  }
}

class _CommunityView extends StatefulWidget {
  const _CommunityView();

  @override
  State<_CommunityView> createState() => _CommunityViewState();
}

class _CommunityViewState extends State<_CommunityView> {
  bool _notifyMeEnabled = false;
  int _lastNotifiedReportCount = 0;
  final MapController _mapController = MapController();
  bool _hasCenteredOnSupplier = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final vm = context.watch<CommunityViewModel>();

    if (_notifyMeEnabled && vm.locationReports.length > _lastNotifiedReportCount) {
      _lastNotifiedReportCount = vm.locationReports.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.notificationTitle(vm.displayName)),
            behavior: SnackBarBehavior.floating,
          ),
        );
      });
    } else {
      _lastNotifiedReportCount = vm.locationReports.length;
    }

    // Center on the bus once, the first time a location report arrives, then
    // leave the camera alone so the user can freely pan/zoom — don't fight
    // their gesture every time a new report comes in.
    final latest = vm.latestReport;
    if (latest != null && !_hasCenteredOnSupplier) {
      _hasCenteredOnSupplier = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(LatLng(latest.latitude, latest.longitude), _mapController.camera.zoom);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(vm.displayName),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: l10n.leaveCommunity,
            onPressed: () async {
              await vm.leave();
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          const _OfflineBanner(),
          Expanded(
            child: Stack(
              children: [
                _MapArea(
                  latestReport: vm.latestReport,
                  mapController: _mapController,
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  top: 12,
                  child: _DemandCard(
                    waitingCount: vm.waitingCount,
                    supplierCount: vm.supplierCount,
                    latestReport: vm.latestReport,
                  ),
                ),
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: _MapControls(
                    onZoomIn: () => _zoomBy(AppConstants.mapZoomStep),
                    onZoomOut: () => _zoomBy(-AppConstants.mapZoomStep),
                    onRecenter: vm.latestReport == null
                        ? null
                        : () => _recenterOn(vm.latestReport!),
                  ),
                ),
              ],
            ),
          ),
          _ActionBar(
            notifyMeEnabled: _notifyMeEnabled,
            onNotifyMeToggled: () {
              setState(() => _notifyMeEnabled = !_notifyMeEnabled);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_notifyMeEnabled ? l10n.notifying : l10n.notifyMe),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            onImOnThisBus: () => _confirmAndStartSharing(context, vm),
            onStopSharing: () => vm.stopSharing(),
          ),
        ],
      ),
    );
  }

  void _zoomBy(double delta) {
    final camera = _mapController.camera;
    final newZoom = (camera.zoom + delta).clamp(
      AppConstants.mapMinZoom,
      AppConstants.mapMaxZoom,
    );
    _mapController.move(camera.center, newZoom);
  }

  void _recenterOn(LocationReport report) {
    _mapController.move(
      LatLng(report.latitude, report.longitude),
      _mapController.camera.zoom,
    );
  }

  Future<void> _confirmAndStartSharing(
    BuildContext context,
    CommunityViewModel vm,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.confirmRidingTitle(vm.displayName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.yesShareLocation),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final ok = await vm.startSharingLocation();
    if (!context.mounted) return;
    if (!ok && vm.sharePhase == LocationSharePhase.permissionDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.locationPermissionDenied)),
      );
    } else if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.helpingPeopleFindBus(vm.waitingCount, vm.displayName))),
      );
    }
  }

  @override
  void dispose() {
    context.read<CommunityViewModel>().leave();
    _mapController.dispose();
    super.dispose();
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: context.read<ConnectivityService>().onStatusChange(),
      builder: (context, snapshot) {
        final online = snapshot.data ?? true;
        if (online) return const SizedBox.shrink();
        final l10n = AppLocalizations.of(context)!;
        return Container(
          width: double.infinity,
          color: AppTheme.warnAmber,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Text(
            l10n.offlineMessage,
            style: const TextStyle(color: Colors.white),
          ),
        );
      },
    );
  }
}

class _MapArea extends StatelessWidget {
  const _MapArea({required this.latestReport, required this.mapController});

  final LocationReport? latestReport;
  final MapController mapController;

  static const _dhakaFallback = LatLng(23.8103, 90.4125);

  @override
  Widget build(BuildContext context) {
    final target = latestReport != null
        ? LatLng(latestReport!.latitude, latestReport!.longitude)
        : _dhakaFallback;

    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: target,
        initialZoom: 15,
        minZoom: AppConstants.mapMinZoom,
        maxZoom: AppConstants.mapMaxZoom,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.byteutility.dev.buskoi.bus_koi',
        ),
        if (latestReport != null)
          CircleLayer(
            circles: [
              CircleMarker(
                point: target,
                radius: latestReport!.accuracy,
                useRadiusInMeter: true,
                color: AppTheme.supplierBlue.withValues(alpha: 0.12),
                borderColor: AppTheme.supplierBlue.withValues(alpha: 0.4),
                borderStrokeWidth: 1,
              ),
            ],
          ),
        if (latestReport != null)
          MarkerLayer(
            markers: [
              Marker(
                point: target,
                width: 36,
                height: 36,
                child: const Icon(
                  Icons.directions_bus,
                  color: AppTheme.supplierBlue,
                  size: 32,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _MapControls extends StatelessWidget {
  const _MapControls({
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onRecenter,
  });

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback? onRecenter;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton.small(
          heroTag: 'mapRecenter',
          tooltip: l10n.recenterOnBus,
          onPressed: onRecenter,
          child: const Icon(Icons.my_location),
        ),
        const SizedBox(height: 8),
        FloatingActionButton.small(
          heroTag: 'mapZoomIn',
          tooltip: l10n.zoomIn,
          onPressed: onZoomIn,
          child: const Icon(Icons.add),
        ),
        const SizedBox(height: 8),
        FloatingActionButton.small(
          heroTag: 'mapZoomOut',
          tooltip: l10n.zoomOut,
          onPressed: onZoomOut,
          child: const Icon(Icons.remove),
        ),
      ],
    );
  }
}

class _DemandCard extends StatelessWidget {
  const _DemandCard({
    required this.waitingCount,
    required this.supplierCount,
    required this.latestReport,
  });

  final int waitingCount;
  final int supplierCount;
  final LocationReport? latestReport;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.circle, size: 10, color: AppTheme.demandGreen),
                const SizedBox(width: 8),
                Expanded(child: Text(l10n.peopleWaiting(waitingCount))),
              ],
            ),
            const SizedBox(height: 6),
            if (latestReport != null)
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: AppTheme.supplierBlue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.passengerLocationUpdatedAgo(
                        RelativeTimeFormatter.format(l10n, latestReport!.reportedAt),
                      ),
                    ),
                  ),
                ],
              )
            else
              Text(
                l10n.noLocationSupplierYet,
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
            if (supplierCount > 1) ...[
              const SizedBox(height: 4),
              Text(
                l10n.passengersSharing(supplierCount),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.notifyMeEnabled,
    required this.onNotifyMeToggled,
    required this.onImOnThisBus,
    required this.onStopSharing,
  });

  final bool notifyMeEnabled;
  final VoidCallback onNotifyMeToggled;
  final VoidCallback onImOnThisBus;
  final VoidCallback onStopSharing;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final vm = context.watch<CommunityViewModel>();
    final isSharing = vm.sharePhase == LocationSharePhase.sharing;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onNotifyMeToggled,
                icon: Icon(notifyMeEnabled ? Icons.notifications_active : Icons.notifications_none),
                label: Text(l10n.notifyMe),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: isSharing ? onStopSharing : onImOnThisBus,
                icon: const Icon(Icons.directions_bus),
                label: Text(isSharing ? l10n.stopSharing : l10n.imOnThisBus),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
