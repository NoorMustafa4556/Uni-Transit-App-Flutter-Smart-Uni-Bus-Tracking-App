import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:uni_transit/models/bus_schedule.dart';
import 'package:uni_transit/services/schedule_service.dart';
import 'package:uni_transit/core/constants/app_colors.dart';
import 'package:uni_transit/views/student/map_screen.dart';

class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key});

  static final _scheduleService = ScheduleService();
  static final _busesRef = FirebaseDatabase.instance.ref('buses');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // ⚡ CLEAN: Pure White Background
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "Bus Schedule",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700, 
            fontSize: 20, 
            color: AppColors.primaryNavy
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.primaryNavy, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: _busesRef.onValue,
        builder: (context, liveSnapshot) {
          Map<dynamic, dynamic> activeBuses = {};
          if (liveSnapshot.hasData && liveSnapshot.data!.snapshot.value != null) {
            try {
              activeBuses = liveSnapshot.data!.snapshot.value as Map<dynamic, dynamic>;
            } catch (_) {}
          }

          return StreamBuilder<List<BusSchedule>>(
            stream: _scheduleService.getSchedules(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: AppColors.primaryNavy));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return _buildEmptyState();
              }

              final allSchedules = snapshot.data!;
              // ⚡ FILTER: Only show Abbasia ➔ Baghdad
              final schedules = allSchedules.where((s) => s.route == "Abbasia ➔ Baghdad").toList();

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
                itemCount: schedules.length,
                itemBuilder: (context, index) {
                  final schedule = schedules[index];
                  String? activeBusId;
                  
                  // Check if any scheduled bus is live
                  List<String> scheduledBuses = schedule.busNumber
                      .split(RegExp(r'[-, ]+'))
                      .where((s) => s.isNotEmpty)
                      .toList();

                  for (var bus in scheduledBuses) {
                    if (activeBuses.containsKey(bus)) {
                      activeBusId = bus;
                      break;
                    }
                  }

                  return _buildMinimalistScheduleCard(context, schedule, activeBusId);
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildMinimalistScheduleCard(BuildContext context, BusSchedule schedule, String? liveBusId) {
    bool isLive = liveBusId != null;
    final routeParts = schedule.route.split("➔");
    final from = routeParts[0].trim();
    final to = routeParts.last.trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isLive ? Colors.greenAccent[700]!.withValues(alpha: 0.3) : Colors.grey[100]!, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (isLive) {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const MapScreen()));
            }
          },
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildRouteBadge(schedule.type),
                    if (isLive) _buildLiveStatusBadge(liveBusId),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Column(
                      children: [
                        Icon(Icons.radio_button_checked, size: 14, color: Colors.greenAccent[700]),
                        Container(width: 1.5, height: 25, color: Colors.grey[200]),
                        const Icon(Icons.location_on, size: 14, color: Colors.redAccent),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(from, style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.primaryNavy)),
                          const SizedBox(height: 12),
                          Text(to, style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.primaryNavy)),
                        ],
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Divider(height: 1),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildInfoItem(Icons.access_time_filled_rounded, "DEPARTURE", schedule.departureTime),
                    _buildInfoItem(Icons.directions_bus_rounded, "BUS ID", schedule.busNumber),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRouteBadge(String type) {
    Color color = AppColors.primaryNavy;
    if (type.contains('Girls')) color = Colors.pinkAccent;
    else if (type.contains('Boys')) color = Colors.blueAccent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        type.toUpperCase(),
        style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildLiveStatusBadge(String busId) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.greenAccent[700]!.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: Colors.greenAccent[700], shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text("LIVE #$busId", style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.greenAccent[700])),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 8, fontWeight: FontWeight.w700, color: Colors.grey[400], letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(icon, size: 14, color: AppColors.primaryNavy.withValues(alpha: 0.7)),
            const SizedBox(width: 6),
            Text(value, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryNavy)),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_month_outlined, size: 60, color: Colors.grey[200]),
          const SizedBox(height: 16),
          Text("No active schedules", style: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 14)),
        ],
      ),
    );
  }
}
