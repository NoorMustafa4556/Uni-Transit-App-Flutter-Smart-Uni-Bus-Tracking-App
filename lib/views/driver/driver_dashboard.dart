import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';

import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uni_transit/core/constants/app_colors.dart';
import 'package:uni_transit/widgets/custom_app_bar.dart';

import 'package:uni_transit/core/constants/campus_locations.dart';
import 'package:uni_transit/services/auth_service.dart';
import 'package:uni_transit/services/location_service.dart';
import 'package:uni_transit/widgets/app_drawer.dart';
import 'package:uni_transit/core/util/logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DriverDashboard extends ConsumerStatefulWidget {
  const DriverDashboard({super.key});

  @override
  ConsumerState<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends ConsumerState<DriverDashboard> {
  bool _isTripStarted = false;
  final _locationService = LocationService();
  final _authService = AuthService();
  final _busNumberController = TextEditingController();

  final MapController _mapController = MapController();
  LatLng _currentLocation = const LatLng(29.3794, 71.6707);

  String? _selectedFrom;
  String? _selectedTo;
  bool _hasArrived = false;

  final List<String> _hubs = [
    'Baghdad Campus',
    'Abbasia Campus',
    'Railway Campus',
    'City Terminal',
  ];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _locationService.locationStream.listen((position) {
      if (mounted) {
        setState(
          () =>
              _currentLocation = LatLng(position.latitude, position.longitude),
        );
        if (_isTripStarted) {
          _mapController.move(_currentLocation, 15.0);
          _checkArrival(_currentLocation);
        }
      }
    });
  }

  Future<void> _getCurrentLocation() async {
    final hasPermission = await LocationService.handleLocationPermission();
    if (!hasPermission) {
      if (mounted) {
        _showError("Location permission is required for the Driver Terminal.");
      }
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
        });
        _mapController.move(_currentLocation, 15.0);
      }
    } catch (e) {
      AppLogger.error("Location error: $e");
    }
  }

  void _checkArrival(LatLng currentPos) {
    if (_selectedTo == null || _hasArrived) return;
    LatLng? target;
    if (_selectedTo == 'Baghdad Campus') target = CampusLocations.baghdadCampus;
    if (_selectedTo == 'Abbasia Campus') target = CampusLocations.abbasiaCampus;
    if (_selectedTo == 'Railway Campus') target = CampusLocations.railwayCampus;

    if (target != null) {
      final distance = const Distance().as(
        LengthUnit.Meter,
        currentPos,
        target,
      );
      if (distance < CampusLocations.arrivalRadiusMeters) {
        setState(() => _hasArrived = true);
        _locationService.updateBusStatus(
          _busNumberController.text.trim(),
          "Arrived at $_selectedTo",
        );
        _showArrivalDialog();
      }
    }
  }

  void _showArrivalDialog() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text(l10n.destinationReached),
            content: Text(l10n.arrivalMessage(_selectedTo ?? "")),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _toggleTrip();
                },
                child: Text(l10n.endTrip),
              ),
            ],
          ),
    );
  }

  void _toggleTrip() async {
    final user = _authService.currentUser;
    if (user == null) return;

    if (!_isTripStarted) {
      if (_busNumberController.text.trim().isEmpty) {
        _showError("Please enter Bus Number");
        return;
      }
      if (_selectedFrom == null || _selectedTo == null) {
        _showError("Please select Route (From & To)");
        return;
      }

      try {
        await _locationService.startSharingLocation(
          user.uid,
          _busNumberController.text.trim(),
          from: _selectedFrom,
          to: _selectedTo,
        );
        setState(() => _isTripStarted = true);
      } catch (e) {
        _showError("Error: $e");
      }
    } else {
      await _locationService.stopSharingLocation();
      setState(() {
        _isTripStarted = false;
        _hasArrived = false;
        _selectedFrom = null;
        _selectedTo = null;
      });
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: CustomAppBar(title: AppLocalizations.of(context)!.driverTerminal),
      drawer: const AppDrawer(),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLocation,
              initialZoom: 15,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.uni_transit.app',
                tileBuilder:
                    isDark
                        ? (context, tileWidget, tile) => ColorFiltered(
                          colorFilter: const ColorFilter.matrix([
                            -1,
                            0,
                            0,
                            0,
                            255,
                            0,
                            -1,
                            0,
                            0,
                            255,
                            0,
                            0,
                            -1,
                            0,
                            255,
                            0,
                            0,
                            0,
                            1,
                            0,
                          ]),
                          child: tileWidget,
                        )
                        : null,
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _currentLocation,
                    width: 80,
                    height: 80,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryNavy,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(color: Colors.black26, blurRadius: 4),
                            ],
                          ),
                          child: Text(
                            "MY BUS",
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.directions_bus_rounded,
                          color: AppColors.primaryNavy,
                          size: 45,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Top Info Gradient Overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.primaryNavy.withValues(alpha: 0.8),
                    AppColors.primaryNavy.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),

          // Professional Control Panel
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 30,
                    spreadRadius: 5,
                    offset: const Offset(0, 10),
                  ),
                ],
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.grey[100]!,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!_isTripStarted) ...[
                    Text(
                      "TRIP INITIALIZATION",
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.accentAmber,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _busNumberController,
                      style: GoogleFonts.poppins(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: "Enter Bus Number (e.g. 45)",
                        prefixIcon: const Icon(
                          Icons.numbers_rounded,
                          color: AppColors.primaryNavy,
                        ),
                        filled: true,
                        fillColor:
                            isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.grey[50],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildRoutePicker(
                            "Origin",
                            _selectedFrom,
                            (v) => setState(() => _selectedFrom = v),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Icon(
                            Icons.swap_horiz_rounded,
                            color: Colors.grey[400],
                          ),
                        ),
                        Expanded(
                          child: _buildRoutePicker(
                            "Destination",
                            _selectedTo,
                            (v) => setState(() => _selectedTo = v),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    _buildActiveTripStatus(),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: _toggleTrip,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _isTripStarted
                                ? AppColors.error
                                : AppColors.liveStatus,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isTripStarted
                                ? Icons.stop_rounded
                                : Icons.play_arrow_rounded,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _isTripStarted
                                ? "TERMINATE TRIP"
                                : "COMMENCE TRACKING",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              fontSize: 13,
                            ),
                          ),
                        ],
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

  Widget _buildActiveTripStatus() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryNavy.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryNavy.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.sensors_rounded,
                color: AppColors.liveStatus,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                "LIVE TRACKING ACTIVE",
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.liveStatus,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "CURRENT ROUTE",
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "$_selectedFrom ➔ $_selectedTo",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryNavy,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "BUS #${_busNumberController.text}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoutePicker(
    String label,
    String? value,
    Function(String?) onChanged,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DropdownButtonFormField<String>(
      initialValue: value,
      hint: Text(label, style: const TextStyle(fontSize: 12)),
      decoration: InputDecoration(
        filled: true,
        fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
      items:
          _hubs
              .map(
                (h) => DropdownMenuItem(
                  value: h,
                  child: Text(h, style: const TextStyle(fontSize: 12)),
                ),
              )
              .toList(),
      onChanged: onChanged,
    );
  }
}
