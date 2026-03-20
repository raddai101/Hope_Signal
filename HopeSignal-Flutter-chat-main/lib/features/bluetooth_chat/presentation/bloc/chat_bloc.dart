import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/ble_repository.dart';
import 'chat_event.dart';
import 'chat_state.dart';
import '../../domain/entities/ble_message.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final BleRepository repository;
  StreamSubscription? _messageSubscription;

  ChatBloc(this.repository) : super(ChatState()) {
    // 1. Initialisation du Chat et écoute du flux Bluetooth
    on<InitChatEvent>((event, emit) {
      _messageSubscription?.cancel();
      _messageSubscription = repository.messagesStream.listen((messages) {
        // Si le repository renvoie une liste, on ajoute chaque message au flux du Bloc
        for (var msg in messages) {
          add(OnMessageReceivedEvent(msg));
        }
      });
      emit(state.copyWith(isReady: true));
    });

    // 2. Envoi d'un message TEXTE (Bluetooth + UI)
    on<SendTextMessageEvent>((event, emit) async {
      if (event.text.isNotEmpty) {
        try {
          // Envoi réel via le repository (Bluetooth/ESP32)
          await repository.sendMessage(event.text);

          final myMsg = BleMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            text: event.text,
            timestamp: DateTime.now(),
            isFromMe: true,
            type: MessageType.text,
          );

          // Mise à jour de l'UI
          emit(state.copyWith(messages: [myMsg, ...state.messages]));
        } catch (e) {
          emit(state.copyWith(error: "Échec de l'envoi : $e"));
        }
      }
    });

    // 3. Envoi d'un message AUDIO (avec compression + fragmentation + ACK/NAK + CRC)
    on<SendAudioMessageEvent>((event, emit) async {
      final audioMsg = BleMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: event
            .path, // Le chemin local du fichier .m4a, utilisé pour playback
        timestamp: DateTime.now(),
        isFromMe: true,
        type: MessageType.audio,
      );

      emit(state.copyWith(messages: [audioMsg, ...state.messages]));

      try {
        await repository.sendAudioFile(event.path);
      } catch (e) {
        emit(state.copyWith(error: "Échec envoi audio : $e"));
      }
    });

    // 4. Réception d'un nouveau message (depuis le stream)
    on<OnMessageReceivedEvent>((event, emit) {
      emit(state.copyWith(messages: [event.message, ...state.messages]));
    });
  }

  @override
  Future<void> close() {
    _messageSubscription?.cancel();
    return super.close();
  }
}
