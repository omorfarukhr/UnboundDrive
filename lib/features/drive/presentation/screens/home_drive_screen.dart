import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../domain/models/drive_item.dart';
import '../widgets/file_card.dart';
import '../widgets/storage_meter.dart';
import '../../../backup/presentation/screens/backup_settings_screen.dart';

class HomeDriveScreen extends StatefulWidget {
  const HomeDriveScreen({super.key});

  @override
  State<HomeDriveScreen> createState() => _HomeDriveScreenState();
}

class _HomeDriveScreenState extends State<HomeDriveScreen> {
  int _currentNavIndex = 0;
  bool _isGrid = true;
  String _selectedCategory = "All";

  final List<DriveItem> _demoItems = [
    DriveItem(
      id: "1",
      name: "Camera Auto-Backup",
      size: 0,
      extension: "",
      isFolder: true,
      uploadDate: DateTime.now(),
    ),
    DriveItem(
      id: "2",
      name: "Work Documents",
      size: 0,
      extension: "",
      isFolder: true,
      uploadDate: DateTime.now(),
    ),
    DriveItem(
      id: "3",
      name: "Trip_to_California_4K.mp4",
      size: 1420000000, // 1.42 GB
      extension: "mp4",
      isEncrypted: true,
      uploadDate: DateTime.now(),
    ),
    DriveItem(
      id: "4",
      name: "Financial_Report_2026.pdf",
      size: 4500000, // 4.5 MB
      extension: "pdf",
      uploadDate: DateTime.now(),
    ),
    DriveItem(
      id: "5",
      name: "Sunset_GrandCanyon.heic",
      size: 8900000, // 8.9 MB
      extension: "heic",
      uploadDate: DateTime.now(),
    ),
    DriveItem(
      id: "6",
      name: "Full_Project_Archive.zip",
      size: 850000000, // 850 MB
      extension: "zip",
      uploadDate: DateTime.now(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.accent],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.cloud_done_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              "UnboundDrive",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, letterSpacing: -0.5),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_isGrid ? Icons.view_list_rounded : Icons.grid_view_rounded),
            onPressed: () => setState(() => _isGrid = !_isGrid),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildCurrentBody(),
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
        return _buildDriveHome();
      case 1:
        return const BackupSettingsScreen();
      case 2:
        return _buildPlaceholderView("Active Transfers", "No active uploads or downloads right now.");
      case 3:
        return _buildPlaceholderView("Account & Security", "Telegram Session: Active\nZero-Knowledge Encryption: Enabled");
      default:
        return _buildDriveHome();
    }
  }

  Widget _buildDriveHome() {
    return CustomScrollView(
      slivers: [
        // Search Bar
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Search files, folders or tags...",
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.tune_rounded, color: AppColors.textMuted),
                  onPressed: () {},
                ),
              ),
            ),
          ),
        ),

        // Storage Meter Banner
        const SliverToBoxAdapter(
          child: StorageMeter(totalBackedUp: "28.4 GB"),
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

        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              "Recent Items",
              style: TextStyle(
                color: AppColors.textLight,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),

        // Items View (Grid or List)
        if (_isGrid)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.15,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = _demoItems[index];
                  return FileCard(
                    item: item,
                    isGrid: true,
                    onShareDirect: () => _showShareDialog(item),
                  );
                },
                childCount: _demoItems.length,
              ),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final item = _demoItems[index];
                return FileCard(
                  item: item,
                  isGrid: false,
                  onShareDirect: () => _showShareDialog(item),
                );
              },
              childCount: _demoItems.length,
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  Widget _buildPlaceholderView(String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_done_rounded, size: 64, color: AppColors.primaryLight),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textLight)),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }

  void _showShareDialog(DriveItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.darkCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.link_rounded, color: AppColors.accent),
                  SizedBox(width: 8),
                  Text("1-Click Direct Download Link", style: TextStyle(color: AppColors.textLight, fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              const SizedBox(height: 12),
              const Text("Anyone with this link can download this file via Chrome/Safari or IDM without a Telegram account.", style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: AppColors.darkSurface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.darkBorder)),
                child: Row(
                  children: [
                    Expanded(
                      child: Text("https://dl.unbounddrive.app/f/${item.id}", style: const TextStyle(color: AppColors.accent, fontSize: 13)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, color: AppColors.textLight, size: 18),
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Link copied to clipboard!")));
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
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
                  subtitle: const Text("Documents, ZIP, Audio, or Any File", style: TextStyle(color: AppColors.textMuted)),
                  onTap: () => Navigator.pop(context),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_rounded, color: Colors.cyan),
                  title: const Text("Upload Photos & Videos", style: TextStyle(color: AppColors.textLight)),
                  subtitle: const Text("Original quality, uncompressed", style: TextStyle(color: AppColors.textMuted)),
                  onTap: () => Navigator.pop(context),
                ),
                ListTile(
                  leading: const Icon(Icons.create_new_folder_rounded, color: Colors.amber),
                  title: const Text("New Folder", style: TextStyle(color: AppColors.textLight)),
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
