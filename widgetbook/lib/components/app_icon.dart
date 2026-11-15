import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';
import 'package:widgetbook/widgetbook.dart';

/// An 8 x 8 PNG, violet over amber, standing in for an editor's icon.
final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAgAAAAICAIAAABLbSncAAAAGElEQVR4nGMoNrqPFTFQUe'
  'L/zhCsiIoSAEEPcgFd9yFcAAAAAElFTkSuQmCC',
);

/// `TtAppIcon`: an editor's icon, or letters on a tile.
final WidgetbookComponent ttAppIconComponent = WidgetbookComponent(
  name: 'TtAppIcon',
  useCases: [
    WidgetbookUseCase(
      name: 'Playground',
      builder: (context) {
        final source = context.knobs.object.dropdown<String>(
          label: 'icon',
          options: const ['letters', 'picture', 'bytes that are not a picture'],
          initialOption: 'letters',
        );
        final letters = context.knobs.string(
          label: 'letters',
          initialValue: 'VN',
        );
        return Padding(
          padding: EdgeInsets.all(context.tt.spacing.xl),
          child: TtAppIcon(
            png: switch (source) {
              'picture' => _png,
              'letters' => null,
              _ => Uint8List.fromList(const [1, 2, 3]),
            },
            fallbackLetters: letters,
          ),
        );
      },
    ),
  ],
);
