import 'package:flutter_riverpod/flutter_riverpod.dart';

class ClinicPing {
  const ClinicPing({
    required this.message,
    required this.timestamp,
  });
  final String message;
  final DateTime timestamp;
}

class PingNotifier extends StateNotifier<ClinicPing?> {
  PingNotifier() : super(null);

  void sendPing(String message) {
    state = ClinicPing(
      message: message,
      timestamp: DateTime.now(),
    );
  }
  
  void clearPing() {
    state = null;
  }
}

final pingProvider = StateNotifierProvider<PingNotifier, ClinicPing?>((ref) {
  return PingNotifier();
});
