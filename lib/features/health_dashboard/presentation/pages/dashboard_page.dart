import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../config/router/route_paths.dart';
import '../../../../shared/utils/spring_curve.dart';
import '../../../../config/theme/app_theme.dart';
import '../../../../shared/presentation/widgets/async_section.dart';
import '../../../../shared/utils/date_formatters.dart';
import '../../../appointments/presentation/pages/book_appointment_page.dart';
import '../../../appointments/domain/entities/appointment.dart';
import '../../../appointments/presentation/pages/reschedule_page.dart';
import '../../../appointments/presentation/providers/appointments_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../patient/presentation/providers/patient_providers.dart';
import '../../../appointments/presentation/widgets/queue_status_view.dart';
import '../../../health_tips/data/health_tips_data.dart';
import '../../../health_tips/presentation/widgets/health_tip_card.dart';
import '../providers/health_dashboard_providers.dart';
import '../widgets/next_appointment_banner.dart';
import '../../../prescriptions/presentation/providers/prescriptions_providers.dart';
import '../../../prescriptions/domain/entities/prescription.dart';

/// P4 — Patient Dashboard: two big hero actions (Book Appointment,
/// Prescriptions) up top, a Health Tips strip, then next-appointment/
/// reminders. Health Overview is no longer featured here.
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();

    final profileAsync = ref.watch(patientProfileProvider(user.id));
    final nextAppointment = ref
        .watch(nextUpcomingAppointmentProvider(user.id))
        .valueOrNull;
    final availableDoctors = ref.watch(availableDoctorsProvider).valueOrNull ?? [];
    final doctor = nextAppointment == null
        ? null
        : availableDoctors.where((d) => d.id == nextAppointment.doctorId).firstOrNull;
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Good morning'
        : (now.hour < 18 ? 'Good afternoon' : 'Good evening');
    final firstName = user.fullName.split(' ').first;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$greeting, $firstName',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormatters.full(now),
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ].animate().fadeIn(duration: 600.ms, curve: AppleSpringCurve()).slideY(begin: 0.2),
            ),
            const SizedBox(height: 20),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                  child: _HeroActionCard(
                    emoji: '📅',
                    title: 'Book\nAppointments',
                    subtitle: 'Schedule your next visit',
                    background: const Color(0xFF5B17B1), // Vibrant Purple
                    onTap: () => Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute(
                        builder: (_) => const BookAppointmentPage(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _HeroActionCard(
                    emoji: '💊',
                    title: 'Prescriptions',
                    subtitle: 'View your medications',
                    background: const Color(0xFF0F5B33), // Vibrant Green
                    onTap: () => context.go(RoutePaths.patientPrescriptions),
                  ),
                ),
              ].animate(interval: 50.ms).fadeIn(duration: 600.ms, curve: AppleSpringCurve()).slideY(begin: 0.1),
              ),
            ),
            AsyncSection(
              value: profileAsync,
              data: (profile) {
                if (profile == null) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    QueueStatusView(
                      compact: true,
                      onTap: () => context.go(RoutePaths.patientAppointments),
                      fallback: nextAppointment != null ? Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: NextAppointmentBanner(
                          appointment: nextAppointment,
                          doctorName: doctor?.fullName ?? 'Your doctor',
                          onViewDetails: () => context.push(
                            RoutePaths.appointmentDetail(nextAppointment.id),
                          ),
                          onReschedule: () => Navigator.of(context, rootNavigator: true).push(
                            MaterialPageRoute(
                              builder: (_) => ReschedulePage(appointment: nextAppointment),
                            ),
                          ),
                        ),
                      ) : Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Daily Health Tip',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 10),
                            HealthTipCard(
                              tip: kHealthTips[now.day % kHealthTips.length],
                              width: double.infinity,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // If QueueStatusView isn't falling back to NextAppointmentBanner
                    // (i.e. they do have a visit today), we still want to show the
                    // next appointment below it.
                    if (nextAppointment != null)
                      Consumer(
                        builder: (context, ref, child) {
                          // Check if they actually have a visit today
                          final appointmentsAsync = ref.watch(patientAppointmentsProvider(user.id));
                          final hasVisitToday = appointmentsAsync.maybeWhen(
                            data: (appointments) => appointments.any(
                              (a) {
                                final now = DateTime.now();
                                return a.scheduledAt.year == now.year &&
                                       a.scheduledAt.month == now.month &&
                                       a.scheduledAt.day == now.day &&
                                       a.status != AppointmentStatus.cancelled &&
                                       a.status != AppointmentStatus.completed;
                              }
                            ),
                            orElse: () => false,
                          );

                          if (hasVisitToday) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 20),
                              child: NextAppointmentBanner(
                                appointment: nextAppointment,
                                doctorName: doctor?.fullName ?? 'Your doctor',
                                onViewDetails: () => context.push(
                                  RoutePaths.appointmentDetail(nextAppointment.id),
                                ),
                                onReschedule: () => Navigator.of(context, rootNavigator: true).push(
                                  MaterialPageRoute(
                                    builder: (_) => ReschedulePage(appointment: nextAppointment),
                                  ),
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                  ],
                );
              },
            ),

            const SizedBox(height: 24),
            Text(
              'Today\'s Reminders',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            _MedicationRemindersSection(patientId: user.id),
            const SizedBox(height: 24),
            Text(
              'Body Temperature',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            _PatientTemperatureSection(patientId: user.id),
            // Removed Your Goals This Week section
          ],
        ),
      ),
    );
  }
}

class _HeroActionCard extends StatelessWidget {
  const _HeroActionCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.background,
    required this.onTap,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 1.8,
            colors: [
              background,
              background.withValues(alpha: 0.4),
              const Color(0xFF101015),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          boxShadow: [
            BoxShadow(
              color: background.withValues(alpha: 0.25),
              blurRadius: 30,
              spreadRadius: -10,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Text(emoji, style: const TextStyle(fontSize: 20)),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PatientTemperatureSection extends ConsumerWidget {
  const _PatientTemperatureSection({required this.patientId});

  final String patientId;

  Widget _buildCard({
    required BuildContext context,
    required String value,
    required String subtitle,
    bool isFever = false,
  }) {
    final colors = context.colors;
    final primaryColor = isFever ? colors.danger : const Color(0xFFEAB308); // Yellow
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: RadialGradient(
          center: Alignment.topLeft,
          radius: 1.8,
          colors: [
            primaryColor,
            primaryColor.withValues(alpha: 0.4),
            const Color(0xFF101015),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.25),
            blurRadius: 30,
            spreadRadius: -10,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'YOUR BODY TEMPERATURE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 60,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.5,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tempAsync = ref.watch(patientLatestTemperatureProvider(patientId));
    final colors = context.colors;

    return tempAsync.when(
      loading: () => Container(
        height: 160,
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: colors.border),
        ),
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (error, stack) => const SizedBox.shrink(),
      data: (data) {
        if (data == null) {
          return _buildCard(
            context: context,
            value: '-- °C',
            subtitle: 'No readings recorded yet',
          );
        }

        final rawTemp = data['temperature'];
        final tempVal = rawTemp is num ? rawTemp.toDouble() : double.tryParse(rawTemp.toString()) ?? 36.8;
        final isFever = tempVal > 37.5;
        final device = data['device']?.toString() ?? 'Clinic Scanner';
        final statusText = isFever ? 'Fever' : 'Normal';

        return _buildCard(
          context: context,
          value: '$tempVal°C',
          subtitle: '$statusText • via $device',
          isFever: isFever,
        );
      },
    );
  }
}

class _MedicationRemindersSection extends ConsumerWidget {
  const _MedicationRemindersSection({required this.patientId});
  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prescriptions = ref.watch(patientPrescriptionsProvider(patientId));
    final activeItems = prescriptions
        .where((p) => p.status == PrescriptionStatus.active)
        .expand((p) => p.items)
        .toList();

    if (activeItems.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.colors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Medication reminders will appear here once you add prescriptions.',
            style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
          ),
        ),
      );
    }

    return Column(
      children: activeItems.take(3).map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              gradient: RadialGradient(
                center: Alignment.topLeft,
                radius: 1.8,
                colors: [
                  const Color(0xFF10B981), // Emerald Green
                  const Color(0xFF10B981).withValues(alpha: 0.4),
                  const Color(0xFF101015),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.25),
                  blurRadius: 30,
                  spreadRadius: -10,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'MEDICATION REMINDER',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                    Icon(Icons.medication, size: 16, color: Colors.white.withValues(alpha: 0.9)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(item.medicationName, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.info_outline, size: 14, color: Colors.white.withValues(alpha: 0.7)),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        item.strength.isNotEmpty
                            ? "${item.strength} • ${item.packagingType} (${item.quantity} ${item.unit})"
                            : "${item.packagingType} (${item.quantity} ${item.unit})",
                        style: const TextStyle(fontSize: 13, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.schedule, size: 14, color: Colors.white.withValues(alpha: 0.7)),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        item.instructions.isNotEmpty && item.instructions != 'As directed'
                            ? "${item.frequency} • ${item.instructions}"
                            : item.frequency,
                        style: const TextStyle(fontSize: 13, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}




