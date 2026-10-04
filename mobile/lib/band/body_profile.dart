/// Body data the band needs for calorie and distance estimates (SDK
/// `SetPersonalInfo`, command 0x02) and the app uses for age-based heart-rate
/// zones. Every field is optional until the user fills it in.
class BodyProfile {
  const BodyProfile({this.sex, this.birthDate, this.heightCm, this.weightKg});

  /// 'male' or 'female', as stored by the backend.
  final String? sex;
  final DateTime? birthDate;
  final int? heightCm;
  final double? weightKg;

  static const cmdSetPersonalInfo = 0x02;

  factory BodyProfile.fromUser(Map<dynamic, dynamic> user) => BodyProfile(
    sex: switch (user['sex']) {
      'male' => 'male',
      'female' => 'female',
      _ => null,
    },
    birthDate: DateTime.tryParse('${user['birth_date']}'),
    heightCm: (user['height_cm'] as num?)?.toInt(),
    weightKg: (user['weight_kg'] as num?)?.toDouble(),
  );

  Map<String, dynamic> toApi() => {
    'sex': sex,
    'birth_date': birthDate == null
        ? null
        : '${birthDate!.year.toString().padLeft(4, '0')}-'
              '${birthDate!.month.toString().padLeft(2, '0')}-'
              '${birthDate!.day.toString().padLeft(2, '0')}',
    'height_cm': heightCm,
    'weight_kg': weightKg,
  };

  int? ageOn(DateTime day) {
    final b = birthDate;
    if (b == null) return null;
    var age = day.year - b.year;
    if (day.month < b.month || (day.month == b.month && day.day < b.day)) {
      age--;
    }
    return age < 0 ? null : age;
  }

  int? get age => ageOn(DateTime.now());

  /// The band needs every field; a partial profile is not sent.
  bool get isComplete =>
      sex != null && age != null && heightCm != null && weightKg != null;

  /// Walking stride from height (common estimate: 0.415 × height for men,
  /// 0.413 × height for women), in centimetres.
  int? get stepLengthCm {
    final h = heightCm;
    if (h == null) return null;
    return (h * (sex == 'female' ? 0.413 : 0.415)).round();
  }

  /// Payload for 0x02: sex (1 male, 0 female per the SDK docs), age, height
  /// cm, weight kg, stride cm — one byte each.
  List<int>? bandPayload() {
    if (!isComplete) return null;
    int byte(num v) => v.round().clamp(0, 255);
    return [
      sex == 'male' ? 1 : 0,
      byte(age!),
      byte(heightCm!),
      byte(weightKg!),
      byte(stepLengthCm!),
    ];
  }

  @override
  bool operator ==(Object other) =>
      other is BodyProfile &&
      other.sex == sex &&
      other.birthDate == birthDate &&
      other.heightCm == heightCm &&
      other.weightKg == weightKg;

  @override
  int get hashCode => Object.hash(sex, birthDate, heightCm, weightKg);
}
