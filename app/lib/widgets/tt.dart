import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.g.dart';

/// TakeTray style building blocks: floating glass chrome, pills and grouped rows.

/// 34 sp extra-bold page title with tight tracking.
TextStyle pageTitle(BuildContext context) => weight(
  context.tt.headlineLarge!,
  800,
).copyWith(fontSize: 34, height: 40 / 34, letterSpacing: -1.2);

Color hairline(BuildContext context) =>
    context.cs.onSurface.withValues(alpha: 0.09);

/// Frosted glass panel (navigation, toasts, sheets).
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    required this.radius,
    this.color,
    this.blur = 18,
    this.shadow = true,
  });
  final Widget child;
  final double radius;
  final Color? color;
  final double blur;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: shadow
            ? const [
                BoxShadow(
                  color: Color(0x59000000),
                  blurRadius: 30,
                  offset: Offset(0, 10),
                  spreadRadius: -8,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: r,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color:
                  color ??
                  context.cs.surfaceContainerHigh.withValues(alpha: 0.78),
              borderRadius: r,
              border: Border.all(color: hairline(context)),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class NavItem {
  const NavItem(this.icon, this.label, {this.badge = 0});
  final IconData icon;
  final String label;
  final int badge;
}

/// Floating glass navigation pill. Labels stay: minimal reading still needs words.
class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({
    super.key,
    required this.items,
    required this.index,
    required this.onTap,
  });
  final List<NavItem> items;
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
        child: Glass(
          radius: 32,
          child: SizedBox(
            height: 64,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Row(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    if (i > 0) const SizedBox(width: 4),
                    Expanded(
                      child: _NavButton(
                        item: items[i],
                        selected: i == index,
                        onTap: () => onTap(i),
                        cs: cs,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
    required this.cs,
  });
  final NavItem item;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? cs.onPrimaryContainer : cs.onSurfaceVariant;
    final icon = Icon(item.icon, color: fg, fill: selected ? 1 : 0, size: 24);
    return Semantics(
      button: true,
      selected: selected,
      label: item.badge > 0
          ? '${item.label}, ${item.badge} clips waiting'
          : item.label,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(26),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: AnimatedContainer(
            duration: Motion.short4,
            curve: Motion.standard,
            decoration: BoxDecoration(
              color: selected ? cs.primaryContainer : Colors.transparent,
              borderRadius: BorderRadius.circular(26),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                item.badge > 0
                    ? Badge(
                        label: Text('${item.badge}'),
                        backgroundColor: cs.tertiary,
                        textColor: cs.onTertiary,
                        child: icon,
                      )
                    : icon,
                const SizedBox(height: 1),
                Text(
                  item.label,
                  style: weight(
                    context.tt.labelSmall!,
                    600,
                  ).copyWith(fontSize: 11.5, color: fg),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pill tabs (single select) instead of outlined filter chips.
class PillTabs<T> extends StatelessWidget {
  const PillTabs({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
  });
  final List<(T, String)> items;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: Space.gutter,
          vertical: 8,
        ),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (v, label) = items[i];
          final on = v == value;
          return Semantics(
            selected: on,
            button: true,
            child: Material(
              color: on ? cs.inverseSurface : cs.surfaceContainerHigh,
              shape: const StadiumBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => onChanged(v),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: Center(
                    child: Text(
                      label,
                      style: context.tt.labelLarge?.copyWith(
                        color: on ? cs.onInverseSurface : cs.onSurfaceVariant,
                        fontFeatures: tabularFigures,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Dark glass pill used on top of media (status, VN, references).
class GlassPill extends StatelessWidget {
  const GlassPill({
    super.key,
    required this.icon,
    required this.iconColor,
    this.text,
  });
  final IconData icon;
  final Color iconColor;
  final String? text;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Container(
        height: 24,
        padding: EdgeInsets.fromLTRB(6, 0, text == null ? 6 : 8, 0),
        color: const Color(0x940E0C14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: iconColor, fill: 1),
            if (text != null) ...[
              const SizedBox(width: 4),
              Text(
                text!,
                style: weight(
                  context.tt.labelMedium!,
                  600,
                ).copyWith(color: Colors.white, fontFeatures: tabularFigures),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

/// Inset grouped rows (settings): rounded group, 2 dp gaps between rows.
class GroupedRows extends StatelessWidget {
  const GroupedRows({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final bg = context.cs.surfaceContainerLow;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 2),
            ClipRRect(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(i == 0 ? 22 : 6),
                bottom: Radius.circular(i == children.length - 1 ? 22 : 6),
              ),
              child: Material(color: bg, child: children[i]),
            ),
          ],
        ],
      ),
    );
  }
}

/// Section label above a group.
class GroupLabel extends StatelessWidget {
  const GroupLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(28, 22, 28, 8),
    child: Text(
      text.toUpperCase(),
      style: weight(
        context.tt.labelMedium!,
        700,
      ).copyWith(letterSpacing: 0.8, color: context.cs.onSurfaceVariant),
    ),
  );
}

/// Floating bottom sheet panel: inset 8 dp, 32 dp corners, own drag handle.
/// Use with showModalBottomSheet(backgroundColor: Colors.transparent).
class FloatingSheet extends StatelessWidget {
  const FloatingSheet({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        8,
        0,
        8,
        8 + MediaQuery.of(context).viewPadding.bottom,
      ),
      child: Material(
        color: cs.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(32),
          side: BorderSide(color: hairline(context)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 4,
              margin: const EdgeInsets.only(top: 14, bottom: 12),
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Flexible(child: child),
          ],
        ),
      ),
    );
  }
}
