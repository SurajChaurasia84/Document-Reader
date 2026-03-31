import 'package:doc_reader/models/subscription_plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('subscription plan model stores values', () {
    const plan = SubscriptionPlan(
      id: 'doc_reader_monthly',
      title: 'Monthly',
      priceLabel: '₹199',
      description: 'Flexible premium access for everyday work.',
    );

    expect(plan.id, 'doc_reader_monthly');
    expect(plan.title, 'Monthly');
    expect(plan.priceLabel, '₹199');
  });
}
