/// The phone makers the help screen has steps for (D-107). Several makers
/// share one set of steps, because they share one Android skin; the order is
/// the order of the cards on the help screen (`screens.js`:
/// `routes['notif-help']`).
enum PhoneBrand { samsung, xiaomi, oppo, vivo, oneplus }

/// The brand whose steps fit a phone made by [maker], or null for any other
/// maker (the help screen then opens no card).
///
/// [maker] is the name Android reports (`Build.MANUFACTURER`; the bridge
/// lower-cases it). The whole name has to match: `samsungx` is nobody. Case
/// and spaces round it are ignored.
///
/// - Xiaomi's sub-brands Redmi and POCO have Xiaomi's skin, Realme has
///   Oppo's, and iQOO has Vivo's.
/// - The maker is never logged (D-10): it says which phone the user has.
PhoneBrand? brandOf(String maker) => switch (maker.trim().toLowerCase()) {
  'samsung' => PhoneBrand.samsung,
  'xiaomi' || 'redmi' || 'poco' => PhoneBrand.xiaomi,
  'oppo' || 'realme' => PhoneBrand.oppo,
  'vivo' || 'iqoo' => PhoneBrand.vivo,
  'oneplus' => PhoneBrand.oneplus,
  _ => null,
};
