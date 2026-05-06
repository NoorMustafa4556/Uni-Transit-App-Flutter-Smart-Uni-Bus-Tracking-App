import 'dart:async';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:uni_transit/services/location_service.dart';
import 'package:uni_transit/services/routing_service.dart';
import 'package:uni_transit/services/notification_service.dart';
import 'package:uni_transit/core/util/logger.dart';
import 'package:uni_transit/core/constants/campus_locations.dart';
import 'package:uni_transit/services/trip_alert_service.dart';
import 'package:uni_transit/core/constants/custom_routes.dart';

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
  final double speed;
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
    this.speed = 0.0,
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
    double? speed,
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
      speed: speed ?? this.speed,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class DriverTripNotifier extends Notifier<DriverTripState> {
  final LocationService _locationService = LocationService();

  // Throttle navigation refresh to avoid excessive API calls
  DateTime _lastRefresh = DateTime.fromMillisecondsSinceEpoch(0);
  static const _refreshInterval = Duration(seconds: 15);

  @override
  DriverTripState build() {
    return DriverTripState();
  }

  void updateLocation(LatLng loc, double heading, {double speed = 0.0}) {
    state = state.copyWith(
      currentLocation: loc,
      heading: heading,
      speed: speed,
    );
    if (state.isTripStarted) {
      // Throttle navigation refresh to every 15 seconds
      final now = DateTime.now();
      if (now.difference(_lastRefresh) > _refreshInterval) {
        _lastRefresh = now;
        _refreshNavigation();
      }
      // Always update tracking position with latest ETA data
      _locationService.updateTracking(
        state.busNumber,
        loc.latitude,
        loc.longitude,
        heading,
        speed: speed,
        remainingTime: state.remainingTime,
        arrivalTime:
            state.remainingTime != "---"
                ? _calculateClockTime(state.remainingTime)
                : "Calculating...",
      );
    }
  }

  String _calculateClockTime(String remainingStr) {
    try {
      final minutes = int.parse(remainingStr.split(' ')[0]);
      final arrival = DateTime.now().add(Duration(minutes: minutes));
      return DateFormat('hh:mm a').format(arrival);
    } catch (e) {
      return "Calculating...";
    }
  }

  void updateInputs({
    String? bus,
    String? plate,
    String? from,
    String? to,
    String? gender,
  }) {
    state = state.copyWith(
      busNumber: bus,
      plateNumber: plate,
      from: from,
      to: to,
      gender: gender,
    );
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
        // Fixed: now passes uid so restoreTracking can re-create RTDB entry
        await _locationService.restoreTracking(uid, state.busNumber);
        await _refreshNavigation();
      }
    } catch (e) {
      AppLogger.error("Restore failed: $e");
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> _refreshNavigation() async {
    if (state.from == null || state.to == null) return;

    final routeName = "${state.from} ➔ ${state.to}";
    final manualPoints = CustomRoutes.getRoutePoints(routeName);

    if (manualPoints.isNotEmpty && manualPoints.length > 2) {
      // ⚡ PROFESSIONAL: Use manual points for the map path
      final target = _hubs[state.to!];
      if (target != null) {
        // We still call OSRM only for Distance/Time estimates, but keep the manual points for drawing
        final routeData = await RoutingService.getFullRoute([
          state.currentLocation,
          target,
        ]);
        state = state.copyWith(
          routePoints: manualPoints,
          remainingDistance:
              routeData != null
                  ? "${(routeData.distanceMeters / 1000).toStringAsFixed(1)} KM"
                  : state.remainingDistance,
          remainingTime:
              routeData != null
                  ? "${(routeData.durationSeconds / 60).ceil()} MIN"
                  : state.remainingTime,
        );
      }
    } else {
      // Fallback to OSRM if no manual points are defined
      final target = _hubs[state.to!];
      if (target == null) return;
      final routeData = await RoutingService.getFullRoute([
        state.currentLocation,
        target,
      ]);
      if (routeData != null) {
        state = state.copyWith(
          routePoints: routeData.points,
          remainingDistance:
              "${(routeData.distanceMeters / 1000).toStringAsFixed(1)} KM",
          remainingTime: "${(routeData.durationSeconds / 60).ceil()} MIN",
        );
      }
    }
  }

  Future<void> toggleTrip(String uid, String driverName) async {
    if (!state.isTripStarted) {
      if (state.from == null || state.to == null) return;
      if (state.busNumber.trim().isEmpty) {
        NotificationService.show(
          title: "Missing Info",
          message: "Please enter a Bus ID before starting.",
          type: NotificationType.warning,
        );
        return;
      }
      try {
        // ⚡ NEW: Capture actual location immediately to avoid (0,0) ocean bug
        final pos = await Geolocator.getCurrentPosition();
        final nowFormatted = DateFormat('hh:mm a').format(DateTime.now());

        await _locationService.startSharingLocation(
          uid,
          state.busNumber,
          from: state.from!,
          to: state.to!,
          gender: state.gender,
          driverName: driverName,
          departureTime: nowFormatted,
          arrivalTime: "Arrival Pending",
          plateNumber: state.plateNumber,
          lat: pos.latitude,
          lng: pos.longitude,
        );

        final activeTrip = await _locationService.getActiveTrip(uid);
        state = state.copyWith(
          isTripStarted: true,
          activeTripId: activeTrip?['tripId'],
        );

        // ⚡ PROFESSIONAL: Publish trip alert for students and Admin Panel
        await TripAlertService().publishTripStart(
          busId: state.busNumber,
          from: state.from!,
          to: state.to!,
          driverName: driverName,
        );

        await _refreshNavigation();

        NotificationService.show(
          title: "Trip Started",
          message:
              "You are now live-tracking from ${state.from} to ${state.to}.",
          type: NotificationType.success,
        );
      } catch (e) {
        NotificationService.show(
          title: "Error",
          message: "Failed to start trip: $e",
          type: NotificationType.error,
        );
      }
    } else {
      // Terminate Trip: Perform a FULL RESET of the state
      await _locationService.stopSharingLocation(
        uid,
        state.busNumber,
        state.activeTripId!,
      );

      state = state.copyWith(
        isTripStarted: false,
        activeTripId: null,
        busNumber: "", // Clear bus info
        plateNumber: "",
        from: null, // Reset hubs
        to: null,
        routePoints: [], // Clear map path
        remainingDistance: "---", // Reset indicators
        remainingTime: "---",
      );

      NotificationService.show(
        title: "Trip Terminated",
        message:
            "Your live tracking session has ended and state has been reset.",
        type: NotificationType.warning,
      );
    }
  }

  /// Hub coordinates — using CampusLocations for consistency across the app.
  static final Map<String, LatLng> _hubs = {
    CampusLocations.baghdadName: CampusLocations.baghdadCampus,
    CampusLocations.abbasiaName: CampusLocations.abbasiaCampus,
  };
}

final driverTripProvider =
    NotifierProvider<DriverTripNotifier, DriverTripState>(
      () => DriverTripNotifier(),
    );
