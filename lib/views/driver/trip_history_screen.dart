import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uni_transit/core/constants/app_colors.dart';
import 'package:uni_transit/services/location_service.dart';
import 'package:uni_transit/services/auth_service.dart';
import 'package:uni_transit/widgets/custom_app_bar.dart';

class TripHistoryScreen extends StatefulWidget {
  const TripHistoryScreen({super.key});

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen> {
  final _locationService = LocationService();
  final _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text("Unauthorized")));

    return Scaffold(
      appBar: CustomAppBar(title: "My Trip History"),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _locationService.getTripHistory(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history_toggle_off_rounded, size: 80, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text("No trips recorded yet", style: GoogleFonts.poppins(color: Colors.grey, fontWeight: FontWeight.w500)),
              ],
            ));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final trip = snapshot.data![index];
              final date = DateTime.fromMillisecondsSinceEpoch(trip['startTime'] as int);
              bool isOngoing = trip['status'] == 'ongoing';

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
                  border: Border.all(color: isOngoing ? Colors.green.withValues(alpha: 0.2) : Colors.grey[100]!),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: [
                          Icon(Icons.calendar_today_rounded, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Text(DateFormat('MMM dd, yyyy').format(date), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ]),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isOngoing ? Colors.green : AppColors.primaryNavy,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isOngoing ? "ONGOING" : "COMPLETED",
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      children: [
                        Column(children: [
                          const Icon(Icons.circle, size: 10, color: Colors.green),
                          Container(width: 2, height: 20, color: Colors.grey[200]),
                          const Icon(Icons.location_on, size: 14, color: Colors.red),
                        ]),
                        const SizedBox(width: 16),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(trip['from'] ?? "Unknown Start", style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            const SizedBox(height: 12),
                            Text(trip['to'] ?? "Unknown Dest", style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          ],
                        )),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildInfoPair("BUS ID", trip['busNumber']),
                        _buildInfoPair("PLATE", trip['plateNumber']),
                        _buildInfoPair("TIME", DateFormat('hh:mm a').format(date)),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildInfoPair(String label, String value) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: Colors.grey, fontSize: 8, fontWeight: FontWeight.bold)),
      Text(value, style: const TextStyle(color: AppColors.primaryNavy, fontSize: 11, fontWeight: FontWeight.bold)),
    ]);
  }
}
