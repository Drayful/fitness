import 'package:flutter/material.dart';

import '../../band/band_variant.dart';
import '../../band/v8_band_service.dart';
import '../../band/v8_protocol.dart';
import '../l10n/app_localizations.dart';
import '../theme.dart';

class BandConnectScreen extends StatefulWidget {
  const BandConnectScreen({super.key, required this.service});

  final V8BandService service;

  @override
  State<BandConnectScreen> createState() => _BandConnectScreenState();
}

class _BandConnectScreenState extends State<BandConnectScreen> {
  bool _showOther = false;

  @override
  void initState() {
    super.initState();
    widget.service.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.service.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.service;
    final l = AppLocalizations.of(context);
    final c = context.appColors;
    final likely = service.scanResults.where((d) => d.likelyBand).toList();
    final other = service.scanResults.where((d) => !d.likelyBand).toList();
    final scanning = service.state == BandConnectionState.scanning;
    final connecting = service.state == BandConnectionState.connecting;
    final connected = service.isConnected;

    return Scaffold(
      appBar: AppBar(title: Text(l.t('watch_connect_title'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: c.accent.withValues(alpha: 0.25)),
              gradient: const LinearGradient(
                colors: [Color(0xFF18302E), Color(0xFF171B21)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: c.accent.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(
                        Icons.watch_outlined,
                        color: c.accent,
                        size: 31,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.t(
                              connected
                                  ? 'watch_connected_title'
                                  : connecting
                                  ? 'watch_connecting_title'
                                  : scanning
                                  ? 'watch_searching_title'
                                  : 'watch_search_title',
                            ),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l.t(
                              connected
                                  ? service.variantConfirmed
                                        ? 'watch_connected_ready_sub'
                                        : 'watch_connected_sub'
                                  : 'watch_search_sub',
                            ),
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(color: c.subtext),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (scanning || connecting) ...[
                  const SizedBox(height: 17),
                  LinearProgressIndicator(
                    minHeight: 4,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
                const SizedBox(height: 17),
                SizedBox(
                  width: double.infinity,
                  child: connected
                      ? OutlinedButton.icon(
                          onPressed: () => service.forgetDevice(),
                          icon: const Icon(Icons.bluetooth_disabled),
                          label: Text(l.t('watch_disconnect')),
                        )
                      : FilledButton.icon(
                          onPressed: scanning || connecting
                              ? null
                              : () => service.startScan(),
                          icon: const Icon(Icons.bluetooth_searching),
                          label: Text(l.t('watch_scan_button')),
                        ),
                ),
              ],
            ),
          ),
          if (service.state == BandConnectionState.error) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: c.warn),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        service.statusMessage ?? l.t('watch_connect_failed'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (!connected && !connecting) ...[
            const SizedBox(height: 24),
            _Heading(label: l.t('watch_candidates'), count: likely.length),
            const SizedBox(height: 5),
            Text(
              l.t('watch_candidates_note'),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: c.subtext),
            ),
            const SizedBox(height: 12),
            if (likely.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Icon(
                        scanning ? Icons.radar : Icons.watch_outlined,
                        color: c.subtext,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l.t(
                            scanning
                                ? 'watch_searching_empty'
                                : 'watch_candidates_empty',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              for (final item in likely) ...[
                _DeviceCard(
                  item: item,
                  l: l,
                  onTap: () => service.connect(item.device),
                ),
                const SizedBox(height: 9),
              ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: other.isEmpty
                    ? null
                    : () => setState(() => _showOther = !_showOther),
                icon: Icon(_showOther ? Icons.expand_less : Icons.expand_more),
                label: Text(
                  '${l.t(_showOther ? 'watch_hide_other' : 'watch_show_other')} (${other.length})',
                ),
              ),
            ),
            if (_showOther) ...[
              const SizedBox(height: 9),
              Text(
                l.t('watch_other_note'),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: c.subtext),
              ),
              const SizedBox(height: 9),
              for (final item in other) ...[
                _DeviceCard(
                  item: item,
                  l: l,
                  onTap: () => service.connect(item.device),
                ),
                const SizedBox(height: 9),
              ],
            ],
            const SizedBox(height: 18),
            Text(
              l.t('watch_scan_tip'),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: c.subtext),
            ),
          ],
          if (connected) ...[
            const SizedBox(height: 16),
            _ModelPicker(service: service, l: l),
            const SizedBox(height: 13),
            _LiveCard(service: service, l: l),
            if (service.deviceInfo != null) ...[
              const SizedBox(height: 13),
              _TechnicalDetails(service: service, l: l),
            ],
          ],
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(label, style: Theme.of(context).textTheme.titleMedium),
      ),
      Text('$count', style: TextStyle(color: context.appColors.subtext)),
    ],
  );
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.item, required this.l, required this.onTap});

  final ScannedBand item;
  final AppLocalizations l;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final t = Theme.of(context);
    final suggested = item.likelyBand;
    final evidence = item.rememberedVariant != null
        ? '${l.t('watch_seen_before')} · ${item.rememberedVariant!.label}'
        : item.hasV8Service
        ? l.t('watch_service_hint')
        : item.hasNameHint
        ? l.t('watch_name_hint')
        : l.t('watch_other_device');
    final signal = item.rssi == 0
        ? l.t('watch_signal_unknown')
        : item.rssi >= -65
        ? l.t('watch_signal_strong')
        : item.rssi >= -80
        ? l.t('watch_signal_medium')
        : l.t('watch_signal_weak');
    final id = item.device.remoteId.str;
    final suffix = id.length > 8 ? id.substring(id.length - 8) : id;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: suggested
                      ? c.accent.withValues(alpha: 0.13)
                      : const Color(0xFF2A313A),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  suggested ? Icons.watch_outlined : Icons.bluetooth,
                  color: suggested ? c.accent : c.subtext,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name.isEmpty ? l.t('watch_unnamed') : item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      evidence,
                      style: t.textTheme.bodySmall?.copyWith(
                        color: suggested ? c.accent : c.subtext,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$signal · ID $suffix',
                      style: t.textTheme.labelSmall?.copyWith(color: c.subtext),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: c.subtext),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModelPicker extends StatelessWidget {
  const _ModelPicker({required this.service, required this.l});

  final V8BandService service;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final t = Theme.of(context);
    final locked =
        service.isWorkoutActive ||
        service.isSleepSyncing ||
        service.isStartingLive;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.t('watch_model_title'), style: t.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              l.t('watch_model_note'),
              style: t.textTheme.bodySmall?.copyWith(color: c.subtext),
            ),
            const SizedBox(height: 13),
            for (final variant in BandVariant.values) ...[
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color:
                        service.variantConfirmed && service.variant == variant
                        ? c.accent
                        : const Color(0xFF2A313A),
                  ),
                ),
                tileColor:
                    service.variantConfirmed && service.variant == variant
                    ? c.accent.withValues(alpha: 0.10)
                    : const Color(0xFF12161B),
                leading: Icon(Icons.watch_outlined, color: c.accent),
                title: Text(variant.label),
                trailing: service.variantConfirmed && service.variant == variant
                    ? Icon(Icons.check_circle, color: c.accent)
                    : null,
                onTap: locked
                    ? null
                    : () async {
                        try {
                          await service.overrideVariant(variant);
                        } catch (error) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(SnackBar(content: Text('$error')));
                          }
                        }
                      },
              ),
              if (variant != BandVariant.values.last) const SizedBox(height: 8),
            ],
            if (!service.variantConfirmed) ...[
              const SizedBox(height: 10),
              Text(
                l.t('watch_model_required'),
                style: t.textTheme.bodySmall?.copyWith(color: c.warn),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LiveCard extends StatelessWidget {
  const _LiveCard({required this.service, required this.l});

  final V8BandService service;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final t = Theme.of(context);
    final vitals = service.liveVitals;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.t('watch_live_title'), style: t.textTheme.titleMedium),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${vitals?.heartRate ?? '—'}',
                  style: t.textTheme.displayMedium?.copyWith(
                    color: c.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 7),
                Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Text(l.t('bpm')),
                ),
              ],
            ),
            if (vitals?.spo2 != null || vitals?.temperatureC != null)
              Text(
                [
                  if (vitals?.spo2 != null) 'SpO₂ ${vitals!.spo2}%',
                  if (vitals?.temperatureC != null)
                    '${l.t('temp_label')} ${vitals!.temperatureC!.toStringAsFixed(1)} °C',
                ].join(' · '),
              ),
            if (service.isLiveHrActive && vitals?.heartRate == null) ...[
              const SizedBox(height: 8),
              Text(
                l.t('watch_waiting_data'),
                style: t.textTheme.bodySmall?.copyWith(color: c.subtext),
              ),
            ],
            const SizedBox(height: 13),
            SizedBox(
              width: double.infinity,
              child: service.isLiveHrActive
                  ? OutlinedButton.icon(
                      onPressed: () => service.stopLiveHeartRate(),
                      icon: const Icon(Icons.stop_circle_outlined),
                      label: Text(l.t('watch_stop_measurement')),
                    )
                  : FilledButton.icon(
                      onPressed:
                          !service.variantConfirmed || service.isStartingLive
                          ? null
                          : () async {
                              try {
                                await service.startLiveHeartRate();
                              } catch (error) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('$error')),
                                  );
                                }
                              }
                            },
                      icon: const Icon(Icons.favorite_outline),
                      label: Text(l.t('watch_start_measurement')),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TechnicalDetails extends StatelessWidget {
  const _TechnicalDetails({required this.service, required this.l});

  final V8BandService service;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final info = service.deviceInfo!;
    return Card(
      child: ExpansionTile(
        title: Text(l.t('watch_details')),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          _InfoRow(label: l.t('watch_device_name'), value: info.name),
          _InfoRow(label: 'MAC', value: info.mac),
          _InfoRow(
            label: l.t('battery'),
            value: info.batteryPercent == null
                ? '—'
                : '${info.batteryPercent}%',
          ),
          _InfoRow(label: l.t('firmware'), value: info.firmware),
          if (service.lastDiscoveredServices.isNotEmpty)
            _InfoRow(
              label: 'BLE',
              value: service.lastDiscoveredServices
                  .map(V8Protocol.shortLabel)
                  .join(', '),
            ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: TextStyle(color: context.appColors.subtext),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}
