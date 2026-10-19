/// Pure calculation utilities for 1RM, volume, unit conversion, and coaching.
class FitnessCalculators {
  FitnessCalculators._();

  static const double kgToLbRatio = 2.2046226218;
  static const double kmToMiRatio = 0.6213711922;

  /// Epley estimated 1RM formula. Returns 0 when inputs are insufficient.
  static double estimateOneRepMax({
    required double weightKg,
    required int reps,
  }) {
    if (weightKg <= 0 || reps <= 0) return 0;
    if (reps == 1) return weightKg;
    final cappedReps = reps > 30 ? 30 : reps;
    return weightKg * (1 + cappedReps / 30.0);
  }

  /// Converts kilograms to pounds when imperial unit system is active.
  static double formatWeight(double weightKg, {required bool isImperial}) {
    return isImperial ? weightKg * kgToLbRatio : weightKg;
  }

  /// Converts user-entered weight back to kilograms for canonical database storage.
  static double toKilograms(double enteredWeight, {required bool isImperial}) {
    return isImperial ? enteredWeight / kgToLbRatio : enteredWeight;
  }

  /// Converts kilometers to miles when imperial unit system is active.
  static double formatDistance(double distanceKm, {required bool isImperial}) {
    return isImperial ? distanceKm * kmToMiRatio : distanceKm;
  }

  /// Estimates calorie expenditure with explicit general-fitness approximation.
  static int estimateCardioCalories({
    required int durationSeconds,
    required double userWeightKg,
    required double metValue,
  }) {
    if (durationSeconds <= 0 || userWeightKg <= 0 || metValue <= 0) return 0;
    final hours = durationSeconds / 3600.0;
    return (metValue * userWeightKg * hours).round();
  }

  /// Generates auto-progression guidance based on latest working set RPE/reps.
  static String suggestProgression({
    required double currentWeightKg,
    required int achievedReps,
    required int targetReps,
    required double? rpe,
    required bool isZh,
  }) {
    if (achievedReps <= 0 || currentWeightKg < 0) {
      return isZh
          ? '尚無足夠訓練組數資料，請先完成至少 1 組標準工作組。'
          : 'Log at least one working set to receive progression guidance.';
    }
    final effectiveRpe = rpe ?? 8.0;
    if (achievedReps >= targetReps && effectiveRpe <= 8.0) {
      final nextWeight = (currentWeightKg + 2.5).toStringAsFixed(1);
      return isZh
          ? '已達成目標次數且 RPE 穩定：建議下次訓練增加 +2.5 kg（目標 $nextWeight kg）或每組增加 +1 次（一般體能參考，非醫療建議）。'
          : 'Target reps achieved at manageable RPE: consider adding +2.5 kg (to $nextWeight kg) or +1 rep next session (general fitness guidance, not medical advice).';
    }
    if (effectiveRpe >= 9.5) {
      final deloadWeight = (currentWeightKg * 0.9).toStringAsFixed(1);
      return isZh
          ? 'RPE 偏高 (>=9.5)：建議維持目前負荷或安排減量週 (Deload 約 $deloadWeight kg) 以優先確保動作控制與恢復。'
          : 'High fatigue detected (RPE >= 9.5): hold load steady or schedule a 10% deload (~$deloadWeight kg) to prioritize recovery.';
    }
    return isZh
        ? '建議維持 $currentWeightKg kg 並穩定完成 $targetReps 次目標後再漸進加載。'
        : 'Maintain ${currentWeightKg.toStringAsFixed(1)} kg until you hit $targetReps clean reps across all working sets.';
  }
}
