import 'package:alarm_test_final/alarm_service.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime? _selectedTime;
  final _alarmService = AlarmService();

  @override
  void initState() {
    super.initState();
    _alarmService.initialize();
  }

  Future<void> _pickTime(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(minutes: 1))),
    );

    if (picked != null) {
      final selected = DateTime(
        now.year,
        now.month,
        now.day,
        picked.hour,
        picked.minute,
      );

      setState(() => _selectedTime = selected);

      final success = await _alarmService.setAlarm(
        id: 1,
        dateTime: selected,
        assetAudioPath: 'assets/alarm.mp3',
        title: 'Alarm',
        body: 'Time to wake up!',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? '✅ Alarm set for ${picked.format(context)}'
                  : '❌ Failed to set alarm. Check audio file.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeText = _selectedTime == null
        ? 'No alarm set'
        : 'Alarm set for: ${TimeOfDay.fromDateTime(_selectedTime!).format(context)}';

    return Scaffold(
      appBar: AppBar(title: const Text('Alarm App'), centerTitle: true),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                timeText,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: () => _pickTime(context),
                icon: const Icon(Icons.alarm),
                label: const Text('Set Alarm'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => _alarmService.stopAllAlarms(),
                icon: const Icon(Icons.stop_circle),
                label: const Text('Stop Alarm'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
