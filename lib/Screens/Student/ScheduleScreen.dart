import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../Constants/AppColors.dart';
import '../../Models/BusSchedule.dart';
import '../../Services/ScheduleService.dart';

class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheduleService = ScheduleService();
    // Reference to Realtime Database 'buses' node to check for live status
    final DatabaseReference _busesRef = FirebaseDatabase.instance.ref('buses');

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: StreamBuilder<DatabaseEvent>(
        stream: _busesRef.onValue,
        builder: (context, liveSnapshot) {
          // Parse live buses data
          Map<dynamic, dynamic> activeBuses = {};
          if (liveSnapshot.hasData &&
              liveSnapshot.data!.snapshot.value != null) {
            try {
              activeBuses =
                  liveSnapshot.data!.snapshot.value as Map<dynamic, dynamic>;
            } catch (e) {
              // Handle casting error if any
            }
          }

          return StreamBuilder<List<BusSchedule>>(
            stream: scheduleService.getSchedules(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text("Error: ${snapshot.error}"));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                  child: Text(
                    "No schedules available.",
                    style: GoogleFonts.poppins(color: Colors.grey),
                  ),
                );
              }

              final schedules = snapshot.data!;

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: schedules.length,
                itemBuilder: (context, index) {
                  final schedule = schedules[index];

                  // --- LIVE STATUS CHECK ---
                  bool isLive = false;
                  String liveBus = "";

                  // Split "1, 2, 3" or "1-2-3" into individual numbers
                  List<String> scheduledBuses =
                      schedule.busNumber
                          .split(RegExp(r'[-, ]+'))
                          .where((s) => s.isNotEmpty)
                          .toList();

                  for (var bus in scheduledBuses) {
                    // Check if this bus number exists in activeBuses map
                    if (activeBuses.containsKey(bus)) {
                      isLive = true;
                      liveBus = bus;
                      break; // Found at least one live bus for this schedule
                    }
                  }

                  return Card(
                    elevation: 3,
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side:
                          isLive
                              ? const BorderSide(color: Colors.green, width: 2)
                              : BorderSide.none,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Live Indicator
                          if (isLive)
                            Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.circle,
                                    color: Colors.white,
                                    size: 8,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    "LIVE: Bus $liveBus",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Bus Number & Type
                              Expanded(
                                child: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        schedule.busNumber,
                                        style: GoogleFonts.poppins(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primaryNavy,
                                        ),
                                        overflow: TextOverflow.visible,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    // Speciality Badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            schedule.type == 'Girls Special'
                                                ? Colors.pink[100]
                                                : schedule.type ==
                                                    'Boys Special'
                                                ? Colors.blue[100]
                                                : Colors.green[100],
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color:
                                              schedule.type == 'Girls Special'
                                                  ? Colors.pink
                                                  : schedule.type ==
                                                      'Boys Special'
                                                  ? Colors.blue
                                                  : Colors.green,
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        schedule.type,
                                        style: GoogleFonts.poppins(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color:
                                              schedule.type == 'Girls Special'
                                                  ? Colors.pink
                                                  : schedule.type ==
                                                      'Boys Special'
                                                  ? Colors.blue
                                                  : Colors.green,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Time Pill
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.accentAmber.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  schedule.departureTime,
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFFD68F00),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Route
                          Row(
                            children: [
                              const Icon(
                                Icons.route,
                                size: 20,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                schedule.route,
                                style: GoogleFonts.poppins(fontSize: 14),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          // Stops
                          Text(
                            "Stops: ${schedule.stops.join(" -> ")}",
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
