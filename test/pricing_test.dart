import 'package:flutter_test/flutter_test.dart';
import 'package:nursaflow/features/subscription/subscription_screen.dart';

void main() {
  group('PlanCatalog pricing', () {
    test('monthly price is ₦1,500', () {
      expect(PlanCatalog.monthlyPrice, 1500);
    });

    test('annual price is ₦12,000', () {
      expect(PlanCatalog.annualPrice, 12000);
    });

    test('annual plan is cheaper per-month than paying monthly', () {
      final monthlyEquivalentOfAnnual = PlanCatalog.annualPrice / 12;
      expect(monthlyEquivalentOfAnnual, lessThan(PlanCatalog.monthlyPrice));
    });
  });
}