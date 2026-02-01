import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../../core/models/routine_model.dart';

class PomodoroTimerScreen extends StatefulWidget {
  final Routine? routine; // Optional, can be started without a specific routine

  const PomodoroTimerScreen({
    super.key,
    this.routine,
  });

  @override
  State<PomodoroTimerScreen> createState() => _PomodoroTimerScreenState();
}

class _PomodoroTimerScreenState extends State<PomodoroTimerScreen> {
  // Timer settings
  static const int focusTime = 25 * 60;
  static const int shortBreakTime = 5 * 60;
  static const int longBreakTime = 15 * 60;
  
  int _remainingSeconds = focusTime;
  int _targetSeconds = focusTime;
  Timer? _timer;
  
  bool _isRunning = false;
  PomodoroMode _mode = PomodoroMode.focus;
  int _completedSessions = 0;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggleTimer() {
    setState(() {
      _isRunning = !_isRunning;
      if (_isRunning) {
        _startTimer();
      } else {
        _timer?.cancel();
      }
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        _handleTimerComplete();
      }
    });
  }

  void _handleTimerComplete() {
    _timer?.cancel();
    HapticFeedback.heavyImpact();
    // Play sound here ideally

    setState(() {
      _isRunning = false;
      
      if (_mode == PomodoroMode.focus) {
        _completedSessions++;
        
        // Auto-switch to break
        if (_completedSessions % 4 == 0) {
          _mode = PomodoroMode.longBreak;
          _targetSeconds = longBreakTime;
        } else {
          _mode = PomodoroMode.shortBreak;
          _targetSeconds = shortBreakTime;
        }
        
        _showNotification('Focus session complete!', 'Time for a break.');
      } else {
        // Back to focus
        _mode = PomodoroMode.focus;
        _targetSeconds = focusTime;
        
        _showNotification('Break over!', 'Ready to focus again?');
      }
      
      _remainingSeconds = _targetSeconds;
    });
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _remainingSeconds = _targetSeconds;
    });
  }

  void _changeMode(PomodoroMode newMode) {
    _timer?.cancel();
    setState(() {
      _mode = newMode;
      _isRunning = false;
      
      switch (newMode) {
        case PomodoroMode.focus:
          _targetSeconds = focusTime;
          break;
        case PomodoroMode.shortBreak:
          _targetSeconds = shortBreakTime;
          break;
        case PomodoroMode.longBreak:
          _targetSeconds = longBreakTime;
          break;
      }
      
      _remainingSeconds = _targetSeconds;
    });
  }

  void _showNotification(String title, String body) {
    // In a real app, trigger local notification here
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$title $body'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Color _getModeColor() {
    switch (_mode) {
      case PomodoroMode.focus:
        return Colors.redAccent;
      case PomodoroMode.shortBreak:
        return Colors.teal;
      case PomodoroMode.longBreak:
        return Colors.blueAccent;
    }
  }

  String _getModeTitle() {
    switch (_mode) {
      case PomodoroMode.focus:
        return 'Focus';
      case PomodoroMode.shortBreak:
        return 'Short Break';
      case PomodoroMode.longBreak:
        return 'Long Break';
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = 1 - (_remainingSeconds / _targetSeconds);
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    final modeColor = _getModeColor();

    return Scaffold(
      backgroundColor: Colors.grey[50], // Light background
      appBar: AppBar(
        title: const Text('Pomodoro Timer'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
      ),
      body: Column(
        children: [
          // Mode toggle tabs
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildModeButton(PomodoroMode.focus, 'Focus'),
                const SizedBox(width: 12),
                _buildModeButton(PomodoroMode.shortBreak, 'Short Break'),
                const SizedBox(width: 12),
                _buildModeButton(PomodoroMode.longBreak, 'Long Break'),
              ],
            ),
          ),

          const Spacer(),

          // Timer display
          SizedBox(
            width: 300,
            height: 300,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Background circle
                SizedBox(
                  width: 300,
                  height: 300,
                  child: CircularProgressIndicator(
                    value: 1.0,
                    strokeWidth: 20,
                    color: Colors.grey[200],
                  ),
                ),
                // Progress circle
                SizedBox(
                  width: 300,
                  height: 300,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 20,
                    color: modeColor,
                    strokeCap: StrokeCap.round,
                  ),
                ),
                // Timer text
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 72,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      _getModeTitle(),
                      style: TextStyle(
                        fontSize: 20,
                        color: Colors.grey[600],
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Session counter
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Sessions completed: $_completedSessions',
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
              ),
              if (_completedSessions > 0 && _completedSessions % 4 == 0)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(Icons.star, color: Colors.amber, size: 20),
                ),
            ],
          ),

          const Spacer(),

          // Routine info (if passed)
          if (widget.routine != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Chip(
                avatar: const Icon(Icons.task_alt, size: 18),
                label: Text('Working on: ${widget.routine!.name}'),
              ),
            ),

          // Control buttons
          Padding(
            padding: const EdgeInsets.only(bottom: 48),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Reset button
                FloatingActionButton(
                  heroTag: 'reset',
                  onPressed: _resetTimer,
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.grey[700],
                  elevation: 2,
                  child: const Icon(Icons.refresh),
                ),
                const SizedBox(width: 32),
                
                // Play/Pause button
                FloatingActionButton.large(
                  heroTag: 'play',
                  onPressed: _toggleTimer,
                  backgroundColor: modeColor,
                  child: Icon(
                    _isRunning ? Icons.pause : Icons.play_arrow,
                    size: 48,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton(PomodoroMode mode, String label) {
    final isSelected = _mode == mode;
    return InkWell(
      onTap: () => _changeMode(mode),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? _getModeColor().withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? _getModeColor() : Colors.grey[300]!,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? _getModeColor() : Colors.grey[600],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

enum PomodoroMode {
  focus,
  shortBreak,
  longBreak,
}
