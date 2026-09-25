# Privacy

Fleeting has no account, no server, and no analytics. There is no code in it that talks to a
network Anthropic, I, or anyone else controls — the only remote destination it can reach is the
user's own iCloud.

## What is stored

| Data | Where | Why |
|---|---|---|
| The text you capture, and anything generated from it | On device, in the app's SwiftData store | It is the app |
| Daily checklist text, scheduled day and completion time | The same SwiftData store and private iCloud database when enabled | Planning and completion history; shared with widgets through the App Group |
| The same, mirrored to your private CloudKit database | Your iCloud account | So a thought captured on one device is on the others (ADR-0003) |
| Notification preferences and whether the first-run hint was dismissed | `UserDefaults`, in the app's App Group | So the app behaves the way you left it |

## What is not

- **Nothing is collected.** No identifiers, no usage events, no crash reporting, no telemetry.
- **Nothing is tracked**, in the App Store's sense or any other. There are no third-party SDKs in
  the project — the dependency list is six local packages and nothing else.
- **Nothing you write is sent to a model provider.** Classification, the Sharpen interview, and
  the write-up all run on-device through Apple's Foundation Models. A device without them falls
  back to rules that also run on-device (ADR-0004). The one exception is deliberate and manual:
  *Take this further elsewhere* opens the system share sheet with a prompt you can read first, and
  it only goes wherever you choose to send it.

The iOS 27 integration continues to use only `SystemLanguageModel`. It does not use Private Cloud
Compute, third-party model providers, or model tools with access to other notes. If a request is
too large for the on-device context window, local rules handle it instead.

## Privacy manifest

[`App/Resources/PrivacyInfo.xcprivacy`](../App/Resources/PrivacyInfo.xcprivacy) declares
`NSPrivacyTracking` false, no tracking domains, and no collected data types. The one required
API-access reason is `CA92.1` for `UserDefaults`, read and written only by this app and its own
widgets.

## Nutrition label

The App Store answer is **Data Not Collected** in every category.
