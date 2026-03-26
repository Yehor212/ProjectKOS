# Data Protection Program — Tofie Play & Learn Adventures

## 1. Data Collection
This application collects ZERO personal data from children or parents.
- No names, emails, phone numbers, or addresses
- No photos, videos, or audio recordings
- No biometric data or voiceprints
- No device identifiers (no OS.get_unique_id())
- No location data
- No browsing/usage analytics sent to any server

## 2. Data Storage
All game data stored LOCALLY on device only:
- Save file: `user://save.save` (encrypted with random key)
- Settings: `user://settings.save` (encrypted)
- No cloud sync, no server communication
- Data deleted when app is uninstalled

## 3. Third-Party Services
NONE. Zero third-party SDKs, analytics, ads, or tracking.
- AnalyticsManager: debug console prints only (OS.is_debug_build)
- No ad networks
- No social media integration
- No external links without parental gate

## 4. Parental Controls
- Parental gate: 3-finger 2-second hold (LAW 27)
- Session timer: configurable 15-60 minutes (default 20)
- Parent Zone: behind parental gate — stats, settings, data export/import
- No in-app purchases in child-accessible areas

## 5. Encryption
- Save files encrypted with FileAccess.open_encrypted_with_pass()
- Encryption key: randomly generated (COPPA-safe, no hardware IDs)
- Key stored locally, never transmitted

## 6. Data Retention
- Data exists only on user's device
- No server-side retention (no servers used)
- Uninstalling app removes all data

## 7. Contact
Developer: KOS Games
Email: [developer contact email]
Website: [developer website]

## 8. Compliance
- **COPPA** (Children's Online Privacy Protection Act) — USA
- **GDPR-K** (General Data Protection Regulation, children's provisions) — EU
- **Apple Kids Category** guidelines
- **Google Play Families Policy**
- **FTC COPPA Amendments** (June 23, 2025, effective April 22, 2026)
  - Biometric data classified as personal information
  - Written Data Protection Program required
  - Opt-in consent model
  - Penalties up to $53,088 per violation
- **European Accessibility Act** (June 2025)
- **State laws**: Texas, Utah, Louisiana age verification (Jan 2026)

Last updated: 2026-03-26
