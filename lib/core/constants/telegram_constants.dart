class TelegramConstants {
  // Vault Settings
  static const String defaultVaultChannelTitle = "UnboundDrive Vault (DO NOT DELETE)";
  static const String defaultVaultChannelAbout = 
      "Official infinite storage vault created by UnboundDrive. Stores encrypted binary envelopes.";
  
  // Secure Storage Keys
  static const String keySessionToken = "ubd_session_token";
  static const String keyApiId = "ubd_api_id";
  static const String keyApiHash = "ubd_api_hash";
  static const String keyVaultChannelId = "ubd_vault_channel_id";
  static const String keyMasterPasswordHash = "ubd_master_pwd_hash";
  static const String keyUserSalt = "ubd_user_salt";
  
  // Telegram API Endpoints
  static const String testServerHost = "149.154.167.40";
  static const String productionServerHost = "149.154.167.50";
  static const int defaultPort = 443;
}
