import 'package:flutter/material.dart';

import '../../band/v8_band_service.dart';
import '../../band/v8_protocol.dart';
import '../theme.dart';

class BandConnectScreen extends StatefulWidget {
  const BandConnectScreen({super.key, required this.service});

  final V8BandService service;

  @override
  State<BandConnectScreen> createState() => _BandConnectScreenState();
}

class _BandConnectScreenState extends State<BandConnectScreen> {
  @override
  void initState() {
    super.initState();
    widget.service.addListener(_onServiceChanged);
  }

  @override
  void dispose() {
    widget.service.removeListener(_onServiceChanged);
    super.dispose();
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = context.appColors;
    final service = widget.service;

    return Scaffold(
      appBar: AppBar(title: const Text('Bracelet')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Status', style: t.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(service.statusMessage ?? 'Ready to scan'),
                  if (service.lastDiscoveredServices.isNotEmpty &&
                      service.state == BandConnectionState.error) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Services found on ${service.lastConnectDeviceName ?? 'device'}:',
                      style: t.textTheme.labelMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      service.lastDiscoveredServices
                          .map(V8Protocol.shortLabel)
                          .join(', '),
                      style: t.textTheme.bodySmall?.copyWith(
                        color: t.colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: service.state == BandConnectionState.scanning ||
                                  service.state == BandConnectionState.connecting
                              ? null
                              : () => service.startScan(),
                          icon: const Icon(Icons.bluetooth_searching),
                          label: const Text('Scan'),
                        ),
                      ),
                      if (service.isConnected) ...[
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () => service.disconnect(),
                          child: const Text('Disconnect'),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  FilterChip(
                    label: const Text('Likely bands only'),
                    selected: service.jcv8OnlyFilter,
                    onSelected: service.setJcv8OnlyFilter,
                  ),
                ],
              ),
            ),
          ),
          if (service.isConnected) ...[
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Live heart rate', style: t.textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        service.liveVitals?.heartRate?.toString() ?? '--',
                        style: t.textTheme.displayLarge?.copyWith(
                          color: c.accent,
                          fontWeight: FontWeight.w700,
                          fontSize: 56,
                        ),
                      ),
                    ),
                    Center(
                      child: Text(
                        'bpm',
                        style: t.textTheme.labelLarge?.copyWith(
                          color: t.colorScheme.onSurface.withValues(alpha: 0.65),
                        ),
                      ),
                    ),
                    if (service.liveVitals?.spo2 != null) ...[
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          'SpO2: ${service.liveVitals!.spo2}%',
                          style: t.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                    if (service.liveVitals?.temperatureC != null) ...[
                      Center(
                        child: Text(
                          'Temp: ${service.liveVitals!.temperatureC!.toStringAsFixed(1)} °C',
                          style: t.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                    if (service.liveHrStatus != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        service.liveHrStatus!,
                        style: t.textTheme.bodySmall?.copyWith(
                          color: t.colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: service.isLiveHrActive
                                ? null
                                : () => service.startLiveHeartRate(),
                            icon: const Icon(Icons.favorite),
                            label: const Text('Start live HR'),
                          ),
                        ),
                        if (service.isLiveHrActive) ...[
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: () => service.stopLiveHeartRate(),
                            child: const Text('Stop'),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Wear the band snugly on your wrist and stay still for 10–30 seconds.',
                      style: t.textTheme.bodySmall?.copyWith(
                        color: t.colorScheme.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (service.deviceInfo != null) ...[
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Device', style: t.textTheme.titleMedium),
                    const SizedBox(height: 10),
                    _InfoRow(label: 'Name', value: service.deviceInfo!.name),
                    _InfoRow(label: 'MAC', value: service.deviceInfo!.mac),
                    _InfoRow(
                      label: 'Battery',
                      value: service.deviceInfo!.isCharging
                          ? '${service.deviceInfo!.batteryPercent}% (charging)'
                          : '${service.deviceInfo!.batteryPercent}%',
                    ),
                    _InfoRow(label: 'Firmware', value: service.deviceInfo!.firmware),
                  ],
                ),
              ),
            ),
          ],
          if (service.visibleScanResults.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('Nearby devices', style: t.textTheme.titleMedium),
            const SizedBox(height: 8),
            ...service.visibleScanResults.map(
              (item) => Card(
                child: ListTile(
                  leading: Icon(
                    Icons.watch,
                    color: item.likelyBand ? c.accent : t.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  title: Text(item.name),
                  subtitle: Text(
                    '${item.device.remoteId.str} · ${item.rssi} dBm'
                    '${item.hasV8Service ? ' · advertises JCV8' : ''}'
                    '${item.likelyBand && !item.hasV8Service ? ' · likely band' : ''}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: service.state == BandConnectionState.connecting
                      ? null
                      : () => service.connect(item.device),
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'How to find your bracelet:\n'
                '• Likely bands are sorted to the top (strongest signal first).\n'
                '• Hold the bracelet against the phone, scan, pick the top entry.\n'
                '• If connect fails with "FFF0 not found", try the next device.\n'
                '• "Likely bands only" is optional — keep it OFF if the list is empty.',
                style: t.textTheme.bodySmall?.copyWith(
                  color: t.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ),
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
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: t.textTheme.labelMedium?.copyWith(
                color: t.colorScheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
          ),
          Expanded(child: Text(value, style: t.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
