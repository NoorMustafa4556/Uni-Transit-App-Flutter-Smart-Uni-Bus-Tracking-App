import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
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
import 'package:uni_transit/models/eta_info.dart';
import 'package:uni_transit/services/trip_alert_service.dart';
import 'package:uni_transit/core/constants/custom_routes.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen>
    with TickerProviderStateMixin {
  final LatLng _defaultLocation = CampusLocations.baghdadCampus;
  LatLng _userLocation = CampusLocations.baghdadCampus;
  bool _hasUserLocation = false;
  final Set<String> _notifiedBuses = {};

  final MapController _mapController = MapController();
  final DatabaseReference _busesRef = FirebaseDatabase.instance.ref('buses');

  Map<String, dynamic> _liveBusData = {};
  final Map<String, LatLng> _animatedPositions = {};
  final Map<String, double> _busHeadings = {};
  // Cache of computed ETAs per bus
  final Map<String, EtaInfo> _busEtas = {};

  // Performance: Track subscriptions and animation controllers for proper cleanup
  StreamSubscription? _busesSubscription;
  StreamSubscription? _routesSubscription;
  StreamSubscription? _tripAlertsSubscription;
  final Map<String, AnimationController> _busAnimControllers = {};
  DateTime _lastEtaUpdate = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastFleetFit = DateTime.fromMillisecondsSinceEpoch(0);

  String? _fromHub;
  String? _toHub;
  List<LatLng> _routePoints = [];
  String? _selectedRoute;
  String _selectedGender = "All";

  final Map<String, LatLng> _hubs = {
    CampusLocations.baghdadName: CampusLocations.baghdadCampus,
    CampusLocations.abbasiaName: CampusLocations.abbasiaCampus,
  };

  Map<String, dynamic> _firebaseRoutes = {};

  StreamSubscription? _stopsSubscription;
  StreamSubscription? _customPolylinesSubscription;
  Map<String, dynamic> _stopsData = {};
  Map<String, List<LatLng>> _manualFirebaseRoutes = {};

  @override
  void initState() {
    super.initState();
    _loadDefaultRoutes();
    _listenToBusLocations();
    _listenToOfficialRoutes();
    _listenToStops(); // ⚡ NEW: Listen to dynamic stops from backend
    _listenToTripAlerts(); // ⚡ NEW: Professional Trip Start Notifications
    _listenToCustomPolylines(); // ⚡ NEW: Live sync for custom road paths
    _getCurrentLocation();
  }

  @override
  void dispose() {
    // Performance: Cancel all subscriptions to prevent memory leaks
    _busesSubscription?.cancel();
    _routesSubscription?.cancel();
    _tripAlertsSubscription?.cancel();
    _stopsSubscription?.cancel();
    _customPolylinesSubscription?.cancel();
    // Dispose all cached animation controllers
    for (final controller in _busAnimControllers.values) {
      controller.dispose();
    }
    _busAnimControllers.clear();
    super.dispose();
  }

  void _fitAllBuses() {
    if (_liveBusData.isEmpty) return;

    List<LatLng> points = [];
    _liveBusData.forEach((id, data) {
      if (data['latitude'] != null && data['longitude'] != null) {
        points.add(
          LatLng(
            (data['latitude'] as num).toDouble(),
            (data['longitude'] as num).toDouble(),
          ),
        );
      }
    });

    if (points.isEmpty) return;

    final bounds = LatLngBounds.fromPoints(points);
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(100)),
    );
  }

  void _centerOnSelectedBus() {
    if (_selectedRoute == null) return;

    // Find the bus that matches the selected route
    String? trackingBusId;
    _liveBusData.forEach((id, data) {
      if (data['from'] == _fromHub && data['to'] == _toHub) {
        trackingBusId = id;
      }
    });

    if (trackingBusId != null) {
      final busPos =
          _animatedPositions[trackingBusId] ??
          LatLng(
            (_liveBusData[trackingBusId]['latitude'] as num).toDouble(),
            (_liveBusData[trackingBusId]['longitude'] as num).toDouble(),
          );

      // Smoothly pan to the bus position
      _mapController.move(busPos, _mapController.camera.zoom);
    }
  }

  void _listenToStops() {
    _stopsSubscription = FirebaseDatabase.instance.ref('stops').onValue.listen((
      event,
    ) {
      if (event.snapshot.value != null && mounted) {
        setState(() {
          _stopsData = Map<String, dynamic>.from(event.snapshot.value as Map);
        });
      } else if (mounted) {
        // Fallback: Default stops if backend is empty
        setState(() {
          _stopsData = {
            "default_stop_1": {
              "name": "One Uni Point",
              "latitude": 29.3850,
              "longitude": 71.7350,
              "route": "Baghdad ➔ Abbasia",
            },
          };
        });
      }
    });
  }

  void _listenToTripAlerts() {
    _tripAlertsSubscription = TripAlertService().alertStream.listen((data) {
      if (data.isNotEmpty && mounted) {
        final busId = data['busId'] ?? "---";
        final from = data['from'] ?? "---";
        final to = data['to'] ?? "---";

        NotificationService.show(
          title: "New Trip Started! 🚌",
          message: "Bus #$busId is departing from $from heading to $to.",
          type: NotificationType.info,
        );

        // ⚡ SYSTEM NOTIFICATION: Professional alert even if user is not looking at map
        NotificationService.showLocalNotification(
          title: "Bus Departure: #$busId",
          body: "Departing from $from to $to.",
          id: busId.hashCode, // Unique ID per bus to prevent overwriting
        );
      }
    });
  }

  List<Marker> _getStopMarkers() {
    if (_selectedRoute == null) return [];

    final List<Marker> markers = [];
    _stopsData.forEach((id, data) {
      final stopRoute = data['route'] as String? ?? "";
      // Only show stops for the selected route
      if (stopRoute != _selectedRoute) return;

      final lat = (data['latitude'] as num).toDouble();
      final lng = (data['longitude'] as num).toDouble();
      final name = data['name'] as String? ?? "Stop";

      markers.add(
        Marker(
          width: 100,
          height: 60,
          point: LatLng(lat, lng),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 4),
                  ],
                  border: Border.all(
                    color: AppColors.primaryNavy.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  name,
                  style: GoogleFonts.poppins(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryNavy,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(
                Icons.radio_button_checked_rounded,
                color: AppColors.primaryNavy,
                size: 16,
              ),
            ],
          ),
        ),
      );
    });
    return markers;
  }

  void _loadDefaultRoutes() {
    _firebaseRoutes = {
      "Abbasia ➔ Baghdad": {
        "from": CampusLocations.abbasiaName,
        "to": CampusLocations.baghdadName,
      },
    };
  }

  void _listenToBusLocations() {
    _busesSubscription = _busesRef.onValue.listen((event) {
      if (event.snapshot.value != null && mounted) {
        final rawData = Map<String, dynamic>.from(event.snapshot.value as Map);
        setState(() {
          _liveBusData = rawData;
        });
        _animateBusMarkers(rawData);

        // ⚡ NEW: Smart Auto-follow (Less aggressive)
        if (_selectedRoute == null && _liveBusData.isNotEmpty) {
          // Only fit all buses once at the beginning, don't keep jumping
          if (_lastFleetFit == DateTime.fromMillisecondsSinceEpoch(0)) {
            _lastFleetFit = DateTime.now();
            _fitAllBuses();
          }
        } else if (_selectedRoute != null && _liveBusData.isNotEmpty) {
          // Only center if it's been a few seconds since last move to prevent jitter
          final now = DateTime.now();
          if (now.difference(_lastFleetFit).inSeconds >= 3) {
            _lastFleetFit = now;
            _centerOnSelectedBus();
          }
        }

        final now = DateTime.now();
        if (now.difference(_lastEtaUpdate).inSeconds >= 5) {
          _lastEtaUpdate = now;
          _updateBusEtas(rawData);
        }
        _checkProximity(rawData);
      } else if (mounted) {
        setState(() {
          _liveBusData = {};
        });
      }
    });
  }

  /// Compute dynamic ETA for each bus based on its position and destination.
  void _updateBusEtas(Map<String, dynamic> buses) {
    buses.forEach((id, data) {
      if (data['latitude'] == null || data['longitude'] == null) return;
      final busPos = LatLng(
        (data['latitude'] as num).toDouble(),
        (data['longitude'] as num).toDouble(),
      );
      final destName = data['to'] as String?;
      if (destName == null) return;
      final destPos = _hubs[destName];
      if (destPos == null) return;

      // Only recalculate if bus has a valid position
      if (busPos.latitude != 0.0 || busPos.longitude != 0.0) {
        _busEtas[id] = EtaInfo.estimateFromCoordinates(busPos, destPos);
      }
    });
  }

  void _checkProximity(Map<String, dynamic> buses) {
    if (!_hasUserLocation || _toHub == null) return;
    buses.forEach((id, data) {
      if (data['to'] != _toHub) return;
      if (data['latitude'] == null || data['longitude'] == null) return;
      final busPos = LatLng(
        (data['latitude'] as num).toDouble(),
        (data['longitude'] as num).toDouble(),
      );
      final distance = const Distance().as(
        LengthUnit.Meter,
        _userLocation,
        busPos,
      );
      if (distance < 1000 && !_notifiedBuses.contains(id)) {
        _notifiedBuses.add(id);
        NotificationService.show(
          title: "Bus Approaching",
          message: "Bus #$id is within 1 KM!",
          type: NotificationType.proximity,
        );
      }
    });
  }

  void _animateBusMarkers(Map<String, dynamic> newData) {
    newData.forEach((id, data) {
      if (data['latitude'] == null || data['longitude'] == null) return;
      final targetPos = LatLng(
        (data['latitude'] as num).toDouble(),
        (data['longitude'] as num).toDouble(),
      );
      final currentPos = _animatedPositions[id] ?? targetPos;
      final targetHeading = (data['heading'] ?? 0.0).toDouble();

      // Performance: Dispose old controller before creating new one
      _busAnimControllers[id]?.dispose();

      // ⚡ SPEED & UX OPT: 2-second duration for smooth vehicular feel
      final controller = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 2),
      );
      _busAnimControllers[id] = controller;

      final animation = CurvedAnimation(
        parent: controller,
        curve: Curves.easeInOut,
      );

      final latTween = Tween<double>(
        begin: currentPos.latitude,
        end: targetPos.latitude,
      );
      final lngTween = Tween<double>(
        begin: currentPos.longitude,
        end: targetPos.longitude,
      );
      final headTween = Tween<double>(
        begin: _busHeadings[id] ?? targetHeading,
        end: targetHeading,
      );

      controller.addListener(() {
        if (mounted) {
          setState(() {
            _animatedPositions[id] = LatLng(
              latTween.evaluate(animation),
              lngTween.evaluate(animation),
            );
            _busHeadings[id] = headTween.evaluate(animation);
          });
        }
      });
      controller.forward();
    });
  }

  void _listenToOfficialRoutes() {
    _routesSubscription = FirebaseDatabase.instance
        .ref('official_routes')
        .onValue
        .listen((event) {
          if (mounted && event.snapshot.value != null) {
            final rawData = Map<String, dynamic>.from(
              event.snapshot.value as Map,
            );
            // ⚡ FILTER: ONLY show Abbasia ➔ Baghdad
            final filteredData = <String, dynamic>{};
            rawData.forEach((key, value) {
              if (key == "Abbasia ➔ Baghdad") {
                filteredData[key] = value;
              }
            });
            setState(() {
              _firebaseRoutes =
                  filteredData.isNotEmpty ? filteredData : _firebaseRoutes;
            });
          }
        });
  }

  void _listenToCustomPolylines() {
    _customPolylinesSubscription = FirebaseDatabase.instance
        .ref('custom_polylines')
        .onValue
        .listen((event) {
          if (event.snapshot.value != null && mounted) {
            final data = Map<String, dynamic>.from(event.snapshot.value as Map);
            final Map<String, List<LatLng>> newRoutes = {};

            data.forEach((routeName, points) {
              if (points is List) {
                newRoutes[routeName] =
                    points.map((p) {
                      final point = Map<String, dynamic>.from(p as Map);
                      return LatLng(
                        (point['lat'] as num).toDouble(),
                        (point['lng'] as num).toDouble(),
                      );
                    }).toList();
              }
            });

            setState(() {
              _manualFirebaseRoutes = newRoutes;
            });
            debugPrint(
              "Synced ${_manualFirebaseRoutes.length} custom polylines from Firebase",
            );
          }
        });
  }

  List<Marker> _getMarkers() {
    final List<Marker> markers = [];

    _liveBusData.forEach((id, data) {
      // ⚡ SMART FILTERING: If a route is selected, filter. Otherwise show all active buses.
      if (_selectedRoute != null) {
        final busFrom = (data['from'] as String? ?? '').toLowerCase().trim();
        final busTo = (data['to'] as String? ?? '').toLowerCase().trim();
        final selFrom = (_fromHub ?? '').toLowerCase().trim();
        final selTo = (_toHub ?? '').toLowerCase().trim();

        // Strict matching: Check if the hub names match exactly or contain each other
        bool fromMatches =
            busFrom.contains(selFrom) || selFrom.contains(busFrom);
        bool toMatches = busTo.contains(selTo) || selTo.contains(busTo);

        if (!(fromMatches && toMatches)) return;
      }

      final gender = data['gender'] ?? 'Combined';
      if (_selectedGender != "All" && gender != _selectedGender) return;

      final lat = (data['latitude'] as num?)?.toDouble() ?? 0.0;
      final lng = (data['longitude'] as num?)?.toDouble() ?? 0.0;

      // ⚡ CRITICAL: Ignore invalid or non-started coordinates
      if (lat == 0.0 || lng == 0.0) return;

      final pos = _animatedPositions[id] ?? LatLng(lat, lng);

      final heading = _busHeadings[id] ?? 0.0;
      Color markerColor =
          (gender == 'Girls')
              ? Colors.pinkAccent
              : (gender == 'Boys' ? Colors.blueAccent : AppColors.primaryNavy);

      final etaInfo = _busEtas[id];
      // ⚡ REAL-TIME: Use driver-pushed ETA if available, otherwise fallback to local estimate
      final etaText =
          data['remainingTime'] != null &&
                  (data['remainingTime'] as String).isNotEmpty
              ? data['remainingTime']
              : (etaInfo != null ? etaInfo.etaMarkerDisplay : "---");

      markers.add(
        Marker(
          width: 80,
          height: 80,
          point: pos,
          child: RepaintBoundary(
            // ⚡ PERFORMANCE: Isolate marker painting
            child: GestureDetector(
              onTap: () => _showBusDetails(id, Map<String, dynamic>.from(data)),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // ⚡ PROFESSIONAL: Pulsing background to show "Live" status
                  _buildPulseEffect(markerColor),

                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Floating ETA Tag
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: markerColor,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: markerColor.withValues(alpha: 0.3),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Text(
                          etaText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Professional Circular Bus Icon with Direction
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: markerColor, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 15,
                              backgroundColor: markerColor.withValues(
                                alpha: 0.1,
                              ),
                              child: Icon(
                                Icons.directions_bus_rounded,
                                color: markerColor,
                                size: 18,
                              ),
                            ),
                          ),
                          // Directional Arrow
                          Transform.rotate(
                            angle: (heading * (3.14159 / 180)),
                            child: SizedBox(
                              width: 42,
                              height: 42,
                              child: Stack(
                                children: [
                                  Positioned(
                                    top: 0,
                                    left: 0,
                                    right: 0,
                                    child: Icon(
                                      Icons.navigation_rounded,
                                      color: markerColor,
                                      size: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
    return markers;
  }

  Widget _buildPulseEffect(Color color) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0.5, end: 1.0),
      duration: const Duration(seconds: 2),
      curve: Curves.easeInOut,
      builder: (context, double value, child) {
        return Container(
          width: 50 * value,
          height: 50 * value,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 1.0 - value),
          ),
        );
      },
      onEnd:
          () {}, // Handled by repeating via a real controller if needed, but this works for basic pulse
    );
  }

  // ⚡ PROFESSIONAL: Custom Student Location Marker (Widget-based for crisp rendering)
  Widget _buildUserLocationMarker() {
    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Stack(
          alignment: Alignment.center,
          children: [
            _buildPulseEffect(AppColors.primaryYellow),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primaryNavy, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryYellow.withValues(alpha: 0.5),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
                CustomPaint(
                  size: const Size(8, 4),
                  painter: _MarkerPointerPainter(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ⚡ PROFESSIONAL: Custom Hub Marker (Start/Destination)
  Widget _buildHubMarker(String name, Color color, bool isDestination) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Floating Label Tag
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            name.split(' ')[0], // Short name
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 4),
        // Pin with Glow/Pulse if it's the start
        Stack(
          alignment: Alignment.center,
          children: [
            if (!isDestination && color != Colors.grey[400])
              _buildPulseEffect(color),
            Icon(Icons.location_on_rounded, color: color, size: 38),
            const Positioned(
              top: 8,
              child: Icon(Icons.circle, color: Colors.white, size: 10),
            ),
          ],
        ),
      ],
    );
  }

  bool _isFetchingRoute = false;

  Future<void> _fetchRoadPath(LatLng start, LatLng end) async {
    setState(() => _isFetchingRoute = true);
    final url =
        'https://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List coordinates = data['routes'][0]['geometry']['coordinates'];
        setState(() {
          _routePoints = coordinates.map((c) => LatLng(c[1], c[0])).toList();
        });
      }
    } catch (e) {
      debugPrint("Error fetching road path: $e");
      // Fallback to straight line if API fails
      setState(() {
        _routePoints = [start, end];
      });
    } finally {
      if (mounted) setState(() => _isFetchingRoute = false);
    }
  }

  void _calculateRoutePoints(String routeName, Map data) async {
    final from = data['from'] as String? ?? CampusLocations.baghdadName;
    final to = data['to'] as String? ?? CampusLocations.abbasiaName;

    final startPos = _hubs[from] ?? CampusLocations.baghdadCampus;
    final endPos = _hubs[to] ?? CampusLocations.abbasiaCampus;

    setState(() {
      _selectedRoute = routeName;
      _fromHub = from;
      _toHub = to;
      _notifiedBuses.clear();
      _routePoints = []; // Reset points
    });

    // ⚡ NEW: Prioritize Firebase Manual Routes -> Then Local Custom Routes
    final firebasePoints = _manualFirebaseRoutes[routeName];
    final localPoints = CustomRoutes.getRoutePoints(routeName);

    if (firebasePoints != null && firebasePoints.isNotEmpty) {
      debugPrint("Using Firebase Manual Route for: $routeName");
      setState(() {
        _routePoints = firebasePoints;
      });
    } else if (localPoints.isNotEmpty && localPoints.length > 2) {
      debugPrint("Using Local GIS Route for: $routeName");
      setState(() {
        _routePoints = localPoints;
      });
    } else {
      // ⚡ DISABLED OSRM: As per user request, don't show auto-generated routes
      debugPrint(
        "No professional route found for $routeName. Waiting for manual drawing.",
      );
      setState(() {
        _routePoints = [];
      });
    }

    if (_routePoints.isNotEmpty) {
      // ⚡ ANIMATED: Smoothly glide to the START of the professional route
      _animatedMapMove(_routePoints[0], 14.5);
    }
  }

  /// ⚡ PROFESSIONAL: Smoothly glides the map to a target location
  void _animatedMapMove(LatLng destLocation, double destZoom) {
    final latTween = Tween<double>(
      begin: _mapController.camera.center.latitude,
      end: destLocation.latitude,
    );
    final lngTween = Tween<double>(
      begin: _mapController.camera.center.longitude,
      end: destLocation.longitude,
    );
    final zoomTween = Tween<double>(
      begin: _mapController.camera.zoom,
      end: destZoom,
    );

    final controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    final animation = CurvedAnimation(
      parent: controller,
      curve: Curves.fastOutSlowIn,
    );

    controller.addListener(() {
      _mapController.move(
        LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
        zoomTween.evaluate(animation),
      );
    });

    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        controller.dispose();
      } else if (status == AnimationStatus.dismissed) {
        controller.dispose();
      }
    });

    controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _defaultLocation,
              initialZoom: 14,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
              ),
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: <Polyline>[
                    Polyline(
                      points: _routePoints,
                      color: AppColors.primaryYellow.withValues(alpha: 0.8),
                      strokeWidth: 5.0,
                      borderStrokeWidth: 2.0,
                      borderColor: AppColors.primaryNavy.withValues(alpha: 0.2),
                    ),
                  ],
                ),
              // ⚡ NEW: Professional Hub Markers
              MarkerLayer(
                markers:
                    _hubs.entries.map((hub) {
                      bool isDest = hub.key == _toHub;
                      bool isStart = hub.key == _fromHub;
                      Color markerColor =
                          isDest
                              ? Colors.redAccent
                              : (isStart
                                  ? Colors.greenAccent[700]!
                                  : Colors.grey[400]!);

                      return Marker(
                        point: hub.value,
                        width: 80,
                        height: 100,
                        child: _buildHubMarker(hub.key, markerColor, isDest),
                      );
                    }).toList(),
              ),
              if (_hasUserLocation)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _userLocation,
                      width: 50,
                      height: 50,
                      child: _buildUserLocationMarker(),
                    ),
                  ],
                ),
              MarkerLayer(markers: _getStopMarkers()),
              MarkerLayer(markers: _getMarkers()),
            ],
          ),
          Positioned(
            top: 40,
            left: 20,
            right: 20,
            child: Column(
              children: [
                Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 20),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.map_rounded,
                        color: AppColors.primaryYellow,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value:
                                _firebaseRoutes.containsKey(_selectedRoute)
                                    ? _selectedRoute
                                    : null,
                            isExpanded: true,
                            hint: const Text("Select Route"),
                            items:
                                _firebaseRoutes.keys
                                    .map(
                                      (r) => DropdownMenuItem(
                                        value: r,
                                        child: Text(
                                          r,
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primaryNavy,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (v) {
                              if (v != null)
                                _calculateRoutePoints(v, _firebaseRoutes[v]);
                            },
                          ),
                        ),
                      ),
                      if (_selectedRoute != null)
                        IconButton(
                          onPressed:
                              () => setState(() {
                                _selectedRoute = null;
                                _fromHub = null;
                                _toHub = null;
                                _routePoints = [];
                              }),
                          icon: const Icon(Icons.close_rounded),
                        ),
                    ],
                  ),
                ),
                if (_isFetchingRoute)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 24, right: 24),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: const LinearProgressIndicator(
                        backgroundColor: Colors.white24,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primaryYellow,
                        ),
                        minHeight: 3,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                _buildGenderFilterBar(),
              ],
            ),
          ),
          Positioned(
            right: 20,
            bottom: 110,
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    _buildPulseEffect(Colors.red),
                    _buildMapControlButton(
                      icon: Icons.emergency_rounded,
                      color: Colors.red,
                      iconColor: Colors.white,
                      onPressed: _handleSOS,
                    ),
                  ],
                ),
                _buildMapControlButton(
                  icon: Icons.add_rounded,
                  color: AppColors.primaryNavy,
                  iconColor: Colors.white,
                  onPressed: () {
                    final currentZoom = _mapController.camera.zoom;
                    _mapController.move(
                      _mapController.camera.center,
                      currentZoom + 1,
                    );
                  },
                ),
                _buildMapControlButton(
                  icon: Icons.remove_rounded,
                  color: AppColors.primaryNavy,
                  iconColor: Colors.white,
                  onPressed: () {
                    final currentZoom = _mapController.camera.zoom;
                    _mapController.move(
                      _mapController.camera.center,
                      currentZoom - 1,
                    );
                  },
                ),
                _buildMapControlButton(
                  icon: Icons.my_location,
                  color: AppColors.primaryYellow,
                  onPressed: _getCurrentLocation,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showBusDetails(String id, Map<String, dynamic> data) async {
    final etaInfo = _busEtas[id];

    // ⚡ REAL-TIME: Prioritize data from Firebase RTDB (pushed by driver)
    final etaText =
        data['remainingTime'] != null &&
                (data['remainingTime'] as String).isNotEmpty
            ? data['remainingTime']
            : (etaInfo?.etaDisplay ?? "Calculating...");

    final arrivalClockTime =
        data['arrivalTime'] != null &&
                (data['arrivalTime'] as String).isNotEmpty
            ? data['arrivalTime']
            : "Calculating...";

    final distText = etaInfo?.distanceDisplay ?? "---";
    final gender = data['gender'] ?? 'Combined';
    final Color genderColor =
        (gender == 'Girls')
            ? Colors.pinkAccent
            : (gender == 'Boys' ? Colors.blueAccent : AppColors.primaryNavy);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: SingleChildScrollView(
                    // ⚡ FIX: Prevent Overflow
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Handle
                        Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Header Row
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: genderColor.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.directions_bus_rounded,
                                color: genderColor,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        data['driverName'] ?? "Driver",
                                        style: GoogleFonts.poppins(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primaryNavy,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      _buildLiveBadge(),
                                    ],
                                  ),
                                  Text(
                                    "BUS #$id • ${data['plateNumber'] ?? ''}",
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: Colors.blueGrey,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, size: 16),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Info Grid
                        Row(
                          children: [
                            Expanded(
                              child: _buildModernInfoBox(
                                Icons.timer_outlined,
                                "REMAINING",
                                etaText,
                                AppColors.primaryNavy,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildModernInfoBox(
                                Icons.event_available_rounded,
                                "ARRIVAL",
                                arrivalClockTime,
                                AppColors.primaryYellow,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildModernInfoBox(
                                Icons.location_on_outlined,
                                "DISTANCE",
                                distText,
                                Colors.blueGrey,
                              ),
                            ),
                            if ((data['speed'] ?? 0.0) > 0.5) ...[
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildModernInfoBox(
                                  Icons.speed,
                                  "SPEED",
                                  "${((data['speed'] ?? 0.0) as num).toStringAsFixed(0)} m/s",
                                  AppColors.liveStatus,
                                ),
                              ),
                            ],
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Route Detail Tile
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.alt_route_rounded,
                                color: AppColors.primaryNavy,
                                size: 20,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "CURRENT TRIP",
                                      style: GoogleFonts.poppins(
                                        fontSize: 9,
                                        color: Colors.grey,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    Text(
                                      "${data['from']} ➔ ${data['to']}",
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        color: AppColors.primaryNavy,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
    );
  }

  Widget _buildLiveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Colors.redAccent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            "LIVE",
            style: GoogleFonts.poppins(
              fontSize: 8,
              fontWeight: FontWeight.bold,
              color: Colors.redAccent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernInfoBox(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.15), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color.withValues(alpha: 0.7), size: 14),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.poppins(
                  color: Colors.grey[500],
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              color: AppColors.primaryNavy,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderFilterBar() {
    return Container(
      height: 50,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children:
            ["All", "Girls", "Boys", "Combined"].map((g) {
              bool isSelected = _selectedGender == g;
              Color activeColor =
                  (g == "Girls")
                      ? Colors.pinkAccent
                      : (g == "Boys"
                          ? Colors.blueAccent
                          : (g == "Combined"
                              ? AppColors.primaryNavy
                              : AppColors.primaryYellow));

              return GestureDetector(
                onTap:
                    () => setState(() {
                      _selectedGender = g;
                    }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutQuint,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
                  ),
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: isSelected ? activeColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    g.toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? Colors.white : Colors.grey[400],
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    // Check if GPS/location services are enabled
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryYellow.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.location_off_rounded,
                        color: AppColors.primaryNavy,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Enable GPS",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                content: Text(
                  "Turn on Location Services to see nearby buses and get accurate ETAs.",
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey[700],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      "SKIP",
                      style: GoogleFonts.poppins(color: Colors.grey),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      LocationService.openLocationSettings();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryNavy,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      "OPEN SETTINGS",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
        );
      }
      return;
    }

    // Request permission
    final hasPermission = await LocationService.handleLocationPermission();
    if (!hasPermission) {
      final status = await LocationService.checkPermissionStatus();
      if (mounted && status == LocationPermission.deniedForever) {
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryYellow.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.location_disabled_rounded,
                        color: AppColors.primaryNavy,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Permission Needed",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                content: Text(
                  "Location permission was permanently denied. To see your position on the map and get bus proximity alerts, please enable it in Settings.",
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey[700],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      "SKIP",
                      style: GoogleFonts.poppins(color: Colors.grey),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      LocationService.openAppSettings();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryNavy,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      "APP SETTINGS",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
        );
      }
      return;
    }

    // Permission granted — get current position
    try {
      final position = await Geolocator.getCurrentPosition();
      if (mounted)
        setState(() {
          _userLocation = LatLng(position.latitude, position.longitude);
          _hasUserLocation = true;
          _mapController.move(_userLocation, 14);
        });
    } catch (e) {
      // Silently handle — user location is optional enhancement
    }
  }

  void _handleSOS() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await SOSService().sendSOS(
        userId: user.uid,
        userName: user.displayName ?? "Student",
        lat: _userLocation.latitude,
        lng: _userLocation.longitude,
        message: "Help!",
      );
      NotificationService.show(
        title: "SOS Triggered",
        message: "Emergency alert sent to university admin.",
        type: NotificationType.error,
      );
    }
  }

  Widget _buildMapControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    Color? color,
    Color? iconColor,
  }) {
    return Container(
      width: 42,
      height: 42,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: iconColor ?? AppColors.primaryNavy, size: 20),
      ),
    );
  }
}

/// Custom painter for the marker's downward pointer triangle
class _MarkerPointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = AppColors.primaryNavy
          ..style = PaintingStyle.fill;

    final path =
        ui.Path()
          ..moveTo(0, 0)
          ..lineTo(size.width, 0)
          ..lineTo(size.width / 2, size.height)
          ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
