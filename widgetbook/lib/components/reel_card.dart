import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';
import 'package:taketray_widgetbook/fixtures.dart';
import 'package:widgetbook/widgetbook.dart';

/// `TtReelCard`: a reel on Home, the cover alone with its text under it.
final WidgetbookComponent ttReelCardComponent = WidgetbookComponent(
  name: 'TtReelCard / TtReelCardNote',
  useCases: [
    WidgetbookUseCase(
      name: 'Playground',
      builder: (context) {
        final name = context.knobs.string(
          label: 'name',
          initialValue: 'Lisbon trip',
        );
        final status = context.knobs.object.dropdown<TtStatusKind>(
          label: 'status',
          options: TtStatusKind.values,
          labelBuilder: (v) => v.name,
        );
        final statusLabel = switch (status) {
          TtStatusKind.collecting => 'Collecting',
          TtStatusKind.ready => 'Ready to edit',
          TtStatusKind.published => 'Published',
        };
        final cover = context.knobs.int.slider(
          label: 'cover (0 = none, 13 = fails to load)',
          initialValue: 1,
          max: 13,
        );
        final meta = context.knobs.string(
          label: 'meta',
          initialValue: '12 clips · 1:03',
        );
        final missing = context.knobs.int.slider(label: 'missing clips');
        final inVn = context.knobs.boolean(label: 'Editing in VN');
        final refs = context.knobs.int.slider(label: 'references', max: 120);
        final width = context.knobs.double.slider(
          label: 'width',
          initialValue: 158,
          min: 100,
          max: 320,
        );
        return SingleChildScrollView(
          padding: EdgeInsets.all(context.tt.spacing.m),
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: TtReelCard(
                name: name,
                semanticLabel: '$name. $statusLabel. $meta',
                status: status,
                statusLabel: statusLabel,
                meta: meta,
                cover: switch (cover) {
                  0 => null,
                  13 => MemoryImage(Uint8List(8)),
                  _ => wbThumb(cover),
                },
                notes: [
                  if (inVn)
                    const TtReelCardNote(
                      TtReelCardNoteKind.editing,
                      'Editing in VN',
                    ),
                  if (missing > 0)
                    TtReelCardNote(
                      TtReelCardNoteKind.missing,
                      '$missing missing',
                    ),
                  if (refs > 0)
                    TtReelCardNote(TtReelCardNoteKind.references, '$refs'),
                ],
                onTap: () {},
              ),
            ),
          ),
        );
      },
    ),
  ],
);
