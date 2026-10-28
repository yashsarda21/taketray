package app.taketray

import io.flutter.embedding.engine.FlutterEngine

/** No debug hooks outside debug builds (the debug copy is in src/debug). */
object DebugHooks {
    @Suppress("UNUSED_PARAMETER")
    fun register(engine: FlutterEngine) {}
}
