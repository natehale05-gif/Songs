/// Connection details for the Supabase project that holds accounts and
/// mirrored entitlements. Injected at build time:
///
///   flutter build ... \
///     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=sb_publishable_...
///
/// The anon/publishable key is designed to be shipped in a client — row level
/// security is what protects the data, not the secrecy of this key. The
/// service role key must never appear in the app.
library;

const String kSupabaseUrl = String.fromEnvironment('SUPABASE_URL');
const String kSupabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

/// Whether this build can sign in and check entitlements at all.
///
/// When false the paid features stay unlocked. A build that cannot verify an
/// entitlement must not lock anyone out on the strength of a paywall it has no
/// way to honour.
bool get billingConfigured =>
    kSupabaseUrl.trim().isNotEmpty && kSupabaseAnonKey.trim().isNotEmpty;
