import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_golden.dart';

/// An 8 x 8 PNG: violet on the top half, amber under it.
final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAgAAAAICAIAAABLbSncAAAAGElEQVR4nGMoNrqPFTFQUe'
  'L/zhCsiIoSAEEPcgFd9yFcAAAAAElFTkSuQmCC',
);

Widget _row(List<Widget> icons) => Row(spacing: 12, children: icons);

void main() {
  ttGoldenTest(
    'App icon',
    fileName: 'app_icon',
    width: 280,
    scenarios: [
      TtScenario(
        'letters',
        _row(const [
          TtAppIcon(fallbackLetters: 'C'),
          TtAppIcon(fallbackLetters: 'E'),
          TtAppIcon(fallbackLetters: 'VN'),
        ]),
      ),
      TtScenario(
        'picture',
        _row([TtAppIcon(png: _png, fallbackLetters: 'VN')]),
      ),
      TtScenario(
        'bytes that are not a picture',
        _row([
          TtAppIcon(png: Uint8List.fromList([1, 2, 3]), fallbackLetters: 'VN'),
        ]),
      ),
    ],
  );
}
