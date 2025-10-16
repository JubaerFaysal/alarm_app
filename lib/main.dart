import 'package:alarm_test_final/Alarm/alarm_service.dart';
import 'package:alarm_test_final/database/db_helper.dart';
import 'package:alarm_test_final/medicine_remainder.dart';
import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final MedicineAlarmService _medicineAlarmService = MedicineAlarmService();
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      debugPrint('🚀 Initializing app...');
      await _medicineAlarmService.initialize();
      _medicineAlarmService.initializeMedicineAlarmListeners();
      await _medicineAlarmService.cancelAllMedicineAlarms();
      await Future.delayed(Duration(seconds: 1));
      await _rescheduleAllMedicineAlarms();

      setState(() {
        _isInitialized = true;
      });

      debugPrint('✅ App initialization complete');
    } catch (e) {
      debugPrint('❌ Error in app initialization: $e');
      setState(() {
        _isInitialized = true; // Still show UI even if alarms fail
      });
    }
  }

  Future<void> _rescheduleAllMedicineAlarms() async {
    try {
      final dbHelper = DatabaseHelper();
      final medicines = await dbHelper.getMedicines();

      debugPrint('🔄 Found ${medicines.length} medicines in database');

      for (final medicine in medicines) {
        if (medicine.isActive &&
            medicine.id != null &&
            medicine.isWithinDateRange) {
          debugPrint('📋 Rescheduling alarms for: ${medicine.name}');
          await _medicineAlarmService.setMedicineAlarms(medicine);
        } else {
          debugPrint('⏸️ Skipping inactive/expired medicine: ${medicine.name}');
        }
      }

      debugPrint('✅ Completed rescheduling alarms');
    } catch (e) {
      debugPrint('❌ Error rescheduling medicine alarms: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Medicine Reminder',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: _isInitialized ? MedicineListScreen() : _buildLoadingScreen(),
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: Color(0xFF667EEA),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.deepPurple),
            SizedBox(height: 20),
            Text(
              'Loading Medicine Reminder...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
