/// Called before clips leave reel [reelId] by a path that has no screen-level
/// clean-up of its own (R8, D-123): it deletes the copies of those clips
/// (`EditSessionService.beforeClipsLeaveReel`). When it throws, the caller
/// changes nothing.
///
/// Repositories take it as an optional argument so they never depend on the
/// editing service: the providers wire the service in, and a repository built
/// without one (most tests) skips the step.
typedef BeforeClipsLeave = Future<void> Function(int reelId, Set<int> clipIds);
