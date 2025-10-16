// ignore_for_file: use_build_context_synchronously

import 'package:alarm_test_final/Alarm/alarm_service.dart';
import 'package:alarm_test_final/model/medicine_model.dart';
import 'package:flutter/material.dart';
import 'database/db_helper.dart';

class AddMedicineScreen extends StatefulWidget {
  final Function()? onMedicineAdded;

  const AddMedicineScreen({super.key, this.onMedicineAdded});

  @override
  AddMedicineScreenState createState() => AddMedicineScreenState();
}

class AddMedicineScreenState extends State<AddMedicineScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _dosageController = TextEditingController();
  final TextEditingController _instructionsController = TextEditingController();

  String _selectedFrequency = 'Once Daily';
  String _selectedType = 'Tablet';
  String _selectedIntakeTime = 'After Food';
  int _pillCount = 1;
  DateTime? _selectedEndDate;

  List<TimeOfDay> _selectedTimes = [TimeOfDay(hour: 8, minute: 0)];
  final List<Color> _availableColors = [
    Color(0xFF4CAF50), // Green
    Color(0xFF2196F3), // Blue
    Color(0xFFFF9800), // Orange
    Color(0xFF9C27B0), // Purple
    Color(0xFFF44336), // Red
    Color(0xFF00BCD4), // Cyan
  ];
  Color _selectedColor = Color(0xFF4CAF50);

  final List<String> _frequencies = [
    'Once Daily',
    'Twice Daily',
    'Three Times Daily',
    'Four Times Daily',
    'As Needed',
  ];
  final List<String> _medicineTypes = [
    'Tablet',
    'Capsule',
    'Liquid',
    'Injection',
    'Cream',
    'Drops',
    'Inhaler',
  ];
  final List<String> _intakeTimes = [
    'Before Food',
    'After Food',
    'With Food',
    'Anytime',
  ];

  final Map<String, int> _frequencyTimeCounts = {
    'Once Daily': 1,
    'Twice Daily': 2,
    'Three Times Daily': 3,
    'Four Times Daily': 4,
    'As Needed': 1,
  };

  @override
  void initState() {
    super.initState();
    _updateTimesBasedOnFrequency();
  }

  void _updateTimesBasedOnFrequency() {
    final requiredCount = _frequencyTimeCounts[_selectedFrequency]!;

    if (_selectedTimes.length < requiredCount) {
      for (int i = _selectedTimes.length; i < requiredCount; i++) {
        _selectedTimes.add(TimeOfDay(hour: 8 + i * 4, minute: 0));
      }
    } else if (_selectedTimes.length > requiredCount) {
      _selectedTimes = _selectedTimes.sublist(0, requiredCount);
    }

    setState(() {});
  }

  Future<void> _selectTime(int index) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTimes[index],
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: Color(0xFF667EEA),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedTimes[index] = picked;
      });
    }
  }

  Future<void> _selectEndDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedEndDate ?? DateTime.now().add(Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: Color(0xFF667EEA),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedEndDate = picked;
      });
    }
  }

  void _saveMedicine() async {
    if (_selectedEndDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select an end date'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(child: CircularProgressIndicator()),
      );

      try {
        final newMedicine = Medicine(
          name: _nameController.text.trim(),
          dosage: _dosageController.text.trim(),
          type: _selectedType,
          times: _selectedTimes,
          frequency: _selectedFrequency,
          pillCount: _pillCount,
          instructions: _instructionsController.text.trim(),
          intakeTime: _selectedIntakeTime,
          color: _selectedColor,
          isActive: true,
          isTaken: false,
          createdAt: DateTime.now(),
          endDate: _selectedEndDate!,
        );

        final dbHelper = DatabaseHelper();
        final medicineId = await dbHelper.insertMedicine(newMedicine);

        final medicineWithId = newMedicine.copyWith(id: medicineId);

        final alarmService = MedicineAlarmService();
        final alarmSuccess = await alarmService.setMedicineAlarms(
          medicineWithId,
        );

        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              alarmSuccess
                  ? 'Medicine added successfully! Alarms set.'
                  : 'Medicine added but failed to set some alarms.',
            ),
            backgroundColor: alarmSuccess ? Color(0xFF4CAF50) : Colors.orange,
          ),
        );

        widget.onMedicineAdded?.call();

        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }

        debugPrint('Error inserting medicine: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add medicine: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildFormField(
    String label,
    String hint,
    IconData icon,
    TextEditingController controller, {
    bool isRequired = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
            fontSize: 14,
          ),
        ),
        SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: Colors.grey[500]),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Color(0xFF667EEA)),
            ),
            filled: true,
            fillColor: Colors.grey[50],
          ),
          validator: isRequired
              ? (value) {
                  if (value == null || value.isEmpty) {
                    return 'This field is required';
                  }
                  return null;
                }
              : null,
        ),
        SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSelectionField(
    String label,
    String value,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
            fontSize: 14,
          ),
        ),
        SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              children: [
                Icon(icon, color: Colors.grey[500]),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(color: Colors.grey[700], fontSize: 16),
                  ),
                ),
                Icon(Icons.arrow_drop_down, color: Colors.grey[500]),
              ],
            ),
          ),
        ),
        SizedBox(height: 16),
      ],
    );
  }

  Widget _buildEndDateSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'End Date *',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
            fontSize: 14,
          ),
        ),
        SizedBox(height: 8),
        GestureDetector(
          onTap: _selectEndDate,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _selectedEndDate == null
                    ? Color.fromARGB(255, 247, 101, 90)
                    : Colors.grey[300]!,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, color: Colors.grey[500]),
                SizedBox(width: 12),
                Text(
                  _selectedEndDate != null
                      ? _formatDate(_selectedEndDate!)
                      : 'Select end date',
                  style: TextStyle(
                    color: _selectedEndDate == null
                        ? Colors.grey[500]
                        : Colors.grey[700],
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_selectedEndDate == null) ...[
          SizedBox(height: 4),
          Text(
            'Please select an end date',
            style: TextStyle(color: Colors.red, fontSize: 12),
          ),
        ] else ...[
          SizedBox(height: 8),
          Text(
            'Medicine will be active until ${_formatDate(_selectedEndDate!)}',
            style: TextStyle(color: Colors.green[600], fontSize: 12),
          ),
        ],
        SizedBox(height: 16),
      ],
    );
  }

  void _showFrequencyPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Select Frequency',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              ..._frequencies.map((frequency) {
                return ListTile(
                  title: Text(frequency),
                  subtitle: Text(
                    '${_frequencyTimeCounts[frequency]} times per day',
                  ),
                  trailing: _selectedFrequency == frequency
                      ? Icon(Icons.check, color: Color(0xFF667EEA))
                      : null,
                  onTap: () {
                    setState(() {
                      _selectedFrequency = frequency;
                      _updateTimesBasedOnFrequency();
                    });
                    Navigator.pop(context);
                  },
                );
              }),
              SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  void _showTypePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Select Medicine Type',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              ..._medicineTypes.map((type) {
                return ListTile(
                  leading: Icon(_getTypeIcon(type)),
                  title: Text(type),
                  trailing: _selectedType == type
                      ? Icon(Icons.check, color: Color(0xFF667EEA))
                      : null,
                  onTap: () {
                    setState(() {
                      _selectedType = type;
                    });
                    Navigator.pop(context);
                  },
                );
              }),
              SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  void _showIntakeTimePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'When to Take',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              ..._intakeTimes.map((time) {
                return ListTile(
                  leading: Icon(_getIntakeTimeIcon(time)),
                  title: Text(time),
                  trailing: _selectedIntakeTime == time
                      ? Icon(Icons.check, color: Color(0xFF667EEA))
                      : null,
                  onTap: () {
                    setState(() {
                      _selectedIntakeTime = time;
                    });
                    Navigator.pop(context);
                  },
                );
              }),
              SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'Tablet':
        return Icons.medication;
      case 'Capsule':
        return Icons.health_and_safety;
      case 'Liquid':
        return Icons.liquor;
      case 'Injection':
        return Icons.airline_seat_flat;
      case 'Cream':
        return Icons.healing;
      case 'Drops':
        return Icons.visibility;
      case 'Inhaler':
        return Icons.air;
      default:
        return Icons.medical_services;
    }
  }

  IconData _getIntakeTimeIcon(String intakeTime) {
    switch (intakeTime) {
      case 'Before Food':
        return Icons.breakfast_dining;
      case 'After Food':
        return Icons.dinner_dining;
      case 'With Food':
        return Icons.restaurant;
      case 'Anytime':
        return Icons.access_time;
      default:
        return Icons.schedule;
    }
  }

  Widget _buildTimeSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Times ($_selectedFrequency)',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
            fontSize: 14,
          ),
        ),
        SizedBox(height: 8),
        ..._selectedTimes.asMap().entries.map((entry) {
          final index = entry.key;
          final time = entry.value;
          return Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: () => _selectTime(index),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.access_time, color: Colors.grey[500]),
                    SizedBox(width: 12),
                    Text(
                      'Time ${index + 1}: ${_formatTime(time)}',
                      style: TextStyle(color: Colors.grey[700], fontSize: 16),
                    ),
                    Spacer(),
                    if (_selectedFrequency != 'As Needed')
                      Icon(Icons.edit, color: Colors.grey[500], size: 18),
                  ],
                ),
              ),
            ),
          );
        }),
        SizedBox(height: 16),
      ],
    );
  }

  Widget _buildColorSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Color Label',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
            fontSize: 14,
          ),
        ),
        SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _availableColors.map((color) {
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedColor = color;
                });
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: _selectedColor == color
                      ? Border.all(color: Colors.black, width: 3)
                      : Border.all(color: Colors.grey[300]!, width: 2),
                ),
                child: _selectedColor == color
                    ? Icon(Icons.check, color: Colors.white, size: 20)
                    : null,
              ),
            );
          }).toList(),
        ),
        SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Add New Medicine',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: Color(0xFF667EEA),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFormField(
                'Medicine Name',
                'Enter medicine name',
                Icons.medical_services,
                _nameController,
              ),
              _buildFormField(
                'Dosage',
                'e.g., 500mg, 10ml',
                Icons.health_and_safety,
                _dosageController,
              ),
              _buildSelectionField(
                'Medicine Type',
                _selectedType,
                Icons.medication,
                _showTypePicker,
              ),
              _buildSelectionField(
                'Frequency',
                _selectedFrequency,
                Icons.repeat,
                _showFrequencyPicker,
              ),
              _buildTimeSelection(),
              _buildSelectionField(
                'When to Take',
                _selectedIntakeTime,
                Icons.schedule,
                _showIntakeTimePicker,
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pill Count per Dose',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.remove_circle_outline,
                          color: Colors.grey[600],
                        ),
                        onPressed: () {
                          if (_pillCount > 1) {
                            setState(() {
                              _pillCount--;
                            });
                          }
                        },
                      ),
                      Container(
                        width: 60,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Center(
                          child: Text(
                            _pillCount.toString(),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.add_circle_outline,
                          color: Colors.grey[600],
                        ),
                        onPressed: () {
                          setState(() {
                            _pillCount++;
                          });
                        },
                      ),
                      SizedBox(width: 8),
                      Text(
                        'pills per dose',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                ],
              ),
              _buildColorSelection(),
              _buildEndDateSelection(),
              _buildFormField(
                'Instructions (Optional)',
                'Special instructions, side effects, etc.',
                Icons.note,
                _instructionsController,
                isRequired: false,
              ),
              SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _saveMedicine,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF667EEA),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                  ),
                  child: Text(
                    'SAVE MEDICINE',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }
}
