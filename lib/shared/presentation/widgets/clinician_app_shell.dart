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
class ClinicianAppShell extends StatefulWidget {
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
  State<ClinicianAppShell> createState() => _ClinicianAppShellState();
}

class _ClinicianAppShellState extends State<ClinicianAppShell> {
  bool _isManuallyExpanded = false;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= AppConstants.desktopBreakpoint;
    if (!isDesktop) {
      return AppShellScaffold(
        navigationShell: widget.navigationShell,
        items: widget.items,
        accentColor: widget.accentColor,
      );
    }

    final isExpandedDesktop = width >= 1100;
    final shouldExpand = isExpandedDesktop || _isManuallyExpanded;
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.surfaceMuted,
      body: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              width: shouldExpand ? 260 : 85,
              decoration: BoxDecoration(
                color: widget.accentColor.withValues(alpha: 0.15),
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
                    crossAxisAlignment: shouldExpand ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                    children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(shouldExpand ? 20 : 0, 20, shouldExpand ? 20 : 0, 16),
                    child: Row(
                      mainAxisAlignment: shouldExpand ? MainAxisAlignment.start : MainAxisAlignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(9),
                          child: Image.asset(
                            'assets/images/logo_mark.png',
                            width: 32,
                            height: 32,
                          ),
                        ),
                        if (shouldExpand) ...[
                          const SizedBox(width: 10),
                          Text(
                            'MyPulse360',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: colors.textPrimary),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Divider(height: 1, color: colors.border),
                  if (!isExpandedDesktop) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: IconButton(
                        icon: Icon(_isManuallyExpanded ? Icons.chevron_left : Icons.menu, color: colors.textPrimary),
                        onPressed: () => setState(() => _isManuallyExpanded = !_isManuallyExpanded),
                      ),
                    ),
                    Divider(height: 1, color: colors.border),
                  ],
                  const SizedBox(height: 12),
                  for (var i = 0; i < widget.items.length; i++)
                    _SidebarItem(
                      item: widget.items[i],
                      selected: i == widget.navigationShell.currentIndex,
                      accent: widget.accentColor,
                      isExpanded: shouldExpand,
                      onTap: () => widget.navigationShell.goBranch(
                        i,
                        initialLocation: i == widget.navigationShell.currentIndex,
                      ),
                    ),
                  const Spacer(),
                  Divider(height: 1, color: colors.border),
                  Padding(
                    padding: EdgeInsets.all(shouldExpand ? 14 : 10),
                    child: shouldExpand
                        ? Row(
                            children: [
                              AvatarWidget(name: widget.userName, size: 34, color: widget.accentColor, imagePath: widget.avatarUrl),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      widget.userName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                    ),
                                    Text(widget.roleLabel, style: TextStyle(fontSize: 11, color: colors.textSecondary)),
                                  ],
                                ),
                              ),
                              const SignOutIconButton(),
                            ],
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AvatarWidget(name: widget.userName, size: 34, color: widget.accentColor, imagePath: widget.avatarUrl),
                              const SizedBox(height: 16),
                              const SignOutIconButton(),
                              const SizedBox(height: 8),
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
                  child: widget.navigationShell,
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
    required this.isExpanded,
    required this.onTap,
  });

  final NavItem item;
  final bool selected;
  final Color accent;
  final bool isExpanded;
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
        padding: EdgeInsets.symmetric(horizontal: isExpanded ? 12.0 : 8.0, vertical: 4.0),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(horizontal: isExpanded ? 16 : 0, vertical: 12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(32),
          ),
          child: Row(
            mainAxisAlignment: isExpanded ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              Icon(
                selected ? item.selectedIcon : item.icon, 
                size: 22, 
                color: iconColor,
              ),
              if (isExpanded) ...[
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
            ],
          ),
        ),
      ),
    );
  }
}
