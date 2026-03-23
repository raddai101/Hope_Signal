import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef OnAudioRecorded = void Function(String audioPath);

class AudioRecorderWidget extends StatefulWidget {
  final OnAudioRecorded onAudioRecorded;
  final Future<String?> Function() startRecording;
  final Future<String?> Function() stopRecording;

  const AudioRecorderWidget({
    required this.onAudioRecorded,
    required this.startRecording,
    required this.stopRecording,
    Key? key,
  }) : super(key: key);

  @override
  State<AudioRecorderWidget> createState() => _AudioRecorderWidgetState();
}

class _AudioRecorderWidgetState extends State<AudioRecorderWidget>
    with SingleTickerProviderStateMixin {
  bool _isRecording = false;
  double _dragOffset = 0.0;
  final double _cancelThreshold = 100.0;
  bool _hasVibratedForCancel = false;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 600),
          lowerBound: 1.0,
          upperBound: 1.4,
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) _animController.reverse();
          if (status == AnimationStatus.dismissed) _animController.forward();
        });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onLongPressStart(_) async {
    final path = await widget.startRecording();
    if (path != null) {
      HapticFeedback.mediumImpact();
      setState(() {
        _isRecording = true;
        _dragOffset = 0.0;
        _hasVibratedForCancel = false;
      });
      _animController.forward();
    }
  }

  void _onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    if (!_isRecording) return;
    setState(() => _dragOffset = details.localOffsetFromOrigin.dx);

    if (_dragOffset.abs() > _cancelThreshold && !_hasVibratedForCancel) {
      HapticFeedback.heavyImpact();
      _hasVibratedForCancel = true;
    } else if (_dragOffset.abs() < _cancelThreshold && _hasVibratedForCancel) {
      _hasVibratedForCancel = false;
    }
  }

  void _onLongPressEnd(LongPressEndDetails _) async {
    if (!_isRecording) return;

    final path = await widget.stopRecording();
    _animController.reset();
    _animController.stop();
    setState(() => _isRecording = false);

    if (_dragOffset.abs() > _cancelThreshold) {
      HapticFeedback.vibrate();
      // Annulation, ne pas envoyer
    } else if (path != null) {
      widget.onAudioRecorded(path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: _onLongPressStart,
      onLongPressMoveUpdate: _onLongPressMoveUpdate,
      onLongPressEnd: _onLongPressEnd,
      child: ScaleTransition(
        scale: _animController,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Icon(
            _isRecording ? Icons.mic_rounded : Icons.mic_none_rounded,
            color: _isRecording
                ? (_dragOffset.abs() > _cancelThreshold
                      ? Colors.grey
                      : Colors.red)
                : Colors.grey.shade500,
            size: 26,
          ),
        ),
      ),
    );
  }
}
