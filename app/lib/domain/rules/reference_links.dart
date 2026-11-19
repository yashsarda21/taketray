import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/rules/reference_url.dart';

final _linkRun = RegExp(r'https?://\S+', caseSensitive: false);
final _trailingPunctuation = RegExp(r'[).,!]+$');
final _scheme = RegExp('^https?://', caseSensitive: false);
final _leadingSubdomain = RegExp(r'^(?:www|m)\.', caseSensitive: false);
final _trailingSlashes = RegExp(r'/+$');
final _whitespace = RegExp(r'\s');

/// The first `http://` or `https://` run of non-space characters in [text]
/// (the scheme in any case), with the `)`, `.`, `,` and `!` that end a
/// sentence stripped from its end; null when there is none.
///
/// Nothing else is cleaned: callers pass the result to
/// `normalizeReferenceUrl`. A bare `www.` address is not a link here.
String? firstLinkIn(String text) {
  final match = _linkRun.firstMatch(text);
  if (match == null) return null;
  final link = match.group(0)!.replaceFirst(_trailingPunctuation, '');
  // Only a scheme left (`(https://).`): not a link.
  if (_scheme.stringMatch(link) == link) return null;
  return link;
}

/// The link in what the user typed or pasted into an address field.
///
/// A text with a link in it gives [firstLinkIn]. Otherwise, a text with no
/// space inside (after trimming) is taken for an address without its scheme:
/// the `)`, `.`, `,` and `!` that end a sentence are stripped from its end,
/// as [firstLinkIn] does, and it gets `https://`. Anything else gives null.
///
/// What it gives is never junk (D-157): `normalizeReferenceUrl` accepts it,
/// and its host has a dot with a name on both sides of every dot, such as
/// `x.com` (so `hello.`, `.com` and `a..com` are not links). Its last part
/// has a letter (`3.5` is a number, not an address), unless it is an IPv4
/// address. A bare address with a user name in it (`user@example.com`,
/// `mailto:a@b.com`) is not a link. A link with a scheme needs the dotted
/// host too, so `https://hello` is not one.
String? typedLink(String text) {
  final found = firstLinkIn(text);
  if (found != null) return _withDottedHost(found);
  final trimmed = text.trim();
  if (trimmed.isEmpty || trimmed.contains(_whitespace)) return null;
  final address = trimmed.replaceFirst(_trailingPunctuation, '');
  final link = 'https://$address';
  final url = normalizeReferenceUrl(link);
  if (url == null || url.userInfo.isNotEmpty) return null;
  return _withDottedHost(link);
}

/// A name with letters or digits, `-` or `_`: one part of a host.
final _hostPart = RegExp(r'^[\p{L}\p{N}_-]+$', unicode: true);
final _digits = RegExp(r'^\d+$');

/// [link] when `normalizeReferenceUrl` accepts it and its host is dotted
/// (see [typedLink]), else null.
String? _withDottedHost(String link) {
  final url = normalizeReferenceUrl(link);
  if (url == null) return null;
  final parts = url.host.split('.');
  if (parts.length < 2 || !parts.every(_hostPart.hasMatch)) return null;
  final isIpv4 = parts.length == 4 && parts.every(_digits.hasMatch);
  if (!isIpv4 && _digits.hasMatch(parts.last)) return null;
  return link;
}

/// A link for a card's subtitle or a missing title: [url] without its scheme,
/// a leading `www.` or `m.`, the query, the fragment and trailing slashes, so
/// `https://www.instagram.com/p/ABC/` is `instagram.com/p/ABC`.
String shortLink(String url) {
  var short = url.replaceFirst(_scheme, '');
  final cut = short.indexOf(RegExp('[?#]'));
  if (cut >= 0) short = short.substring(0, cut);
  return short
      .replaceFirst(_leadingSubdomain, '')
      .replaceFirst(_trailingSlashes, '');
}

/// What a saved link is, for the label and icon on its card.
enum ReferenceKind {
  instagram,
  instagramProfile,
  youtubeShort,
  youtubeVideo,
  tiktok,
  link,
}

/// The kind of [url], which should come from `normalizeReferenceUrl`.
///
/// Normalisation rewrites an Instagram `/reel/` link to `/p/`, so a saved
/// reel and a saved post are both [ReferenceKind.instagram]; any other
/// Instagram path is a profile (D-154).
ReferenceKind referenceKindOf(Uri url) => switch (referenceSourceOf(url)) {
  ReferenceSource.instagram =>
    url.path.startsWith('/p/')
        ? ReferenceKind.instagram
        : ReferenceKind.instagramProfile,
  ReferenceSource.youtube =>
    url.path.startsWith('/shorts/')
        ? ReferenceKind.youtubeShort
        : ReferenceKind.youtubeVideo,
  ReferenceSource.tiktok => ReferenceKind.tiktok,
  ReferenceSource.link => ReferenceKind.link,
};
