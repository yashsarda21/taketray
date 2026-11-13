package app.taketray.editors

object CopyFolderPath {
    const val ROOT = "Movies/TakeTray/"
    fun relativePath(folder: String): String = "$ROOT$folder/"
    /** Exactly Movies/TakeTray/<folder>/, ignoring case; never a deeper folder or "TakeTray Test". */
    fun isInFolder(rowRelativePath: String?, folder: String): Boolean =
        rowRelativePath != null && rowRelativePath.equals(relativePath(folder), ignoreCase = true)
    fun isOwn(ownerPackage: String?, ourPackage: String): Boolean = ownerPackage == ourPackage
}
