package app.taketray.background

import android.content.SharedPreferences

/**
 * SharedPreferences with a "disk" that only `commit()` writes, for proving
 * that a store survives its process ending right after a write (a receiver,
 * the job). `apply()` changes the in-memory values only, as a real `apply()`
 * does until its queued write runs; [afterProcessEnd] is a new process
 * reading the disk. (Under Robolectric a real `apply()` reaches the file at
 * once, so re-reading the real file cannot tell the two apart.)
 */
class ProcessPrefs private constructor(
    private val disk: MutableMap<String, Any?>,
) : SharedPreferences {
    constructor() : this(mutableMapOf())

    private val memory = HashMap(disk)

    /** What a new process would read: the committed values only. */
    fun afterProcessEnd(): ProcessPrefs = ProcessPrefs(disk)

    override fun getAll(): Map<String, *> = HashMap(memory)

    override fun getString(
        key: String,
        defValue: String?,
    ): String? = if (memory.containsKey(key)) memory[key] as String? else defValue

    @Suppress("UNCHECKED_CAST")
    override fun getStringSet(
        key: String,
        defValues: Set<String>?,
    ): Set<String>? = if (memory.containsKey(key)) memory[key] as Set<String>? else defValues

    override fun getInt(
        key: String,
        defValue: Int,
    ): Int = if (memory.containsKey(key)) memory[key] as Int else defValue

    override fun getLong(
        key: String,
        defValue: Long,
    ): Long = if (memory.containsKey(key)) memory[key] as Long else defValue

    override fun getFloat(
        key: String,
        defValue: Float,
    ): Float = if (memory.containsKey(key)) memory[key] as Float else defValue

    override fun getBoolean(
        key: String,
        defValue: Boolean,
    ): Boolean = if (memory.containsKey(key)) memory[key] as Boolean else defValue

    override fun contains(key: String): Boolean = memory.containsKey(key)

    override fun edit(): SharedPreferences.Editor = Editor()

    override fun registerOnSharedPreferenceChangeListener(listener: SharedPreferences.OnSharedPreferenceChangeListener) =
        throw UnsupportedOperationException()

    override fun unregisterOnSharedPreferenceChangeListener(listener: SharedPreferences.OnSharedPreferenceChangeListener) =
        throw UnsupportedOperationException()

    private inner class Editor : SharedPreferences.Editor {
        private val changes = LinkedHashMap<String, Any?>()
        private val removed = mutableSetOf<String>()
        private var clear = false

        private fun put(
            key: String,
            value: Any?,
        ) = apply {
            removed -= key
            changes[key] = value
        }

        override fun putString(
            key: String,
            value: String?,
        ) = put(key, value)

        override fun putStringSet(
            key: String,
            values: Set<String>?,
        ) = put(key, values)

        override fun putInt(
            key: String,
            value: Int,
        ) = put(key, value)

        override fun putLong(
            key: String,
            value: Long,
        ) = put(key, value)

        override fun putFloat(
            key: String,
            value: Float,
        ) = put(key, value)

        override fun putBoolean(
            key: String,
            value: Boolean,
        ) = put(key, value)

        override fun remove(key: String) =
            apply {
                changes -= key
                removed += key
            }

        override fun clear() = apply { clear = true }

        private fun applyTo(map: MutableMap<String, Any?>) {
            if (clear) map.clear()
            removed.forEach { map -= it }
            map += changes
        }

        override fun commit(): Boolean {
            applyTo(memory)
            applyTo(disk)
            return true
        }

        override fun apply() = applyTo(memory)
    }
}
