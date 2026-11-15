# Raksha Kawach (रक्षा कवच)
## IoT-Powered University Transit Safety & Anti-Proxy Attendance Platform

**Institution:** SGT University  
**Event:** Synergy 2026 (18 November 2026)  
**Monorepo Architecture:** Hardware Firmware, Cloud Backend, Admin Command Center, and Student Mobile App  

---

## 1. System Overview

**Raksha Kawach** ("Safety Shield") is an enterprise fleet safety and anti-proxy transit attendance system engineered for SGT University. The system eliminates buddy punching and ghost attendance by cross-verifying physical student RFID card taps against continuous smartphone GPS telemetry in real time.

```
   ┌──────────────────┐               ┌───────────────────────────┐
   │ Student Mobile   │               │   Bus Hardware Unit       │
   │ Flutter App      │               │   ESP32 + RFID + GPS      │
   └────────┬─────────┘               └─────────────┬─────────────┘
            │ Telemetry                             │ RFID Tap + Hardware GPS
            │ (25s Foreground Service)              │ Fix
            ▼                                       ▼
   ┌──────────────────────────────────────────────────────────────┐
   │                 Supabase Cloud Infrastructure                │
   │  - PostgreSQL + Row-Level Security (RLS)                    │
   │  - Edge Functions (Anti-Proxy Geofence Cross-Check)          │
   │  - Real-Time Subscription Engine                             │
   └──────────────────────────────┬───────────────────────────────┘
                                  │ Live Telemetry & Metrics
                                  ▼
                     ┌──────────────────────────┐
                     │ Admin Command Center     │
                     │ Flutter Web Dashboard    │
                     └──────────────────────────┘
```

---

## 2. Monorepo Structure

```text
/
├── assets/                     # High-resolution institutional branding & badges
├── config/                     # Shared configuration templates
├── firmware/                   # ESP32 embedded C++ firmware (RFID, GPS, Network)
├── raksha_kawach_app/          # Flutter Student Mobile App (Android / iOS)
├── raksha_kwacch_admin/        # Flutter Web Admin Portal & Fleet Operations
├── supabase/                   # Database schemas, migrations, and RLS policies
└── scripts/                    # Hardware flashing and automation scripts
```

---

## 3. Core Subsystems

### A. Student Mobile App (`raksha_kawach_app/`)
- **Technology:** Flutter (Dart 3.x), Material 3 Nordic Minimalist Theme, Riverpod State Management, GoRouter.
- **Key Capabilities:**
  - **Authenticated Student Sessions:** Supabase Auth with secure persistent credential tokens.
  - **Digital Transit Card:** Displays student photo, enrollment code, RFID UID hash, bus code, and active pass status.
  - **Attendance History:** Real-time log of verified transit boarding events with instant IST timestamps and verification pills.
  - **Continuous Background GPS:** Android Foreground Service with persistent notification delivering continuous 25-second location synchronization to `student_phone_locations` with user-managed privacy consent.
  - **Institutional Branding:** SGT University RakshaTrack official shield and safety banner assets.

### B. Admin Command Center (`raksha_kwacch_admin/`)
- **Technology:** Flutter Web, Responsive Desktop Layout, GoRouter, Riverpod.
- **Key Capabilities:**
  - **Fleet Operations Command:** Live overview of transit vehicles, route allocations, and active bus capacities.
  - **Student & Guardian Management:** Atomic student enrollment, RFID card assignment, guardian contacts, and disciplinary strike tracking (0–3 strikes).
  - **Anti-Proxy Compliance Console:** Audits attendance scans flagged as `phone_present` vs. `phone_absent_proxy_flagged`.

### C. On-Bus IoT Hardware (`firmware/`)
- **Technology:** ESP32 Microcontroller, RC522 / PN532 RFID reader, NEO-6M / NEO-8M GPS module, SIMCOM GSM / Wi-Fi telemetry.
- **Behavior:** On card tap, captures ISO 14443A card UID, locks real-time hardware GPS fix (latitude, longitude, speed, timestamp), and publishes encrypted transit event to backend.

### D. Cloud Backend (`supabase/`)
- **Technology:** PostgreSQL 15, PostGIS, Row Level Security (RLS), Edge Functions.
- **Security:** Strict student-isolated RLS policies ensuring students can read and write only their own profiles and location telemetry.

---

## 4. Hardware-to-App Anti-Proxy Workflow

1. **Boarding Tap:** The student presents their physical RFID transit card to the bus entrance scanner.
2. **Hardware Ingestion:** The ESP32 reader reads the card UID, attaches the bus's instantaneous GPS coordinates and UTC timestamp, and transmits the payload.
3. **Anti-Proxy Geofence Evaluation:**
   - The backend retrieves the student's latest phone GPS coordinates uploaded via the Student App's background service.
   - The system calculates the Haversine distance between the bus coordinates and the student's phone coordinates at scan time.
4. **Verification Status:**
   - **Distance ≤ 50 meters:** Marked `phone_present` (Authorized & Verified).
   - **Distance > 50 meters or no recent telemetry:** Marked `phone_absent_proxy_flagged` (Anti-Proxy Violation Recorded).
5. **Real-Time Notification:** Verified status appears on the student's dashboard immediately and propagates to the Admin Command Center.

---

## 5. Development & Build Setup

### Prerequisites
- Flutter SDK (3.13.7 or higher, recommended Flutter 3.24+)
- Android SDK (API 34 / Java 17) for Student App release builds
- Chrome / Edge for Admin Dashboard Web
- Git

---

### Running the Student App (`raksha_kawach_app`)

1. **Navigate to the Student App directory:**
   ```bash
   cd raksha_kawach_app
   ```

2. **Configure environment:**
   Copy the example configuration:
   ```bash
   cp config/dev.example.json config/dev.json
   ```
   Fill in your Supabase project URL and public Anon Key:
   ```json
   {
     "SUPABASE_URL": "https://your-project.supabase.co",
     "SUPABASE_ANON_KEY": "your-public-anon-key"
   }
   ```
   *(Note: `config/dev.json` is strictly ignored by Git to prevent credential exposure).*

3. **Install dependencies & verify code health:**
   ```bash
   flutter pub get
   flutter analyze
   flutter test
   ```

4. **Build Android Release APK:**
   ```bash
   flutter build apk --release --dart-define-from-file=config/dev.json
   ```
   Output binary: `build/app/outputs/flutter-apk/app-release.apk`.

5. **Deploy to connected Android phone:**
   ```bash
   flutter install
   ```

---

### Running the Admin Dashboard (`raksha_kwacch_admin`)

1. **Navigate to the Admin Dashboard directory:**
   ```bash
   cd raksha_kwacch_admin
   ```

2. **Configure environment:**
   ```bash
   cp config/dev.example.json config/dev.json
   ```

3. **Run tests & static analysis:**
   ```bash
   flutter pub get
   flutter analyze
   flutter test
   ```

4. **Build for Web:**
   ```bash
   flutter build web --dart-define-from-file=config/dev.json
   ```
   Output bundle: `build/web/`.

---

## 6. Security & Privacy Guarantees

- **Zero Hardcoded Secrets:** All Supabase URLs and public Anon keys are injected exclusively via `--dart-define-from-file` configurations.
- **Privacy Consent Lifecycle:** The Student App operates strictly under user consent; students can pause or start location sharing at any time.
- **Isolation by Policy:** PostgreSQL Row Level Security (RLS) guarantees that student devices cannot read or modify any other student's personal identifiable information or GPS logs.
- **No Private Keys Committed:** All keystores, local properties, and production credentials are excluded via repository `.gitignore` filters.

---

*Raksha Kawach Transit Safety Platform • SGT University Synergy 2026*
