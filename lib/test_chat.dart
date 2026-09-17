// ignore_for_file: avoid_print
import 'package:mypulse360/features/chatbot/data/utils/chat_reply_engine.dart';
import 'package:mypulse360/features/chatbot/domain/entities/chat_message.dart';

void main() {
  final m1 = ChatMessage(id: '1', sender: ChatSender.user, text: 'Book appointment', timestamp: DateTime.now());
  final m2 = ChatMessage(id: '2', sender: ChatSender.assistant, text: 'Sure, I can help you book an appointment. Would you like to come in today or tomorrow?', timestamp: DateTime.now());
  final m3 = ChatMessage(id: '3', sender: ChatSender.user, text: 'Tomorrow', timestamp: DateTime.now());

  final history = [m1, m2, m3];

  final reply = generateChatReply(
    history: history,
    upcomingAppointments: [],
    activeMedications: [],
  );

  print('Reply text: ${reply.text}');
}
