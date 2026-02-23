class BusSchedule {
  final String id;
  final String busNumber;
  final String route;
  final String departureTime;
  final List<String> stops;
  final String type; // Boys Special, Girls Special, Combined

  BusSchedule({
    required this.id,
    required this.busNumber,
    required this.route,
    required this.departureTime,
    required this.stops,
    required this.type,
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'busNumber': busNumber,
      'route': route,
      'departureTime': departureTime,
      'stops': stops,
      'type': type,
    };
  }

  // Create Object from Firestore Map
  factory BusSchedule.fromMap(String id, Map<String, dynamic> map) {
    return BusSchedule(
      id: id,
      busNumber: map['busNumber'] ?? '',
      route: map['route'] ?? '',
      departureTime: map['departureTime'] ?? '',
      stops: List<String>.from(map['stops'] ?? []),
      type: map['type'] ?? 'Combined',
    );
  }
}
