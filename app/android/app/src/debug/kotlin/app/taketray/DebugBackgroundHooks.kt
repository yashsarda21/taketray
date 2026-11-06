package app.taketray

import android.app.NotificationManager
import android.app.job.JobScheduler
import android.content.Context
import android.util.Log
import app.taketray.background.NewClipsJobService
import app.taketray.background.ReminderScheduler
import app.taketray.background.Receivers
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlin.coroutines.cancellation.CancellationException
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.asCoroutineDispatcher
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * Debug-only hooks for the on-device background tests (Phase 6, Task 9):
 * registers the `app.taketray/test_background` channel. The release and
 * profile builds have none of this (`DebugHooks` there registers nothing),
 * and `tool/check_release_permissions` fails if the release dex holds it.
 */
object DebugBackgroundHooks {
    fun register(
        engine: FlutterEngine,
        context: Context,
    ) {
        MethodChannel(engine.dartExecutor.binaryMessenger, DebugBackgroundHandler.CHANNEL)
            .setMethodCallHandler(DebugBackgroundHandler(context.applicationContext))
    }
}

/**
 * The method channel [CHANNEL]. Each hook goes through the code Android
 * itself reaches, never a copy of it:
 *
 * - `fireEvening`: sends the broadcast the evening alarm carries
 *   ([ReminderScheduler.eveningIntent]) to `ReminderReceiver`, so the manifest
 *   entry, the receiver, its thread and its rules (the reminder on, one a
 *   day, only clips shot today) all run. Answers success once the broadcast is
 *   sent, not when the notification is posted: the receiver works on its own
 *   thread.
 * - `fireStill`: the same for Still shooting?, with the stored session
 *   ([ReminderScheduler.stillIntent]); `no-session` when Shooting mode is off
 *   (the real alarm is not armed then either).
 * - `runNewClipsJob`: the job's work, built by the service's own factory
 *   ([NewClipsJobService.newJob]) and run on the service's thread, so it never
 *   overlaps a real run. `JobScheduler` cannot be forced to run a job by an
 *   app. Answers success when the run (and its re-arming) is over.
 * - `activeNotifications`: the ids of this app's own notifications now in the
 *   shade (`NotificationManager.activeNotifications` only ever returns the
 *   calling app's), sorted. Another app's notification is never seen. The
 *   tests use it where opening the shade would move the app (focus loss and
 *   a resume run the scan, which clears the new-clips notification).
 * - `pendingJobs`: the ids of this app's pending jobs (`JobScheduler` only
 *   lists the calling app's), sorted: exactly one new-clips job must be there.
 *
 * Errors reach Dart as `native-error` with the method and the exception's
 * class name only, never a message, a name or a path (D-10).
 */
class DebugBackgroundHandler(
    private val context: Context,
    private val scope: CoroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.Main),
    private val io: CoroutineDispatcher = NewClipsJobService.executor.asCoroutineDispatcher(),
) : MethodChannel.MethodCallHandler {
    override fun onMethodCall(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        val method = call.method
        scope.launch {
            try {
                when (method) {
                    "fireEvening" -> {
                        context.sendBroadcast(ReminderScheduler.eveningIntent(context))
                        result.success(null)
                    }
                    "fireStill" -> {
                        val state = Receivers.store(context).state()
                        val since = state.sinceMs
                        if (!state.shootingOn || since == null) {
                            Log.w(TAG, "$method: no session")
                            result.error("no-session", "Shooting mode is off", null)
                        } else {
                            context.sendBroadcast(ReminderScheduler.stillIntent(context, since))
                            result.success(null)
                        }
                    }
                    "runNewClipsJob" -> {
                        withContext(io) { NewClipsJobService.newJob(context).run() }
                        result.success(null)
                    }
                    "activeNotifications" ->
                        result.success(context.getSystemService(NotificationManager::class.java).activeNotifications.map { it.id }.sorted())
                    "pendingJobs" ->
                        result.success(context.getSystemService(JobScheduler::class.java).allPendingJobs.map { it.id }.sorted())
                    else -> result.notImplemented()
                }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Throwable) {
                Log.w(TAG, "$method failed: ${e.javaClass.simpleName}")
                result.error("native-error", "$method failed: ${e.javaClass.simpleName}", null)
            }
        }
    }

    companion object {
        /** The channel name Dart uses (`patrol_test/support/test_background.dart`). */
        const val CHANNEL = "app.taketray/test_background"

        private const val TAG = "TakeTrayTestBackground"
    }
}
