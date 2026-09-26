import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';

class BackupSettingsScreen extends StatefulWidget {
  const BackupSettingsScreen({super.key});

  @override
  State<BackupSettingsScreen> createState() => _BackupSettingsScreenState();
}

class _BackupSettingsScreenState extends State<BackupSettingsScreen> {
  bool _autoBackupEnabled = true;
  bool _backupPhotos = true;
  bool _backupVideos = true;
  bool _wifiOnly = true;
  bool _whileCharging = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Smart Auto-Backup", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.darkCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.darkBorder),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.cloud_done_rounded, color: AppColors.success, size: 28),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Backup Status: Up to date", style: TextStyle(color: AppColors.textLight, fontWeight: FontWeight.bold, fontSize: 16)),
                      SizedBox(height: 4),
                      Text("All recent camera photos & videos are safe in Telegram cloud.", style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          const Text("BACKUP PREFERENCES", style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          const SizedBox(height: 8),

          Card(
            child: Column(
              children: [
                SwitchListTile(
                  value: _autoBackupEnabled,
                  activeThumbColor: AppColors.accent,
                  title: const Text("Automatic Background Backup", style: TextStyle(color: AppColors.textLight, fontWeight: FontWeight.w600)),
                  subtitle: const Text("Upload new photos & videos automatically", style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  onChanged: (val) => setState(() => _autoBackupEnabled = val),
                ),
                const Divider(color: AppColors.darkBorder, height: 1),
                SwitchListTile(
                  value: _backupPhotos,
                  activeThumbColor: AppColors.accent,
                  title: const Text("Photos (DCIM & Camera)", style: TextStyle(color: AppColors.textLight)),
                  onChanged: _autoBackupEnabled ? (val) => setState(() => _backupPhotos = val) : null,
                ),
                const Divider(color: AppColors.darkBorder, height: 1),
                SwitchListTile(
                  value: _backupVideos,
                  activeThumbColor: AppColors.accent,
                  title: const Text("Videos", style: TextStyle(color: AppColors.textLight)),
                  onChanged: _autoBackupEnabled ? (val) => setState(() => _backupVideos = val) : null,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          const Text("NETWORK & BATTERY", style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          const SizedBox(height: 8),

          Card(
            child: Column(
              children: [
                SwitchListTile(
                  value: _wifiOnly,
                  activeThumbColor: AppColors.accent,
                  title: const Text("Back up over Wi-Fi only", style: TextStyle(color: AppColors.textLight, fontWeight: FontWeight.w600)),
                  subtitle: const Text("Avoid using mobile data allowance", style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  onChanged: (val) => setState(() => _wifiOnly = val),
                ),
                const Divider(color: AppColors.darkBorder, height: 1),
                SwitchListTile(
                  value: _whileCharging,
                  activeThumbColor: AppColors.accent,
                  title: const Text("Only while charging", style: TextStyle(color: AppColors.textLight)),
                  subtitle: const Text("Conserve battery power during heavy uploads", style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  onChanged: (val) => setState(() => _whileCharging = val),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Checking for new photos to sync...")),
              );
            },
            icon: const Icon(Icons.sync_rounded),
            label: const Text("Sync Now"),
          ),
        ],
      ),
    );
  }
}
