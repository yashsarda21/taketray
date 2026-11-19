import 'package:taketray/domain/models/reel_reference.dart';
import 'package:taketray/domain/rules/reference_links.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';

final _leadingSubdomain = RegExp(r'^(?:www|m)\.');

/// What the link [url] is, in words, for a reference card and the Edit label
/// sheet: "Instagram", "Instagram profile", "YouTube Short", "YouTube video"
/// or "TikTok video"; for any other link, its host without a leading `www.`
/// or `m.` ("example.com"). [url] should be a saved reference's own
/// (`normalizeReferenceUrl`'s form).
String referenceKindText(AppLocalizations l10n, Uri url) =>
    switch (referenceKindOf(url)) {
      ReferenceKind.instagram => l10n.referenceKindInstagram,
      ReferenceKind.instagramProfile => l10n.referenceKindInstagramProfile,
      ReferenceKind.youtubeShort => l10n.referenceKindYoutubeShort,
      ReferenceKind.youtubeVideo => l10n.referenceKindYoutubeVideo,
      ReferenceKind.tiktok => l10n.referenceKindTiktok,
      ReferenceKind.link => url.host.replaceFirst(_leadingSubdomain, ''),
    };

/// The words of a reference card (D-157): the title is the label, or the
/// short link when there is none. The subtitle is "{kind} · {short link}"
/// with a label, or the kind alone without one (the title already is the
/// link).
({String title, String subtitle}) referenceCardText(
  AppLocalizations l10n,
  ReelReference reference,
) {
  final link = shortLink(reference.url);
  final kind = referenceKindText(l10n, Uri.tryParse(reference.url) ?? Uri());
  final label = reference.label?.trim();
  if (label == null || label.isEmpty) return (title: link, subtitle: kind);
  return (title: label, subtitle: l10n.referenceCardSubtitle(kind, link));
}
