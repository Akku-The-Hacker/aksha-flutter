import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

enum PomodoroPhase {
  work,
  shortBreak,
  longBreak,
}

class PomodoroTimerScreen extends StatefulWidget {
  const PomodoroTimerScreen({super.key});

  @override
  State<PomodoroTimerScreen> createState() => _PomodoroTimerScreenState();
}

class _PomodoroTimerScreenState extends State<PomodoroTimerScreen> {
  // Settings
  int _workMinutes = 25;
  int _shortBreakMinutes = 5;
  int _longBreakMinutes = 15;
  int _sessionsUntilLongBreak = 4;

  // State
  PomodoroPhase _currentPhase = PomodoroPhase.work;
  int _remainingSeconds = 25 * 60;
  int _completedSessions = 0;
  Timer? _timer;
  bool _isPaused = true;
  bool _showSettings = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    setState(() => _isPaused = false);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        _completePhase();
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() => _isPaused = true);
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _isPaused = true;
      _remainingSeconds = _getPhaseMinutes(_currentPhase) * 60;
    });
  }

  void _completePhase() {
    _timer?.cancel();
    
    // Vibrate on completion
    HapticFeedback.heavyImpact();

    setState(() {
      if (_currentPhase == PomodoroPhase.work) {
        _completedSessions++;
        
        // Determine next break type
        if (_completedSessions % _sessionsUntilLongBreak == 0) {
          _currentPhase = PomodoroPhase.longBreak;
        } else {
          _currentPhase = PomodoroPhase.shortBreak;
        }
      } else {
        // Break completed, back to work
        _currentPhase = PomodoroPhase.work;
      }
      
      _remainingSeconds = _getPhaseMinutes(_currentPhase) * 60;
      _isPaused = true;
    });

    _showPhaseCompleteDialog();
  }

  void _showPhaseCompleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_currentPhase == PomodoroPhase.work ? '🎯 Ready to Focus?' : '☕ Time for a Break!'),
        content: Text(
          _currentPhase == PomodoroPhase.work
              ? 'Your break is over. Ready to start the next work session?'
              : 'Great work! Time to take a ${_currentPhase == PomodoroPhase.longBreak ? 'long' : 'short'} break.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _startTimer();
            },
            child: const Text('Start'),
          ),
        ],
      ),
    );
  }

  int _getPhaseMinutes(PomodoroPhase phase) {
    switch (phase) {
      case PomodoroPhase.work:
        return _workMinutes;
      case PomodoroPhase.shortBreak:
        return _shortBreakMinutes;
      case PomodoroPhase.longBreak:
        return _longBreakMinutes;
    }
  }

  Color _getPhaseColor(PomodoroPhase phase) {
    switch (phase) {
      case PomodoroPhase.work:
        return Colors.red;
      case PomodoroPhase.shortBreak:
        return Colors.green;
      case PomodoroPhase.longBreak:
        return Colors.blue;
    }
  }

  String _getPhaseName(PomodoroPhase phase) {
    switch (phase) {
      case PomodoroPhase.work:
        return 'Focus Time';
      case PomodoroPhase.shortBreak:
        return 'Short Break';
      case PomodoroPhase.longBreak:
        return 'Long Break';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showSettings) {
      return _buildSettingsScreen();
    }

    final phaseColor = _getPhaseColor(_currentPhase);
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    final totalSeconds = _getPhaseMinutes(_currentPhase) * 60;
    final progress = 1 - (_remainingSeconds / totalSeconds);

    return Scaffold(
      appBar: AppBar(
        title: const Text('🍅 Pomodoro Timer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => setState(() => _showSettings = true),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Phase indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: phaseColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                _getPhaseName(_currentPhase),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: phaseColor,
                ),
              ),
            ),

            const SizedBox(height: 48),

            // Circular timer
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
                      strokeWidth: 16,
                      backgroundColor: Colors.grey[200],
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.grey),
                    ),
                  ),
                  // Progress circle
                  SizedBox(
                    width: 300,
                    height: 300,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 16,
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation<Color>(phaseColor),
                    ),
                  ),
                  // Timer text
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          fontSize: 72,
                          fontWeight: FontWeight.bold,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      if (_isPaused)
                        Text(
                          'PAUSED',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 48),

            // Session counter
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  '$_completedSessions session${_completedSessions != 1 ? 's' : ''} completed',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Control buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Reset button
                FloatingActionButton(
                  onPressed: _resetTimer,
                  backgroundColor: Colors.grey,
                  child: const Icon(Icons.refresh),
                ),
                const SizedBox(width: 16),
                // Play/Pause button
                FloatingActionButton.large(
                  onPressed: _isPaused ? _startTimer : _pauseTimer,
                  backgroundColor: phaseColor,
                  child: Icon(
                    _isPaused ? Icons.play_arrow : Icons.pause,
                    size: 36,
                  ),
                ),
                const SizedBox(width: 16),
                // Skip button
                FloatingActionButton(
                  onPressed: _completePhase,
                  backgroundColor: Colors.orange,
                  child: const Icon(Icons.skip_next),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pomodoro Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() => _showSettings = false),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSettingTile(
            'Work Duration',
            _workMinutes,
            (value) => setState(() {
              _workMinutes = value;
              if (_currentPhase == PomodoroPhase.work && _isPaused) {
                _remainingSeconds = _workMinutes * 60;
              }
            }),
          ),
          _buildSettingTile(
            'Short Break',
            _shortBreakMinutes,
            (value) => setState(() {
              _shortBreakMinutes = value;
              if (_currentPhase == PomodoroPhase.shortBreak && _isPaused) {
                _remainingSeconds = _shortBreakMinutes * 60;
              }
            }),
          ),
          _buildSettingTile(
            'Long Break',
            _longBreakMinutes,
            (value) => setState(() {
              _longBreakMinutes = value;
              if (_currentPhase == PomodoroPhase.longBreak && _isPaused) {
                _remainingSeconds = _longBreakMinutes * 60;
              }
            }),
          ),
          _buildSettingTile(
            'Sessions Until Long Break',
            _sessionsUntilLongBreak,
            (value) => setState(() => _sessionsUntilLongBreak = value),
            min: 2,
            max: 8,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _completedSessions = 0;
                _currentPhase = PomodoroPhase.work;
                _remainingSeconds = _workMinutes * 60;
                _isPaused = true;
                _showSettings = false;
              });
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Reset Session'),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile(
    String title,
    int value,
    Function(int) onChanged, {
    int min = 1,
    int max = 60,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  '$value min',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Slider(
              value: value.toDouble(),
              min: min.toDouble(),
              max: max.toDouble(),
              divisions: max - min,
              onChanged: (newValue) => onChanged(newValue.toInt()),
            ),
          ],
        ),
      ),
    );
  }
}
