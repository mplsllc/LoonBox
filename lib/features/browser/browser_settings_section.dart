import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'browser_service.dart';

/// Browser settings section for the main settings page.
class BrowserSettingsSection extends ConsumerStatefulWidget {
  const BrowserSettingsSection({super.key});

  @override
  ConsumerState<BrowserSettingsSection> createState() =>
      _BrowserSettingsSectionState();
}

class _BrowserSettingsSectionState
    extends ConsumerState<BrowserSettingsSection> {
  bool _adBlockEnabled = true;
  int _ruleCount = 0;
  int _lastUpdated = 0;
  bool _updating = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final browserService = ref.read(browserServiceProvider);
      final json = await browserService.getFilterStats();
      final stats = jsonDecode(json) as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _ruleCount = stats['rule_count'] as int? ?? 0;
          _lastUpdated = stats['last_updated'] as int? ?? 0;
          _adBlockEnabled = stats['enabled'] as bool? ?? true;
        });
      }
    } catch (_) {
      // Browser service may not be available
    }
  }

  Future<void> _updateFilterLists() async {
    setState(() => _updating = true);
    try {
      final browserService = ref.read(browserServiceProvider);
      await browserService.updateFilterLists();
      await _loadStats();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update filter lists: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  String _formatLastUpdated() {
    if (_lastUpdated == 0) return 'Never';
    final date =
        DateTime.fromMillisecondsSinceEpoch(_lastUpdated * 1000);
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SwitchListTile(
          title: const Text('Ad blocking'),
          subtitle: Text('$_ruleCount rules loaded'),
          value: _adBlockEnabled,
          onChanged: (value) {
            setState(() => _adBlockEnabled = value);
            // TODO: wire to Rust toggle when implemented
          },
        ),
        ListTile(
          title: const Text('Filter lists'),
          subtitle: Text('Last updated: ${_formatLastUpdated()}'),
          trailing: _updating
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : TextButton(
                  onPressed: _updateFilterLists,
                  child: const Text('Update now'),
                ),
        ),
      ],
    );
  }
}
