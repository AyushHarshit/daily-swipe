# One-Tap Leave — Android App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A small native Android app (own repo, built via GitHub Actions) that marks leave from the phone — Sick (single date, default today) or Vacation (start–end range) — by dispatching the `mark-leave.yml` workflow on `AyushHarshit/daily-swipe`.

**Architecture:** Single-Activity Jetpack Compose app. A pure `buildDispatchBody` function (JVM-unit-tested) builds the JSON; `LeaveApi` POSTs it to the GitHub `workflow_dispatch` API; `TokenStore` keeps the PAT in `EncryptedSharedPreferences`. There is no local Android build — a `build-apk.yml` GitHub Actions workflow compiles the debug APK and uploads it as an artifact, which is the compile verification.

**Tech Stack:** Kotlin 1.9.24, Jetpack Compose (BOM 2024.06.00, Material 3), AGP 8.5.2, Gradle 8.7, JDK 17, `androidx.security:security-crypto` (EncryptedSharedPreferences), `HttpURLConnection` (no HTTP lib). compileSdk/targetSdk 34, minSdk 26.

## Prerequisites (USER — before Task 2's build can run)

- Create a **new GitHub repo** `daily-swipe-leave-app` under `AyushHarshit` (private is fine — Actions still builds it). Empty (no README).
- Provide push access to it. The existing fine-grained token is scoped to `daily-swipe` only, so either (a) create a **second fine-grained token** with `Contents: read/write` on `daily-swipe-leave-app` and put it in a local `.token` in that repo, reusing the `push.sh` pattern, or (b) push via an authenticated `gh`/SSH identity for the `AyushHarshit` account. The implementer will ask for confirmation that the repo + push auth exist before pushing.
- The **runtime token stored in the app** (entered on the phone) is the *existing* fine-grained **Actions: read/write on `daily-swipe`** token — it dispatches `mark-leave.yml`. It is NOT committed anywhere.

## Global Constraints

- All app code lives in the new `daily-swipe-leave-app` repo (NOT in `daily-swipe`).
- Package: `com.ayushharshit.dailyswipeleave`. App label: `Daily Swipe Leave`.
- Versions exactly: Kotlin `1.9.24`, AGP `8.5.2`, Gradle `8.7`, Compose Compiler ext `1.5.14`, Compose BOM `2024.06.00`, compileSdk/targetSdk `34`, minSdk `26`, JDK `17`.
- API call: `POST https://api.github.com/repos/AyushHarshit/daily-swipe/actions/workflows/mark-leave.yml/dispatches`, headers `Accept: application/vnd.github+json`, `Authorization: Bearer <token>`, `X-GitHub-Api-Version: 2022-11-28`, `User-Agent: daily-swipe-leave`, `Content-Type: application/json`; body `{"ref":"main","inputs":{"from":"<from>","to":"<to>"}}`; success = HTTP **204**.
- Dates formatted `YYYY-MM-DD`. Sick: `from == to` (default today). Vacation: `from <= to`.
- Token stored ONLY in `EncryptedSharedPreferences`; never logged, never committed. No secrets in source.
- APK is **debug-signed** (fine for sideload). Build in CI only; the `build-apk.yml` run is the compile check.

---

### Task 1: Buildable Compose skeleton + CI (green APK artifact)

Get the toolchain green in CI first (the riskiest part), before any logic. Deliverable: a `build-apk.yml` run that compiles a debug APK showing a placeholder screen and uploads it as an artifact.

**Files (all in `daily-swipe-leave-app`):**
- Create: `settings.gradle.kts`
- Create: `build.gradle.kts` (root)
- Create: `gradle.properties`
- Create: `app/build.gradle.kts`
- Create: `app/src/main/AndroidManifest.xml`
- Create: `app/src/main/java/com/ayushharshit/dailyswipeleave/MainActivity.kt`
- Create: `app/src/main/res/values/strings.xml`
- Create: `.github/workflows/build-apk.yml`
- Create: `.gitignore`

**Interfaces:**
- Consumes: nothing.
- Produces: a compiling Compose app + a CI job that outputs `app/build/outputs/apk/debug/app-debug.apk` as an artifact named `app-debug-apk`.

- [ ] **Step 1: `settings.gradle.kts`**
```kotlin
pluginManagement {
    repositories { google(); mavenCentral(); gradlePluginPortal() }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories { google(); mavenCentral() }
}
rootProject.name = "DailySwipeLeave"
include(":app")
```

- [ ] **Step 2: root `build.gradle.kts`**
```kotlin
plugins {
    id("com.android.application") version "8.5.2" apply false
    id("org.jetbrains.kotlin.android") version "1.9.24" apply false
}
```

- [ ] **Step 3: `gradle.properties`**
```properties
org.gradle.jvmargs=-Xmx2048m
android.useAndroidX=true
kotlin.code.style=official
```

- [ ] **Step 4: `app/build.gradle.kts`**
```kotlin
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.ayushharshit.dailyswipeleave"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.ayushharshit.dailyswipeleave"
        minSdk = 26
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"
    }
    buildTypes {
        release { isMinifyEnabled = false }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
    buildFeatures { compose = true }
    composeOptions { kotlinCompilerExtensionVersion = "1.5.14" }
}

dependencies {
    implementation(platform("androidx.compose:compose-bom:2024.06.00"))
    implementation("androidx.activity:activity-compose:1.9.0")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.security:security-crypto:1.1.0-alpha06")
    testImplementation("junit:junit:4.13.2")
}
```

- [ ] **Step 5: `app/src/main/AndroidManifest.xml`**
```xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET" />
    <application
        android:allowBackup="true"
        android:label="@string/app_name"
        android:theme="@android:style/Theme.Material.Light.NoActionBar">
        <activity android:name=".MainActivity" android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
```

- [ ] **Step 6: `app/src/main/res/values/strings.xml`**
```xml
<resources>
    <string name="app_name">Daily Swipe Leave</string>
</resources>
```

- [ ] **Step 7: `app/src/main/java/com/ayushharshit/dailyswipeleave/MainActivity.kt`** (placeholder screen)
```kotlin
package com.ayushharshit.dailyswipeleave

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MaterialTheme {
                Surface { Text("Daily Swipe Leave") }
            }
        }
    }
}
```

- [ ] **Step 8: `.gitignore`**
```gitignore
.gradle/
build/
*.apk
local.properties
.idea/
.token
.env
*.token
.DS_Store
```

- [ ] **Step 9: `.github/workflows/build-apk.yml`**
```yaml
name: Build APK
on:
  workflow_dispatch:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: "17"
      - uses: gradle/actions/setup-gradle@v4
        with:
          gradle-version: "8.7"
      - name: Build debug APK
        run: gradle assembleDebug --no-daemon
      - name: Upload APK
        uses: actions/upload-artifact@v4
        with:
          name: app-debug-apk
          path: app/build/outputs/apk/debug/app-debug.apk
          if-no-files-found: error
```

- [ ] **Step 10: Commit and push, then verify the CI build**

```bash
cd daily-swipe-leave-app
git add .
git commit -m "chore: buildable Compose skeleton + APK build workflow"
# push via your configured auth for daily-swipe-leave-app
```
Then on GitHub → the repo's **Actions** tab → the `Build APK` run (fires on push) must be **green**, with an `app-debug-apk` artifact. Download and confirm it installs and shows "Daily Swipe Leave".
Expected: green build; APK artifact present.
> If the build fails, read the Actions log and fix the version/config error (this is the expected iteration for a first Android build), then push again until green.

---

### Task 2: Dispatch payload + network + token storage

**Files (in `daily-swipe-leave-app`):**
- Create: `app/src/main/java/com/ayushharshit/dailyswipeleave/LeaveApi.kt`
- Create: `app/src/main/java/com/ayushharshit/dailyswipeleave/TokenStore.kt`
- Test: `app/src/test/java/com/ayushharshit/dailyswipeleave/LeaveApiTest.kt`

**Interfaces:**
- Consumes: nothing from Task 1 (independent logic).
- Produces:
  - `buildDispatchBody(from: String, to: String): String` — returns the exact JSON body.
  - `object LeaveApi { fun dispatch(token: String, from: String, to: String): Result<Unit> }` — POSTs; `Result.success` on HTTP 204, `Result.failure` with the status/message otherwise.
  - `class TokenStore(context: Context) { fun save(token: String); fun load(): String? }` — EncryptedSharedPreferences-backed.

- [ ] **Step 1: Write the failing unit test for the payload**

`app/src/test/java/com/ayushharshit/dailyswipeleave/LeaveApiTest.kt`:
```kotlin
package com.ayushharshit.dailyswipeleave

import org.junit.Assert.assertEquals
import org.junit.Test

class LeaveApiTest {
    @Test
    fun buildsExactDispatchBody() {
        val body = buildDispatchBody("2026-07-10", "2026-07-14")
        assertEquals(
            """{"ref":"main","inputs":{"from":"2026-07-10","to":"2026-07-14"}}""",
            body,
        )
    }

    @Test
    fun sameDaySickBody() {
        val body = buildDispatchBody("2026-07-01", "2026-07-01")
        assertEquals(
            """{"ref":"main","inputs":{"from":"2026-07-01","to":"2026-07-01"}}""",
            body,
        )
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run (in CI or locally if SDK present): `gradle testDebugUnitTest --no-daemon`
Expected: FAIL — `buildDispatchBody` unresolved. (If no local Android SDK, this RED is confirmed by the compile error; the GREEN is confirmed by the CI `test` step added in Step 5.)

- [ ] **Step 3: Write `LeaveApi.kt`**
```kotlin
package com.ayushharshit.dailyswipeleave

import java.net.HttpURLConnection
import java.net.URL

private const val DISPATCH_URL =
    "https://api.github.com/repos/AyushHarshit/daily-swipe/actions/workflows/mark-leave.yml/dispatches"

fun buildDispatchBody(from: String, to: String): String =
    """{"ref":"main","inputs":{"from":"$from","to":"$to"}}"""

object LeaveApi {
    fun dispatch(token: String, from: String, to: String): Result<Unit> {
        return try {
            val conn = (URL(DISPATCH_URL).openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                setRequestProperty("Accept", "application/vnd.github+json")
                setRequestProperty("Authorization", "Bearer $token")
                setRequestProperty("X-GitHub-Api-Version", "2022-11-28")
                setRequestProperty("User-Agent", "daily-swipe-leave")
                setRequestProperty("Content-Type", "application/json")
                doOutput = true
                connectTimeout = 15000
                readTimeout = 15000
            }
            conn.outputStream.use { it.write(buildDispatchBody(from, to).toByteArray()) }
            val code = conn.responseCode
            conn.disconnect()
            if (code == 204) Result.success(Unit)
            else Result.failure(RuntimeException("GitHub API returned HTTP $code"))
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
}
```

- [ ] **Step 4: Write `TokenStore.kt`**
```kotlin
package com.ayushharshit.dailyswipeleave

import android.content.Context
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

class TokenStore(context: Context) {
    private val prefs = EncryptedSharedPreferences.create(
        context,
        "leave_secure_prefs",
        MasterKey.Builder(context).setKeyScheme(MasterKey.KeyScheme.AES256_GCM).build(),
        EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
        EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
    )

    fun save(token: String) = prefs.edit().putString("token", token).apply()
    fun load(): String? = prefs.getString("token", null)
}
```

- [ ] **Step 5: Add the unit-test step to CI so GREEN is verified**

In `.github/workflows/build-apk.yml`, add before the "Build debug APK" step:
```yaml
      - name: Unit tests
        run: gradle testDebugUnitTest --no-daemon
```

- [ ] **Step 6: Commit, push, verify CI**

```bash
git add app/src .github/workflows/build-apk.yml
git commit -m "feat: dispatch payload, GitHub API call, encrypted token storage"
# push
```
Expected: CI `Unit tests` step passes (`buildsExactDispatchBody`, `sameDaySickBody`), then the APK builds green.

---

### Task 3: Leave screen (Sick / Vacation) wired to API + token

**Files (in `daily-swipe-leave-app`):**
- Modify: `app/src/main/java/com/ayushharshit/dailyswipeleave/MainActivity.kt`

**Interfaces:**
- Consumes: `TokenStore(context)`, `LeaveApi.dispatch(token, from, to)` from Task 2.
- Produces: the working UI. No further consumers.

- [ ] **Step 1: Replace `MainActivity.kt` with the full screen**
```kotlin
package com.ayushharshit.dailyswipeleave

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.time.LocalDate

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val store = TokenStore(this)
        setContent { MaterialTheme { LeaveScreen(store) } }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LeaveScreen(store: TokenStore) {
    val scope = rememberCoroutineScope()
    var vacation by remember { mutableStateOf(false) }
    val today = remember { LocalDate.now().toString() }
    var from by remember { mutableStateOf(today) }
    var to by remember { mutableStateOf(today) }
    var token by remember { mutableStateOf(store.load() ?: "") }
    var status by remember { mutableStateOf("") }
    var busy by remember { mutableStateOf(false) }

    Column(Modifier.padding(24.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text("Daily Swipe Leave", style = MaterialTheme.typography.headlineSmall)

        Row(verticalAlignment = androidx.compose.ui.Alignment.CenterVertically) {
            FilterChip(selected = !vacation, onClick = { vacation = false }, label = { Text("Sick") })
            Spacer(Modifier.width(8.dp))
            FilterChip(selected = vacation, onClick = { vacation = true }, label = { Text("Vacation") })
        }

        OutlinedTextField(from, { from = it }, label = { Text(if (vacation) "From (YYYY-MM-DD)" else "Date (YYYY-MM-DD)") }, singleLine = true)
        if (vacation) {
            OutlinedTextField(to, { to = it }, label = { Text("To (YYYY-MM-DD)") }, singleLine = true)
        }

        OutlinedTextField(
            token,
            { token = it; store.save(it) },
            label = { Text("GitHub token") },
            singleLine = true,
        )

        Button(
            enabled = !busy && token.isNotBlank(),
            onClick = {
                val f = from.trim()
                val t = if (vacation) to.trim() else f
                if (!isIsoDate(f) || !isIsoDate(t) || t < f) {
                    status = "Invalid date(s): use YYYY-MM-DD, and To ≥ From."
                    return@Button
                }
                busy = true; status = "Submitting…"
                scope.launch {
                    val result = withContext(Dispatchers.IO) { LeaveApi.dispatch(token, f, t) }
                    busy = false
                    status = result.fold({ "Recorded ✓ (leave $f..$t)" }, { "Failed: ${it.message}" })
                }
            },
        ) { Text("Submit") }

        if (status.isNotEmpty()) Text(status)
    }
}

private fun isIsoDate(s: String): Boolean =
    Regex("""\d{4}-\d{2}-\d{2}""").matches(s) && runCatching { LocalDate.parse(s) }.isSuccess
```

- [ ] **Step 2: Commit, push, verify CI build green**

```bash
git add app/src/main/java/com/ayushharshit/dailyswipeleave/MainActivity.kt
git commit -m "feat: Sick/Vacation leave screen wired to mark-leave dispatch"
# push
```
Expected: CI green; new `app-debug-apk` artifact.

- [ ] **Step 3: Manual end-to-end (on device)**

Download the APK artifact, sideload it (enable "install unknown apps"). In the app: paste the fine-grained **Actions:write** token once, keep **Sick / today**, tap **Submit** → expect "Recorded ✓". In GitHub → `daily-swipe` Actions → a `Mark Leave` run appears and commits today's date to `leave.yaml`. Try **Vacation** with a range and confirm the same. (Remove any test dates from `leave.yaml` afterward.)

---

## Notes & risks

- **First Android build will likely need 1–2 CI iterations** for version/config nits; that's expected — fix from the Actions log and re-push (Task 1 isolates this risk before any logic).
- **No local Android toolchain** — RED/GREEN for the one unit test is confirmed by the CI `testDebugUnitTest` step, not a local run.
- **Token never leaves the device** except as the `Authorization` header to GitHub; it's stored in `EncryptedSharedPreferences` and never logged.
- **Date pickers:** MVP uses validated text fields (`YYYY-MM-DD`) to keep the first version simple; a graphical `DatePicker` can be a later enhancement.
- **JSON building** is a tiny hand-rolled string (dates are validated ISO, so no escaping needed) — no JSON library dependency (YAGNI).
