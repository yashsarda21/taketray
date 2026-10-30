import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_golden.dart';

/// The width of a full-width card at 360 dp (16 + 328 + 16).
const _full = 328.0;

void main() {
  ttGoldenTest(
    'Reference card',
    fileName: 'reference_card',
    width: _full,
    scenarios: const [
      TtScenario('with the more button', _Card()),
      TtScenario('without the more button', _Card(more: false)),
      TtScenario(
        'link source, no label',
        _Card(
          title: 'instagram.com/reel/C9x2Ab',
          subtitle: 'Instagram',
          letter: null,
        ),
      ),
      TtScenario(
        'long title',
        _Card(
          title:
              'A very long reference title that keeps on going and going well '
              'past two lines of text',
          subtitle:
              'Instagram · instagram.com/reel/a-very-long-link-that-goes-on',
        ),
      ),
      TtScenario('add reference tile', _Add()),
      TtScenario(
        'add reference tile, long text',
        _Add(
          title: 'Add a reference to recreate a reel from somewhere else',
          subtitle:
              'Save a reel you want to recreate, from any app that can share '
              'a link to it',
        ),
      ),
    ],
  );
}

class _Card extends StatelessWidget {
  const new({
    this.title = 'Cafe tour in Porto',
    this.subtitle = 'Instagram · instagram.com/reel/abc',
    this.more = true,
    this.letter = 'I',
  });

  final String title;
  final String subtitle;
  final bool more;
  final String? letter;

  @override
  Widget build(BuildContext context) => TtReferenceCard(
    title: title,
    subtitle: subtitle,
    sourceIcon: _SourceIcon(letter: letter),
    openLabel: 'Open',
    openSemanticLabel: 'Open reference: $title, $subtitle',
    onOpen: () {},
    moreSemanticLabel: more ? 'More options for $title' : null,
    onMore: more ? () {} : null,
  );
}

/// A stand-in for the app icon the phone supplies: a lettered square with a
/// ring in the card's colour (proto.css: .srcic).
class _SourceIcon extends StatelessWidget {
  const new({required this.letter});

  final String? letter;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final link = letter == null;
    return Container(
      width: 18,
      height: 18,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: link ? scheme.surfaceContainerHighest : scheme.inverseSurface,
        borderRadius: BorderRadius.circular(5),
        boxShadow: [
          BoxShadow(color: scheme.surfaceContainerLow, spreadRadius: 2),
        ],
      ),
      child: link
          ? Icon(Symbols.link_rounded, size: 16, color: scheme.onSurfaceVariant)
          : Text(
              letter!,
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w800,
                height: 1,
                color: scheme.onInverseSurface,
              ),
            ),
    );
  }
}

class _Add extends StatelessWidget {
  const new({
    this.title = 'Add reference',
    this.subtitle = 'Save a reel you want to recreate',
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => TtAddReferenceTile(
    title: title,
    subtitle: subtitle,
    semanticLabel: '$title. $subtitle',
    onPressed: () {},
  );
}
