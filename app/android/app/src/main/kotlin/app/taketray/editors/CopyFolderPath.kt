package app.taketray.editors

object CopyFolderPath {
    const val ROOT = "Movies/TakeTray/"
    fun relativePath(folder: String): String = "$ROOT$folder/"

    /**
     * Exactly Movies/TakeTray/<folder>/, ignoring ASCII case only; never a
     * deeper folder, "TakeTray Test" or a Unicode lookalike (a Kelvin sign for
     * k, a dotless i): Kotlin's `ignoreCase` would fold those onto ASCII.
     */
    fun isInFolder(rowRelativePath: String?, folder: String): Boolean =
        rowRelativePath != null && equalsAscii(rowRelativePath, relativePath(folder))

    /** [path] begins with [ROOT], ignoring ASCII case only. */
    fun startsWithRoot(path: String): Boolean = path.length >= ROOT.length && equalsAscii(path.substring(0, ROOT.length), ROOT)

    fun isOwn(ownerPackage: String?, ourPackage: String): Boolean = ownerPackage == ourPackage

    private fun equalsAscii(a: String, b: String): Boolean = a.length == b.length && a.indices.all { asciiLower(a[it]) == asciiLower(b[it]) }

    private fun asciiLower(c: Char): Char = if (c in 'A'..'Z') c + ('a' - 'A') else c
}
