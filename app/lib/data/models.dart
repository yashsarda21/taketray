import 'dart:convert';

import 'package:flutter/services.dart';

enum ReelStatus { recording, ready, published }

ReelStatus _status(String s) => switch (s) {
  'ready' => ReelStatus.ready,
  'pub' => ReelStatus.published,
  _ => ReelStatus.recording,
};

/// A link to a reel the creator wants to recreate. TakeTray only stores the link.
class Reference {
  Reference({required this.id, required this.url, required this.label});
  final String id;
  final String url;
  String label;
}

class VnCopies {
  VnCopies({required this.folder, required this.copied});
  final String folder;
  final List<String> copied;
}

class Reel {
  Reel({
    required this.id,
    required this.name,
    required this.status,
    required this.created,
    this.desc = '',
    this.vn,
    List<Reference>? refs,
  }) : refs = refs ?? [];

  final String id;
  String name;
  ReelStatus status;
  final DateTime created;
  String desc;
  VnCopies? vn;
  final List<Reference> refs;
}

/// A reference to a video in the phone's gallery. Times are local shooting time.
class VideoClip {
  VideoClip({
    required this.id,
    required this.thumb,
    required this.horizontal,
    required this.at,
    required this.durationSec,
    required this.sizeMb,
    required this.missing,
    required this.reels,
  });

  final String id;
  final String thumb;
  final bool horizontal;
  final DateTime at;
  final int durationSec;
  final int sizeMb;
  final bool missing;
  final Set<String> reels;
}

/// Sample content: the same London trip as the design prototype.
class SampleData {
  SampleData({
    required this.today,
    required this.shootingSince,
    required this.reels,
    required this.clips,
    required this.toTag,
    required this.skipped,
  });

  final DateTime today;
  final DateTime shootingSince;
  final List<Reel> reels;
  final Map<String, VideoClip> clips;
  final List<String> toTag;
  final List<String> skipped;

  static Future<SampleData> load() async {
    final j = jsonDecode(
      await rootBundle.loadString('assets/sample/sample_data.json'),
    ) as Map<String, dynamic>;
    final clips = <String, VideoClip>{
      for (final c in (j['clips'] as List).cast<Map<String, dynamic>>())
        c['id'] as String: VideoClip(
          id: c['id'] as String,
          thumb: 'assets/sample/thumbs/${c['id']}.jpg',
          horizontal: c['orient'] == 'h',
          at: DateTime.parse(c['at'] as String),
          durationSec: (c['dur'] as num).toInt(),
          sizeMb: (c['mb'] as num).toInt(),
          missing: c['missing'] as bool,
          reels: (c['reels'] as List).cast<String>().toSet(),
        ),
    };
    final reels = [
      for (final r in (j['reels'] as List).cast<Map<String, dynamic>>())
        Reel(
          id: r['id'] as String,
          name: r['name'] as String,
          status: _status(r['status'] as String),
          created: DateTime.parse(r['created'] as String),
          desc: r['desc'] as String? ?? '',
          vn: r['vn'] == null
              ? null
              : VnCopies(
                  folder: r['vn']['folder'] as String,
                  copied: (r['vn']['copied'] as List).cast<String>(),
                ),
          refs: [
            for (final x in (r['refs'] as List).cast<Map<String, dynamic>>())
              Reference(
                id: x['id'] as String,
                url: x['url'] as String,
                label: x['label'] as String? ?? '',
              ),
          ],
        ),
    ];
    return SampleData(
      today: DateTime.parse(j['today'] as String),
      shootingSince: DateTime.parse(j['shooting']['since'] as String),
      reels: reels,
      clips: clips,
      toTag: (j['toTag'] as List).cast<String>(),
      skipped: (j['skipped'] as List).cast<String>(),
    );
  }
}
