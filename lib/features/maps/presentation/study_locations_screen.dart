// Presents saved study places, an optional map, directions, and permission help.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/responsive/breakpoints.dart';
import '../../../core/config/app_config.dart';
import '../../../core/widgets/mento_card.dart';
import '../../../core/widgets/mento_controls.dart';
import '../../../core/widgets/mento_states.dart';
import '../../../data/models/models.dart';
import '../application/map_providers.dart';

class StudyLocationsScreen extends ConsumerWidget {
  const StudyLocationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locations = ref.watch(savedLocationsProvider);
    final locationState = ref.watch(mapLocationProvider);
    final action = ref.watch(mapActionProvider);
    ref.listen(mapActionProvider, (_, next) {
      if (next case AsyncError()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'The saved location could not be changed. Please retry.',
            ),
          ),
        );
      }
    });
    return Scaffold(
      appBar: AppBar(
        title: const MentoScreenTitle(
          title: 'Study locations',
          semanticIdentifier: 'mento_screen_study_locations',
        ),
        actions: [
          MentoIconButton(
            icon: Icons.add_location_alt_outlined,
            tooltip: 'Add study location',
            onPressed:
                action.isLoading ? null : () => _addLocation(context, ref),
          ),
        ],
      ),
      body: locations.when(
        loading:
            () => const MentoPage(child: MentoLoadingSkeleton(height: 420)),
        error:
            (_, __) => MentoErrorState(
              title: 'Locations are unavailable',
              message:
                  'Manual venue names in timetable events still work. Retry when connected.',
              onRetry: () => ref.invalidate(savedLocationsProvider),
            ),
        data:
            (items) => MentoPage(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (AppConfig.mapsEnabled)
                    _MapPanel(locations: items, locationState: locationState)
                  else
                    const MentoCard(
                      highlighted: true,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.map_outlined),
                        title: Text(
                          'Interactive map is disabled in this build',
                        ),
                        subtitle: Text(
                          'Saved places, current-location capture, manual coordinates and directions remain available. Enable the map only after separate restricted Android/iOS keys are configured.',
                        ),
                      ),
                    ),
                  const SizedBox(height: 14),
                  if (locationState.message != null)
                    MentoCard(
                      child: Row(
                        children: [
                          Icon(_statusIcon(locationState.status)),
                          const SizedBox(width: 12),
                          Expanded(child: Text(locationState.message!)),
                          if (locationState.status ==
                              MentoLocationStatus.deniedForever)
                            TextButton(
                              onPressed:
                                  () =>
                                      ref
                                          .read(mapLocationProvider.notifier)
                                          .openSettings(),
                              child: const Text('Settings'),
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 14),
                  MentoResponsiveGrid(
                    compactColumns: 1,
                    mediumColumns: 2,
                    expandedColumns: 2,
                    spacing: 10,
                    children: [
                      MentoButton(
                        label:
                            locationState.status == MentoLocationStatus.loading
                                ? 'Locating…'
                                : 'Use current location',
                        icon: Icons.my_location,
                        loading:
                            locationState.status == MentoLocationStatus.loading,
                        onPressed:
                            locationState.status == MentoLocationStatus.loading
                                ? null
                                : () => _explainAndLocate(context, ref),
                      ),
                      MentoButton(
                        label: 'Add manually',
                        icon: Icons.edit_location_alt_outlined,
                        variant: MentoButtonVariant.outlined,
                        onPressed: () => _addLocation(context, ref),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const MentoSectionHeader(
                    title: 'Saved places',
                    subtitle:
                        'Only places you explicitly save are persisted; location history is never collected',
                  ),
                  const SizedBox(height: 12),
                  if (items.isEmpty)
                    MentoEmptyState(
                      title: 'No saved study locations',
                      message:
                          'Add a library, campus room or study space manually. Location permission is optional.',
                      icon: Icons.location_on_outlined,
                      actionLabel: 'Add location',
                      onAction: () => _addLocation(context, ref),
                    )
                  else
                    for (final item in items) ...[
                      MentoCard(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            child: Icon(_typeIcon(item.type)),
                          ),
                          title: Text(item.name),
                          subtitle: Text(
                            item.address ??
                                '${item.latitude.toStringAsFixed(5)}, ${item.longitude.toStringAsFixed(5)}',
                          ),
                          trailing: PopupMenuButton<String>(
                            tooltip: 'Actions for ${item.name}',
                            onSelected: (value) {
                              if (value == 'directions') _directions(item);
                              if (value == 'delete') {
                                ref
                                    .read(mapActionProvider.notifier)
                                    .delete(item.id);
                              }
                            },
                            itemBuilder:
                                (context) => const [
                                  PopupMenuItem(
                                    value: 'directions',
                                    child: Text('Open directions'),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete'),
                                  ),
                                ],
                          ),
                          onTap: () => _directions(item),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                ],
              ),
            ),
      ),
    );
  }

  Future<void> _explainAndLocate(BuildContext context, WidgetRef ref) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Use your location for this map?'),
            content: const Text(
              'Mento requests location only now to centre the map and help with nearby study spaces. It does not track in the background or store location history. You can continue manually if you decline.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Not now'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Continue'),
              ),
            ],
          ),
    );
    if (accepted == true) await ref.read(mapLocationProvider.notifier).locate();
  }

  Future<void> _addLocation(BuildContext context, WidgetRef ref) async {
    final current = ref.read(mapLocationProvider).position;
    final name = TextEditingController();
    final address = TextEditingController();
    final latitude = TextEditingController(
      text: current?.latitude.toString() ?? '',
    );
    final longitude = TextEditingController(
      text: current?.longitude.toString() ?? '',
    );
    var type = SavedLocationType.studySpace;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setModalState) => SafeArea(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      8,
                      20,
                      20 + MediaQuery.viewInsetsOf(context).bottom,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Save a study location',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 16),
                          MentoTextField(label: 'Name', controller: name),
                          const SizedBox(height: 12),
                          MentoTextField(
                            label: 'Address (optional)',
                            controller: address,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: MentoTextField(
                                  label: 'Latitude',
                                  controller: latitude,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                        signed: true,
                                      ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: MentoTextField(
                                  label: 'Longitude',
                                  controller: longitude,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                        signed: true,
                                      ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<SavedLocationType>(
                            value: type,
                            decoration: const InputDecoration(
                              labelText: 'Type',
                            ),
                            items: [
                              for (final value in SavedLocationType.values)
                                DropdownMenuItem(
                                  value: value,
                                  child: Text(value.name),
                                ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setModalState(() => type = value);
                              }
                            },
                          ),
                          const SizedBox(height: 18),
                          MentoButton(
                            label: 'Save location',
                            onPressed: () {
                              final lat = double.tryParse(latitude.text);
                              final lng = double.tryParse(longitude.text);
                              Navigator.pop(
                                context,
                                name.text.trim().isNotEmpty &&
                                    lat != null &&
                                    lng != null &&
                                    lat >= -90 &&
                                    lat <= 90 &&
                                    lng >= -180 &&
                                    lng <= 180,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          ),
    );
    if (saved == true) {
      await ref
          .read(mapActionProvider.notifier)
          .save(
            name: name.text,
            address: address.text,
            latitude: double.parse(latitude.text),
            longitude: double.parse(longitude.text),
            type: type,
          );
    }
    name.dispose();
    address.dispose();
    latitude.dispose();
    longitude.dispose();
  }

  static Future<void> _directions(SavedLocation item) async {
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '${item.latitude},${item.longitude}',
    });
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _MapPanel extends StatelessWidget {
  const _MapPanel({required this.locations, required this.locationState});
  final List<SavedLocation> locations;
  final MentoLocationState locationState;

  @override
  Widget build(BuildContext context) {
    final current = locationState.position;
    final initial =
        current == null
            ? locations.firstOrNull == null
                ? const LatLng(6.9271, 79.8612)
                : LatLng(locations.first.latitude, locations.first.longitude)
            : LatLng(current.latitude, current.longitude);
    return SizedBox(
      height: 380,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: GoogleMap(
          initialCameraPosition: CameraPosition(target: initial, zoom: 14),
          myLocationEnabled: current != null,
          myLocationButtonEnabled: current != null,
          markers: {
            for (final item in locations)
              Marker(
                markerId: MarkerId(item.id),
                position: LatLng(item.latitude, item.longitude),
                infoWindow: InfoWindow(title: item.name, snippet: item.address),
              ),
          },
        ),
      ),
    );
  }
}

IconData _statusIcon(MentoLocationStatus status) => switch (status) {
  MentoLocationStatus.ready => Icons.my_location,
  MentoLocationStatus.denied ||
  MentoLocationStatus.deniedForever => Icons.location_disabled,
  MentoLocationStatus.servicesDisabled => Icons.location_off_outlined,
  MentoLocationStatus.error => Icons.error_outline,
  _ => Icons.info_outline,
};

IconData _typeIcon(SavedLocationType type) => switch (type) {
  SavedLocationType.campus => Icons.school_outlined,
  SavedLocationType.library => Icons.local_library_outlined,
  SavedLocationType.studySpace => Icons.desk_outlined,
  SavedLocationType.cafe => Icons.local_cafe_outlined,
  SavedLocationType.home => Icons.home_outlined,
  SavedLocationType.other => Icons.place_outlined,
};
