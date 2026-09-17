import '../../../../config/env/env.dart';
import '../../../../shared/mock/mock_ids.dart';
import '../../../../shared/utils/date_formatters.dart';
import '../../domain/entities/chat_message.dart';

/// The appointment data the reply engine needs, pre-resolved by the caller's
/// backend so the engine itself stays network-free.
class AppointmentContext {
  const AppointmentContext({required this.scheduledAt, required this.doctorName});

  final DateTime scheduledAt;
  final String doctorName;
}

/// A generated assistant reply, still neutral about where it gets persisted.
class ChatReply {
  const ChatReply({
    required this.text,
    this.quickReplies = const [],
    this.actionType,
    this.bookingDoctorId,
    this.bookingDateTime,
  });

  final String text;
  final List<String> quickReplies;

  /// Drives a one-shot UI action on the client (booking-success overlay,
  /// theme switch, settings navigation) — never persisted.
  final String? actionType;

  final String? bookingDoctorId;
  final DateTime? bookingDateTime;
}

/// The raw text of a user message plus the patient's live appointment /
/// medication state becomes a canned reply. `upcomingAppointments` is expected
/// sorted soonest-first; only the first (next) one is shown. This keeps the
/// keyword rules identical between the mock backend and Supabase — the two
/// datasources just feed different context.

ChatReply generateChatReply({
  required List<ChatMessage> history,
  required List<AppointmentContext> upcomingAppointments,
  required List<String> activeMedications,
}) {
  // Find the most recent user message by looking for the one with the latest timestamp
  // or just grabbing the last user message in the list.
  final userMessages = history.where((m) => m.sender == ChatSender.user).toList();
  if (userMessages.isEmpty) {
    return const ChatReply(text: "Hello! How can I help you?");
  }
  
  // Sort user messages by timestamp to ensure we get the latest one
  userMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
  final text = userMessages.last.text;
  final lower = text.toLowerCase();

  if (lower.contains('book') && lower.contains('appointment')) {
    return const ChatReply(
      text: 'Sure, I can help you book an appointment. Would you like to come in today or tomorrow?',
      quickReplies: ['Today', 'Tomorrow'],
    );
  } else if (lower.contains('today') || lower.contains('tomorrow')) {
    final isToday = lower.contains('today');
    // Compute current time in Malaysia (UTC+8)
    final nowUtc = DateTime.now().toUtc();
    final malaysiaTime = nowUtc.add(const Duration(hours: 8));

    List<String> replies = ['Morning', 'Afternoon'];
    
    if (isToday) {
      if (malaysiaTime.hour >= 12) {
        replies = ['Afternoon'];
      }
    }

    return ChatReply(
      text: replies.length == 1 
          ? 'Got it. Since it is already ${replies[0].toLowerCase()}, what time would you prefer?' 
          : 'Got it. And what time would you prefer?',
      quickReplies: replies,
    );
  } else if (lower.contains('morning') || lower.contains('afternoon')) {
    // Determine if they picked today
    bool isToday = false;
    for (var i = userMessages.length - 1; i >= 0; i--) {
      final msg = userMessages[i].text.toLowerCase();
      if (msg.contains('today')) {
        isToday = true;
        break;
      } else if (msg.contains('tomorrow')) {
        break;
      }
    }

    final nowUtc = DateTime.now().toUtc();
    final malaysiaTime = nowUtc.add(const Duration(hours: 8));

    bool isMorning = lower.contains('morning');
    int suggestHour = isMorning ? 9 : 14; // 9 AM or 2 PM
    int altHour = isMorning ? 10 : 15; // 10 AM or 3 PM

    if (isToday) {
      // Ensure at least a 30-minute buffer
      int nextAvailableHour = malaysiaTime.hour + 1;
      if (malaysiaTime.minute > 30) {
        nextAvailableHour = malaysiaTime.hour + 2;
      }

      if (nextAvailableHour > suggestHour) {
        suggestHour = nextAvailableHour;
        altHour = suggestHour + 1;
      }
    }
    
    // Ensure we don't suggest a time past 5 PM for afternoon, unless the buffer forces us to
    if (!isMorning && suggestHour > 17 && !isToday) {
      suggestHour = 17;
      altHour = 18;
    } else if (isToday && suggestHour > 17 && malaysiaTime.hour < 17) {
      suggestHour = 17;
      altHour = 18;
    }

    String formatTime(int h) {
      final period = h >= 12 ? 'PM' : 'AM';
      final hour12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
      return '$hour12:00 $period';
    }

    final timeStr = formatTime(suggestHour);
    final altTimeStr = formatTime(altHour);

    return ChatReply(
      text: 'What time would you like to book? I suggest $timeStr as there are fewer people booked and the doctor can see you as soon as possible.',
      quickReplies: [timeStr, altTimeStr],
    );
  } else if (lower.contains('am') || lower.contains('pm')) {
    return const ChatReply(
      text: 'Okay. Which doctor would you like to see?',
      quickReplies: ['Dr. Ahmed Rashid', 'Dr. Lina Fernandez'],
    );
  } else if (lower.contains('rashid') || lower.contains('fernandez')) {
    // Try to find the time and day from previous messages
    String day = 'an upcoming date';
    String time = 'a time';
    
    for (var i = userMessages.length - 1; i >= 0; i--) {
      final msg = userMessages[i].text.toLowerCase();
      if ((msg.contains('today') || msg.contains('tomorrow')) && day == 'an upcoming date') {
        day = userMessages[i].text;
      }
      if ((msg.contains('am') || msg.contains('pm') || msg.contains('morning') || msg.contains('afternoon')) && time == 'a time') {
        time = userMessages[i].text;
      }
    }

    final isRashid = lower.contains('rashid');
    final doctorId = isRashid 
        ? (Env.isMockMode ? MockIds.drAhmedDoctorId : '22222222-2222-2222-2222-222222222221')
        : (Env.isMockMode ? 'user-dr-lina' : '22222222-2222-2222-2222-222222222222');
    final doctor = lower.contains('rashid') ? 'Dr. Ahmed Rashid' : 'Dr. Lina Fernandez';

    // Compute DateTime
    DateTime scheduledDate = DateTime.now();
    if (day.toLowerCase().contains('tomorrow')) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    
    int hour = 9; // Default 9 AM
    int minute = 0;
    
    final timeMatch = RegExp(r'(\d+):(\d+)\s*(am|pm)').firstMatch(time.toLowerCase());
    if (timeMatch != null) {
      hour = int.parse(timeMatch.group(1)!);
      minute = int.parse(timeMatch.group(2)!);
      if (timeMatch.group(3) == 'pm' && hour < 12) hour += 12;
      if (timeMatch.group(3) == 'am' && hour == 12) hour = 0;
    } else if (time.toLowerCase().contains('afternoon') || time.toLowerCase().contains('pm')) {
      hour = 14; // Default 2 PM
    }
    
    final finalDateTime = DateTime(
      scheduledDate.year, 
      scheduledDate.month, 
      scheduledDate.day, 
      hour, 
      minute
    );

    return ChatReply(
      text: 'Great! Your appointment with $doctor has been successfully booked for $day, $time.',
      actionType: 'booking_success',
      bookingDoctorId: doctorId,
      bookingDateTime: finalDateTime,
    );
  } else if (lower.contains('appointment')) {
    if (upcomingAppointments.isEmpty) {
      return const ChatReply(
        text:
            "You don't have any upcoming appointments. Want to book one from the Appointments tab?",
      );
    }
    final next = upcomingAppointments.first;
    return ChatReply(
      text:
          'Your next appointment is with ${next.doctorName} on '
          '${DateFormatters.full(next.scheduledAt)} at ${DateFormatters.time(next.scheduledAt)}.',
    );
  } else if (lower.contains('medication') ||
      lower.contains('prescription') ||
      lower.contains('rx')) {
    if (activeMedications.isEmpty) {
      return const ChatReply(
        text: "You don't have any active prescriptions right now.",
      );
    }
    return ChatReply(
      text: 'Your current medications: ${activeMedications.join(', ')}.',
      quickReplies: const ['Any side effects to watch for?'],
    );
  } else if (lower.contains('headache') ||
      lower.contains('pain') ||
      lower.contains('symptom') ||
      lower.contains('fever')) {
    return const ChatReply(
      text:
          "I'm sorry you're not feeling well. For persistent or severe symptoms, please book an "
          'appointment so your doctor can take a look. In the meantime, rest and stay hydrated.',
      quickReplies: ['Book an appointment'],
    );
  } else if (lower.contains('thank')) {
    return const ChatReply(
      text: "You're welcome! Let me know if there's anything else I can help with.",
    );
  } else if (lower.contains('dark mode') || lower.contains('dark theme')) {
    return const ChatReply(
      text: 'I have enabled dark mode for you!',
      actionType: 'enable_dark_mode',
    );
  } else if (lower.contains('light mode') || lower.contains('light theme')) {
    return const ChatReply(
      text: 'I have switched back to light mode!',
      actionType: 'enable_light_mode',
    );
  } else if (lower.contains('setting') || lower.contains('profile')) {
    return const ChatReply(
      text: 'I can help you navigate to your settings and profile page.',
      actionType: 'open_settings',
    );
  } else {
    return const ChatReply(
      text:
          "I can help with questions about your appointments, medications, or general symptoms. "
          'You can also ask me to change settings, like "Turn on dark mode". '
          'What would you like to know?',
      quickReplies: ['When is my next appointment?', 'Turn on dark mode', 'Open settings'],
    );
  }
}