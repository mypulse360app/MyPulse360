import '../../../../shared/mock/mock_database.dart';
import '../../../../shared/utils/date_formatters.dart';
import '../../../../shared/utils/id_generator.dart';
import '../../../../shared/utils/mock_latency.dart';
import '../../../prescriptions/domain/entities/prescription.dart';
import '../../domain/entities/chat_conversation.dart';
import '../../domain/entities/chat_message.dart';
import 'chatbot_datasource.dart';

/// Simple keyword-matching canned-response engine. No real NLU — this is a
/// mock backend, per the implementation plan's explicit deferral of a real
/// chatbot service.
class MockChatbotDataSource implements ChatbotDataSource {
  MockChatbotDataSource(this._db);

  final MockDatabase _db;

  @override
  ChatConversation getConversation(String patientId) {
    return _db.chatConversations.firstWhere(
      (c) => c.patientId == patientId,
      orElse: () {
        final convo = ChatConversation(id: generateId(), patientId: patientId, messages: const []);
        _db.chatConversations.add(convo);
        return convo;
      },
    );
  }

  @override
  Future<ChatMessage> sendMessage(String patientId, String text) async {
    final convo = getConversation(patientId);
    final userMessage = ChatMessage(
      id: generateId(),
      sender: ChatSender.user,
      text: text,
      timestamp: DateTime.now(),
    );
    _replaceConversation(convo.copyWith(messages: [...convo.messages, userMessage]));

    await simulateLatency();

    final reply = _generateReply(patientId, text);
    final refreshed = getConversation(patientId);
    _replaceConversation(refreshed.copyWith(messages: [...refreshed.messages, reply]));
    return reply;
  }

  void _replaceConversation(ChatConversation updated) {
    final i = _db.chatConversations.indexWhere((c) => c.id == updated.id);
    if (i == -1) {
      _db.chatConversations.add(updated);
    } else {
      _db.chatConversations[i] = updated;
    }
  }

  ChatMessage _generateReply(String patientId, String text) {
    final lower = text.toLowerCase();
    String reply;
    List<String> quickReplies = const [];

    if (lower.contains('tomorrow morning') || lower.contains('next week')) {
      reply = 'Great! Your appointment has been successfully booked.';
      return ChatMessage(
        id: generateId(),
        sender: ChatSender.assistant,
        text: reply,
        timestamp: DateTime.now(),
        actionType: 'booking_success',
      );
    } else if (lower.contains('book') && lower.contains('appointment')) {
      reply = 'When would you like to book your appointment for, and with which doctor?';
      quickReplies = const [
        'Tomorrow morning',
        'Next week',
      ];
    } else if (lower.contains('appointment')) {
      final upcoming = _db.appointments
          .where((a) => a.patientId == patientId && a.scheduledAt.isAfter(DateTime.now()))
          .toList()
        ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
      if (upcoming.isEmpty) {
        reply = "You don't have any upcoming appointments. Want to book one from the Appointments tab?";
      } else {
        final next = upcoming.first;
        final doctor = _db.userById(next.doctorId);
        reply =
            'Your next appointment is with ${doctor?.fullName ?? 'your doctor'} on '
            '${DateFormatters.full(next.scheduledAt)} at ${DateFormatters.time(next.scheduledAt)}.';
      }
    } else if (lower.contains('medication') || lower.contains('prescription') || lower.contains('rx')) {
      final active = _db.prescriptions
          .where((p) => p.patientId == patientId && p.status != PrescriptionStatus.expired)
          .toList();
      if (active.isEmpty) {
        reply = "You don't have any active prescriptions right now.";
      } else {
        final names = active.expand((p) => p.items.map((i) => '${i.medicationName} ${i.strength}')).join(', ');
        reply = 'Your current medications: $names.';
      }
      quickReplies = const ['Any side effects to watch for?'];
    } else if (lower.contains('headache') || lower.contains('pain') || lower.contains('symptom') || lower.contains('fever')) {
      reply =
          "I'm sorry you're not feeling well. For persistent or severe symptoms, please book an appointment "
          'so your doctor can take a look. In the meantime, rest and stay hydrated.';
      quickReplies = const ['Book an appointment'];
    } else if (lower.contains('thank')) {
      reply = "You're welcome! Let me know if there's anything else I can help with.";
    } else if (lower.contains('dark mode') || lower.contains('dark theme')) {
      reply = 'I have enabled dark mode for you!';
      return ChatMessage(
        id: generateId(),
        sender: ChatSender.assistant,
        text: reply,
        timestamp: DateTime.now(),
        actionType: 'enable_dark_mode',
      );
    } else if (lower.contains('light mode') || lower.contains('light theme')) {
      reply = 'I have switched back to light mode!';
      return ChatMessage(
        id: generateId(),
        sender: ChatSender.assistant,
        text: reply,
        timestamp: DateTime.now(),
        actionType: 'enable_light_mode',
      );
    } else if (lower.contains('setting') || lower.contains('profile')) {
      reply = 'I can help you navigate to your settings and profile page.';
      return ChatMessage(
        id: generateId(),
        sender: ChatSender.assistant,
        text: reply,
        timestamp: DateTime.now(),
        actionType: 'open_settings',
      );
    } else {
      reply =
          "I can help with questions about your appointments, medications, or general symptoms. "
          'You can also ask me to change settings, like "Turn on dark mode". '
          'What would you like to know?';
      quickReplies = const [
        'When is my next appointment?',
        'Turn on dark mode',
        'Open settings',
      ];
    }

    return ChatMessage(
      id: generateId(),
      sender: ChatSender.assistant,
      text: reply,
      timestamp: DateTime.now(),
      quickReplies: quickReplies,
    );
  }
}
