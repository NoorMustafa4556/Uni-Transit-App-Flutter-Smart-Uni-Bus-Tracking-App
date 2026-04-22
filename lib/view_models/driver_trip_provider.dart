import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:uni_transit/services/location_service.dart';
import 'package:uni_transit/services/routing_service.dart';
import 'package:uni_transit/services/notification_service.dart';
import 'package:uni_transit/core/util/logger.dart';
import 'package:uni_transit/core/constants/campus_locations.dart';

class DriverTripState {
  final bool isTripStarted;
  final String? activeTripId;
  final String busNumber;
  final String plateNumber;
  final String? from;
  final String? to;
  final String gender;
  final List<LatLng> routePoints;
  final String remainingDistance;
  final String remainingTime;
  final LatLng currentLocation;
  final double heading;
  final bool isLoading;

  DriverTripState({
    this.isTripStarted = false,
    this.activeTripId,
    this.busNumber = "",
    this.plateNumber = "",
    this.from,
    this.to,
    this.gender = "Combined",
    this.routePoints = const [],
    this.remainingDistance = "---",
    this.remainingTime = "---",
    this.currentLocation = const LatLng(29.3794, 71.6707),
    this.heading = 0.0,
    this.isLoading = false,
  });

  DriverTripState copyWith({
    bool? isTripStarted,
    String? activeTripId,
    String? busNumber,
    String? plateNumber,
    String? from,
    String? to,
    String? gender,
    List<LatLng>? routePoints,
    String? remainingDistance,
    String? remainingTime,
    LatLng? currentLocation,
    double? heading,
    bool? isLoading,
  }) {
    return DriverTripState(
      isTripStarted: isTripStarted ?? this.isTripStarted,
      activeTripId: activeTripId ?? this.activeTripId,
      busNumber: busNumber ?? this.busNumber,
      plateNumber: plateNumber ?? this.plateNumber,
      from: from ?? this.from,
      to: to ?? this.to,
      gender: gender ?? this.gender,
      routePoints: routePoints ?? this.routePoints,
      remainingDistance: remainingDistance ?? this.remainingDistance,
      remainingTime: remainingTime ?? this.remainingTime,
      currentLocation: currentLocation ?? this.currentLocation,
      heading: heading ?? this.heading,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class DriverTripNotifier extends Notifier<DriverTripState> {
  final LocationService _locationService = LocationService();

  @override
  DriverTripState build() {
    return DriverTripState();
  }

  void updateLocation(LatLng loc, double heading) {
    state = state.copyWith(currentLocation: loc, heading: heading);
    if (state.isTripStarted) {
      _refreshNavigation();
      _locationService.updateTracking(state.busNumber, loc.latitude, loc.longitude, heading);
    }
  }

  void updateInputs({String? bus, String? plate, String? from, String? to, String? gender}) {
    state = state.copyWith(busNumber: bus, plateNumber: plate, from: from, to: to, gender: gender);
  }

  Future<void> restoreActiveTrip(String uid) async {
    state = state.copyWith(isLoading: true);
    try {
      final activeTrip = await _locationService.getActiveTrip(uid);
      if (activeTrip != null) {
        state = state.copyWith(
          isTripStarted: true,
          activeTripId: activeTrip['tripId'],
          busNumber: activeTrip['busNumber'],
          plateNumber: activeTrip['plateNumber'],
          from: activeTrip['from'],
          to: activeTrip['to'],
          gender: activeTrip['gender'],
        );
        _locationService.restoreTracking(state.busNumber);
        await _refreshNavigation();
      }
    } catch (e) {
      AppLogger.error("Restore failed: $e");
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> _refreshNavigation() async {
    if (state.to == null) return;
    final target = _hubs[state.to];
    if (target == null) return;

    final routeData = await RoutingService.getFullRoute([state.currentLocation, target]);
    if (routeData != null) {
      state = state.copyWith(
        routePoints: routeData.points,
        remainingDistance: "${(routeData.distanceMeters / 1000).toStringAsFixed(1)} KM",
        remainingTime: "${(routeData.durationSeconds / 60).ceil()} MIN",
      );
    }
  }

  Future<void> toggleTrip(String uid, String driverName) async {
    if (!state.isTripStarted) {
      if (state.from == null || state.to == null) return;
      try {
        await _locationService.startSharingLocation(
          uid, state.busNumber, from: state.from!, to: state.to!, 
          gender: state.gender, driverName: driverName, 
          departureTime: "Now", arrivalTime: "Arrival Pending", plateNumber: state.plateNumber
        );
        final activeTrip = await _locationService.getActiveTrip(uid);
        state = state.copyWith(isTripStarted: true, activeTripId: activeTrip?['tripId']);
        await _refreshNavigation();
        
        NotificationService.show(
          title: "Trip Started",
          message: "You are now live-tracking from ${state.from} to ${state.to}.",
          type: NotificationType.success,
        );
      } catch (e) {
        NotificationService.show(title: "Error", message: "Failed to start trip.", type: NotificationType.error);
      }
    } else {
      await _locationService.stopSharingLocation(uid, state.busNumber, state.activeTripId!);
      state = state.copyWith(isTripStarted: false, activeTripId: null, routePoints: []);
      
      NotificationService.show(
        title: "Trip Terminated",
        message: "Your live tracking session has ended.",
        type: NotificationType.warning,
      );
    }
  }

  static final Map<String, LatLng> _hubs = {
    'Baghdad Campus': CampusLocations.baghdadCampus,
    'Abbasia Campus': CampusLocations.abbasiaCampus,
    'Railway Campus': CampusLocations.railwayCampus,
  };
}

final driverTripProvider = NotifierProvider<DriverTripNotifier, DriverTripState>(() => DriverTripNotifier());
