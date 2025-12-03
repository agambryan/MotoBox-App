import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import '../theme.dart';

enum TimezoneType {
  wib('Asia/Jakarta', 'WIB'),
  wita('Asia/Makassar', 'WITA'),
  wit('Asia/Jayapura', 'WIT'),
  london('Europe/London', 'London');

  const TimezoneType(this.timezoneName, this.displayName);
  final String timezoneName;
  final String displayName;
}

class TimezoneClockPanel extends StatefulWidget {
  const TimezoneClockPanel({super.key});

  @override
  State<TimezoneClockPanel> createState() => _TimezoneClockPanelState();
}

class _TimezoneClockPanelState extends State<TimezoneClockPanel> {
  static bool _initialized = false;
  TimezoneType _selectedTimezone = TimezoneType.wib;
  DateTime _currentTime = DateTime.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _initializeTimezone();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _initializeTimezone() {
    if (!_initialized) {
      tz.initializeTimeZones();
      _initialized = true;
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  DateTime _getTimeInTimezone(TimezoneType timezone) {
    final location = tz.getLocation(timezone.timezoneName);
    return tz.TZDateTime.from(_currentTime, location);
  }

  String _formatTime(DateTime dateTime) {
    return DateFormat('HH:mm:ss').format(dateTime);
  }

  void _showTimezonePicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: TimezoneType.values.map((tz) {
            final isSelected = _selectedTimezone == tz;
            return ListTile(
              leading: isSelected
                  ? Icon(Icons.check_circle, color: kAccent)
                  : const Icon(Icons.circle_outlined),
              title: Text(tz.displayName),
              subtitle: Text(tz.timezoneName),
              onTap: () {
                setState(() {
                  _selectedTimezone = tz;
                });
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timeInTimezone = _getTimeInTimezone(_selectedTimezone);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: kAccent.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: kAccent.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.access_time, color: kAccent, size: 18),
              const SizedBox(width: 8),
              Text(
                _formatTime(timeInTimezone),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: kAccent,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          InkWell(
            onTap: _showTimezonePicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: kAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: kAccent.withValues(alpha: 0.5), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _selectedTimezone.displayName,
                    style: const TextStyle(
                      color: kAccent,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down, color: kAccent, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
