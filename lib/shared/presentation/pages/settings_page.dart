import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/theme/theme_mode_provider.dart';
import '../../../features/auth/domain/entities/user_role.dart';
import '../../../features/auth/presentation/providers/auth_providers.dart';
import '../../../features/appointments/presentation/providers/appointments_providers.dart';
import '../widgets/app_card.dart';
import '../widgets/large_title_app_bar.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {


  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: const LargeTitleAppBar(title: 'Settings'),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (user != null && (user.role == UserRole.doctor || user.role == UserRole.pharmacist)) ...[
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Clinic Operations',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      Consumer(
                        builder: (context, ref, child) {
                          final isClosed = ref.watch(clinicClosedProvider);
                          return SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Clinic is Closed'),
                            subtitle: Text(isClosed ? 'The clinic is currently marked as closed.' : 'The clinic is currently open.'),
                            value: isClosed,
                            onChanged: (val) => ref.read(clinicClosedProvider.notifier).state = val,
                            activeThumbColor: Theme.of(context).colorScheme.error,
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Preferences',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.brightness_6_outlined),
                      title: const Text('Dark Mode'),
                      trailing: Switch(
                        value: themeMode == ThemeMode.dark,
                        onChanged: (value) {
                          ref.read(themeModeProvider.notifier).setThemeMode(
                                value ? ThemeMode.dark : ThemeMode.light,
                              );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Center(
                child: FilledButton.tonalIcon(
                  onPressed: () {
                    ref.read(authControllerProvider.notifier).logout();
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Log Out'),
                  style: FilledButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
