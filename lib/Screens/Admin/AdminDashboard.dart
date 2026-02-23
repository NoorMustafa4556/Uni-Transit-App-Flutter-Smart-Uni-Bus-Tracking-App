import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../Constants/AppColors.dart';

import '../../Models/BusSchedule.dart';
import '../../Services/ScheduleService.dart';
import 'AddScheduleScreen.dart';
import 'LiveTrackingScreen.dart';

import '../../Widgets/AppDrawer.dart'; // Import Drawer

import '../../Widgets/CustomAppBar.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final _scheduleService = ScheduleService();
  // Logout moved to Drawer

  void _deleteSchedule(String id) async {
    try {
      await _scheduleService.deleteSchedule(id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Schedule Deleted")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: "Admin Dashboard",
        actions: [
          IconButton(
            icon: const Icon(Icons.map, color: Colors.white),
            tooltip: 'Live Tracking',
            onPressed:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LiveTrackingScreen()),
                ),
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: StreamBuilder<List<BusSchedule>>(
        stream: _scheduleService.getSchedules(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Text(
                "No schedules found. Add one!",
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
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primaryNavy,
                    child: const Icon(
                      Icons.directions_bus,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(
                    schedule.busNumber,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    "${schedule.route}\n${schedule.departureTime} • ${schedule.type}",
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteSchedule(schedule.id),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddScheduleScreen()),
          );
        },
        backgroundColor: AppColors.accentAmber,
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }
}
