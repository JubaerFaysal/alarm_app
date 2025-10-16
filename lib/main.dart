import 'package:alarm_test_final/Alarm/alarm_screen.dart';
import 'package:alarm_test_final/Alarm/alarm_service.dart';
import 'package:alarm_test_final/database/db_helper.dart';
import 'package:alarm_test_final/medicine_remainder.dart';
import 'package:alarm_test_final/model/medicine_model.dart';
import 'package:flutter/material.dart';

// Global navigator key for showing alarm screen from anywhere
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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

      // Initialize alarm service with callback for showing alarm screen
      await _medicineAlarmService.initialize(
        onAlarmTriggered: (medicine) {
          _showAlarmScreen(medicine);
        },
      );

      // Initialize alarm listeners
      _medicineAlarmService.initializeMedicineAlarmListeners();

      // Clear any existing alarms
      await _medicineAlarmService.cancelAllMedicineAlarms();

      // Wait a moment to ensure alarms are cleared
      await Future.delayed(Duration(seconds: 1));

      // Reschedule all alarms from database
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

  void _showAlarmScreen(Medicine medicine) {
    // Use the global navigator key to show alarm screen from anywhere
    if (navigatorKey.currentState?.mounted ?? false) {
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (context) => AlarmScreen(
            medicineName: medicine.name,
            dosage: medicine.dosage,
            pillCount: medicine.pillCount.toString(),
            type: medicine.type,
            medicineNames: medicine.medicineNames,
            onDismiss: () {
              // Mark medicine as taken and cancel its alarms
              if (medicine.id != null) {
                _medicineAlarmService.cancelMedicineAlarms(medicine.id!);
              }
              // Close the alarm screen
              Navigator.of(context).pop();
            },
          ),
        ),
      );
    } else {
      debugPrint('❌ Navigator not available for showing alarm screen');
    }
  }

  Future<void> _rescheduleAllMedicineAlarms() async {
    try {
      final dbHelper = DatabaseHelper();
      final medicines = await dbHelper.getMedicines();

      debugPrint('🔄 Found ${medicines.length} medicines in database');

      int scheduledCount = 0;
      for (final medicine in medicines) {
        if (medicine.isActive &&
            medicine.id != null &&
            medicine.isWithinDateRange) {
          debugPrint('📋 Scheduling alarms for: ${medicine.name}');
          final success = await _medicineAlarmService.setMedicineAlarms(
            medicine,
          );
          if (success) {
            scheduledCount++;
          }
        } else {
          debugPrint('⏸️ Skipping inactive/expired medicine: ${medicine.name}');
        }
      }

      debugPrint('✅ Scheduled $scheduledCount active medicines');
    } catch (e) {
      debugPrint('❌ Error rescheduling medicine alarms: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Medicine Reminder',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Color(0xFF667EEA),
          brightness: Brightness.light,
        ),
      ),
      navigatorKey: navigatorKey, // Use the global navigator key
      home: _isInitialized ? MedicineListScreen() : _buildLoadingScreen(),
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: Color(0xFF667EEA),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 20),
            Text(
              'Loading Medicine Reminder...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            SizedBox(height: 10),
            Text(
              'Setting up alarms...',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
