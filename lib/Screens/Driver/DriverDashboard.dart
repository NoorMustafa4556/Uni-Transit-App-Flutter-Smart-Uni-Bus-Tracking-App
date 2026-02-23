import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import '../../Constants/CampusLocations.dart';
import '../../Constants/AppColors.dart';
import '../../Services/AuthService.dart';
import '../../Services/LocationService.dart';
import '../../Widgets/AppDrawer.dart';
import '../../Widgets/CustomAppBar.dart';

class DriverDashboard extends StatefulWidget {
  const DriverDashboard({super.key});

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  bool _isTripStarted = false;
  final _locationService = LocationService();
  final _authService = AuthService();
  final _busNumberController = TextEditingController();

  // Map Controller
  final MapController _mapController = MapController();
  LatLng _currentLocation = const LatLng(
    29.3794,
    71.6707,
  ); // Default IUB BJ Campus
  String? _selectedDestination;
  bool _hasArrived = false;

  final Map<String, LatLng> _destinations = {
    'Baghdad Campus': CampusLocations.baghdadCampus,
    'Abbasia Campus': CampusLocations.abbasiaCampus,
    'Railway Campus': CampusLocations.railwayCampus,
  };

  @override
  void initState() {
    super.initState();
    _getCurrentLocation(); // Get location immediately
    // Listen to location updates (from the service, active only during trip)
    _locationService.locationStream.listen((position) {
      final newLoc = LatLng(position.latitude, position.longitude);

      if (mounted) {
        setState(() {
          _currentLocation = newLoc;
        });

        if (_isTripStarted) {
          _mapController.move(newLoc, 15.0);
          _checkArrival(newLoc);
        }
      }
    });
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

      // Try last known
      final lastPosition = await Geolocator.getLastKnownPosition();
      if (lastPosition != null && mounted) {
        setState(() {
          _currentLocation = LatLng(
            lastPosition.latitude,
            lastPosition.longitude,
          );
        });
        _mapController.move(_currentLocation, 15.0);
      }

      // Get current & FORCE Hardware GPS
      final position = await Geolocator.getCurrentPosition(
        locationSettings:
            kIsWeb
                ? const LocationSettings(accuracy: LocationAccuracy.high)
                : AndroidSettings(
                  accuracy: LocationAccuracy.high,
                  distanceFilter: 10,
                  forceLocationManager: true, // <--- FORCES HARDWARE GPS
                  intervalDuration: const Duration(seconds: 10),
                ),
      );

      if (mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
        });
        _mapController.move(_currentLocation, 15.0);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Driver Location Updated!")),
        );
      }
    } catch (e) {
      print("Error getting location: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error fetching driver location: $e")),
        );
      }
    }
  }

  void _checkArrival(LatLng currentPos) {
    if (_selectedDestination == null || _hasArrived) return;

    final target = _destinations[_selectedDestination]!;
    final distance = const Distance().as(LengthUnit.Meter, currentPos, target);

    if (distance < CampusLocations.arrivalRadiusMeters) {
      if (mounted) {
        setState(() => _hasArrived = true);
        _locationService.updateBusStatus(
          _busNumberController.text.trim(),
          "Arrived at $_selectedDestination",
        );

        showDialog(
          context: context,
          builder:
              (_) => AlertDialog(
                title: const Text("Destination Reached!"),
                content: Text("You have arrived at $_selectedDestination."),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("OK"),
                  ),
                ],
              ),
        );
      }
    }
  }

  @override
  void dispose() {
    _busNumberController.dispose();
    super.dispose();
  }

  void _toggleTrip() async {
    final user = _authService.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Error: User not found")));
      }
      return;
    }

    if (!_isTripStarted) {
      // STARTING TRIP
      if (_busNumberController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please Enter Bus Number")),
        );
        return;
      }
      if (_selectedDestination == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please Select Destination")),
        );
        return;
      }

      try {
        await _locationService.startSharingLocation(
          user.uid,
          _busNumberController.text.trim(),
        );

        // Update initial status with destination
        await _locationService.updateBusStatus(
          _busNumberController.text.trim(),
          "En Route to $_selectedDestination",
        );

        setState(() {
          _isTripStarted = true;
          _hasArrived = false; // Reset arrival status
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Trip Started! Broadcasting location..."),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Error starting trip: $e")));
        }
      }
    } else {
      // STOPPING TRIP
      await _locationService.stopSharingLocation();
      setState(() {
        _isTripStarted = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Trip Ended.")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: "Driver Dashboard"),
      drawer: const AppDrawer(),
      body: Stack(
        children: [
          // Map Background
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLocation,
              initialZoom: 13.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all, // Enables Scroll Wheel Zoom
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.uni_transit',
              ),
              MarkerLayer(
                markers: [
                  // Driver Marker
                  Marker(
                    point: _currentLocation,
                    width: 80,
                    height: 80,
                    child: const Icon(
                      Icons.directions_bus,
                      color: Colors.blue,
                      size: 40,
                    ),
                  ),
                  // Destination Marker
                  if (_selectedDestination != null)
                    Marker(
                      point: _destinations[_selectedDestination]!,
                      width: 80,
                      height: 80,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),
                ],
              ),
            ],
          ),

          // Zoom Controls (Right Side)
          Positioned(
            right: 20,
            bottom: 250, // Above the bottom panel
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: "driver_zoom_in",
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
                  heroTag: "driver_zoom_out",
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
              ],
            ),
          ),

          // Controls Overlay (Your existing controls)
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!_isTripStarted) ...[
                    TextField(
                      controller: _busNumberController,
                      decoration: const InputDecoration(
                        labelText: "Bus Number",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.directions_bus),
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _selectedDestination,
                      decoration: const InputDecoration(
                        labelText: "Destination",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.map),
                      ),
                      items:
                          _destinations.keys
                              .map(
                                (k) =>
                                    DropdownMenuItem(value: k, child: Text(k)),
                              )
                              .toList(),
                      onChanged:
                          (val) => setState(() => _selectedDestination = val),
                    ),
                    const SizedBox(height: 10),
                  ] else
                    Column(
                      children: [
                        Text(
                          "Heading to: $_selectedDestination",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (_hasArrived)
                          Text(
                            "ARRIVED",
                            style: GoogleFonts.poppins(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                      ],
                    ),

                  const SizedBox(height: 10),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _toggleTrip,
                      icon: Icon(
                        _isTripStarted ? Icons.stop : Icons.play_arrow,
                      ),
                      label: Text(_isTripStarted ? "Stop Trip" : "Start Trip"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _isTripStarted ? Colors.red : Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
