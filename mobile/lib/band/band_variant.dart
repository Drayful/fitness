/// Firmware protocol variants supported by [V8Protocol].
///
/// The supplied V8 and 2208A SDKs share BCD time and 0x53 sleep framing.
/// Select a model explicitly: time and MTU replies cannot identify it.
enum BandVariant {
  /// V8 SDK-20260319. The enum name is retained for existing callers.
  legacyV8,

  /// JStyle 2208A firmware: BCD date fields, per-unit sleep activity counts,
  /// 16-byte 0x18 workout packets, phone-driven 0x17 heartbeat.
  jc2208a;

  String get label => switch (this) {
    BandVariant.legacyV8 => 'V8 SDK',
    BandVariant.jc2208a => 'JStyle 2208A',
  };
}
