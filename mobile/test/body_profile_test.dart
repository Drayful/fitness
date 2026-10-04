import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_app/band/body_profile.dart';

void main() {
  test('band payload follows SDK SetPersonalInfo: sex, age, cm, kg, stride', () {
    final p = BodyProfile(
      sex: 'male',
      birthDate: DateTime(2000, 1, 1),
      heightCm: 180,
      weightKg: 75.4,
    );
    final age = p.age!;
    expect(p.bandPayload(), [1, age, 180, 75, 75]); // 180 × 0.415 ≈ 75
    final f = BodyProfile(
      sex: 'female',
      birthDate: DateTime(2012, 5, 20),
      heightCm: 152,
      weightKg: 41.5,
    );
    expect(f.bandPayload()!.first, 0);
    expect(f.stepLengthCm, 63); // 152 × 0.413
  });

  test('age counts the birthday', () {
    final p = BodyProfile(birthDate: DateTime(2012, 5, 20));
    expect(p.ageOn(DateTime(2026, 5, 19)), 13);
    expect(p.ageOn(DateTime(2026, 5, 20)), 14);
  });

  test('incomplete profile is not sent to the band', () {
    expect(const BodyProfile(heightCm: 170).bandPayload(), isNull);
    expect(
      BodyProfile(
        sex: 'male',
        birthDate: DateTime(2000),
        heightCm: 170,
      ).bandPayload(),
      isNull,
    );
  });

  test('round-trips the API shape', () {
    final p = BodyProfile.fromUser({
      'sex': 'female',
      'birth_date': '2012-05-20',
      'height_cm': 152,
      'weight_kg': 41.5,
    });
    expect(p.toApi(), {
      'sex': 'female',
      'birth_date': '2012-05-20',
      'height_cm': 152,
      'weight_kg': 41.5,
    });
    expect(BodyProfile.fromUser({'sex': 'other'}).sex, isNull);
  });
}
