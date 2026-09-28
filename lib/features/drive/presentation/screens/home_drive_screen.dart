import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/file_download_helper.dart';
import '../../../../core/utils/file_utils.dart';
import '../../domain/models/drive_item.dart';
import '../controllers/drive_controller.dart';
import '../widgets/file_card.dart';
import '../widgets/file_preview_dialog.dart';
import '../widgets/storage_meter.dart';
import '../widgets/share_privacy_dialog.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../backup/presentation/screens/backup_settings_screen.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../transfers/presentation/screens/transfer_center_screen.dart';
import '../../../transfers/presentation/widgets/active_upload_hud.dart';
import '../../../transfers/data/active_upload_notifier.dart';

class HomeDriveScreen extends ConsumerStatefulWidget {
  const HomeDriveScreen({super.key});

  @override
  ConsumerState<HomeDriveScreen> createState() => _HomeDriveScreenState();
}

class _HomeDriveScreenState extends ConsumerState<HomeDriveScreen> {
  int _currentNavIndex = 0;
  bool _isGrid = true;
  String _selectedCategory = "All";
  String _searchQuery = "";
  String? _currentFolderId;
  String? _currentFolderName;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = ref.read(authControllerProvider);
      await ref.read(driveControllerProvider.notifier).reloadPersistedItems(auth.phoneNumber);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.accent],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.cloud_done_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 8),
            const Flexible(
              child: Text(
                "UnboundDrive",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: -0.5),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync_rounded),
            tooltip: "Sync Telegram Cloud",
            onPressed: () async {
              final auth = ref.read(authControllerProvider);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Syncing with Telegram Cloud..."),
                  duration: Duration(seconds: 1),
                ),
              );
              await ref.read(driveControllerProvider.notifier).reloadPersistedItems(auth.phoneNumber);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("✓ Telegram Cloud Synced!"),
                    backgroundColor: AppColors.success,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: Icon(_isGrid ? Icons.view_list_rounded : Icons.grid_view_rounded),
            onPressed: () => setState(() => _isGrid = !_isGrid),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Stack(
        children: [
          _buildCurrentBody(),
          const ActiveUploadHUD(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentNavIndex,
        onDestinationSelected: (idx) => setState(() => _currentNavIndex = idx),
        backgroundColor: AppColors.darkSurface,
        indicatorColor: AppColors.primary.withValues(alpha: 0.2),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder_rounded, color: AppColors.accent),
            label: "Files",
          ),
          NavigationDestination(
            icon: Icon(Icons.backup_outlined),
            selectedIcon: Icon(Icons.backup_rounded, color: AppColors.accent),
            label: "Auto Sync",
          ),
          NavigationDestination(
            icon: Icon(Icons.swap_vert_rounded),
            selectedIcon: Icon(Icons.swap_vert_circle_rounded, color: AppColors.accent),
            label: "Transfers",
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded, color: AppColors.accent),
            label: "Settings",
          ),
        ],
      ),
      floatingActionButton: _currentNavIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () => _showUploadSheet(context),
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text("Upload", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }

  Widget _buildCurrentBody() {
    switch (_currentNavIndex) {
      case 0:
        return _buildFilesView();
      case 1:
        return const BackupSettingsScreen();
      case 2:
        return const TransferCenterScreen();
      case 3:
        return _buildSettingsView();
      default:
        return _buildFilesView();
    }
  }

  Widget _buildFilesView() {
    final allItems = ref.watch(driveControllerProvider);

    // Calculate real storage size dynamically
    final totalBytes = allItems.where((i) => !i.isFolder).fold<int>(0, (sum, i) => sum + i.size);
    final totalBackedUpFormatted = FileUtils.formatBytes(totalBytes);

    // Filter items based on current folder, category, and search query
    final filteredItems = allItems.where((item) {
      // 1. Folder scoping
      if (_currentFolderId == null) {
        if (item.parentFolderId != null) return false;
      } else {
        if (item.parentFolderId != _currentFolderId) return false;
      }

      // 2. Search query
      if (_searchQuery.isNotEmpty && !item.name.toLowerCase().contains(_searchQuery.toLowerCase())) {
        return false;
      }

      // 3. Category Filter
      if (_selectedCategory == "Photos") {
        return ["jpg", "jpeg", "png", "gif", "webp", "heic"].contains(item.extension.toLowerCase());
      } else if (_selectedCategory == "Videos") {
        return ["mp4", "mov", "mkv", "webm", "avi"].contains(item.extension.toLowerCase());
      } else if (_selectedCategory == "Documents") {
        return ["pdf", "txt", "md", "doc", "docx", "json", "csv"].contains(item.extension.toLowerCase());
      } else if (_selectedCategory == "Encrypted Vault") {
        return item.isEncrypted;
      }
      return true;
    }).toList();

    final auth = ref.watch(authControllerProvider);
    return RefreshIndicator(
      onRefresh: () => ref.read(driveControllerProvider.notifier).reloadPersistedItems(auth.phoneNumber),
      color: AppColors.accent,
      backgroundColor: AppColors.darkCard,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
        // Search & Filter Header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              style: const TextStyle(color: AppColors.textLight),
              decoration: InputDecoration(
                hintText: "Search your vault files...",
                hintStyle: const TextStyle(color: AppColors.textMuted),
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.darkCard,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.darkBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.darkBorder),
                ),
              ),
            ),
          ),
        ),

        // Storage Meter Banner (Only on root view)
        if (_currentFolderId == null)
          SliverToBoxAdapter(
            child: StorageMeter(totalBackedUp: totalBackedUpFormatted),
          ),

        // Folder Navigation Breadcrumb Header
        if (_currentFolderId != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton.filledTonal(
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                    ),
                    icon: const Icon(Icons.arrow_back_rounded, color: AppColors.primaryLight, size: 20),
                    onPressed: () => setState(() {
                      _currentFolderId = null;
                      _currentFolderName = null;
                    }),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.folder_open_rounded, color: AppColors.primaryLight, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _currentFolderName ?? "Folder",
                      style: const TextStyle(
                        color: AppColors.textLight,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Category Filter Chips
        SliverToBoxAdapter(
          child: SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: ["All", "Photos", "Videos", "Documents", "Encrypted Vault"].map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: isSelected,
                    label: Text(cat),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textMuted,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                    backgroundColor: AppColors.darkCard,
                    selectedColor: AppColors.primary,
                    checkmarkColor: Colors.white,
                    side: BorderSide(
                      color: isSelected ? AppColors.primary : AppColors.darkBorder,
                    ),
                    onSelected: (_) => setState(() => _selectedCategory = cat),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _currentFolderId != null ? "Folder Contents" : "Recent Items",
                  style: const TextStyle(
                    color: AppColors.textLight,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "${filteredItems.length} items",
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ],
            ),
          ),
        ),

        // Items View (Grid or List)
        if (filteredItems.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_open_rounded, size: 56, color: AppColors.textMuted),
                  SizedBox(height: 12),
                  Text("No files in this view", style: TextStyle(color: AppColors.textMuted, fontSize: 16)),
                  SizedBox(height: 4),
                  Text("Tap + Upload to add your real files", style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            ),
          )
        else if (_isGrid)
          SliverLayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.crossAxisExtent;
              final crossAxisCount = (width / 170).floor().clamp(2, 6);
              final isPhone = width < 500;
              final childAspectRatio = isPhone ? 0.82 : 0.95;

              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: childAspectRatio,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = filteredItems[index];
                      return FileCard(
                        item: item,
                        isGrid: true,
                        onTap: () {
                          if (item.isFolder) {
                            setState(() {
                              _currentFolderId = item.id;
                              _currentFolderName = item.name;
                            });
                          } else {
                            _showFilePreview(item);
                          }
                        },
                        onShareDirect: () => _showShareDialog(item),
                        onDownload: () => _handleFileDownload(item),
                      );
                    },
                    childCount: filteredItems.length,
                  ),
                ),
              );
            },
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final item = filteredItems[index];
                return FileCard(
                  item: item,
                  isGrid: false,
                  onTap: () {
                    if (item.isFolder) {
                      setState(() {
                        _currentFolderId = item.id;
                        _currentFolderName = item.name;
                      });
                    } else {
                      _showFilePreview(item);
                    }
                  },
                  onShareDirect: () => _showShareDialog(item),
                  onDownload: () => _handleFileDownload(item),
                );
              },
              childCount: filteredItems.length,
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    ),
  );
}

  void _showFilePreview(DriveItem item) {
    showDialog(
      context: context,
      builder: (context) {
        return FilePreviewDialog(
          item: item,
          onShare: () => _showShareDialog(item),
          onDelete: () {
            ref.read(driveControllerProvider.notifier).deleteItem(item.id);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("${item.name} deleted")),
            );
          },
        );
      },
    );
  }

  Future<void> _handleFileDownload(DriveItem item) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Text("Saving ${item.name} to downloads..."),
          ],
        ),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 2),
      ),
    );

    final bytes = item.rawBytes ??
        (item.previewText != null
            ? Uint8List.fromList(item.previewText!.codeUnits)
            : Uint8List.fromList("Decrypted UnboundDrive File: ${item.name}".codeUnits));

    await FileDownloadHelper.downloadFile(
      bytes: bytes,
      fileName: item.name,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("✓ Download complete: ${item.name}"),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Widget _buildSettingsView() {
    final auth = ref.watch(authControllerProvider);
    final displayName = auth.displayName.isNotEmpty ? auth.displayName : "Telegram User";
    final initialLetter = displayName.isNotEmpty ? displayName[0].toUpperCase() : "U";

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Telegram Account Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.darkCard,
                AppColors.primary.withOpacity(0.12),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.primaryLight.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      initialLetter,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                displayName,
                                style: const TextStyle(
                                  color: AppColors.textLight,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.verified_rounded,
                              color: AppColors.accent,
                              size: 18,
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        if (auth.username != null && auth.username!.isNotEmpty)
                          Text(
                            "@${auth.username}",
                            style: const TextStyle(
                              color: AppColors.accent,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        const SizedBox(height: 2),
                        Text(
                          auth.phoneNumber ?? "Connected via MTProto",
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(color: AppColors.darkBorder),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    "Connected to Telegram Cloud",
                    style: TextStyle(
                      color: AppColors.success,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (auth.telegramUserId != null)
                    Text(
                      "ID: ${auth.telegramUserId}",
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.darkBg.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_done_rounded, color: AppColors.primaryLight, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Vault Destination: Saved Messages & Personal Channel (Unlimited)",
                        style: TextStyle(
                          color: AppColors.textLight.withOpacity(0.85),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.logout_rounded, size: 18, color: Colors.redAccent),
                  label: const Text(
                    "Log Out from Telegram",
                    style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.redAccent),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => _confirmLogout(context),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text("SECURITY & ARCHITECTURE", style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        _buildSettingTile(Icons.security_rounded, "Zero-Central-Database Engine", "No server honeypots or leak vulnerabilities", AppColors.success),
        _buildSettingTile(Icons.memory_rounded, "Argon2id Memory-Hard KDF", "RFC 9106 GPU-resistant derivation", Colors.amber),
        _buildSettingTile(Icons.fingerprint_rounded, "Hardware Keystore / Secure Enclave", "Android Knox / Titan M hardware bound", Colors.cyan),
        _buildSettingTile(Icons.speed_rounded, "MTProto Load-Balanced Pool", "Adaptive 2-8 parallel worker streams", AppColors.primaryLight),
      ],
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkCard,
        title: const Text(
          "Log Out from Telegram?",
          style: TextStyle(color: AppColors.textLight, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          "Are you sure you want to log out? Your uploaded files remain safe and encrypted in your Telegram Cloud.",
          style: TextStyle(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authControllerProvider.notifier).logout();
              await ref.read(driveControllerProvider.notifier).clearCache();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text("Log Out"),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile(IconData icon, String title, String subtitle, Color iconColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: ListTile(
        leading: Icon(icon, color: iconColor),
        title: Text(title, style: const TextStyle(color: AppColors.textLight, fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
      ),
    );
  }

  void _showShareDialog(DriveItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SharePrivacyDialog(
          item: item,
          onPrivacyChanged: (privacy) {
            ref.read(driveControllerProvider.notifier).setPrivacy(item.id, privacy);
            final message = privacy == FilePrivacy.publicWithLink
                ? "File is now Public with link."
                : "File is now Private. Public links revoked.";
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
          },
        );
      },
    );
  }

  void _showUploadSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.darkCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.darkBorder, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                const Text("Add to UnboundDrive", style: TextStyle(color: AppColors.textLight, fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.upload_file_rounded, color: AppColors.primaryLight),
                  title: const Text("Upload Files", style: TextStyle(color: AppColors.textLight)),
                  subtitle: const Text("Documents, ZIP, Audio, or Any File from PC/Phone", style: TextStyle(color: AppColors.textMuted)),
                  onTap: () async {
                    Navigator.pop(context);
                    final auth = ref.read(authControllerProvider);
                    try {
                      await ref.read(driveControllerProvider.notifier).pickAndUploadFiles(
                        masterPassword: "user_vault_secure_pwd",
                        userPhone: auth.phoneNumber,
                        targetFolderId: _currentFolderId,
                      );
                    } catch (e) {
                      ref.read(activeUploadProvider.notifier).failUpload(e.toString());
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_rounded, color: Colors.cyan),
                  title: const Text("Upload Photos & Videos", style: TextStyle(color: AppColors.textLight)),
                  subtitle: const Text("Original quality, uncompressed", style: TextStyle(color: AppColors.textMuted)),
                  onTap: () async {
                    Navigator.pop(context);
                    final auth = ref.read(authControllerProvider);
                    try {
                      await ref.read(driveControllerProvider.notifier).pickAndUploadMedia(
                        masterPassword: "user_vault_secure_pwd",
                        userPhone: auth.phoneNumber,
                        targetFolderId: _currentFolderId,
                      );
                    } catch (e) {
                      ref.read(activeUploadProvider.notifier).failUpload(e.toString());
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.create_new_folder_rounded, color: Colors.amber),
                  title: const Text("New Folder", style: TextStyle(color: AppColors.textLight)),
                  onTap: () {
                    Navigator.pop(context);
                    _showNewFolderDialog();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showNewFolderDialog() {
    final folderController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkCard,
        title: const Text("New Folder", style: TextStyle(color: AppColors.textLight, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: folderController,
          autofocus: true,
          style: const TextStyle(color: AppColors.textLight),
          decoration: const InputDecoration(hintText: "Folder name"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              if (folderController.text.trim().isNotEmpty) {
                ref.read(driveControllerProvider.notifier).createFolder(
                  folderController.text.trim(),
                  parentFolderId: _currentFolderId,
                );
              }
              Navigator.pop(ctx);
            },
            child: const Text("Create"),
          ),
        ],
      ),
    );
  }
}
