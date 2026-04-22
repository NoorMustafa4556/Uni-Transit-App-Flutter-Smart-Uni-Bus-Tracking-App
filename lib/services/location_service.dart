import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_database/firebase_database.dart';

class LocationService {
  final DatabaseReference _busesRef = FirebaseDatabase.instance.ref('buses');
  final DatabaseReference _tripsRef = FirebaseDatabase.instance.ref('driver_trips');

  Stream<Position> get locationStream => Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    ),
  );

  static Future<bool> handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    if (permission == LocationPermission.deniedForever) return false;
    return true;
  }

  Future<void> startSharingLocation(
    String uid, String busNumber, {
    required String from, required String to, 
    required String gender, required String driverName,
    required String departureTime, required String arrivalTime,
    String plateNumber = ""
  }) async {
    final tripId = DateTime.now().millisecondsSinceEpoch.toString();
    
    await _busesRef.child(busNumber).set({
      'driverId': uid,
      'driverName': driverName,
      'busNumber': busNumber,
      'plateNumber': plateNumber,
      'latitude': 0.0,
      'longitude': 0.0,
      'heading': 0.0,
      'from': from,
      'to': to,
      'gender': gender,
      'status': 'active',
      'departureTime': departureTime,
      'arrivalTime': arrivalTime,
      'lastUpdated': ServerValue.timestamp,
    });

    await _tripsRef.child(uid).child(tripId).set({
      'tripId': tripId,
      'busNumber': busNumber,
      'plateNumber': plateNumber,
      'from': from,
      'to': to,
      'gender': gender,
      'startTime': ServerValue.timestamp,
      'status': 'active',
    });
  }

  Future<void> updateTracking(String busNumber, double lat, double lng, double heading) async {
    await _busesRef.child(busNumber).update({
      'latitude': lat,
      'longitude': lng,
      'heading': heading,
      'lastUpdated': ServerValue.timestamp,
    });
  }

  Future<void> stopSharingLocation(String uid, String busNumber, String tripId) async {
    await _busesRef.child(busNumber).remove();
    await _tripsRef.child(uid).child(tripId).update({
      'endTime': ServerValue.timestamp,
      'status': 'completed',
    });
  }

  Future<Map<String, dynamic>?> getActiveTrip(String uid) async {
    final snapshot = await _tripsRef.child(uid).orderByChild('status').equalTo('active').limitToFirst(1).get();
    if (snapshot.exists) {
      final data = snapshot.value as Map;
      return Map<String, dynamic>.from(data.values.first);
    }
    return null;
  }

  /// Fetches the entire trip history for a specific driver
  Future<List<Map<String, dynamic>>> getTripHistory(String uid) async {
    final snapshot = await _tripsRef.child(uid).get();
    if (snapshot.exists) {
       final data = snapshot.value as Map;
       final List<Map<String, dynamic>> history = [];
       data.forEach((key, value) {
         history.add(Map<String, dynamic>.from(value as Map));
       });
       // Sort by start time (newest first)
       history.sort((a, b) => (b['startTime'] ?? 0).compareTo(a['startTime'] ?? 0));
       return history;
    }
    return [];
  }

  void restoreTracking(String busNumber) {}
}
