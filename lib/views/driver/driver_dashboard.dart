import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:uni_transit/core/constants/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uni_transit/services/auth_service.dart';
import 'package:uni_transit/services/location_service.dart';
import 'package:uni_transit/widgets/app_drawer.dart';
import 'package:uni_transit/view_models/driver_trip_provider.dart';

class DriverDashboard extends ConsumerStatefulWidget {
  const DriverDashboard({super.key});

  @override
  ConsumerState<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends ConsumerState<DriverDashboard>
    with TickerProviderStateMixin {
  final _authService = AuthService();
  final _busNumberController = TextEditingController();
  final _plateNumberController = TextEditingController();
  final MapController _mapController = MapController();
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = _authService.currentUser;
      if (user != null) {
        ref.read(driverTripProvider.notifier).restoreActiveTrip(user.uid);
      }
    });

    LocationService().locationStream.listen((pos) {
      if (mounted) {
        ref.read(driverTripProvider.notifier).updateLocation(
          LatLng(pos.latitude, pos.longitude), 
          pos.heading
        );
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _busNumberController.dispose();
    _plateNumberController.dispose();
    super.dispose();
  }

  void _onToggle() async {
    final user = _authService.currentUser;
    if (user == null) return;

    final tripState = ref.read(driverTripProvider);
    if (!tripState.isTripStarted) {
      ref.read(driverTripProvider.notifier).updateInputs(
        bus: _busNumberController.text.trim(),
        plate: _plateNumberController.text.trim(),
      );
    }
    await ref.read(driverTripProvider.notifier).toggleTrip(user.uid, user.displayName ?? "Driver");
  }

  @override
  Widget build(BuildContext context) {
    final tripState = ref.watch(driverTripProvider);

    if (tripState.isTripStarted && _busNumberController.text.isEmpty) {
      _busNumberController.text = tripState.busNumber;
      _plateNumberController.text = tripState.plateNumber;
    }

    return Scaffold(
      drawer: const AppDrawer(),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: tripState.currentLocation, initialZoom: 15),
            children: [
              TileLayer(urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png', subdomains: const ['a', 'b', 'c', 'd']),
              if (tripState.routePoints.isNotEmpty)
                PolylineLayer(polylines: [Polyline(points: tripState.routePoints, color: AppColors.primaryYellow.withValues(alpha: 0.8), strokeWidth: 7.0)]),
              if (tripState.isTripStarted && tripState.to != null)
                MarkerLayer(markers: [Marker(point: _getHubPos(tripState.to!), width: 100, height: 100, child: _buildDestinationMarker())]),
              MarkerLayer(markers: [Marker(point: tripState.currentLocation, width: 80, height: 80, child: _buildBusMarker(tripState.heading))]),
            ],
          ),
          if (tripState.isTripStarted) Positioned(top: 50, left: 20, right: 20, child: _buildNavigationBanner(tripState)),
          Positioned(top: 40, left: 20, child: Builder(builder: (context) => _buildCircleButton(Icons.menu, () => Scaffold.of(context).openDrawer()))),
          DraggableScrollableSheet(
            initialChildSize: tripState.isTripStarted ? 0.25 : 0.6,
            minChildSize: 0.1,
            maxChildSize: 0.9,
            builder: (context, scrollController) => Container(
              decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32)), boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20)]),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                children: [
                  Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
                  const SizedBox(height: 16),
                  if (!tripState.isTripStarted) _buildConfigUI(tripState) else _buildActiveTripStatus(tripState),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity, height: 56,
                    child: ElevatedButton(
                      onPressed: _onToggle,
                      style: ElevatedButton.styleFrom(backgroundColor: tripState.isTripStarted ? Colors.red : AppColors.primaryNavy, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                      child: Text(tripState.isTripStarted ? "TERMINATE TRIP" : "COMMENCE TRACKING", style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
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

  LatLng _getHubPos(String name) {
    final map = {'Baghdad Campus': const LatLng(29.3794, 71.6707), 'Abbasia Campus': const LatLng(29.3837, 71.6749), 'Railway Campus': const LatLng(29.3892, 71.6851)};
    return map[name] ?? const LatLng(29.3794, 71.6707);
  }

  Widget _buildBusMarker(double heading) {
    return Column(children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: AppColors.primaryNavy, borderRadius: BorderRadius.circular(8)), child: const Text("MY BUS", style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold))),
        Transform.rotate(angle: (heading * (3.14159 / 180)), child: const Icon(Icons.navigation_rounded, color: AppColors.primaryYellow, size: 45)),
    ]);
  }

  Widget _buildDestinationMarker() {
    return AnimatedBuilder(animation: _pulseController, builder: (context, child) => Stack(alignment: Alignment.center, children: [
          Container(width: 20 + (20 * _pulseController.value), height: 20 + (20 * _pulseController.value), decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.red.withValues(alpha: 1 - _pulseController.value))),
          const Icon(Icons.flag_rounded, color: Colors.red, size: 40),
        ]));
  }

  Widget _buildNavigationBanner(DriverTripState state) {
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.primaryNavy, borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 15)]),
      child: Row(children: [
          const CircleAvatar(backgroundColor: AppColors.primaryYellow, child: Icon(Icons.directions_rounded, color: AppColors.primaryNavy)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("NAVIGATING TO ${state.to?.toUpperCase()}", style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold)),
                Row(children: [
                    Text(state.remainingDistance, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(width: 8), const Text("•", style: TextStyle(color: Colors.white24)), const SizedBox(width: 8),
                    Text(state.remainingTime, style: const TextStyle(color: AppColors.primaryYellow, fontWeight: FontWeight.bold, fontSize: 18)),
                ]),
          ])),
      ]));
  }

  Widget _buildCircleButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(onTap: onTap, child: Container(padding: const EdgeInsets.all(12), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]), child: Icon(icon, color: AppColors.primaryNavy, size: 24)));
  }

  Widget _buildConfigUI(DriverTripState state) {
    return Column(children: [
        Text("READY TO DEPART", style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryNavy, letterSpacing: 1.5)),
        const SizedBox(height: 16),
        TextField(controller: _busNumberController, decoration: InputDecoration(hintText: "Bus ID", prefixIcon: const Icon(Icons.numbers, size: 20), filled: true, fillColor: Colors.grey[50], border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none))),
        const SizedBox(height: 12),
        TextField(controller: _plateNumberController, decoration: InputDecoration(hintText: "Plate Number", prefixIcon: const Icon(Icons.credit_card, size: 20), filled: true, fillColor: Colors.grey[50], border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none))),
        const SizedBox(height: 16),
        _buildGenderSelector(state),
        const SizedBox(height: 16),
        _buildRoutePicker("Beginning Hub", state.from, (v) => ref.read(driverTripProvider.notifier).updateInputs(from: v)),
        const SizedBox(height: 12),
        _buildRoutePicker("Destination Hub", state.to, (v) => ref.read(driverTripProvider.notifier).updateInputs(to: v)),
    ]);
  }

  Widget _buildGenderSelector(DriverTripState state) {
    return SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: ["Girls", "Boys", "Combined"].map((g) {
          bool isSelected = state.gender == g;
          return GestureDetector(onTap: () => ref.read(driverTripProvider.notifier).updateInputs(gender: g), child: Container(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), margin: const EdgeInsets.only(right: 8), decoration: BoxDecoration(color: isSelected ? AppColors.primaryYellow : Colors.grey[50], borderRadius: BorderRadius.circular(16), border: Border.all(color: isSelected ? AppColors.primaryYellow : Colors.grey[200]!)), child: Text(g, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSelected ? AppColors.primaryNavy : Colors.blueGrey))));
        }).toList()));
  }

  Widget _buildActiveTripStatus(DriverTripState state) {
    return Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: AppColors.primaryNavy, borderRadius: BorderRadius.circular(24)),
      child: Column(children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(state.plateNumber, style: const TextStyle(color: AppColors.primaryYellow, fontSize: 10, fontWeight: FontWeight.bold)),
                Text("${state.from} ➔ ${state.to}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          ])),
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(8)), child: Text("ID: ${state.busNumber}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
        ]),
        const Divider(color: Colors.white24, height: 24),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_buildActiveInfo("DISTANCE", state.remainingDistance), _buildActiveInfo("ETA", state.remainingTime), _buildActiveInfo("TRACKING", "LIVE")]),
      ]),
    );
  }

  Widget _buildActiveInfo(String label, String value) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 8, fontWeight: FontWeight.bold)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
    ]);
  }

  Widget _buildRoutePicker(String label, String? value, Function(String?) onChanged) {
    final hubs = ['Baghdad Campus', 'Abbasia Campus', 'Railway Campus'];
    return DropdownButtonFormField<String>(isExpanded: true, value: value, hint: Text(label, style: const TextStyle(fontSize: 12)), decoration: InputDecoration(filled: true, fillColor: Colors.grey[50], border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
      items: hubs.map((h) => DropdownMenuItem(value: h, child: Text(h, style: const TextStyle(fontSize: 12)))).toList(),
      onChanged: onChanged,
    );
  }
}
