import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:uni_transit/models/bus_schedule.dart';
import 'package:uni_transit/services/schedule_service.dart';
import 'package:uni_transit/core/constants/app_colors.dart';

class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheduleService = ScheduleService();
    final DatabaseReference busesRef = FirebaseDatabase.instance.ref('buses');
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : AppColors.backgroundLight,
      body: StreamBuilder<DatabaseEvent>(
        stream: busesRef.onValue,
        builder: (context, liveSnapshot) {
          Map<dynamic, dynamic> activeBuses = {};
          if (liveSnapshot.hasData && liveSnapshot.data!.snapshot.value != null) {
            try {
              activeBuses = liveSnapshot.data!.snapshot.value as Map<dynamic, dynamic>;
            } catch (_) {}
          }

          return StreamBuilder<List<BusSchedule>>(
            stream: scheduleService.getSchedules(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Colors.black));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return _buildEmptyState();
              }

              final schedules = snapshot.data!;

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                itemCount: schedules.length,
                itemBuilder: (context, index) {
                  final schedule = schedules[index];
                  bool isLive = false;
                  String liveBus = "";

                  List<String> scheduledBuses = schedule.busNumber
                      .split(RegExp(r'[-, ]+'))
                      .where((s) => s.isNotEmpty)
                      .toList();

                  for (var bus in scheduledBuses) {
                    if (activeBuses.containsKey(bus)) {
                      isLive = true;
                      liveBus = bus;
                      break;
                    }
                  }

                  return _buildScheduleCard(context, schedule, isLive, liveBus);
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_today_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            "No Schedules Found",
            style: GoogleFonts.poppins(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleCard(BuildContext context, BusSchedule schedule, bool isLive, String liveBus) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: isLive 
                ? AppColors.liveStatus.withValues(alpha: 0.15) 
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: isLive 
            ? Border.all(color: AppColors.liveStatus, width: 1.5)
            : Border.all(color: isDark ? Colors.white10 : Colors.grey[50]!),
      ),
      child: Stack(
        children: [
          if (isLive) 
            Positioned(
              top: 16, right: 16,
              child: _LiveBadge(busNum: liveBus),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.directions_bus_rounded, color: Colors.black, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "BUS #${schedule.busNumber}",
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : AppColors.primaryNavy,
                            ),
                          ),
                          _buildTypeBadge(schedule.type),
                        ],
                      ),
                    ),
                    Text(
                      schedule.departureTime,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildRouteInfo(Icons.location_on_rounded, "ORIGIN", schedule.route.split("➔")[0]),
                const Padding(
                  padding: EdgeInsets.only(left: 10),
                  child: SizedBox(height: 10, child: VerticalDivider(width: 1, thickness: 1, color: Colors.grey)),
                ),
                _buildRouteInfo(Icons.flag_rounded, "DESTINATION", schedule.route.split("➔").last),
                const Divider(height: 32),
                Text(
                  "STOPS",
                  style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 1.5),
                ),
                const SizedBox(height: 8),
                Text(
                  schedule.stops.join(" • "),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeBadge(String type) {
    Color color = AppColors.staffOnly;
    if (type.contains('Girls')) {
      color = AppColors.girlsSpecial;
    } else if (type.contains('Boys')) {
      color = AppColors.boysSpecial;
    }

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        type.toUpperCase(),
        style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }

  Widget _buildRouteInfo(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primaryYellow),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold)),
            Text(value.trim(), style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }
}

class _LiveBadge extends StatefulWidget {
  final String busNum;
  const _LiveBadge({required this.busNum});

  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.liveStatus,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: AppColors.liveStatus.withValues(alpha: 0.5), blurRadius: 8)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sensors_rounded, color: Colors.white, size: 12),
            const SizedBox(width: 6),
            Text(
              "LIVE BUS #${widget.busNum}",
              style: GoogleFonts.poppins(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}
