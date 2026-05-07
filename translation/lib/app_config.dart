class AppConfig {
  /// FastAPI base URL (ngrok URL when running on Colab), e.g. https://xxxx.ngrok-free.app
  static const String aiServerBaseUrl = String.fromEnvironment(
    'AI_SERVER_BASE_URL',
    defaultValue: 'https://cisted-hospitably-sherell.ngrok-free.dev',
  );

  /// Agora App ID.
  ///
  /// You can still override this at runtime with:
  /// --dart-define=AGORA_APP_ID=your_other_id
  static const String agoraAppId = String.fromEnvironment(
    'AGORA_APP_ID',
    defaultValue: 'da5575f97c4a42d4950b20abafb8f439',
  );
}

