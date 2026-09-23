import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../config/constants/app_constants.dart';
import '../../../config/theme/app_theme.dart';
import 'app_shell_scaffold.dart';
import 'avatar_widget.dart';
import 'sign_out_icon_button.dart';

/// Desktop dashboard shell for the clinician roles (doctor, pharmacist):
/// a fixed sidebar with branded header, nav, and account footer, with
/// content centered in a max-width column — the "used at a desk in a web
/// browser" counterpart to the patient app's mobile bottom-tab shell.
///
/// Below [AppConstants.desktopBreakpoint] it falls back to the same
/// bottom-tab [AppShellScaffold] the patient app uses, so nothing breaks if
/// a clinician opens the link on a phone.
class ClinicianAppShell extends StatelessWidget {
  const ClinicianAppShell({
    super.key,
    required this.navigationShell,
    required this.items,
    required this.accentColor,
    required this.userName,
    required this.roleLabel,
    this.avatarUrl,
  });

  final StatefulNavigationShell navigationShell;
  final List<NavItem> items;
  final Color accentColor;
  final String userName;
  final String roleLabel;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= AppConstants.desktopBreakpoint;
    if (!isDesktop) {
      return AppShellScaffold(
        navigationShell: navigationShell,
        items: items,
        accentColor: accentColor,
      );
    }

    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.surfaceMuted,
      body: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
            child: Container(
              width: 260,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [colors.success, colors.info]),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: const Icon(Icons.monitor_heart_outlined, color: Colors.white, size: 17),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'MyPulse360',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: colors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: colors.border),
                  const SizedBox(height: 12),
                  for (var i = 0; i < items.length; i++)
                    _SidebarItem(
                      item: items[i],
                      selected: i == navigationShell.currentIndex,
                      accent: accentColor,
                      onTap: () => navigationShell.goBranch(
                        i,
                        initialLocation: i == navigationShell.currentIndex,
                      ),
                    ),
                  const Spacer(),
                  Divider(height: 1, color: colors.border),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        AvatarWidget(name: userName, size: 34, color: accentColor, imagePath: avatarUrl),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                userName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                              Text(roleLabel, style: TextStyle(fontSize: 11, color: colors.textSecondary)),
                            ],
                          ),
                        ),
                        const SignOutIconButton(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
          Expanded(
            child: ColoredBox(
              color: colors.surfaceMuted,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: navigationShell,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.item,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final NavItem item;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final bgColor = selected 
        ? (isDark ? Colors.white : accent) 
        : Colors.transparent;
    final iconColor = selected 
        ? (isDark ? Colors.black87 : Colors.white) 
        : colors.textSecondary;
    final textColor = selected 
        ? (isDark ? Colors.black87 : Colors.white) 
        : colors.textPrimary;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(32),
          ),
          child: Row(
            children: [
              Icon(
                selected ? item.selectedIcon : item.icon, 
                size: 22, 
                color: iconColor,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
