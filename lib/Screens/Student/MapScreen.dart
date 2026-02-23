import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../Constants/AppColors.dart';

import 'package:geolocator/geolocator.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // Baghdad-ul-Jadeed Campus Coordinates (Approximate)
  final LatLng _campusLocation = const LatLng(
    29.3794,
    71.6707,
  ); // IUB BJ Campus

  LatLng _userLocation = const LatLng(29.3794, 71.6707); // Default to Campus
  bool _hasUserLocation = false;

  final MapController _mapController = MapController();
  final DatabaseReference _busesRef = FirebaseDatabase.instance.ref('buses');

  List<Marker> _busMarkers = [];

  @override
  void initState() {
    super.initState();
    _listenToBusLocations();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Location services are disabled. Please enable them.",
              ),
            ),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Location permission denied.")),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Location permission permanently denied. Enable in Settings.",
              ),
            ),
          );
        }
        return;
      }

      // 1. Try last known position first (Faster) - Skip on Web
      if (!kIsWeb) {
        try {
          final lastPosition = await Geolocator.getLastKnownPosition();
          if (lastPosition != null && mounted) {
            _updateUserLocation(lastPosition, isLive: false);
          }
        } catch (e) {
          print("Last known error: $e");
        }
      }

      // 2. Get current position (More accurate) & FORCE Hardware GPS
      final position = await Geolocator.getCurrentPosition(
        locationSettings:
            kIsWeb
                ? const LocationSettings(accuracy: LocationAccuracy.high)
                : AndroidSettings(
                  accuracy: LocationAccuracy.high,
                  distanceFilter: 10,
                  forceLocationManager:
                      true, // <--- FORCES HARDWARE GPS (Fixes DC issue)
                  intervalDuration: const Duration(seconds: 10),
                ),
      );

      if (mounted) {
        _updateUserLocation(position, isLive: true);
      }
    } catch (e) {
      print("Error getting location: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error fetching location: $e")));
      }
    }
  }

  void _updateUserLocation(Position position, {required bool isLive}) {
    setState(() {
      _userLocation = LatLng(position.latitude, position.longitude);
      _hasUserLocation = true;
    });
    _mapController.move(_userLocation, 15.0);
  }

  void _listenToBusLocations() {
    _busesRef.onValue.listen((event) {
      final data = event.snapshot.value;
      if (data == null) return;

      final Map<dynamic, dynamic> buses = data as Map<dynamic, dynamic>;
      List<Marker> newMarkers = [];

      buses.forEach((key, value) {
        final busData = value as Map<dynamic, dynamic>;
        final double lat = busData['latitude'];
        final double lng = busData['longitude'];
        final String busNumber = key.toString();

        newMarkers.add(
          Marker(
            point: LatLng(lat, lng),
            width: 80,
            height: 80,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: const [
                      BoxShadow(blurRadius: 4, color: Colors.black26),
                    ],
                  ),
                  child: Text(
                    busNumber,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Icon(
                  Icons.directions_bus,
                  color: AppColors.primaryNavy,
                  size: 40,
                ),
              ],
            ),
          ),
        );
      });

      if (mounted) {
        setState(() {
          _busMarkers = newMarkers;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _campusLocation,
          initialZoom: 15.0,
          interactionOptions: const InteractionOptions(
            flags:
                InteractiveFlag.all, // Enables Scroll Wheel, Pinch, Drag, etc.
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.microcode.uni_transit',
          ),
          MarkerLayer(markers: _busMarkers),
          MarkerLayer(
            markers: [
              Marker(
                point: _campusLocation,
                width: 80,
                height: 80,
                child: const Icon(Icons.school, color: Colors.red, size: 40),
              ),
              if (_hasUserLocation)
                Marker(
                  point: _userLocation,
                  width: 60,
                  height: 60,
                  child: const Icon(
                    Icons.my_location,
                    color: Colors.blue,
                    size: 30,
                  ),
                ),
            ],
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "zoom_in",
            mini: true,
            backgroundColor: Colors.white,
            onPressed: () {
              final currentZoom = _mapController.camera.zoom;
              _mapController.move(
                _mapController.camera.center,
                currentZoom + 1,
              );
            },
            child: const Icon(Icons.add, color: AppColors.primaryNavy),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: "zoom_out",
            mini: true,
            backgroundColor: Colors.white,
            onPressed: () {
              final currentZoom = _mapController.camera.zoom;
              _mapController.move(
                _mapController.camera.center,
                currentZoom - 1,
              );
            },
            child: const Icon(Icons.remove, color: AppColors.primaryNavy),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: "my_location",
            onPressed: () {
              if (_hasUserLocation) {
                _mapController.move(_userLocation, 15);
              } else {
                _mapController.move(_campusLocation, 15);
                _getCurrentLocation();
              }
            },
            backgroundColor: AppColors.primaryNavy,
            child: const Icon(Icons.my_location, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
