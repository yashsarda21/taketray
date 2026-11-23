import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/domain/rules/reference_links.dart';
import 'package:taketray/domain/rules/reference_url.dart';

void main() {
  group('firstLinkIn', () {
    test('finds a link after a title', () {
      expect(
        firstLinkIn('Title https://vm.tiktok.com/ZM8x/'),
        'https://vm.tiktok.com/ZM8x/',
      );
    });

    test('strips a closing bracket and a full stop after the link', () {
      expect(firstLinkIn('see (https://youtu.be/a1).'), 'https://youtu.be/a1');
    });

    test('strips a comma and an exclamation mark after the link', () {
      expect(firstLinkIn('go https://x.com/a,'), 'https://x.com/a');
      expect(firstLinkIn('wow https://x.com/a!'), 'https://x.com/a');
      expect(firstLinkIn('wow https://x.com/a!!.,)'), 'https://x.com/a');
    });

    test('keeps punctuation inside the link and a trailing slash', () {
      expect(
        firstLinkIn('https://x.com/a.b/c?d=1,2'),
        'https://x.com/a.b/c?d=1,2',
      );
      expect(firstLinkIn('https://x.com/a/'), 'https://x.com/a/');
    });

    test('the first of two links wins', () {
      expect(
        firstLinkIn('a https://x.com/1 b https://y.com/2'),
        'https://x.com/1',
      );
    });

    test('the scheme is case-insensitive', () {
      expect(firstLinkIn('HTTPS://X.COM/a'), 'HTTPS://X.COM/a');
      expect(firstLinkIn('Http://x.com/a'), 'Http://x.com/a');
    });

    test('a link on its own line or after a newline is found', () {
      expect(firstLinkIn('caption\nhttps://x.com/a\nmore'), 'https://x.com/a');
    });

    test('a bare www link is not a link here', () {
      expect(firstLinkIn('www.instagram.com/reel/a'), isNull);
    });

    test('nothing to find gives null', () {
      expect(firstLinkIn(''), isNull);
      expect(firstLinkIn('no link here'), isNull);
      expect(firstLinkIn('ftp://x.com/a'), isNull);
    });

    test('a scheme with nothing after it gives null', () {
      expect(firstLinkIn('https://'), isNull);
      expect(firstLinkIn('see https:// now'), isNull);
      expect(firstLinkIn('(https://).'), isNull);
    });

    test('a very long link is returned whole', () {
      final long = 'https://example.com/${'a' * 2000}';
      expect(firstLinkIn('look $long'), long);
    });
  });

  group('typedLink', () {
    test('a text with a link gives the link', () {
      expect(typedLink('Title https://x.com/a.'), 'https://x.com/a');
    });

    test('a bare address gets https://', () {
      expect(
        typedLink('instagram.com/reel/abc'),
        'https://instagram.com/reel/abc',
      );
    });

    test('edge spaces are trimmed', () {
      expect(typedLink('  https://x.com/a  '), 'https://x.com/a');
      expect(typedLink('  x.com/a  '), 'https://x.com/a');
    });

    test('words are not a link', () {
      expect(typedLink('hello world'), isNull);
      expect(typedLink('hello'), isNull);
      expect(typedLink(''), isNull);
      expect(typedLink('   '), isNull);
    });

    test('two words with a dot are not a link', () {
      expect(typedLink('see x.com'), isNull);
    });

    test('a dotted single word with nothing around the dot is not a link', () {
      expect(typedLink('hello.'), isNull);
      expect(typedLink('.com'), isNull);
      expect(typedLink('.'), isNull);
      expect(typedLink('...'), isNull);
      expect(typedLink('a..com'), isNull);
      expect(typedLink('x.com..'), 'https://x.com');
    });

    test('a bare address loses the punctuation that ends a sentence', () {
      expect(typedLink('x.com.'), 'https://x.com');
      expect(typedLink('x.com/a).'), 'https://x.com/a');
      expect(typedLink('x.com/a,'), 'https://x.com/a');
      expect(typedLink('x.com/a!'), 'https://x.com/a');
      expect(typedLink('(instagram.com/reel/abc)'), isNull);
      expect(
        typedLink('instagram.com/reel/abc)'),
        'https://instagram.com/reel/abc',
      );
    });

    test('a number or an email or another scheme is not an address', () {
      expect(typedLink('3.5'), isNull);
      expect(typedLink('1.2.3'), isNull);
      expect(typedLink('user@example.com'), isNull);
      expect(typedLink('mailto:a@b.com'), isNull);
      expect(typedLink('tel:1.2'), isNull);
      expect(typedLink('ftp://x.com/a'), isNull);
    });

    test('an IP address and a port are fine', () {
      expect(typedLink('192.168.1.2/a'), 'https://192.168.1.2/a');
      expect(typedLink('x.com:8080/a'), 'https://x.com:8080/a');
    });

    test('a link with a scheme needs a dotted host too', () {
      expect(typedLink('https://hello'), isNull);
      expect(typedLink('https://hello.'), isNull);
      expect(typedLink('Look http://localhost/a ok'), isNull);
      expect(typedLink('https://x.com/a'), 'https://x.com/a');
    });

    test('a Unicode domain is a link, typed with or without a scheme (F1)', () {
      expect(typedLink('https://café.fr'), 'https://café.fr');
      expect(typedLink('café.fr'), 'https://café.fr');
      expect(typedLink('bücher.de/x'), 'https://bücher.de/x');
      expect(typedLink('Look https://bücher.de/x ok'), 'https://bücher.de/x');
      expect(typedLink('https://例え.jp/a'), 'https://例え.jp/a');
    });

    test('a punycode domain is still a link (F1)', () {
      expect(typedLink('https://xn--caf-dma.fr'), 'https://xn--caf-dma.fr');
      expect(typedLink('xn--caf-dma.fr'), 'https://xn--caf-dma.fr');
    });

    test('a bad percent run in a host is not a link (F1)', () {
      expect(typedLink('https://%zz.com'), isNull);
      expect(typedLink('%zz.com'), isNull);
      expect(typedLink('https://%.com'), isNull);
      expect(typedLink('https://%2.com'), isNull);
      expect(typedLink('https://caf%.fr'), isNull);
      expect(typedLink('https://%C3.com'), isNull);
    });

    test('whatever it gives, normalizeReferenceUrl accepts', () {
      for (final text in [
        'x.com/a',
        'https://x.com/a)',
        ' www.instagram.com/reel/A1/ ',
        'Look https://instagram.com/reel/A1 wow',
      ]) {
        final link = typedLink(text);
        expect(link, isNotNull, reason: text);
        expect(normalizeReferenceUrl(link!), isNotNull, reason: text);
      }
    });
  });

  group('pastedLink', () {
    test('a text with a link gives the first link, like firstLinkIn', () {
      expect(pastedLink('Look https://x.com/a. ok'), 'https://x.com/a');
      expect(
        pastedLink('a https://youtu.be/AAA b https://youtu.be/BBB'),
        'https://youtu.be/AAA',
      );
      expect(pastedLink('(https://x.com/a)'), 'https://x.com/a');
    });

    test('a link without a dotted host is not a link', () {
      expect(pastedLink('see https://hello.'), isNull);
      expect(pastedLink('https://hello'), isNull);
      expect(pastedLink('Look http://localhost/a ok'), isNull);
      expect(pastedLink('https://.com'), isNull);
      expect(pastedLink('https://a..com'), isNull);
      expect(pastedLink('https://3.5'), isNull);
    });

    test('an IP address and a port are fine', () {
      expect(pastedLink('https://192.168.1.2/a'), 'https://192.168.1.2/a');
      expect(pastedLink('https://x.com:8080/a'), 'https://x.com:8080/a');
    });

    test('a bare address, words, nothing: null', () {
      expect(pastedLink('instagram.com/reel/abc'), isNull);
      expect(pastedLink('www.instagram.com/reel/abc'), isNull);
      expect(pastedLink('hello world'), isNull);
      expect(pastedLink(''), isNull);
      expect(pastedLink('   '), isNull);
      expect(pastedLink('https://'), isNull);
    });

    test(
      'whatever it gives, typedLink gives the same (Paste and Save agree)',
      () {
        for (final text in [
          'https://x.com/a',
          'Look https://instagram.com/reel/A1 wow',
          'a https://youtu.be/AAA b https://youtu.be/BBB',
          'see https://hello.',
          'https://hello',
        ]) {
          final pasted = pastedLink(text);
          if (pasted != null) expect(typedLink(pasted), pasted, reason: text);
        }
      },
    );

    test('a very long text is fine', () {
      expect(
        pastedLink('${'word ' * 20000}https://x.com/end.'),
        'https://x.com/end',
      );
    });

    test('a pasted caption with a Unicode domain gives the link (F1)', () {
      expect(
        pastedLink('Great shop https://bücher.de/x thanks'),
        'https://bücher.de/x',
      );
      expect(pastedLink('https://café.fr'), 'https://café.fr');
      expect(
        pastedLink('see https://xn--caf-dma.fr/a'),
        'https://xn--caf-dma.fr/a',
      );
      expect(pastedLink('see https://%zz.com'), isNull);
    });
  });

  group('shortLink', () {
    test('drops the scheme, www and the trailing slash', () {
      expect(
        shortLink('https://www.instagram.com/p/ABC/'),
        'instagram.com/p/ABC',
      );
    });

    test('drops m., the query and the fragment', () {
      expect(
        shortLink('https://m.youtube.com/watch?v=1#t'),
        'youtube.com/watch',
      );
    });

    test('a host alone', () {
      expect(shortLink('https://example.com'), 'example.com');
      expect(shortLink('http://example.com/'), 'example.com');
    });

    test('several trailing slashes go', () {
      expect(shortLink('https://example.com/a///'), 'example.com/a');
    });

    test('only a leading www. or m. goes', () {
      expect(shortLink('https://vm.tiktok.com/ZM8x/'), 'vm.tiktok.com/ZM8x');
      expect(shortLink('https://x.www.example.com/a'), 'x.www.example.com/a');
    });

    test('a fragment alone goes', () {
      expect(shortLink('https://example.com/a#top'), 'example.com/a');
    });
  });

  group('shortLink shows a percent-encoded host decoded (M32)', () {
    test('caf%C3%A9.fr/x is café.fr/x', () {
      expect(shortLink('https://caf%C3%A9.fr/x'), 'café.fr/x');
    });

    test('lower-case hex, a leading www. and the slash', () {
      expect(shortLink('https://www.caf%c3%a9.fr/'), 'café.fr');
    });

    test('the port stays', () {
      expect(shortLink('https://caf%C3%A9.fr:8080/x'), 'café.fr:8080/x');
    });

    test('a link as normalizeReferenceUrl stores it', () {
      final stored = normalizeReferenceUrl('https://café.fr/menu?a=1')!;
      expect(stored.toString(), contains('%C3%A9'));
      expect(shortLink(stored.toString()), 'café.fr/menu');
    });

    test('a Cyrillic host', () {
      final stored = normalizeReferenceUrl('https://пример.рф/a')!;
      expect(shortLink(stored.toString()), 'пример.рф/a');
    });

    test('only the host is decoded: the path keeps its %XX', () {
      expect(
        shortLink('https://example.com/caf%C3%A9'),
        'example.com/caf%C3%A9',
      );
      expect(shortLink('https://example.com/a%2Fb'), 'example.com/a%2Fb');
    });

    test('a run that is not valid UTF-8 stays as it is', () {
      expect(shortLink('https://%C3.com/x'), '%C3.com/x');
      expect(shortLink('https://%zz.com/x'), '%zz.com/x');
    });

    test('a decoded host never gains a slash, a query mark or a space', () {
      expect(shortLink('https://a%2Fb.com/x'), 'a%2Fb.com/x');
      expect(shortLink('https://a%3Fb.com/x'), 'a%3Fb.com/x');
      expect(shortLink('https://a%20b.com/x'), 'a%20b.com/x');
      expect(shortLink('https://a%23b.com/x'), 'a%23b.com/x');
      expect(shortLink('https://a%40b.com/x'), 'a%40b.com/x');
    });

    test('an ordinary host is not touched', () {
      expect(shortLink('https://example.com/a'), 'example.com/a');
    });
  });

  group('referenceKindOf', () {
    ReferenceKind kind(String raw) =>
        referenceKindOf(normalizeReferenceUrl(raw)!);

    test('an Instagram post or reel is instagram', () {
      expect(kind('https://www.instagram.com/p/ABC/'), ReferenceKind.instagram);
      // Normalisation turns /reel/ into /p/.
      expect(
        kind('https://www.instagram.com/reel/ABC/'),
        ReferenceKind.instagram,
      );
    });

    test('an Instagram profile is instagramProfile', () {
      expect(
        kind('https://www.instagram.com/someuser/'),
        ReferenceKind.instagramProfile,
      );
    });

    test('a YouTube Short is youtubeShort', () {
      expect(
        kind('https://www.youtube.com/shorts/abc'),
        ReferenceKind.youtubeShort,
      );
    });

    test('other YouTube is youtubeVideo', () {
      expect(
        kind('https://www.youtube.com/watch?v=abc'),
        ReferenceKind.youtubeVideo,
      );
      expect(kind('https://youtu.be/abc'), ReferenceKind.youtubeVideo);
    });

    test('TikTok is tiktok', () {
      expect(kind('https://vm.tiktok.com/ZM8x/'), ReferenceKind.tiktok);
    });

    test('anything else is link', () {
      expect(kind('https://example.com/a'), ReferenceKind.link);
    });
  });
}
