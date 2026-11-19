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
/// space inside (after trimming) and a `.` is taken for an address without its
/// scheme, and gets `https://`. Anything else gives null.
String? typedLink(String text) {
  final found = firstLinkIn(text);
  if (found != null) return found;
  final trimmed = text.trim();
  if (trimmed.isNotEmpty &&
      !trimmed.contains(_whitespace) &&
      trimmed.contains('.')) {
    return 'https://$trimmed';
  }
  return null;
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
