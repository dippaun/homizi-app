import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/format/ordered_range.dart';

void main() {
  test('a dragged minimum cannot pass the maximum', () {
    final inverted = orderRange(
      start: 80000,
      end: 15000,
      min: InrRangeScale.min,
      max: InrRangeScale.max,
      step: InrRangeScale.step,
    );
    expect(inverted.start, 15000);
    expect(inverted.end, 80000);
    expect(inverted.start <= inverted.end, isTrue);

    final snapped = orderRange(
      start: 12400,
      end: 35600,
      min: InrRangeScale.min,
      max: InrRangeScale.max,
      step: InrRangeScale.step,
    );
    expect(snapped.start, 12000);
    expect(snapped.end, 36000);
  });

  test('saved values stay on their columns until the user drags', () {
    final offStep = clampOrdered(
      start: null,
      end: 9999,
      min: InrRangeScale.min,
      max: InrRangeScale.max,
      fallbackStart: InrRangeScale.min,
      fallbackEnd: InrRangeScale.max,
    );
    expect(offStep.start, 0);
    expect(offStep.end, 9999);

    final preset = clampOrdered(
      start: null,
      end: null,
      min: InrRangeScale.min,
      max: InrRangeScale.max,
      fallbackStart: InrRangeScale.presetMin,
      fallbackEnd: InrRangeScale.presetMax,
    );
    expect(preset.start, 12000);
    expect(preset.end, 35000);
  });

  test('open ends and the live label use Indian grouping', () {
    expect(
      openBounds(
        start: 0,
        end: InrRangeScale.max,
        min: InrRangeScale.min,
        max: InrRangeScale.max,
      ),
      (start: null, end: null),
    );
    expect(
      openBounds(
        start: 12000,
        end: 35000,
        min: InrRangeScale.min,
        max: InrRangeScale.max,
      ),
      (start: 12000, end: 35000),
    );
    expect(
      orderedRangeLabel(
        start: 12000,
        end: 35000,
        min: InrRangeScale.min,
        max: InrRangeScale.max,
        format: formatInr,
      ),
      '₹12,000 – ₹35,000',
    );
    expect(
      orderedRangeLabel(
        start: 0,
        end: 9999,
        min: InrRangeScale.min,
        max: InrRangeScale.max,
        format: formatInr,
        openAtBounds: true,
      ),
      'Up to ₹9,999',
    );
    expect(
      orderedRangeLabel(
        start: 50000,
        end: InrRangeScale.max,
        min: InrRangeScale.min,
        max: InrRangeScale.max,
        format: formatInr,
        openAtBounds: true,
      ),
      '₹50,000 and above',
    );
    expect(
      orderedRangeLabel(
        start: 600,
        end: 1600,
        min: AreaRangeScale.min,
        max: AreaRangeScale.max,
        format: formatSqft,
      ),
      '600 sq ft – 1,600 sq ft',
    );
  });

  test('owner budget filter keeps overlapping tenants', () {
    expect(
      budgetOverlaps(min: 18000, max: 32000, filterMin: 30000, filterMax: null),
      isTrue,
    );
    expect(
      budgetOverlaps(min: 15000, max: 28000, filterMin: 30000, filterMax: null),
      isFalse,
    );
    expect(
      budgetOverlaps(min: null, max: null, filterMin: null, filterMax: null),
      isTrue,
    );
    expect(
      budgetOverlaps(min: null, max: null, filterMin: 12000, filterMax: 35000),
      isFalse,
    );
  });
}
