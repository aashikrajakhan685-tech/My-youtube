import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/library_provider.dart';
import '../services/settings_provider.dart';
import '../services/theme_provider.dart';
import '../theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const Map<int, String> _qualityNames = {
    0: 'Auto (HD, 1080p tak)',
    360: '360p',
    480: '480p',
    720: '720p',
    1080: '1080p',
    1440: '1440p (2K)',
    2160: '4K (2160p)',
  };

  void _pickQuality(BuildContext context) {
    final st = context.read<SettingsProvider>();
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: _qualityNames.entries
              .map((e) => ListTile(
                    title: Text(e.value),
                    trailing: st.defaultQuality == e.key ? const Icon(Icons.check) : null,
                    onTap: () {
                      st.setDefaultQuality(e.key);
                      Navigator.pop(ctx);
                    },
                  ))
              .toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tp = context.watch<ThemeProvider>();
    final st = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const ListTile(title: Text('Themes', style: TextStyle(fontWeight: FontWeight.bold))),
          ...AppThemes.themes.keys.map((name) => ListTile(
                title: Text(name),
                trailing: tp.themeName == name ? const Icon(Icons.check) : null,
                onTap: () => tp.setTheme(name),
              )),
          const Divider(),
          const ListTile(title: Text('Playback', style: TextStyle(fontWeight: FontWeight.bold))),
          SwitchListTile(
            title: const Text('SponsorBlock'),
            subtitle: const Text('Sponsor, self-promo aur subscribe-reminder wale hisse apne aap skip'),
            value: st.sponsorBlock,
            onChanged: (v) => st.setSponsorBlock(v),
          ),
          ListTile(
            title: const Text('Default quality'),
            subtitle: Text(_qualityNames[st.defaultQuality] ?? 'Auto'),
            onTap: () => _pickQuality(context),
          ),
          const Divider(),
          const ListTile(title: Text('Data', style: TextStyle(fontWeight: FontWeight.bold))),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Watch history saaf karo'),
            onTap: () {
              context.read<LibraryProvider>().clearHistory();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('History saaf ho gayi')));
            },
          ),
          ListTile(
            leading: const Icon(Icons.search_off),
            title: const Text('Search history saaf karo'),
            onTap: () {
              context.read<LibraryProvider>().clearSearches();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Search history saaf ho gayi')));
            },
          ),
        ],
      ),
    );
  }
}
