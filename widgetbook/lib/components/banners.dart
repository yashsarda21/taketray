import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';
import 'package:widgetbook/widgetbook.dart';

/// `TtBanner`: a full-width notice with an optional action.
final WidgetbookComponent ttBannerComponent = WidgetbookComponent(
  name: 'TtBanner',
  useCases: [
    WidgetbookUseCase(
      name: 'Playground',
      builder: (context) {
        final kind = context.knobs.object.dropdown<TtBannerKind>(
          label: 'kind',
          options: TtBannerKind.values,
          labelBuilder: (v) => v.name,
        );
        final title = context.knobs.string(
          label: 'title',
          initialValue: "TakeTray can't see your videos",
        );
        final body = context.knobs.string(
          label: 'body (empty for none)',
          initialValue: 'Allow access to find new clips.',
        );
        final withAction = context.knobs.boolean(
          label: 'action',
          initialValue: true,
        );
        final iconFilled = context.knobs.boolean(
          label: 'icon filled',
          initialValue: true,
        );
        final tappable = context.knobs.boolean(label: 'tappable (no action)');
        final action = withAction
            ? kind == TtBannerKind.vn
                  ? Wrap(
                      spacing: 4,
                      children: [
                        TtButton(
                          label: 'Done editing',
                          size: TtButtonSize.small,
                          onPressed: () {},
                        ),
                        TtButton(
                          label: 'Add more clips',
                          size: TtButtonSize.small,
                          kind: TtButtonKind.text,
                          onPressed: () {},
                        ),
                      ],
                    )
                  : TtButton(
                      label: 'Allow',
                      kind: TtButtonKind.text,
                      onPressed: () {},
                    )
            : null;
        return TtBanner(
          kind: kind,
          icon: Symbols.info_rounded,
          title: title,
          body: body.isEmpty ? null : body,
          action: action,
          iconFilled: iconFilled,
          onTap: tappable && action == null ? () {} : null,
        );
      },
    ),
  ],
);

/// `TtCallout`: a rounded note inside a page.
final WidgetbookComponent ttCalloutComponent = WidgetbookComponent(
  name: 'TtCallout',
  useCases: [
    WidgetbookUseCase(
      name: 'Playground',
      builder: (context) {
        final warning = context.knobs.boolean(label: 'warning');
        final rich = context.knobs.boolean(label: 'rich body (bold word)');
        final title = context.knobs.string(
          label: 'title (empty for none)',
          initialValue: 'Your videos stay on your phone',
        );
        final body = context.knobs.string(
          label: 'body',
          initialValue:
              'TakeTray only reads them. It never uploads, moves or '
              'deletes them.',
        );
        final withAction = context.knobs.boolean(label: 'action');
        return Padding(
          padding: EdgeInsets.all(context.tt.spacing.m),
          child: TtCallout(
            icon: Symbols.shield_rounded,
            title: title.isEmpty ? null : title,
            body: rich ? null : body,
            richBody: rich
                ? TextSpan(
                    children: [
                      const TextSpan(text: 'Choose '),
                      const TextSpan(
                        text: 'Allow all',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontVariations: [FontVariation('wght', 700)],
                        ),
                      ),
                      TextSpan(text: ' in the next step. $body'),
                    ],
                  )
                : null,
            warning: warning,
            action: withAction
                ? TtButton(
                    label: 'Got it',
                    kind: TtButtonKind.text,
                    onPressed: () {},
                  )
                : null,
          ),
        );
      },
    ),
  ],
);

/// `TtInfoBar`: a one-line note above a list.
final WidgetbookComponent ttInfoBarComponent = WidgetbookComponent(
  name: 'TtInfoBar',
  useCases: [
    WidgetbookUseCase(
      name: 'Playground',
      builder: (context) => TtInfoBar(
        icon: Symbols.info_rounded,
        text: context.knobs.string(
          label: 'text',
          initialValue:
              'Skipped clips are still in your gallery. Restore any you want '
              'to tag.',
        ),
      ),
    ),
  ],
);
