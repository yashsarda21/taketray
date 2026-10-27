import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/rules/reference_url.dart';

void main() {
  group('normalizeReferenceUrl', () {
    String? norm(String raw) => normalizeReferenceUrl(raw)?.toString();

    test('drops the Instagram tracking query', () {
      expect(
        norm('https://www.instagram.com/reel/ABC/?igsh=x'),
        'https://www.instagram.com/p/ABC/',
      );
    });

    test('the same reel shared twice normalises to the same URL', () {
      expect(
        norm('https://www.instagram.com/reel/ABC/?igsh=one'),
        norm('https://www.instagram.com/reel/ABC/?igsh=two&utm_source=ig'),
      );
    });

    test('with or without a trailing slash is the same Instagram URL', () {
      expect(
        norm('https://www.instagram.com/reel/ABC'),
        'https://www.instagram.com/p/ABC/',
      );
      expect(
        norm('https://www.instagram.com/reel/ABC///?igsh=x'),
        'https://www.instagram.com/p/ABC/',
      );
    });

    test('an Instagram URL with no path keeps a single slash', () {
      expect(norm('https://instagram.com'), 'https://www.instagram.com/');
    });

    test('every Instagram host and scheme gives one canonical URL', () {
      const canonical = 'https://www.instagram.com/p/ABC/';
      for (final raw in [
        'https://www.instagram.com/p/ABC/?igsh=x',
        'https://instagram.com/p/ABC/?utm_source=ig_web_copy_link',
        'http://instagram.com/p/ABC?utm_source=ig_web_copy_link',
        'https://m.instagram.com/p/ABC/',
        'https://instagr.am/p/ABC/?igsh=x',
        'HTTP://WWW.INSTAGRAM.COM:80/p/ABC//#top',
      ]) {
        expect(norm(raw), canonical, reason: raw);
      }
    });

    test('every kind of post path folds to /p/<code>/', () {
      for (final path in [
        '/reel/ABC',
        '/reels/ABC/',
        '/p/ABC',
        '/tv/ABC/',
        '/someuser/reel/ABC/',
        '/some.user/p/ABC//',
        '/someuser/reels/ABC',
      ]) {
        expect(
          norm('https://www.instagram.com$path?igsh=x'),
          'https://www.instagram.com/p/ABC/',
          reason: path,
        );
      }
    });

    test('codes with _ and - are kept whole', () {
      expect(
        norm('https://instagram.com/reel/A_b-9/?igsh=x'),
        'https://www.instagram.com/p/A_b-9/',
      );
    });

    test('paths that are not a post only get one trailing slash', () {
      expect(
        norm('https://www.instagram.com/reels?igsh=x'),
        'https://www.instagram.com/reels/',
      );
      expect(
        norm('https://www.instagram.com/someuser/reels//'),
        'https://www.instagram.com/someuser/reels/',
      );
      expect(
        norm('https://www.instagram.com/someuser'),
        'https://www.instagram.com/someuser/',
      );
      expect(
        norm('https://www.instagram.com/explore/tags/goa/'),
        'https://www.instagram.com/explore/tags/goa/',
      );
      expect(
        norm('https://www.instagram.com/reel/ABC/comments/'),
        'https://www.instagram.com/reel/ABC/comments/',
      );
    });

    test('different codes stay different', () {
      expect(
        norm('https://instagram.com/p/ABC/?igsh=x'),
        isNot(norm('https://www.instagram.com/p/ABD/?igsh=x')),
      );
      expect(
        norm('https://www.instagram.com/reel/ABC/'),
        isNot(norm('https://www.instagram.com/reel/abc/')),
      );
      expect(
        norm('https://www.instagram.com/someuser/reel/ABC/'),
        isNot(norm('https://www.instagram.com/someuser/reel/ABD/')),
      );
    });

    test('keeps the query for other hosts', () {
      expect(
        norm('https://www.youtube.com/watch?v=abc&t=5'),
        'https://www.youtube.com/watch?v=abc&t=5',
      );
    });

    test('keeps the query on an Instagram redirector host', () {
      // l.instagram.com/?u=<target> carries its whole meaning in the query.
      expect(
        norm('https://l.instagram.com/?u=https%3A%2F%2Fexample.com'),
        'https://l.instagram.com/?u=https%3A%2F%2Fexample.com',
      );
    });

    test('lowercases the scheme and host but not the path', () {
      expect(
        norm('HTTPS://WWW.Instagram.COM/Reel/AbC/'),
        'https://www.instagram.com/Reel/AbC/',
      );
    });

    test('drops a fragment', () {
      expect(
        norm('https://example.com/a?b=1#top'),
        'https://example.com/a?b=1',
      );
      expect(norm('https://example.com/a#top'), 'https://example.com/a');
    });

    test('trims surrounding whitespace', () {
      expect(norm('  https://youtu.be/x  \n'), 'https://youtu.be/x');
    });

    test('keeps http and a port', () {
      expect(norm('http://example.com:8080/a'), 'http://example.com:8080/a');
    });

    test('cleaning a cleaned link changes nothing', () {
      // The importer cleans every stored link again (D-59), so a second pass
      // must not change a link the first pass stored. Every input the tests
      // above accept, plus three awkward ones.
      for (final raw in [
        'https://www.instagram.com/reel/ABC/?igsh=x',
        'https://www.instagram.com/p/ABC/',
        'https://www.instagram.com/reel/ABC/?igsh=one',
        'https://www.instagram.com/reel/ABC/?igsh=two&utm_source=ig',
        'https://www.instagram.com/reel/ABC',
        'https://www.instagram.com/reel/ABC///?igsh=x',
        'https://instagram.com',
        'https://www.instagram.com/',
        'https://www.instagram.com/p/ABC/?igsh=x',
        'https://instagram.com/p/ABC/?utm_source=ig_web_copy_link',
        'http://instagram.com/p/ABC?utm_source=ig_web_copy_link',
        'https://m.instagram.com/p/ABC/',
        'https://instagr.am/p/ABC/?igsh=x',
        'HTTP://WWW.INSTAGRAM.COM:80/p/ABC//#top',
        'https://instagram.com/reel/A_b-9/?igsh=x',
        'https://www.instagram.com/p/A_b-9/',
        'https://www.instagram.com/reels?igsh=x',
        'https://www.instagram.com/reels/',
        'https://www.instagram.com/someuser/reels//',
        'https://www.instagram.com/someuser/reels/',
        'https://www.instagram.com/someuser',
        'https://www.instagram.com/someuser/',
        'https://www.instagram.com/explore/tags/goa/',
        'https://www.instagram.com/reel/ABC/comments/',
        'https://instagram.com/p/ABC/?igsh=x',
        'https://www.instagram.com/p/ABD/?igsh=x',
        'https://www.instagram.com/reel/ABC/',
        'https://www.instagram.com/reel/abc/',
        'https://www.instagram.com/someuser/reel/ABC/',
        'https://www.instagram.com/someuser/reel/ABD/',
        'https://www.youtube.com/watch?v=abc&t=5',
        'https://l.instagram.com/?u=https%3A%2F%2Fexample.com',
        'HTTPS://WWW.Instagram.COM/Reel/AbC/',
        'https://www.instagram.com/Reel/AbC/',
        'https://example.com/a?b=1#top',
        'https://example.com/a?b=1',
        'https://example.com/a#top',
        'https://example.com/a',
        'https://youtu.be/x',
        'http://example.com:8080/a',
        '  https://youtu.be/x  \n',
        for (final path in [
          '/reel/ABC',
          '/reels/ABC/',
          '/p/ABC',
          '/tv/ABC/',
          '/someuser/reel/ABC/',
          '/some.user/p/ABC//',
          '/someuser/reels/ABC',
        ])
          'https://www.instagram.com$path?igsh=x',
        'https://example.com/%7Euser',
        'https://bücher.example/',
        'https://instagram.com/a//b//',
      ]) {
        final once = norm(raw);
        expect(once, isNotNull, reason: raw);
        expect(norm(once!), once, reason: raw);
      }
    });

    test('rejects other schemes', () {
      expect(normalizeReferenceUrl('ftp://x'), isNull);
      expect(normalizeReferenceUrl('mailto:a@b.com'), isNull);
    });

    test('rejects text that is not a URL', () {
      expect(normalizeReferenceUrl('not a url'), isNull);
      expect(normalizeReferenceUrl(''), isNull);
      expect(normalizeReferenceUrl('   '), isNull);
      expect(normalizeReferenceUrl('instagram.com/reel/ABC'), isNull);
    });

    test('rejects a URL with no host', () {
      expect(normalizeReferenceUrl('https://'), isNull);
      expect(normalizeReferenceUrl('https:///path'), isNull);
    });

    test('rejects malformed input instead of throwing', () {
      expect(normalizeReferenceUrl('http://[::1'), isNull);
      expect(normalizeReferenceUrl('https://exa mple.com'), isNull);
      expect(normalizeReferenceUrl('see https://example.com'), isNull);
    });
  });

  group('referenceSourceOf', () {
    ReferenceSource of(String url) => referenceSourceOf(Uri.parse(url));

    test('Instagram hosts and subdomains', () {
      expect(
        of('https://www.instagram.com/reel/A/'),
        ReferenceSource.instagram,
      );
      expect(of('https://instagram.com/reel/A/'), ReferenceSource.instagram);
      expect(of('https://instagr.am/p/A/'), ReferenceSource.instagram);
      expect(of('https://m.instagram.com/p/A/'), ReferenceSource.instagram);
    });

    test('YouTube hosts', () {
      expect(of('https://youtu.be/x'), ReferenceSource.youtube);
      expect(of('https://youtube.com/watch?v=x'), ReferenceSource.youtube);
      expect(of('https://www.youtube.com/shorts/x'), ReferenceSource.youtube);
      expect(of('https://m.youtube.com/watch?v=x'), ReferenceSource.youtube);
    });

    test('TikTok hosts and subdomains', () {
      expect(of('https://tiktok.com/@a/video/1'), ReferenceSource.tiktok);
      expect(of('https://www.tiktok.com/@a/video/1'), ReferenceSource.tiktok);
      expect(of('https://vm.tiktok.com/abc/'), ReferenceSource.tiktok);
    });

    test('anything else is a plain link', () {
      expect(of('https://example.com/'), ReferenceSource.link);
    });

    test('a look-alike host is a plain link', () {
      expect(of('https://notinstagram.com/'), ReferenceSource.link);
      expect(of('https://evilyoutube.com/'), ReferenceSource.link);
      expect(of('https://instagram.com.evil.example/'), ReferenceSource.link);
    });

    test('the host is matched without regard to case', () {
      expect(
        referenceSourceOf(Uri(scheme: 'https', host: 'YouTu.be', path: '/x')),
        ReferenceSource.youtube,
      );
    });
  });
}
