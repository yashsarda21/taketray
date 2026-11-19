import 'package:taketray/platform/links_bridge.dart';

/// A [LinksBridge] for the Patrol reference flows (Phase 9A, D-161): no link
/// is ever opened on the phone, so no browser, Instagram or YouTube starts
/// in front of the test and nothing outside TakeTray Dev is touched.
///
/// - **`openLink`** records the link and answers [answer] (true by default:
///   an app opened it). It answers false at once, as the real bridge does
///   (D-155), for anything that is not an `http` or `https` link, so a flow
///   cannot hide a link Android would refuse.
/// - **[opened]** is every link asked for, in order, for the flow to prove
///   that a tap reached the bridge with the stored link.
///
/// The real bridge, Android's choice of app and the Instagram and YouTube
/// apps are on the owner's hand-check list (`docs/dev-setup.md`, "Phase 9A
/// check"). The unit tests have their own `FakeLinksBridge`
/// (`test/support/fake_links_bridge.dart`): the Patrol and unit test trees
/// import nothing from each other.
///
/// Nothing here prints a link (D-10).
class PatrolLinksBridge implements LinksBridge {
  final List<String> _opened = [];

  /// What `openLink` answers for an `http` or `https` link.
  bool answer = true;

  /// Every link asked for since the start or the last [clear], in order.
  List<String> get opened => List.unmodifiable(_opened);

  /// Forgets the recorded links. [answer] stays.
  void clear() => _opened.clear();

  @override
  Future<bool> openLink(String url) async {
    _opened.add(url);
    final scheme = Uri.tryParse(url)?.scheme;
    if (scheme != 'http' && scheme != 'https') return false;
    return answer;
  }
}
