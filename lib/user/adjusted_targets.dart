// Helper to compute adjusted period targets with carry-over and backward adjustment.
Map<String, Map<String, dynamic>> computeAdjustedTargets(
  Map<String, Map<String, dynamic>> mealTargets,
  Map<String, Map<String, double>> periodIntake,
  bool includeSnacks,
) {
  // Build a fresh adjusted map (period targets) starting from base mealTargets
  Map<String, Map<String, dynamic>> adjusted = {};
  mealTargets.forEach((key, value) {
    adjusted[key] = Map<String, dynamic>.from(value);
  });

  final metrics = ['Calories', 'Protein_g', 'Carbs_g', 'Fats_g'];
  final order = ['Breakfast', 'Lunch', 'Dinner', 'Snack'];

  // Forward pass: compute period targets with carryover
  Map<String, Map<String, double>> remaining = {};
  for (var m in metrics) {
    double carryover = 0.0;
    for (var i = 0; i < order.length; i++) {
      final meal = order[i];
      if (meal == 'Snack' && !includeSnacks) {
        adjusted[meal]?[m] = (mealTargets[meal]?[m] ?? adjusted[meal]?[m] ?? 0.0);
        remaining[meal] ??= {};
        remaining[meal]![m] = (adjusted[meal]![m] as num).toDouble() - (periodIntake[meal]?[m] ?? 0.0);
        continue;
      }
      final base = (mealTargets[meal]?[m] ?? 0.0);
      final intake = (periodIntake[meal]?[m] ?? 0.0);
      double periodTarget = base.toDouble() + carryover;
      if (periodTarget < 0) periodTarget = 0.0;
      adjusted[meal]?[m] = periodTarget;

      final rem = periodTarget - intake;
      remaining[meal] ??= {};
      remaining[meal]![m] = rem;

      carryover = rem;
    }
  }

  // Backward pass: ensure previous remaining <= next remaining
  for (var m in metrics) {
    for (var i = order.length - 2; i >= 0; i--) {
      final meal = order[i];
      final nextMeal = order[i + 1];
      if (!remaining.containsKey(meal) || !remaining.containsKey(nextMeal)) continue;
      final curRem = remaining[meal]![m] ?? 0.0;
      final nextRem = remaining[nextMeal]![m] ?? 0.0;
      if (curRem > nextRem) {
        // Reduce current remaining to match nextRem, and update its period target accordingly
        remaining[meal]![m] = nextRem;
        final intake = (periodIntake[meal]?[m] ?? 0.0);
        adjusted[meal]?[m] = (intake).toDouble() + nextRem;
      }
    }
  }

  return adjusted;
}
