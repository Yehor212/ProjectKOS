# Data Protection Program — Tofie Play & Learn Adventures

## COPPA 2026 Compliance (16 CFR §312.10)

This Written Comprehensive Data Protection Program is maintained pursuant to the FTC COPPA Rule amendments effective April 22, 2026.

---

## 1. Designated Coordinator (§312.10(b)(1))

**Data Protection Coordinator:** Yehor Shamraiev, Lead Developer
**Email:** projectkos.game@gmail.com
**Responsibilities:**
- Oversee all data protection practices
- Review this document annually
- Respond to parent/guardian inquiries within 72 hours
- Maintain compliance with COPPA, state laws, and platform policies

## 2. Data Collection Practices

This application collects **ZERO personal data** from children or parents.

### 2.1 Data NOT Collected
- No names, emails, phone numbers, or addresses
- No photos, videos, or audio recordings
- No biometric data or voiceprints (§312.2 expanded definition)
- No device identifiers (OS.get_unique_id() explicitly prohibited in codebase)
- No advertising identifiers (IDFA/GAID)
- No location data (GPS, IP-based, or cell tower)
- No browsing history or usage analytics sent externally
- No cookies or persistent tracking technologies
- No push notification tokens

### 2.2 Device-Local Data (NOT transmitted)
- **Save file:** `user://save.save` — encrypted game progress (stars, unlocked items)
- **Settings:** `user://settings.save` — encrypted preferences (volume, language)
- **Encryption key:** `user://enc.key` — randomly generated, never transmitted
- **Device locale:** `OS.get_locale()` read once at first launch for default language (not stored externally)

### 2.3 Clipboard Access
- Save export/import uses `DisplayServer.clipboard_set/get()` for Base64-encoded game progress
- **Only accessible behind parental gate** (cognitive challenge + 3-finger hold)
- No PII is placed on or read from the clipboard — only game progress data

## 3. Risk Assessment (§312.10(b)(2))

| Risk Vector | Likelihood | Impact | Mitigation |
|-------------|-----------|--------|------------|
| Save file read by other app | Low | Low (no PII) | AES encryption with random key |
| Clipboard contains PII from other apps | Low | Low | Clipboard read only behind parental gate; data parsed as Base64 game save, PII ignored |
| Network exfiltration | None | N/A | Zero network permissions; no HTTPRequest nodes in codebase |
| Device ID leakage | None | N/A | OS.get_unique_id() removed from codebase; comment warning preserved |
| Biometric capture | None | N/A | No camera/microphone permissions requested |
| Third-party SDK data collection | None | N/A | Zero third-party SDKs integrated |

## 4. Safeguards (§312.10(b)(3))

### 4.1 Technical Safeguards
- **Encryption:** All save files use `FileAccess.open_encrypted_with_pass()` with randomly generated key
- **Atomic writes:** Save uses tmp+rename pattern to prevent corruption
- **No network access:** Application requests zero network permissions on Android
- **Input validation:** LAW 22 — all loaded save values are validated/clamped to safe ranges
- **Debug guards:** All analytics/debug output gated by `OS.is_debug_build()`

### 4.2 Administrative Safeguards
- Code review required for any change touching save/load, encryption, or external access
- `export_presets.cfg` in `.gitignore` to prevent credential leakage
- Parental gate (cognitive + motor challenge) protects all adult-facing features

### 4.3 Codebase Enforcement
- Automated test suite (48+ tests) verifies compliance at build time
- Hook system blocks commits without compliance checks
- grep scan for `OS.get_unique_id`, `HTTPRequest`, `get_unique_id` in CI

## 5. Third-Party Services (§312.10(b)(4))

**NONE.** This application integrates zero third-party services:
- No ad networks (no ads whatsoever)
- No analytics platforms (AnalyticsManager = debug console stub only)
- No social media SDKs
- No crash reporting services
- No cloud storage or sync services
- No payment processors in child-accessible areas
- No authentication providers

If third-party services are ever added, this section must be updated with:
- Service name and purpose
- Data shared with service
- Contractual COPPA compliance obligations
- Annual compliance verification procedure

## 6. Training (§312.10(b)(5))

All team members with code access must:
1. Read this Data Protection Program document before contributing
2. Understand COPPA definitions of "personal information" (§312.2), including the 2026 biometric expansion
3. Never introduce: network requests, device ID reads, third-party SDKs, or external analytics without coordinator approval
4. Run compliance test suite before submitting code changes

**Training log:** Maintained in project wiki. Updated when team changes.

## 7. Incident Response Plan (§312.10(b)(6))

### 7.1 Definition
A "data incident" is any event where:
- Personal information of a child user is accessed, disclosed, or lost
- A code change introduces data collection without parental consent
- A third-party dependency is found to collect data

### 7.2 Response Procedure
1. **Detection** (0-1 hour): Identify scope of incident
2. **Containment** (1-4 hours): Remove/disable affected code; issue hotfix build
3. **Assessment** (4-24 hours): Determine if children's data was affected
4. **Notification** (24-72 hours):
   - FTC notification if children's PI was compromised
   - Apple/Google platform notification
   - User notification via app store listing update
   - State AG notification per applicable state breach laws
5. **Remediation** (1-7 days): Root cause analysis; preventive measures
6. **Documentation**: Full incident report preserved for 5 years

### 7.3 Current Risk Level
**MINIMAL** — Application collects zero data and has zero network access. The incident response plan exists for contingency compliance.

## 8. Data Retention & Deletion (§312.10(b)(7))

- **Server-side data:** NONE — no servers used
- **Device-local data:** Exists only on user's device
- **Deletion method:** Uninstalling the application removes all `user://` data
- **Retention period:** Data persists only as long as the app is installed
- **No archival:** No data is archived, backed up, or transmitted off-device

## 9. Annual Review (§312.10(b)(8))

This Data Protection Program must be reviewed and updated:
- **Annually:** On or before April 22 of each year (COPPA amendment anniversary)
- **After any code change** that touches: save/load, encryption, permissions, or external access
- **After any regulatory change** to COPPA, state privacy laws, or platform policies

### Review History
| Date | Reviewer | Changes |
|------|----------|---------|
| 2026-03-26 | Yehor Shamraiev | Initial DPP created |
| 2026-04-04 | Yehor Shamraiev | COPPA 2026 audit: added §312.10 required sections (coordinator, risk assessment, training, incident response, annual review). Removed OS.get_unique_id() from codebase. |

## 10. Regulatory Compliance Matrix

| Regulation | Status | Notes |
|------------|--------|-------|
| **COPPA** (16 CFR §312) | COMPLIANT | Zero data collection; written DPP maintained |
| **COPPA 2026 Amendments** (eff. Apr 22, 2026) | COMPLIANT | Biometric = PI acknowledged; DPP complete per §312.10 |
| **FTC §5** (unfair/deceptive) | COMPLIANT | Privacy representations match technical reality |
| **California CCPA/CPRA** | NOT APPLICABLE | No personal data processed |
| **California AADC** (AB 2273) | NOT APPLICABLE | Offline app; no "online service" |
| **Texas TDPSA** | NOT APPLICABLE | No personal data processed |
| **Texas SCOPE Act** | NOT APPLICABLE | No algorithms, social features, or harmful content |
| **Utah UCPA** | NOT APPLICABLE | No personal data processed |
| **Louisiana Act 440** | NOT APPLICABLE | Educational content; not "harmful to minors" |
| **Illinois BIPA** | NOT APPLICABLE | No biometric data collected |
| **GDPR Article 8** (EU) | COMPLIANT | Zero data collection exceeds requirements |
| **Apple Kids Category** | COMPLIANT | No tracking, no ads, no third-party SDKs |
| **Google Play Families** | COMPLIANT | No ads, no data collection, parental gate present |

## 11. Contact

**Developer:** KOS Games
**Data Protection Coordinator:** Yehor Shamraiev
**Email:** projectkos.game@gmail.com
**Response time:** Within 72 hours for privacy-related inquiries

---

Last updated: 2026-04-04
Next scheduled review: 2027-04-22
