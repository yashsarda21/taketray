package app.taketray.background

import android.content.Context

/**
 * Arms the background work for a freshly written [BackgroundState]: the
 * new-clips job (Task 4) and the reminder alarms (Task 5). Called by
 * `BackgroundHostApiImpl.writeState` after the state is stored, and by the
 * receivers that re-arm after a reboot, an update or a clock change.
 */
fun interface Arming {
    fun apply(
        context: Context,
        state: BackgroundState,
    )

    companion object {
        /** Arms nothing: what MainActivity wires until Tasks 4 and 5 add the job and the alarms. */
        val NONE = Arming { _, _ -> }
    }
}
