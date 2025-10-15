import 'package:alarm_test_final/database/db_helper.dart';
import 'package:alarm_test_final/model/medicine_model.dart';
import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import 'Alarm/alarm_service.dart';
import 'add_medicine.dart';

class MedicineListScreen extends StatefulWidget {
  const MedicineListScreen({super.key});

  @override
  MedicineListScreenState createState() => MedicineListScreenState();
}

class MedicineListScreenState extends State<MedicineListScreen> {
  int _currentIndex = 0;
  List<Medicine> _medicines = [];
  List<Medicine> _todayMedicines = [];
  List<Medicine> _upcomingMedicines = [];

  @override
  void initState() {
    super.initState();
    _fetchMedicines();
  }

  Future<void> _fetchMedicines() async {
    try {
      final dbHelper = DatabaseHelper();
      final allMeds = await dbHelper.getMedicines();

      setState(() {
        _medicines = allMeds;
        _todayMedicines =
            allMeds.where((m) => m.isActive && m.isWithinDateRange).toList();
        _upcomingMedicines =
            allMeds.where((m) => !m.isActive || !m.isWithinDateRange).toList();
      });
    } catch (e) {
      developer.log("Error fetching medicines: $e");
    }
  }

  void _navigateToAddMedicine() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => AddMedicineScreen(
              onMedicineAdded: () {
                _fetchMedicines();
              },
            ),
      ),
    );
  }

  void _deleteMedicine(Medicine medicine) async {
    if (medicine.id != null) {
      final dbHelper = DatabaseHelper();
      await dbHelper.deleteMedicine(medicine.id!);

      // Cancel alarms when deleting medicine
      final alarmService = MedicineAlarmService();
      await alarmService.cancelMedicineAlarms(medicine.id!);

      _fetchMedicines();
    }
  }

  void _markAsTaken(Medicine medicine) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${medicine.name} marked as taken!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _toggleMedicineStatus(Medicine medicine) async {
    final newStatus = !medicine.isActive;

    final dbHelper = DatabaseHelper();
    await dbHelper.toggleMedicineStatus(medicine.id!, newStatus);

    // Update alarms based on new status
    final alarmService = MedicineAlarmService();
    if (newStatus) {
      await alarmService.setMedicineAlarms(medicine.copyWith(isActive: true));
    } else {
      await alarmService.cancelMedicineAlarms(medicine.id!);
    }

    _fetchMedicines();
  }

  int get _takenCount {
    // You can implement actual taken count logic here
    return 1;
  }

  int get _totalCount {
    return _todayMedicines.length;
  }

  double get _progressPercentage {
    return _totalCount > 0 ? _takenCount / _totalCount : 0;
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Good Morning,',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  Text(
                    'Jubaer Ahmed!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              CircleAvatar(
                radius: 25,
                backgroundColor: Colors.white,
                child: Icon(Icons.person, color: Color(0xFF667EEA), size: 30),
              ),
            ],
          ),
          SizedBox(height: 20),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(80),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.medical_services, color: Colors.white, size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Today\'s Progress',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      Text(
                        '$_takenCount/$_totalCount Medicines Taken',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${(_progressPercentage * 100).round()}%',
                    style: TextStyle(
                      color: Color(0xFF667EEA),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 10),
          LinearProgressIndicator(
            value: _progressPercentage,
            backgroundColor: Colors.white.withOpacity(0.3),
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicineCard(Medicine medicine, bool isToday) {
    final allTimes = medicine.times.map((time) => _formatTime(time)).join(', ');

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          // Pill Icon with Color
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: medicine.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.medication, color: medicine.color, size: 28),
          ),
          SizedBox(width: 16),

          // Medicine Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        medicine.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    if (!isToday)
                      IconButton(
                        icon: Icon(Icons.delete_outline, color: Colors.grey),
                        iconSize: 18,
                        onPressed: () => _deleteMedicine(medicine),
                      ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  '${medicine.dosage} • ${medicine.pillCount} pill${medicine.pillCount > 1 ? 's' : ''}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: medicine.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        medicine.type,
                        style: TextStyle(
                          color: medicine.color,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.access_time, size: 12, color: Colors.blue),
                          SizedBox(width: 4),
                          Text(
                            medicine.frequency,
                            style: TextStyle(
                              color: Colors.blue,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.restaurant, size: 12, color: Colors.green),
                          SizedBox(width: 4),
                          Text(
                            medicine.intakeTime,
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.schedule, size: 14, color: Colors.grey[600]),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        allTimes,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: Colors.orange[600],
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Ends: ${_formatDate(medicine.endDate)} ${medicine.daysRemaining != null ? '(${medicine.daysRemaining} days left)' : ''}',
                        style: TextStyle(
                          color: Colors.orange[600],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                if (medicine.instructions.isNotEmpty) ...[
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.note, size: 14, color: Colors.grey[600]),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          medicine.instructions,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Action Button
          if (isToday)
            Column(
              children: [
                GestureDetector(
                  onTap: () => _markAsTaken(medicine),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.green),
                    ),
                    child: Icon(Icons.check, color: Colors.green, size: 20),
                  ),
                ),
                SizedBox(height: 8),
                Switch(
                  value: medicine.isActive,
                  onChanged: (value) => _toggleMedicineStatus(medicine),
                  activeColor: Color(0xFF667EEA),
                ),
              ],
            )
          else
            Column(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.schedule,
                    color: Colors.grey[500],
                    size: 20,
                  ),
                ),
                SizedBox(height: 8),
                Switch(
                  value: medicine.isActive,
                  onChanged: (value) => _toggleMedicineStatus(medicine),
                  activeColor: Color(0xFF667EEA),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    if (_currentIndex == 0) {
      return _todayMedicines.isEmpty
          ? _buildEmptyState()
          : ListView(
            children:
                _todayMedicines.map((medicine) {
                  return _buildMedicineCard(medicine, true);
                }).toList(),
          );
    } else {
      return _upcomingMedicines.isEmpty
          ? _buildEmptyUpcomingState()
          : ListView(
            children:
                _upcomingMedicines.map((medicine) {
                  return _buildMedicineCard(medicine, false);
                }).toList(),
          );
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.medical_services_outlined,
            size: 80,
            color: Colors.grey[300],
          ),
          SizedBox(height: 20),
          Text(
            'No Medicines Today',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[500],
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Add medicines to see them here',
            style: TextStyle(color: Colors.grey[400]),
          ),
          SizedBox(height: 20),
          ElevatedButton.icon(
            icon: Icon(Icons.add),
            label: Text('Add First Medicine'),
            onPressed: _navigateToAddMedicine,
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF667EEA),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyUpcomingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 80,
            color: Colors.grey[300],
          ),
          SizedBox(height: 20),
          Text(
            'No Upcoming Medicines',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[500],
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Medicines for future dates will appear here',
            style: TextStyle(color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildHeader(),
          SizedBox(height: 20),

          // Tab Bar
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _currentIndex = 0;
                        });
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color:
                              _currentIndex == 0
                                  ? Colors.white
                                  : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow:
                              _currentIndex == 0
                                  ? [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ]
                                  : null,
                        ),
                        child: Center(
                          child: Text(
                            'Today (${_todayMedicines.length})',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color:
                                  _currentIndex == 0
                                      ? Color(0xFF667EEA)
                                      : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _currentIndex = 1;
                        });
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color:
                              _currentIndex == 1
                                  ? Colors.white
                                  : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow:
                              _currentIndex == 1
                                  ? [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ]
                                  : null,
                        ),
                        child: Center(
                          child: Text(
                            'Upcoming (${_upcomingMedicines.length})',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color:
                                  _currentIndex == 1
                                      ? Color(0xFF667EEA)
                                      : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 20),

          // Medicine List
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: _buildTabContent(),
            ),
          ),
        ],
      ),

      // Floating Action Button
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddMedicine,
        backgroundColor: Color(0xFF667EEA),
        foregroundColor: Colors.white,
        elevation: 4,
        child: Icon(Icons.add, size: 28),
      ),

      // Bottom Navigation Bar
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: 0,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: Color(0xFF667EEA),
          unselectedItemColor: Colors.grey,
          items: [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today_outlined),
              activeIcon: Icon(Icons.calendar_today),
              label: 'Calendar',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.analytics_outlined),
              activeIcon: Icon(Icons.analytics),
              label: 'Reports',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
          onTap: (index) {
            // Navigation logic can be added here
          },
        ),
      ),
    );
  }
}
