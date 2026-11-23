import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/domain/rules/shared_link_kind.dart';

void main() {
  SharedLinkKind kind(String raw) => sharedLinkKindOf(Uri.parse(raw));

  group('sharedLinkKindOf, read from the raw link', () {
    for (final (url, expected) in <(String, SharedLinkKind)>[
      ('https://www.instagram.com/reel/ABC/', SharedLinkKind.instagramReel),
      ('https://www.instagram.com/reels/ABC/', SharedLinkKind.instagramReel),
      ('https://instagram.com/reel/ABC?igsh=x', SharedLinkKind.instagramReel),
      ('https://instagr.am/reel/ABC', SharedLinkKind.instagramReel),
      ('https://m.instagram.com/reel/ABC/', SharedLinkKind.instagramReel),
      (
        'https://www.instagram.com/someuser/reel/X',
        SharedLinkKind.instagramReel,
      ),
      ('https://www.instagram.com/p/ABC/', SharedLinkKind.instagramPost),
      (
        'https://www.instagram.com/someuser/p/ABC',
        SharedLinkKind.instagramPost,
      ),
      ('https://www.instagram.com/tv/ABC/', SharedLinkKind.instagramVideo),
      ('https://www.instagram.com/someuser/', SharedLinkKind.instagramProfile),
      ('https://www.instagram.com/', SharedLinkKind.instagramProfile),
      // A page named like a post path but with no code is a profile.
      ('https://www.instagram.com/p', SharedLinkKind.instagramProfile),
      ('https://www.instagram.com/reel/', SharedLinkKind.instagramProfile),
      (
        'https://www.instagram.com/explore/tags/x/',
        SharedLinkKind.instagramProfile,
      ),
      ('https://www.youtube.com/shorts/abc', SharedLinkKind.youtubeShort),
      (
        'https://youtube.com/shorts/abc?feature=share',
        SharedLinkKind.youtubeShort,
      ),
      ('https://youtu.be/abc', SharedLinkKind.youtubeVideo),
      ('https://www.youtube.com/watch?v=abc', SharedLinkKind.youtubeVideo),
      ('https://m.youtube.com/@channel', SharedLinkKind.youtubeVideo),
      ('https://vm.tiktok.com/ZM8x/', SharedLinkKind.tiktokVideo),
      ('https://www.tiktok.com/@a/video/1', SharedLinkKind.tiktokVideo),
      ('https://example.com/a', SharedLinkKind.link),
      ('https://www.example.com/reel/ABC', SharedLinkKind.link),
      ('https://notinstagram.com/reel/ABC', SharedLinkKind.link),
    ]) {
      test('$url is $expected', () => expect(kind(url), expected));
    }

    test('the host and the path may be upper case', () {
      expect(
        kind('HTTPS://WWW.INSTAGRAM.COM/reel/ABC'),
        SharedLinkKind.instagramReel,
      );
    });

    test('is read before normalising: /reel/ is not already /p/', () {
      // normalizeReferenceUrl rewrites /reel/ABC to /p/ABC; the kind of the
      // raw link is the reel, not the post.
      expect(
        kind('https://www.instagram.com/reel/ABC/'),
        isNot(SharedLinkKind.instagramPost),
      );
    });
  });
}
