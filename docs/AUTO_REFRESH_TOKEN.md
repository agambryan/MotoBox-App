# Auto Refresh Token - Penjelasan Lengkap

## ❓ Apa itu Auto Refresh Token?

Auto Refresh Token adalah mekanisme untuk **secara otomatis memperpanjang masa berlaku session user** tanpa user harus login ulang.

---

## 🤔 Mengapa Perlu Auto Refresh Token?

### Masalah Tanpa Auto Refresh:

1. **Token Expire:**
   - Token Supabase biasanya expire dalam **1 jam**
   - Setelah 1 jam, user akan otomatis **logout**
   - User harus **login ulang** (bad UX!)

2. **Background Sync Gagal:**
   - Jika token expire, sync ke cloud **gagal**
   - Data tidak tersimpan
   - Inconsistency antara local & cloud

3. **Bad User Experience:**
   ```
   User Story (TANPA auto refresh):
   - 09:00 - User login
   - 10:00 - Token expire
   - 10:01 - User buka app
   - ❌ User tiba-tiba logout
   - 😠 User harus login lagi
   ```

### Solusi Dengan Auto Refresh:

```
User Story (DENGAN auto refresh):
- 09:00 - User login
- 09:50 - Auto refresh token (background)
- 10:40 - Auto refresh token (background)
- 11:30 - Auto refresh token (background)
- ✅ User tetap login
- 😊 Seamless experience
```

---

## 🔧 Bagaimana Cara Kerjanya?

### 1. Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Supabase Service                          │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────────┐      ┌──────────────────────────┐    │
│  │  Timer (50 min)  │──────▶│  Auto Refresh Token      │    │
│  └──────────────────┘      └──────────────────────────┘    │
│                                                               │
│  ┌──────────────────┐      ┌──────────────────────────┐    │
│  │  Auth Stream     │──────▶│  Session Monitoring      │    │
│  └──────────────────┘      └──────────────────────────┘    │
│                                                               │
└─────────────────────────────────────────────────────────────┘
         │                              │
         │                              │
         ▼                              ▼
  ┌─────────────┐            ┌──────────────────┐
  │   Supabase  │            │  Handle Events   │
  │     Auth    │            │  - Signed In     │
  │             │            │  - Signed Out    │
  │  (Cloud)    │            │  - Token Refresh │
  └─────────────┘            │  - Expired       │
                             └──────────────────┘
```

### 2. Dual Layer Protection

#### Layer 1: Supabase SDK (Built-in)
- Supabase Flutter SDK **sudah punya auto refresh**
- Otomatis refresh sebelum expire
- Handles network errors

#### Layer 2: Our Implementation (Backup)
```dart
// Backup timer - refresh every 50 minutes
_refreshTimer = Timer.periodic(const Duration(minutes: 50), (_) async {
  await client.auth.refreshSession();
});
```

**Why 50 minutes?**
- Token expire dalam **60 menit**
- Refresh di **50 menit** = safety buffer 10 menit
- Jika Supabase SDK fail, backup timer akan trigger

---

## 📋 Implementation Details

### Code Flow:

```dart
// 1. User Login
Future<AuthResponse> signIn({
  required String email,
  required String password,
}) async {
  final response = await client.auth.signInWithPassword(
    email: email,
    password: password,
  );

  if (response.session != null) {
    _startAutoRefresh();        // ← Start timer
    _startSessionMonitoring();  // ← Monitor auth events
  }

  return response;
}

// 2. Start Auto Refresh Timer
void _startAutoRefresh() {
  _refreshTimer = Timer.periodic(const Duration(minutes: 50), (_) async {
    final session = client.auth.currentSession;
    if (session != null) {
      debugPrint('Auto refreshing session token...');
      await client.auth.refreshSession();  // ← Refresh!
      debugPrint('Session token refreshed successfully');
    }
  });
}

// 3. Monitor Session Events
void _startSessionMonitoring() {
  _authSubscription = client.auth.onAuthStateChange.listen((AuthState data) {
    final event = data.event;

    if (event == AuthChangeEvent.signedOut) {
      _stopAutoRefresh();  // Stop when logout
    }
    else if (event == AuthChangeEvent.tokenRefreshed) {
      debugPrint('Token refreshed');  // Log success
    }
    else if (data.session == null) {
      _handleSessionExpired();  // Handle expired
    }
  });
}
```

---

## 🔍 Session Monitoring

### Events yang Di-monitor:

1. **`signedIn`**
   - User berhasil login
   - **Action:** Start auto refresh timer

2. **`signedOut`**
   - User logout
   - **Action:** Stop auto refresh timer

3. **`tokenRefreshed`**
   - Token berhasil di-refresh
   - **Action:** Log ke console (debug)

4. **`userUpdated`**
   - User profile updated
   - **Action:** Log ke console (debug)

5. **Session Expired**
   - Token gagal refresh & expired
   - **Action:** Trigger `_handleSessionExpired()`

### Handle Session Expired:

```dart
void _handleSessionExpired() {
  debugPrint('Handling session expired...');
  // UI layer akan listen auth stream
  // Otomatis redirect ke login page
}
```

Di UI layer (seperti `main.dart` atau wrapper):
```dart
StreamBuilder<AuthState>(
  stream: Supabase.instance.client.auth.onAuthStateChange,
  builder: (context, snapshot) {
    if (snapshot.hasData) {
      final session = snapshot.data!.session;

      if (session == null) {
        // Session expired - redirect to login
        return LoginPage();
      }

      // Session valid - show app
      return HomePage();
    }

    return LoadingPage();
  },
)
```

---

## 🛡️ Error Handling

### Scenario 1: Network Error

```dart
try {
  await client.auth.refreshSession();
} catch (e) {
  debugPrint('Error auto refreshing token: $e');
  // Timer will retry in next cycle (50 min)
  // Supabase SDK will also retry
}
```

### Scenario 2: Invalid Session

```dart
final session = client.auth.currentSession;
if (session != null) {
  // Only refresh if session exists
  await client.auth.refreshSession();
}
```

### Scenario 3: Token Already Expired

```dart
// Check if session is still valid
Future<bool> isSessionValid() async {
  final session = await getCurrentSession();
  if (session == null) return false;

  final expiresAt = session.expiresAt;
  if (expiresAt == null) return false;

  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  return expiresAt > now;
}

// Manual refresh if needed
if (!await isSessionValid()) {
  await refreshSession();
}
```

---

## 📊 Timeline Example

```
Time  | Event                          | Action
------|--------------------------------|----------------------------------
09:00 | User login                     | Start timer (50 min)
      |                                | Start monitoring
09:50 | Timer trigger                  | Auto refresh token (background)
      |                                | New token valid until 10:50
10:40 | Timer trigger                  | Auto refresh token (background)
      |                                | New token valid until 11:40
11:30 | Timer trigger                  | Auto refresh token (background)
      |                                | New token valid until 12:30
12:00 | User logout                    | Stop timer
      |                                | Stop monitoring
```

---

## 💡 Benefits

### 1. Seamless UX
- User **tidak pernah logout** secara tiba-tiba
- Tidak perlu login ulang
- App always ready

### 2. Background Sync
- Sync queue bisa jalan background
- Token selalu valid
- Data always synced

### 3. Security
- Token tetap expire (security)
- Tapi auto-renewed (convenience)
- Best of both worlds

### 4. Reliability
- Dual-layer: SDK + Our timer
- Jika satu fail, ada backup
- Monitor via auth stream

---

## 🔧 Configuration

### Customize Refresh Interval:

```dart
// Default: 50 minutes
const refreshInterval = Duration(minutes: 50);

// For testing: 5 minutes
const refreshInterval = Duration(minutes: 5);

// For production: 45-50 minutes recommended
const refreshInterval = Duration(minutes: 45);
```

### Disable Auto Refresh (Not Recommended):

```dart
// Don't start auto refresh
Future<AuthResponse> signIn({...}) async {
  final response = await client.auth.signInWithPassword(...);

  // Comment out these lines
  // _startAutoRefresh();
  // _startSessionMonitoring();

  return response;
}
```

---

## 🧪 Testing

### Manual Test:

```dart
// 1. Login
await supabaseService.signIn(
  email: 'test@example.com',
  password: 'password',
);

// 2. Check logs after 50 minutes
// You should see:
// "Auto refreshing session token..."
// "Session token refreshed successfully"

// 3. Verify session still valid
final isValid = await supabaseService.isSessionValid();
print(isValid); // Should be true
```

### Force Refresh Test:

```dart
// Manually trigger refresh
await supabaseService.refreshSession();

// Check if successful
final session = await supabaseService.getCurrentSession();
print(session?.expiresAt); // Should be ~1 hour from now
```

---

## ⚠️ Important Notes

1. **Supabase SDK Already Handles This**
   - Supabase Flutter SDK punya built-in auto refresh
   - Implementation kita adalah **backup layer**
   - Untuk extra reliability

2. **Don't Refresh Too Often**
   - Jangan set interval terlalu pendek (< 30 min)
   - Waste of network & battery
   - 50 menit adalah sweet spot

3. **Always Clean Up**
   ```dart
   void dispose() {
     _stopAutoRefresh();
     _stopSessionMonitoring();
   }
   ```

4. **Monitor Production**
   - Log refresh events
   - Track success/fail rate
   - Monitor session expiry issues

---

## 📚 References

- [Supabase Auth Docs](https://supabase.com/docs/guides/auth)
- [Flutter Timer Docs](https://api.flutter.dev/flutter/dart-async/Timer-class.html)
- [JWT Token Best Practices](https://tools.ietf.org/html/rfc8725)

---

## 🎯 Summary

**Auto Refresh Token:**
- ✅ Prevents unexpected logout
- ✅ Enables background sync
- ✅ Better user experience
- ✅ Dual-layer protection
- ✅ Monitored via auth stream
- ✅ Automatic cleanup

**Without Auto Refresh:**
- ❌ User logout setelah 1 jam
- ❌ Sync gagal
- ❌ Bad UX
- ❌ Frequent re-login

**Conclusion:** Auto refresh token adalah **essential feature** untuk production app yang memerlukan persistent login dan background sync.
