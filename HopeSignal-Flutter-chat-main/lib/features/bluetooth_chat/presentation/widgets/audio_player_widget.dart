import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class AudioPlayerWidget extends StatefulWidget {
  final String url; // Le chemin du fichier (msg.text)
  final bool isMe; // Pour adapter les couleurs

  const AudioPlayerWidget({super.key, required this.url, required this.isMe});

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();

    // Configuration des écouteurs (Listeners)
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() => _isPlaying = state == PlayerState.playing);
      }
    });

    _audioPlayer.onDurationChanged.listen((newDuration) {
      if (mounted) setState(() => _duration = newDuration);
    });

    _audioPlayer.onPositionChanged.listen((newPosition) {
      if (mounted) setState(() => _position = newPosition);
    });

    // Remise à zéro quand le son est fini
    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          _position = Duration.zero;
          _isPlaying = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose(); // Très important pour libérer la mémoire
    super.dispose();
  }

  void _playPause() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      // On utilise DeviceFileSource car le fichier est stocké localement sur le téléphone
      await _audioPlayer.play(DeviceFileSource(widget.url));
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = widget.isMe ? Colors.white : const Color(0xFF0055FF);
    final textColor = widget.isMe
        ? Colors.white.withOpacity(0.8)
        : Colors.grey.shade600;

    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Bouton Play/Pause
          GestureDetector(
            onTap: _playPause,
            child: Icon(
              _isPlaying
                  ? Icons.pause_circle_filled_rounded
                  : Icons.play_circle_filled_rounded,
              color: accentColor,
              size: 38,
            ),
          ),
          const SizedBox(width: 8),

          // Slider et Temps
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    // Barre de fond
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    // Barre de progression
                    FractionallySizedBox(
                      widthFactor: _duration.inMilliseconds > 0
                          ? (_position.inMilliseconds /
                                    _duration.inMilliseconds)
                                .clamp(0.0, 1.0)
                          : 0.0,
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: accentColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(_position),
                      style: TextStyle(color: textColor, fontSize: 10),
                    ),
                    if (_duration != Duration.zero)
                      Text(
                        _formatDuration(_duration),
                        style: TextStyle(color: textColor, fontSize: 10),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
