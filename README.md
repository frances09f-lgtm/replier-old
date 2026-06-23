# Auto Reply Assistant

A Flutter Android application that automatically replies to notifications from supported apps like WhatsApp and Instagram.

## ⚠️ Important Notice

**Automated replying to WhatsApp or Instagram may violate their Terms of Service.** This application uses official Android notification APIs where possible, but automated interaction with messaging apps should be used with caution and at your own risk. This app is intended for educational purposes and personal use only.

## Features

### Notification Access
- Request Notification Access permission
- Listen to notifications from WhatsApp and Instagram
- Extract app name, sender name, message content, and timestamp

### Auto Reply Rules
- Create custom auto-reply rules
- Configure trigger text and reply text
- Match options: exact match, contains match, case sensitive
- Enable/disable individual rules
- Search and filter rules

### Supported Apps
- WhatsApp
- Instagram
- Extensible architecture for Telegram, Messenger, and Signal

### Automatic Reply
- Detect incoming messages
- Find matching rules
- Send replies using official notification direct reply APIs
- Fallback to Accessibility Service when direct reply is unavailable

### Rule Management
- Add, edit, and delete rules
- Enable/disable rules
- Search rules by trigger or reply text

### Dashboard
- Total notifications received
- Total replies sent
- Last reply sent
- Active rules count

### Reply Logs
- Store complete reply history
- Filter by app
- Clear logs

### Settings
- Master enable/disable switch
- App selection (WhatsApp, Instagram)
- Configurable reply delay (0-60 seconds)
- Prevent duplicate replies
- Ignore group chats option
- Dark mode support

## Architecture

- **MVVM Architecture**: Clean separation of concerns
- **Repository Pattern**: Data access abstraction
- **Dependency Injection**: Using GetIt
- **State Management**: Using Riverpod
- **Local Storage**: Hive database
- **Native Integration**: Kotlin for Android services

## Requirements

- Flutter SDK (>=3.0.0)
- Android SDK (API 26+)
- Kotlin 1.9.0
- Android Studio or VS Code

## Installation

### 1. Clone the Repository

```bash
git clone <repository-url>
cd auto_reply_assistant
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Generate Hive Adapters

```bash
flutter pub run build_runner build
```

### 4. Configure Android

The Android configuration is already set up, but you may need to:

- Update the `applicationId` in `android/app/build.gradle` to match your package name
- Update the package name in `android/app/src/main/AndroidManifest.xml`
- Update the package name in all Kotlin files under `android/app/src/main/kotlin/`

### 5. Run the App

```bash
flutter run
```

## Setup Instructions

### 1. Grant Notification Access

1. Open the app
2. Go to **Settings**
3. Tap **Grant** next to **Notification Access**
4. Enable "Auto Reply Notification Listener" in system settings

### 2. Grant Accessibility Service (Optional)

This is only needed as a fallback when direct reply is unavailable:

1. Go to **Settings**
2. Tap **Grant** next to **Accessibility Service**
3. Enable "Auto Reply Accessibility Service" in system settings

### 3. Disable Battery Optimization

For reliable background operation:

1. Go to **Settings**
2. Tap **Grant** next to **Battery Optimization**
3. Select "Don't optimize" for this app

### 4. Create Rules

1. Go to **Rules** screen
2. Tap the **+** button
3. Enter trigger text (e.g., "hi")
4. Enter reply text (e.g., "hello")
5. Configure match options
6. Save the rule

### 5. Enable Auto Reply

1. On the **Dashboard**, enable the **Master Enable** switch
2. Ensure the desired apps (WhatsApp, Instagram) are enabled in **Settings**

## Project Structure

```
lib/
├── core/
│   ├── constants.dart           # App constants
│   ├── hive_config.dart         # Hive database configuration
│   └── injection_container.dart # Dependency injection setup
├── models/
│   ├── rule.dart                # Rule model
│   ├── app_settings.dart        # Settings model
│   ├── reply_log.dart           # Reply log model
│   └── notification_data.dart    # Notification data model
├── repositories/
│   ├── rule_repository.dart     # Rule data access
│   ├── settings_repository.dart # Settings data access
│   ├── log_repository.dart      # Log data access
│   └── statistics_repository.dart # Statistics data access
├── providers/
│   ├── settings_provider.dart   # Settings state management
│   ├── rule_provider.dart       # Rules state management
│   ├── log_provider.dart        # Logs state management
│   └── statistics_provider.dart # Statistics state management
├── services/
│   ├── notification_service.dart # Native communication
│   └── auto_reply_service.dart  # Auto-reply logic
├── screens/
│   ├── splash_screen.dart       # Splash screen
│   ├── dashboard_screen.dart    # Dashboard
│   ├── rules_screen.dart        # Rules management
│   ├── add_edit_rule_screen.dart # Add/edit rule
│   ├── logs_screen.dart         # Reply logs
│   └── settings_screen.dart    # Settings
├── utils/
│   ├── error_handler.dart       # Error handling utilities
│   └── permission_handler.dart # Permission handling utilities
└── main.dart                    # App entry point

android/
├── app/
│   ├── src/main/
│   │   ├── AndroidManifest.xml  # App manifest with permissions
│   │   ├── kotlin/
│   │   │   └── com/example/auto_reply_assistant/
│   │   │       ├── MainActivity.kt
│   │   │       └── service/
│   │   │           ├── NotificationListenerService.kt
│   │   │           └── AutoReplyAccessibilityService.kt
│   │   └── res/
│   │       ├── xml/
│   │       │   └── accessibility_service_config.xml
│   │       └── values/
│   │           ├── strings.xml
│   │           └── styles.xml
│   └── build.gradle
├── build.gradle
├── settings.gradle
└── gradle.properties
```

## Dependencies

### Flutter
- `flutter_riverpod`: State management
- `get_it`: Dependency injection
- `injectable`: Code generation for DI
- `hive`: Local database
- `hive_flutter`: Hive Flutter integration
- `path_provider`: File system access
- `permission_handler`: Permission handling
- `intl`: Date formatting
- `uuid`: Unique ID generation

### Android
- Kotlin 1.9.0
- Android Gradle Plugin 8.1.0
- Min SDK: 26 (Android 8.0)
- Target SDK: 34 (Android 14)

## Permissions

The app requires the following permissions:

- `POST_NOTIFICATIONS`: Post notifications
- `BIND_NOTIFICATION_LISTENER_SERVICE`: Read notifications
- `BIND_ACCESSIBILITY_SERVICE`: Accessibility service for fallback
- `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`: Battery optimization exemption
- `SYSTEM_ALERT_WINDOW`: System alert window
- `FOREGROUND_SERVICE`: Foreground service
- `FOREGROUND_SERVICE_SPECIAL_USE`: Special use foreground service

## Usage Example

### Creating a Rule

1. Navigate to **Rules** screen
2. Tap **+** button
3. Enter:
   - Trigger text: "hi"
   - Reply text: "hello"
4. Set match options:
   - Contains match: true
   - Case sensitive: false
5. Enable the rule
6. Save

### How It Works

1. When a notification arrives from WhatsApp or Instagram
2. The app extracts the message content
3. It searches for a matching rule
4. If a match is found and the app is enabled:
   - It waits for the configured delay (if any)
   - It sends the reply using the notification's direct reply action
   - If direct reply is unavailable, it uses the Accessibility Service
5. The reply is logged for future reference

## Troubleshooting

### Notifications not being received
- Ensure Notification Access is granted in system settings
- Check that the app is enabled in Notification Access settings
- Restart the app after granting permissions

### Replies not being sent
- Ensure the app is enabled in Settings
- Check that rules are enabled
- Verify that the master switch is enabled
- Check if the app is battery optimized (disable it)
- Ensure the notification has a direct reply action

### Accessibility Service not working
- Ensure Accessibility Service is enabled in system settings
- Check that the service is not disabled by the system
- Restart the app after enabling the service

### Build errors
- Run `flutter clean`
- Run `flutter pub get`
- Run `flutter pub run build_runner build --delete-conflicting-outputs`
- Try running `flutter run` again

## Limitations

- Only works on Android (iOS does not support NotificationListenerService)
- Requires Android 8.0 (API 26) or higher
- Some apps may not support direct reply
- Automated interaction may violate app Terms of Service
- Group chat detection may not be 100% accurate

## Security and Privacy

- All data is stored locally on the device
- No data is sent to external servers
- The app only reads notifications from apps you explicitly enable
- The app does not access message history or personal data beyond notifications

## Contributing

Contributions are welcome! Please follow these guidelines:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is provided as-is for educational purposes. Use at your own risk.

## Disclaimer

This application is for educational purposes only. Automated interaction with messaging apps may violate their Terms of Service. The authors are not responsible for any consequences of using this application. Always respect the Terms of Service of the apps you interact with.

## Support

For issues, questions, or contributions, please open an issue on the repository.

---

**Note**: This app uses official Android APIs where possible. The Accessibility Service is only used as a fallback when the notification direct reply API is unavailable. Always use automation tools responsibly and ethically.
