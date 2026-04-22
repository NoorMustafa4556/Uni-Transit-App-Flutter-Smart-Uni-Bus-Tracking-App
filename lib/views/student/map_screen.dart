import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:uni_transit/core/constants/app_colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uni_transit/services/sos_service.dart';
import 'package:uni_transit/services/location_service.dart';
import 'package:uni_transit/services/notification_service.dart';
import 'package:uni_transit/core/constants/campus_locations.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> with TickerProviderStateMixin {
  final LatLng _defaultLocation = CampusLocations.baghdadCampus;
  LatLng _userLocation = CampusLocations.baghdadCampus;
  bool _hasUserLocation = false;
  final Set<String> _notifiedBuses = {};

  final MapController _mapController = MapController();
  final DatabaseReference _busesRef = FirebaseDatabase.instance.ref('buses');

  Map<String, dynamic> _liveBusData = {};
  final Map<String, LatLng> _animatedPositions = {};
  final Map<String, double> _busHeadings = {};

  String? _fromHub;
  String? _toHub;
  List<LatLng> _routePoints = [];
  String? _selectedRoute;
  String _selectedGender = "All";

  final Map<String, LatLng> _hubs = {
    'Baghdad Campus': CampusLocations.baghdadCampus,
    'Abbasia Campus': CampusLocations.abbasiaCampus,
    'Railway Campus': CampusLocations.railwayCampus,
  };

  // Detailed Real Road Path (Bahawalpur University Road)
  final List<LatLng> _universityRoadPath = [
    CampusLocations.baghdadCampus,
    const LatLng(29.3750, 71.7700),
    const LatLng(29.3780, 71.7620),
    const LatLng(29.3800, 71.7580),
    const LatLng(29.3815, 71.7500), // One Unit Chowk Area
    const LatLng(29.3830, 71.7400),
    const LatLng(29.3850, 71.7300),
    const LatLng(29.3880, 71.7150),
    const LatLng(29.3900, 71.7050), // Dera Adda
    const LatLng(29.3898, 71.6980),
    CampusLocations.abbasiaCampus,
  ];

  final List<LatLng> _railwayRoadPath = [
    CampusLocations.baghdadCampus,
    const LatLng(29.3750, 71.7700),
    const LatLng(29.3780, 71.7620),
    const LatLng(29.3815, 71.7500),
    const LatLng(29.3880, 71.7150),
    const LatLng(29.3920, 71.7080), // Fawara Chowk
    const LatLng(29.3950, 71.7020),
    CampusLocations.railwayCampus,
  ];

  Map<String, dynamic> _firebaseRoutes = {};

  @override
  void initState() {
    super.initState();
    _loadDefaultRoutes();
    _listenToBusLocations();
    _listenToOfficialRoutes();
    _getCurrentLocation();
  }

  void _loadDefaultRoutes() {
    _firebaseRoutes = {
      "Baghdad ➔ Abbasia": {"from": "Baghdad Campus", "to": "Abbasia Campus"},
      "Abbasia ➔ Baghdad": {"from": "Abbasia Campus", "to": "Baghdad Campus"},
      "Baghdad ➔ Railway": {"from": "Baghdad Campus", "to": "Railway Campus"},
      "Railway ➔ Baghdad": {"from": "Railway Campus", "to": "Baghdad Campus"},
    };
  }

  void _listenToBusLocations() {
    _busesRef.onValue.listen((event) {
      if (event.snapshot.value != null && mounted) {
        final rawData = Map<String, dynamic>.from(event.snapshot.value as Map);
        setState(() { _liveBusData = rawData; });
        _animateBusMarkers(rawData);
        _checkProximity(rawData);
      }
    });
  }

  void _checkProximity(Map<String, dynamic> buses) {
    if (!_hasUserLocation || _toHub == null) return;
    buses.forEach((id, data) {
      if (data['to'] != _toHub) return;
      final busPos = LatLng(data['latitude'], data['longitude']);
      final distance = const Distance().as(LengthUnit.Meter, _userLocation, busPos);
      if (distance < 1000 && !_notifiedBuses.contains(id)) {
        _notifiedBuses.add(id);
        NotificationService.show(title: "Bus Approaching", message: "Bus #$id is within 1 KM!", type: NotificationType.proximity);
      }
    });
  }

  void _animateBusMarkers(Map<String, dynamic> newData) {
    newData.forEach((id, data) {
      if (data['latitude'] == null || data['longitude'] == null) return;
      final targetPos = LatLng(data['latitude'] as double, data['longitude'] as double);
      final currentPos = _animatedPositions[id] ?? targetPos;
      final targetHeading = (data['heading'] ?? 0.0).toDouble();
      final controller = AnimationController(vsync: this, duration: const Duration(seconds: 1));
      final latTween = Tween<double>(begin: currentPos.latitude, end: targetPos.latitude);
      final lngTween = Tween<double>(begin: currentPos.longitude, end: targetPos.longitude);
      final headTween = Tween<double>(begin: _busHeadings[id] ?? targetHeading, end: targetHeading);

      controller.addListener(() {
        if (mounted) setState(() { _animatedPositions[id] = LatLng(latTween.evaluate(controller), lngTween.evaluate(controller)); _busHeadings[id] = headTween.evaluate(controller); });
      });
      controller.forward().then((_) => controller.dispose());
    });
  }

  void _listenToOfficialRoutes() {
    FirebaseDatabase.instance.ref('official_routes').onValue.listen((event) {
      if (mounted && event.snapshot.value != null) setState(() { _firebaseRoutes = Map<String, dynamic>.from(event.snapshot.value as Map); });
    });
  }

  List<Marker> _getMarkers() {
    final List<Marker> markers = [];
    _liveBusData.forEach((id, data) {
      final gender = data['gender'] ?? 'Combined';
      bool matchesRoute = true;
      if (_fromHub != null && data['from'] != _fromHub) matchesRoute = false;
      if (_toHub != null && data['to'] != _toHub) matchesRoute = false;
      if (!matchesRoute) return;
      if (_selectedGender != "All" && gender != _selectedGender) return;

      if (data['latitude'] == null || data['longitude'] == null) return;
      final pos = _animatedPositions[id] ?? LatLng(data['latitude'] as double, data['longitude'] as double);
      final heading = _busHeadings[id] ?? 0.0;
      final driverName = data['driverName'] ?? "Driver";
      Color markerColor = (gender == 'Girls') ? Colors.pinkAccent : (gender == 'Boys' ? Colors.blueAccent : AppColors.primaryNavy);

      markers.add(Marker(
        width: 100, height: 120, point: pos,
        child: GestureDetector(
          onTap: () => _showBusDetails(id, Map<String, dynamic>.from(data)),
          child: Column(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)]),
              child: const Text("~12 MIN", style: TextStyle(color: Colors.black, fontSize: 7, fontWeight: FontWeight.bold))),
            const SizedBox(height: 2),
            Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: markerColor, width: 1)), child: Text(driverName, style: GoogleFonts.poppins(color: markerColor, fontSize: 8, fontWeight: FontWeight.bold))),
            Transform.rotate(angle: (heading * (3.14159 / 180)), child: Stack(alignment: Alignment.center, children: [Icon(Icons.location_on_rounded, color: markerColor, size: 48), const Positioned(top: 8, child: Icon(Icons.directions_bus_rounded, color: Colors.white, size: 18))])),
          ]),
        ),
      ));
    });
    return markers;
  }

  void _calculateRoutePoints(String routeName, Map data) {
    final from = data['from'] as String? ?? "Baghdad Campus";
    final to = data['to'] as String? ?? "Abbasia Campus";
    setState(() { 
      _selectedRoute = routeName; 
      _fromHub = from; 
      _toHub = to;
      if (routeName.contains("Railway")) {
        _routePoints = routeName.startsWith("Railway") ? _railwayRoadPath.reversed.toList() : _railwayRoadPath;
      } else {
        _routePoints = routeName.startsWith("Abbasia") ? _universityRoadPath.reversed.toList() : _universityRoadPath;
      }
      _notifiedBuses.clear(); 
    });
    _mapController.move(_routePoints[_routePoints.length ~/ 2], 14);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController, options: MapOptions(initialCenter: _defaultLocation, initialZoom: 14),
            children: [
              TileLayer(urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png', subdomains: const ['a', 'b', 'c', 'd']),
              if (_routePoints.isNotEmpty) PolylineLayer(polylines: <Polyline>[
                Polyline(
                  points: _routePoints, 
                  color: AppColors.primaryYellow.withValues(alpha: 0.8), 
                  strokeWidth: 5.0, 
                  borderStrokeWidth: 2.0,
                  borderColor: AppColors.primaryNavy.withValues(alpha: 0.2),
                )
              ]),
              MarkerLayer(markers: _hubs.entries.map((hub) => Marker(point: hub.value, width: 60, height: 60, child: Icon(Icons.location_on_rounded, color: hub.key == _toHub ? Colors.red : (hub.key == _fromHub ? Colors.green : Colors.grey[400]), size: 38))).toList()),
              MarkerLayer(markers: _getMarkers()),
              if (_hasUserLocation) MarkerLayer(markers: [Marker(point: _userLocation, child: Container(decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.2), shape: BoxShape.circle), padding: const EdgeInsets.all(4), child: const Icon(Icons.my_location, color: Colors.blue, size: 20)))]),
            ],
          ),
          Positioned(top: 40, left: 20, right: 20, child: Column(children: [
                Container(height: 60, padding: const EdgeInsets.symmetric(horizontal: 16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 20)]),
                  child: Row(children: [
                      const Icon(Icons.map_rounded, color: AppColors.primaryYellow), const SizedBox(width: 12),
                      Expanded(child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: _selectedRoute, isExpanded: true, hint: const Text("Select Route"), items: _firebaseRoutes.keys.map((r) => DropdownMenuItem(value: r, child: Text(r, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryNavy)))).toList(), onChanged: (v) { if (v != null) _calculateRoutePoints(v, _firebaseRoutes[v]); }))),
                      if (_selectedRoute != null) IconButton(onPressed: () => setState(() { _selectedRoute = null; _fromHub = null; _toHub = null; _routePoints = []; }), icon: const Icon(Icons.close_rounded)),
                  ])),
                const SizedBox(height: 12),
                _buildGenderFilterBar(),
          ])),
          Positioned(right: 20, bottom: 110, child: Column(children: [
                _buildMapControlButton(icon: Icons.emergency_rounded, color: Colors.red, iconColor: Colors.white, onPressed: _handleSOS),
                _buildMapControlButton(icon: Icons.my_location, color: AppColors.primaryYellow, onPressed: _getCurrentLocation),
          ])),
        ],
      ),
    );
  }

  void _showBusDetails(String id, Map<String, dynamic> data) async {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, builder: (context) => Container(margin: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(32)),
        child: ClipRRect(borderRadius: BorderRadius.circular(32), child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [CircleAvatar(radius: 25, backgroundColor: AppColors.primaryYellow.withValues(alpha: 0.2), child: const Icon(Icons.bus_alert, color: AppColors.primaryNavy, size: 30)), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(data['driverName'] ?? "Driver", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), Text("BUS #$id • ${data['plateNumber']}", style: const TextStyle(fontSize: 12, color: Colors.blueGrey))])), IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))]),
          const SizedBox(height: 24), Row(children: [Expanded(child: _buildGlassInfoBox(Icons.timer_rounded, "ETA", "12 MINS", AppColors.primaryNavy)), const SizedBox(width: 12), Expanded(child: _buildGlassInfoBox(Icons.people_alt_rounded, "GENDER", (data['gender'] ?? "Combined").toUpperCase(), AppColors.primaryYellow))]),
          const SizedBox(height: 12), _buildDetailTile(Icons.alt_route_rounded, "FROM ➔ TO", "${data['from']} to ${data['to']}"),
        ]))))));
  }

  Widget _buildGlassInfoBox(IconData icon, String label, String value, Color color) {
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withValues(alpha: 0.2))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(color: color.withValues(alpha: 0.6), fontSize: 9, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Row(children: [Icon(icon, color: color, size: 16), const SizedBox(width: 6), Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13))])]));
  }

  Widget _buildDetailTile(IconData icon, String label, String value) {
     return Container(margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(20)), child: Row(children: [Icon(icon, color: AppColors.primaryNavy), const SizedBox(width: 16), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey)), Text(value, style: const TextStyle(fontWeight: FontWeight.bold))])]));
  }

  Widget _buildGenderFilterBar() {
    return Container(height: 48, padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)]),
      child: Row(mainAxisSize: MainAxisSize.min, children: ["All", "Girls", "Boys", "Combined"].map((g) {
          bool isSelected = _selectedGender == g;
          Color activeColor = (g == "Girls") ? Colors.pinkAccent : (g == "Boys" ? Colors.blueAccent : (g == "Combined" ? AppColors.primaryNavy : AppColors.primaryYellow));
          return GestureDetector(onTap: () => setState(() { _selectedGender = g; }), child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), margin: const EdgeInsets.symmetric(horizontal: 2), decoration: BoxDecoration(color: isSelected ? activeColor : Colors.transparent, borderRadius: BorderRadius.circular(20)), child: Text(g, style: GoogleFonts.poppins(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, color: isSelected ? Colors.white : Colors.grey[600]))));
        }).toList()));
  }

  Future<void> _getCurrentLocation() async {
    final hasPermission = await LocationService.handleLocationPermission();
    if (!hasPermission) return;
    try {
      final position = await Geolocator.getCurrentPosition();
      if (mounted) setState(() { _userLocation = LatLng(position.latitude, position.longitude); _hasUserLocation = true; _mapController.move(_userLocation, 14); });
    } catch (e) {}
  }

  void _handleSOS() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await SOSService().sendSOS(userId: user.uid, userName: user.displayName ?? "Student", lat: _userLocation.latitude, lng: _userLocation.longitude, message: "Help!");
      NotificationService.show(title: "SOS Triggered", message: "Emergency alert sent to university admin.", type: NotificationType.error);
    }
  }

  Widget _buildMapControlButton({required IconData icon, required VoidCallback onPressed, Color? color, Color? iconColor}) {
    return Container(width: 54, height: 54, margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: color ?? Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)]), child: IconButton(onPressed: onPressed, icon: Icon(icon, color: iconColor ?? AppColors.primaryNavy)));
  }
}
