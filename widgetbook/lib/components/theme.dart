import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';
import 'package:widgetbook/widgetbook.dart';

/// Colour roles and text styles of the active theme, mirroring the swatch
/// golden in `packages/taketray_ui/test/theme/theme_golden_test.dart`.
final WidgetbookComponent themeComponent = WidgetbookComponent(
  name: 'Theme',
  useCases: [
    _useCase('Material type scale', const _MaterialType()),
    _useCase('TakeTray type', const _TakeTrayType()),
    _useCase('Scheme roles', const _SchemeRoles()),
    _useCase('TakeTray colours', const _TakeTrayColors()),
  ],
);

WidgetbookUseCase _useCase(String name, Widget body) => WidgetbookUseCase(
  name: name,
  builder: (context) => SingleChildScrollView(
    padding: EdgeInsets.all(context.tt.spacing.m),
    child: body,
  ),
);

class _MaterialType extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final t = context.tt.text.material;
    return _Specimens({
      'displaySmall': t.displaySmall,
      'headlineLarge': t.headlineLarge,
      'headlineMedium': t.headlineMedium,
      'headlineSmall': t.headlineSmall,
      'titleLarge': t.titleLarge,
      'titleMedium': t.titleMedium,
      'titleSmall': t.titleSmall,
      'bodyLarge': t.bodyLarge,
      'bodyMedium': t.bodyMedium,
      'bodySmall': t.bodySmall,
      'labelLarge': t.labelLarge,
      'labelMedium': t.labelMedium,
      'labelSmall': t.labelSmall,
    });
  }
}

class _TakeTrayType extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final t = context.tt.text;
    return _Specimens({
      'pageTitle': t.pageTitle,
      'detailTitle': t.detailTitle,
      'screenTitle': t.screenTitle,
      'dialogTitle': t.dialogTitle,
      'shootTitle': t.shootTitle,
      'cardTitle': t.cardTitle,
      'groupLabel': t.groupLabel,
      'navLabel': t.navLabel,
      'numeric 0:12 · 23 clips': t.numeric(t.material.bodyLarge!),
    });
  }
}

class _Specimens extends StatelessWidget {
  const new(this.styles);

  final Map<String, TextStyle?> styles;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final MapEntry(:key, :value) in styles.entries)
        Text(key, style: value),
    ],
  );
}

class _SchemeRoles extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final s = context.scheme;
    return _Swatches([
      ('primary', s.primary, s.onPrimary),
      ('primaryContainer', s.primaryContainer, s.onPrimaryContainer),
      ('secondary', s.secondary, s.onSecondary),
      ('secondaryContainer', s.secondaryContainer, s.onSecondaryContainer),
      ('tertiary', s.tertiary, s.onTertiary),
      ('tertiaryContainer', s.tertiaryContainer, s.onTertiaryContainer),
      ('error', s.error, s.onError),
      ('errorContainer', s.errorContainer, s.onErrorContainer),
      ('surface', s.surface, s.onSurface),
      ('surfaceContainerLowest', s.surfaceContainerLowest, s.onSurface),
      ('surfaceContainerLow', s.surfaceContainerLow, s.onSurface),
      ('surfaceContainer', s.surfaceContainer, s.onSurface),
      ('surfaceContainerHigh', s.surfaceContainerHigh, s.onSurface),
      ('surfaceContainerHighest', s.surfaceContainerHighest, s.onSurface),
      ('onSurfaceVariant', s.surface, s.onSurfaceVariant),
      ('outline', s.outline, s.surface),
      ('outlineVariant', s.outlineVariant, s.onSurface),
      ('inverseSurface', s.inverseSurface, s.onInverseSurface),
    ]);
  }
}

class _TakeTrayColors extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final c = context.tt.colors;
    final s = context.scheme;
    return _Swatches([
      ('waiting', c.waiting, c.onWaiting),
      ('waitingContainer', c.waitingContainer, c.onWaitingContainer),
      ('record', c.record, c.onRecord),
      ('recordContainer', c.recordContainer, c.onRecordContainer),
      ('success', c.success, c.onSuccess),
      ('successContainer', c.successContainer, c.onSuccessContainer),
      ('hairline', c.hairline, s.onSurface),
      ('glass', c.glass, s.onSurface),
      ('glassOnMedia', c.glassOnMedia, c.onMedia),
      ('onMediaVariant', c.mediaScrimEnd, c.onMediaVariant),
      ('missingOnMedia', c.mediaScrimEnd, c.missingOnMedia),
      ('recordOnMedia', c.mediaScrimEnd, c.recordOnMedia),
      ('readyOnMedia', c.mediaScrimEnd, c.readyOnMedia),
      ('publishedOnMedia', c.mediaScrimEnd, c.publishedOnMedia),
      ('videoBackground', c.videoBackground, c.onVideo),
      ('videoScrimTop', c.videoScrimTop, c.onVideoVariant),
      ('videoScrimBottom', c.videoScrimBottom, c.onVideo),
    ]);
  }
}

/// Labelled swatches, two per row: the fill is the colour, the label is
/// drawn in its paired content colour.
class _Swatches extends StatelessWidget {
  const new(this.swatches);

  final List<(String, Color, Color)> swatches;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final label = tt.text.material.labelMedium!;
    Widget swatch((String, Color, Color) s) {
      final (name, fill, content) = s;
      return Expanded(
        child: Container(
          padding: EdgeInsets.all(tt.spacing.xs),
          decoration: BoxDecoration(
            color: fill,
            border: Border.all(color: tt.colors.hairline),
            borderRadius: BorderRadius.circular(tt.radii.s),
          ),
          child: Text(name, style: label.copyWith(color: content)),
        ),
      );
    }

    return Column(
      spacing: tt.spacing.xxs,
      children: [
        for (var i = 0; i < swatches.length; i += 2)
          Row(
            spacing: tt.spacing.xxs,
            children: [
              swatch(swatches[i]),
              if (i + 1 < swatches.length)
                swatch(swatches[i + 1])
              else
                const Spacer(),
            ],
          ),
      ],
    );
  }
}
