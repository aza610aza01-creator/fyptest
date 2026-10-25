import 'package:flutter/foundation.dart';
import 'package:ai_gym_flutter/core/utils/fitness_calculators.dart';

/// Provides reactive BMI, BMR, TDEE, and heart-rate zone calculations for Body & Health views.
class HealthController extends ChangeNotifier {
  bool _isDisposed = false;
  bool get isDisposed => _isDisposed;

  double calculateBmi({required double weightKg, required double heightCm}) {
    return FitnessCalculators.calculateBmi(
      weightKg: weightKg,
      heightCm: heightCm,
    );
  }

  double calculateBmr({
    required double weightKg,
    required double heightCm,
    required int age,
    bool isMale = true,
  }) {
    return FitnessCalculators.calculateBmr(
      weightKg: weightKg,
      heightCm: heightCm,
      age: age,
      gender: isMale ? 'male' : 'female',
    );
  }

  @override
  void notifyListeners() {
    if (_isDisposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
