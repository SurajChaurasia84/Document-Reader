import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/storage_info.dart';
import '../models/storage_overview.dart';
import '../services/app_controller.dart';
import '../services/storage_info_service.dart';
import '../utils/formatters.dart';
import '../utils/theme_utils.dart';
import '../widgets/fixed_top_header.dart';
import '../widgets/glass_card.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const String _playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.example.pdf_studio';
  static const String _shareMessage =
      'Try PDF Studio for fast offline document reading and PDF tools.\n\n$_playStoreUrl';
  static const String _privacyUrl = 'https://www.example.com/privacy-policy';
  static const String _aboutAssetPath = 'assets/about_us.txt';

  late final StorageInfoService _storageInfoService = StorageInfoService();
  late Future<StorageOverview?> _storageOverviewFuture =
      _storageInfoService.getStorageOverview();
  final Future<PackageInfo> _packageInfoFuture = PackageInfo.fromPlatform();

  Future<void> _refreshStorageOverview() async {
    setState(() {
      _storageOverviewFuture = _storageInfoService.getStorageOverview();
    });
    await _storageOverviewFuture;
  }

  Future<String> _loadAssetText(String path, String fallbackText) async {
    try {
      return await rootBundle.loadString(path);
    } catch (_) {
      return fallbackText;
    }
  }

  Future<void> _openPrivacyPage(BuildContext context) async {
    final uri = Uri.parse(_privacyUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open privacy policy link.')),
        );
      }
    }
  }

  Future<void> _openAboutPage(BuildContext context) async {
    _openInfoPage(
      context,
      title: 'About us',
      content: _aboutText,
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    return Column(
      children: <Widget>[
        const FixedTopHeader(title: 'Settings'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 120),
            children: <Widget>[
              FutureBuilder<StorageOverview?>(
                future: _storageOverviewFuture,
                builder: (context, snapshot) {
                  final overview = snapshot.data;
                  final downloadsFolderBytes = controller.downloadFiles.fold<int>(
                    0,
                    (sum, file) => sum + file.size,
                  );
                  final downloadsFolderSize = formatFileSize(
                    downloadsFolderBytes,
                  );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'My Storage',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      if (snapshot.connectionState == ConnectionState.waiting)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else ...<Widget>[
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.02,
                          children: <Widget>[
                            _StorageCard(
                              info: overview?.filesStorage ??
                                  const StorageInfo(
                                    label: 'Internal Storage',
                                    path: '',
                                    totalBytes: 0,
                                    availableBytes: 0,
                                    isAvailable: false,
                                  ),
                              icon: Icons.phone_android_rounded,
                              accent: const Color(0xFF2D87F3),
                              title: 'Internal Storage',
                              showUsedValue: false,
                            ),
                            _StorageCard(
                              info: const StorageInfo(
                                label: 'Downloads',
                                path: '',
                                totalBytes: 0,
                                availableBytes: 0,
                                isAvailable: true,
                              ),
                              icon: Icons.download_rounded,
                              accent: const Color(0xFF00B7FF),
                              title: 'Downloads',
                              customSummary: downloadsFolderSize,
                              availableValue: '--',
                              showUsedValue: false,
                            ),
                            _StorageCard(
                              info: overview?.sdCardStorage ??
                                  const StorageInfo(
                                    label: 'SD Card',
                                    path: '',
                                    totalBytes: 0,
                                    availableBytes: 0,
                                    isAvailable: false,
                                  ),
                              icon: Icons.sd_card_rounded,
                              accent: const Color(0xFF7B86FF),
                              title: 'SD Card',
                              showUsedValue: false,
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _refreshStorageOverview,
                        icon: const Icon(Icons.storage_rounded),
                        label: const Text('Refresh storage'),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Preferences',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Icon(
                          Icons.dark_mode_rounded,
                          color: context.iconMuted,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Dark Mode',
                                style: TextStyle(
                                  color: context.primaryText,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Turn on for a better experience',
                                style: TextStyle(
                                  color: context.secondaryText,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: controller.isDarkMode,
                          onChanged: (value) => controller.setDarkMode(value),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'More',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    _MoreMenuTile(
                      icon: Icons.privacy_tip_outlined,
                      title: 'Privacy Policy',
                      onTap: () => _openPrivacyPage(context),
                    ),
                    _MoreMenuTile(
                      icon: Icons.info_outline_rounded,
                      title: 'About us',
                      onTap: () => _openAboutPage(context),
                    ),
                    _MoreMenuTile(
                      icon: Icons.help_outline_rounded,
                      title: 'Help / Contact',
                      onTap: () => _contactSupport(context),
                    ),
                    _MoreMenuTile(
                      icon: Icons.share_outlined,
                      title: 'Share App',
                      showDivider: false,
                      onTap: () => _showShareOptions(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const SizedBox(height: 20),
              GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'App Info',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    FutureBuilder<PackageInfo>(
                      future: _packageInfoFuture,
                      builder: (context, snapshot) {
                        final version = snapshot.data?.version ?? '--';
                        final buildNumber = snapshot.data?.buildNumber ?? '';
                        final fullVersion = buildNumber.isNotEmpty 
                            ? '$version ($buildNumber)' 
                            : version;
                        
                        return Column(
                          children: [
                            _AppInfoTile(
                              icon: Icons.info_outline_rounded,
                              label: 'App Name',
                              value: snapshot.data?.appName ?? 'PDF Studio',
                            ),
                            _AppInfoTile(
                              icon: Icons.verified_outlined,
                              label: 'Version',
                              value: fullVersion,
                              showDivider: false,
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _openInfoPage(
    BuildContext context, {
    required String title,
    required String content,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _InfoPage(title: title, content: content),
      ),
    );
  }

  Future<void> _contactSupport(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'pdfstudio9@gmail.com',
      queryParameters: <String, String>{
        'subject': 'PDF Studio Support',
      },
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      return;
    }

    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No email app found. Contact: pdfstudio9@gmail.com'),
      ),
    );
  }

  Future<void> _showShareOptions(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.panelBackground,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ListTile(
                  leading: Icon(Icons.share_outlined, color: context.primaryText),
                  title: Text(
                    'Share via',
                    style: TextStyle(color: context.primaryText),
                  ),
                  subtitle: Text(
                    'Choose an app to send text and Play Store link',
                    style: TextStyle(color: context.secondaryText),
                  ),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await Share.share(_shareMessage, subject: 'PDF Studio');
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.content_copy_rounded,
                    color: context.primaryText,
                  ),
                  title: Text(
                    'Copy link',
                    style: TextStyle(color: context.primaryText),
                  ),
                  subtitle: Text(
                    'Copy Play Store link to clipboard',
                    style: TextStyle(color: context.secondaryText),
                  ),
                  onTap: () async {
                    await Clipboard.setData(
                      const ClipboardData(text: _playStoreUrl),
                    );
                    if (!context.mounted) {
                      return;
                    }
                    Navigator.of(sheetContext).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Play Store link copied'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StorageCard extends StatelessWidget {
  const _StorageCard({
    required this.info,
    required this.icon,
    required this.accent,
    required this.title,
    this.customSummary,
    this.availableValue,
    this.showUsedValue = true,
  });

  final StorageInfo info;
  final IconData icon;
  final Color accent;
  final String title;
  final String? customSummary;
  final String? availableValue;
  final bool showUsedValue;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final usedStorage = formatFileSize(info.usedBytes);
    final availableStorage = formatFileSize(info.availableBytes);
    final totalStorage = formatFileSize(info.totalBytes);
    final summary = customSummary ??
        (info.isAvailable
            ? '$usedStorage / $totalStorage'
            : 'Not available');
    final progress = info.isAvailable ? info.usedFraction : 0.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            accent.withValues(alpha: 0.22),
            (isDark ? const Color(0xFF19304F) : Colors.white).withValues(
              alpha: isDark ? 0.94 : 0.98,
            ),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: isDark ? Colors.white : accent,
              size: 18,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: context.primaryText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            summary,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.secondaryText,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 6,
              value: progress,
              backgroundColor: context.softPanel,
              valueColor: AlwaysStoppedAnimation<Color>(
                accent,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              if (showUsedValue)
                Text(
                  'Used: $usedStorage',
                  style: TextStyle(
                    color: context.secondaryText,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (showUsedValue) const Spacer(),
              Text(
                'Available: ${availableValue ?? availableStorage}',
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: context.secondaryText,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MoreMenuTile extends StatelessWidget {
  const _MoreMenuTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.showDivider = true,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: <Widget>[
                Icon(icon, color: context.iconMuted, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: context.primaryText,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: context.secondaryText,
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            color: context.borderColor,
          ),
      ],
    );
  }
}

class _AppInfoTile extends StatelessWidget {
  const _AppInfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.showDivider = true,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: <Widget>[
              Icon(icon, color: context.iconMuted, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: context.secondaryText,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: context.primaryText,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            color: context.borderColor,
          ),
      ],
    );
  }
}


class _InfoPage extends StatelessWidget {
  const _InfoPage({required this.title, required this.content});

  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Text(
          content,
          style: TextStyle(
            color: context.primaryText,
            fontSize: 14,
            height: 1.6,
          ),
        ),
      ),
    );
  }
}

const String _privacyText =
    'PDF Studio is designed to work offline-first. Your files stay on your device unless you explicitly share or export them. We do not require account signup for core usage, and the app avoids unnecessary data collection.';

const String _aboutText =
    'PDF Studio is a high-performance, offline-first document toolkit designed for speed and privacy. We believe that your documents should stay on your device, which is why all our tools—from scanning to PDF conversion—work completely locally without any cloud dependency.\n\nOur mission is to provide a clutter-free, professional experience for managing your digital paperwork without the weight of unnecessary features or data tracking.';

