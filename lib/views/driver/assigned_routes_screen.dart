import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:uni_transit/core/constants/app_colors.dart';
import 'package:uni_transit/core/constants/campus_locations.dart';

class AssignedRoutesScreen extends StatelessWidget {
  const AssignedRoutesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> assignedRoutes = [
      {
        "id": "1",
        "from": CampusLocations.baghdadName,
        "to": CampusLocations.abbasiaName,
        "fromCoord": CampusLocations.baghdadCampus,
        "toCoord": CampusLocations.abbasiaCampus,
        "time": "08:00 AM",
        "busId": "B-4421",
        "isActive": true,
        "stops": "4 Stops",
      },
      {
        "id": "2",
        "from": CampusLocations.abbasiaName,
        "to": CampusLocations.baghdadName,
        "fromCoord": CampusLocations.abbasiaCampus,
        "toCoord": CampusLocations.baghdadCampus,
        "time": "01:30 PM",
        "busId": "B-4421",
        "isActive": false,
        "stops": "3 Stops",
      },
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context, assignedRoutes.length),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildProfessionalRouteCard(context, assignedRoutes[index]),
                childCount: assignedRoutes.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, int count) {
    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      backgroundColor: AppColors.primaryNavy,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          children: [
            Positioned(
              right: -30,
              top: -30,
              child: CircleAvatar(
                radius: 100,
                backgroundColor: Colors.white.withValues(alpha: 0.05),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 80, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Assigned Routes",
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "$count Routes Allocated",
                        style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfessionalRouteCard(BuildContext context, Map<String, dynamic> route) {
    bool isActive = route['isActive'];
    final fromCoord = route['fromCoord'] as LatLng;
    final toCoord = route['toCoord'] as LatLng;
    final center = LatLng((fromCoord.latitude + toCoord.latitude) / 2, (fromCoord.longitude + toCoord.longitude) / 2);

    return InkWell(
      onTap: () {
        Navigator.pop(context);
      },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: 190,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(
            color: isActive ? AppColors.primaryYellow.withValues(alpha: 0.2) : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: 120,
                child: Stack(
                  children: [
                    AbsorbPointer(
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter: center,
                          initialZoom: 11.2,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                            subdomains: const ['a', 'b', 'c', 'd'],
                          ),
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: [fromCoord, toCoord],
                                color: AppColors.primaryNavy.withValues(alpha: 0.4),
                                strokeWidth: 2,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [Colors.white, Colors.white.withValues(alpha: 0.1)],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isActive ? AppColors.primaryYellow.withValues(alpha: 0.1) : Colors.grey[100],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            route['busId'],
                            style: GoogleFonts.poppins(
                              color: isActive ? AppColors.primaryYellow : Colors.grey[500],
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (isActive) ...[
                          const SizedBox(width: 8),
                          _buildLiveTag(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: Row(
                        children: [
                          Column(
                            children: [
                              const Icon(Icons.radio_button_checked_rounded, size: 14, color: Colors.green),
                              Expanded(
                                child: Container(
                                  width: 1,
                                  margin: const EdgeInsets.symmetric(vertical: 2),
                                  color: Colors.grey[200],
                                ),
                              ),
                              const Icon(Icons.location_on_rounded, size: 14, color: Colors.red),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildHubInfo("FROM", route['from']),
                                _buildHubInfo("TO", route['to']),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (isActive)
                      Row(
                        children: [
                          _buildInfoIcon(Icons.access_time_rounded, route['time']),
                          const SizedBox(width: 16),
                          _buildInfoIcon(Icons.stop_circle_outlined, route['stops']),
                        ],
                      )
                    else
                      Text(
                        "STANDBY • ASSIGNED",
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[400],
                          letterSpacing: 0.5,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );


  }

  Widget _buildLiveTag() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        "LIVE",
        style: GoogleFonts.poppins(color: Colors.green, fontSize: 9, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildHubInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 8, color: Colors.grey[400], fontWeight: FontWeight.bold)),
        Text(
          value,
          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildInfoIcon(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 12, color: Colors.grey[400]),
        const SizedBox(width: 4),
        Text(
          text,
          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[600]),
        ),
      ],
    );
  }

}

