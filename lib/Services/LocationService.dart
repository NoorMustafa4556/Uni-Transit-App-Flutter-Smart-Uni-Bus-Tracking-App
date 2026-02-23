import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_database/firebase_database.dart';

class LocationService {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  StreamSubscription<Position>? _positionStreamSubscription;
  final StreamController<Position> _locationController =
      StreamController<Position>.broadcast();

  Stream<Position> get locationStream => _locationController.stream;

  // Determine the current position of the device.
  // When the location services are not enabled or permissions
  // are denied the `Future` will return an error.
  Future<void> _checkPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permissions are permanently denied, we cannot request permissions.',
      );
    }
  }

  // Start Broadcasting Location
  Future<void> startSharingLocation(String driverId, String busNumber) async {
    await _checkPermission();

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Update every 10 meters
    );

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      // 1. Notify UI listeners
      _locationController.add(position);

      // 2. Update Firebase Realtime Database
      _dbRef.child('buses/$busNumber').set({
        'driverId': driverId,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'timestamp': ServerValue.timestamp,
        'speed': position.speed,
        'status': 'En Route', // Default status
      });
    });
  }

  // Update Status manually (e.g. Arrived)
  Future<void> updateBusStatus(String busNumber, String status) async {
    await _dbRef.child('buses/$busNumber/status').set(status);
  }

  // Stop Broadcasting Location
  Future<void> stopSharingLocation() async {
    await _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    // _locationController.close(); // Don't close if we want to reuse service? Better to keep open.
  }
}
