import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Pour le HapticFeedback
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../main.dart';
import '../../domain/entities/ble_message.dart';
import '../bloc/chat_bloc.dart';
import '../bloc/chat_event.dart';
import '../bloc/chat_state.dart';
import '../../../../core/services/audio_service.dart';
import '../widgets/audio_player_widget.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AudioService _audioService = AudioService();

  bool _isRecording = false;
  double _dragOffset = 0.0;
  final double _cancelThreshold = 100.0;
  bool _hasVibratedForCancel = false;

  late AnimationController _micAnimController;

  @override
  void initState() {
    super.initState();
    context.read<ChatBloc>().add(InitChatEvent());

    _micAnimController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 600),
          lowerBound: 1.0,
          upperBound: 1.4,
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) _micAnimController.reverse();
          if (status == AnimationStatus.dismissed) _micAnimController.forward();
        });
  }

  @override
  void dispose() {
    _audioService.dispose();
    _micAnimController.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // --- Logique Audio avec Annulation et Haptique ---

  void _onLongPressStart(_) async {
    if (await _audioService.hasPermission()) {
      final path = await _audioService.startRecording();
      if (path != null) {
        HapticFeedback.mediumImpact(); // Vibration au début
        setState(() {
          _isRecording = true;
          _dragOffset = 0.0;
          _hasVibratedForCancel = false;
        });
        _micAnimController.forward();
      }
    }
  }

  void _onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    if (!_isRecording) return;

    setState(() {
      _dragOffset = details.localOffsetFromOrigin.dx;
    });

    // Vibration unique quand on dépasse le seuil d'annulation
    if (_dragOffset.abs() > _cancelThreshold && !_hasVibratedForCancel) {
      HapticFeedback.heavyImpact();
      _hasVibratedForCancel = true;
    } else if (_dragOffset.abs() < _cancelThreshold && _hasVibratedForCancel) {
      _hasVibratedForCancel = false;
    }
  }

  void _onLongPressEnd(LongPressEndDetails details) async {
    if (!_isRecording) return;

    final path = await _audioService.stopRecording();

    _micAnimController.reset();
    _micAnimController.stop();

    if (_dragOffset.abs() > _cancelThreshold) {
      // Annulation
      HapticFeedback.vibrate();
      setState(() => _isRecording = false);
    } else {
      // Envoi
      setState(() => _isRecording = false);
      if (path != null) {
        context.read<ChatBloc>().add(SendAudioMessageEvent(path));
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const primaryBlue = Color(0xFF0055FF);

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F0F10)
          : const Color(0xFFF8F9FB),
      appBar: _buildAppBar(isDark, primaryBlue),
      body: Column(
        children: [
          Expanded(
            child: BlocBuilder<ChatBloc, ChatState>(
              builder: (context, state) {
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  reverse: true,
                  itemCount: state.messages.length,
                  itemBuilder: (context, index) => _buildModernBubble(
                    state.messages[index],
                    isDark,
                    primaryBlue,
                  ),
                );
              },
            ),
          ),
          if (_isRecording) _buildRecordingIndicator(),
          _buildModernInput(isDark, primaryBlue),
        ],
      ),
    );
  }

  Widget _buildRecordingIndicator() {
    bool isCancelling = _dragOffset.abs() > (_cancelThreshold / 2);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.circle,
            color: isCancelling ? Colors.grey : Colors.red,
            size: 10,
          ),
          const SizedBox(width: 8),
          Text(
            isCancelling ? "RELACHEZ POUR ANNULER" : "ENREGISTREMENT...",
            style: TextStyle(
              color: isCancelling ? Colors.grey : Colors.red,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernInput(bool isDark, Color primary) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15),
          ],
        ),
        child: Row(
          children: [
            GestureDetector(
              onLongPressStart: _onLongPressStart,
              onLongPressMoveUpdate: _onLongPressMoveUpdate,
              onLongPressEnd: _onLongPressEnd,
              child: ScaleTransition(
                scale: _micAnimController,
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
            ),
            Expanded(
              child: _isRecording
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Opacity(
                        opacity: (1 - (_dragOffset.abs() / _cancelThreshold))
                            .clamp(0.0, 1.0),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.arrow_back_ios,
                              size: 12,
                              color: Colors.grey,
                            ),
                            Text(
                              " Glisser pour annuler",
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    )
                  : TextField(
                      controller: _controller,
                      onSubmitted: (_) => _sendMessage(),
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      decoration: const InputDecoration(
                        hintText: "Type Here...",
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
            ),
            if (!_isRecording)
              IconButton(
                onPressed: _sendMessage,
                icon: Icon(Icons.send_rounded, color: primary),
              ),
          ],
        ),
      ),
    );
  }

  // --- UI Helpers ---

  AppBar _buildAppBar(bool isDark, Color primaryBlue) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new,
          size: 20,
          color: isDark ? Colors.white : Colors.black,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        children: [
          Text(
            "ESP32 Terminal",
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Text(
            "Online",
            style: TextStyle(color: Colors.green, fontSize: 12),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(
            isDark ? Icons.light_mode : Icons.dark_mode,
            color: primaryBlue,
          ),
          onPressed: () =>
              themeNotifier.value = isDark ? ThemeMode.light : ThemeMode.dark,
        ),
      ],
    );
  }

  Widget _buildModernBubble(BleMessage msg, bool isDark, Color primary) {
    final isMe = msg.isFromMe;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.only(
              top: 4,
              bottom: 4,
              left: isMe ? 50 : 0,
              right: isMe ? 0 : 50,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isMe
                  ? primary
                  : (isDark ? const Color(0xFF1C1C1E) : Colors.white),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isMe ? 18 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 18),
              ),
            ),
            child: msg.type == MessageType.audio
                ? AudioPlayerWidget(url: msg.text, isMe: isMe)
                : Text(
                    msg.text,
                    style: TextStyle(
                      color: isMe
                          ? Colors.white
                          : (isDark ? Colors.white : Colors.black87),
                      fontSize: 15,
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 4, right: 4),
            child: Text(
              "${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}",
              style: const TextStyle(color: Colors.grey, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    print(
      "🔤 _sendMessage appelée avec: '${_controller.text}' -> trim: '$text'",
    );
    if (text.isNotEmpty) {
      print("📤 Envoi event SendTextMessageEvent: '$text'");
      context.read<ChatBloc>().add(SendTextMessageEvent(text));
      _controller.clear();
      print("🧹 Champ de texte effacé");
      _scrollToBottom();
    } else {
      print("⚠️ Texte vide après trim, pas d'envoi");
    }
  }
}
