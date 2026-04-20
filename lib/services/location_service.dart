import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:uni_transit/core/util/logger.dart';

class LocationService {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref('buses');
  StreamSubscription<Position>? _positionStreamSubscription;

  // Static method for initial permission handling (Professional UI flow)
  static Future<bool> handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      AppLogger.error('Location services are disabled.');
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        AppLogger.error('Location permissions are denied');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      AppLogger.error('Location permissions are permanently denied.');
      return false;
    }

    return true;
  }

  // Stream for UI updates
  Stream<Position> get locationStream => Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    ),
  );

  // Driver: Start sharing bus location to Firebase
  Future<void> startSharingLocation(
    String uid, 
    String busNumber, 
    {String? from, String? to}
  ) async {
    // 1. Check permissions first
    final hasPermission = await handleLocationPermission();
    if (!hasPermission) throw Exception("Location Permission Denied");

    // 2. Set initial status
    await _dbRef.child(busNumber).set({
      'driverId': uid,
      'status': 'Active',
      'from': from,
      'to': to,
      'lastUpdated': ServerValue.timestamp,
    });

    // 3. Start high-frequency stream updates
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = locationStream.listen((Position position) {
      _dbRef.child(busNumber).update({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'speed': position.speed,
        'lastUpdated': ServerValue.timestamp,
      });
    });
  }

  // Driver: Stop sharing
  Future<void> stopSharingLocation() async {
    await _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
  }

  // Driver: Update status manually (e.g. Arrived)
  Future<void> updateBusStatus(String busNumber, String status) async {
    await _dbRef.child(busNumber).update({'status': status});
  }
}
