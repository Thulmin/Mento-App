// Handles saved locations and explicit, on-demand device location requests.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/models.dart';
import '../../../data/repositories/repositories.dart';

final savedLocationsProvider = StreamProvider<List<SavedLocation>>(
  (ref) => ref.watch(studentRepositoryProvider).watchSavedLocations(),
);

enum MentoLocationStatus {
  idle,
  loading,
  ready,
  servicesDisabled,
  denied,
  deniedForever,
  error,
}

class MentoLocationState {
  const MentoLocationState({
    this.status = MentoLocationStatus.idle,
    this.position,
    this.accuracyStatus,
    this.message,
  });

  final MentoLocationStatus status;
  final Position? position;
  final LocationAccuracyStatus? accuracyStatus;
  final String? message;
}

final mapLocationProvider =
    NotifierProvider<MapLocationController, MentoLocationState>(
      MapLocationController.new,
    );

class MapLocationController extends Notifier<MentoLocationState> {
  @override
  MentoLocationState build() => const MentoLocationState();

  Future<void> locate() async {
    state = const MentoLocationState(status: MentoLocationStatus.loading);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        state = const MentoLocationState(
          status: MentoLocationStatus.servicesDisabled,
          message:
              'Location services are off. Manual study locations still work.',
        );
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        state = const MentoLocationState(
          status: MentoLocationStatus.deniedForever,
          message:
              'Location is blocked in system settings. Mento never requires it for planning.',
        );
        return;
      }
      if (permission == LocationPermission.denied) {
        state = const MentoLocationState(
          status: MentoLocationStatus.denied,
          message:
              'Location permission was declined. You can add venues manually.',
        );
        return;
      }
      final accuracy = await Geolocator.getLocationAccuracy();
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 12),
        ),
      );
      state = MentoLocationState(
        status: MentoLocationStatus.ready,
        position: position,
        accuracyStatus: accuracy,
        message:
            accuracy == LocationAccuracyStatus.reduced
                ? 'Approximate location is active. Nearby results may be less precise.'
                : 'Current location is used only for this map view and is not stored.',
      );
    } catch (_) {
      state = const MentoLocationState(
        status: MentoLocationStatus.error,
        message:
            'Current location could not be obtained. Try again or enter a venue manually.',
      );
    }
  }

  Future<void> openSettings() => Geolocator.openAppSettings();
}

final mapActionProvider =
    NotifierProvider<MapActionController, AsyncValue<void>>(
      MapActionController.new,
    );

class MapActionController extends Notifier<AsyncValue<void>> {
  static const _uuid = Uuid();

  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<bool> save({
    required String name,
    required double latitude,
    required double longitude,
    required SavedLocationType type,
    String? address,
    String? notes,
  }) async {
    state = const AsyncLoading();
    try {
      await ref
          .read(studentRepositoryProvider)
          .saveSavedLocation(
            SavedLocation(
              id: _uuid.v4(),
              name: name.trim(),
              address: address?.trim().isEmpty == true ? null : address?.trim(),
              latitude: latitude,
              longitude: longitude,
              type: type,
              notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
              createdAt: DateTime.now(),
            ),
          );
      state = const AsyncData(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }

  Future<void> delete(String id) async {
    state = const AsyncLoading();
    try {
      await ref.read(studentRepositoryProvider).deleteSavedLocation(id);
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }
}
