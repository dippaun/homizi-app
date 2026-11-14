import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/tools/domain/smart_split.dart';
import 'package:homizi/features/tools/split_screen.dart';

const _home = SplitHome(
  bhk: '3 BHK',
  locality: 'Andheri East, Mumbai',
  rentInr: 30000,
);

List<SplitRoom> _design() => const [
  SplitRoom(size: SplitRoomSize.large, attachedBath: true, occupants: ['You']),
  SplitRoom(
    size: SplitRoomSize.standard,
    attachedBath: false,
    occupants: ['Amit'],
  ),
  SplitRoom(
    size: SplitRoomSize.standard,
    attachedBath: false,
    occupants: ['Rahul'],
  ),
];

void main() {
  test('the design example: master ₹13,500, standard rooms ₹8,250', () {
    final out = computeSplit(
      home: _home,
      rooms: _design(),
      mode: SplitMode.smart,
    );
    expect(out.problem, isNull);
    expect(out.shares.map((s) => s.rentInr), [13500, 8250, 8250]);
    expect(out.grandTotal, 30000);
    expect(roomTitle(_design(), 0), 'Room 1 (Master)');
    expect(roomTitle(_design(), 1), 'Room 2');
    expect(_design().first.detail, 'Larger room + Attached bathroom');
  });

  test('equal split gives ₹10,000 each', () {
    final out = computeSplit(
      home: _home,
      rooms: _design(),
      mode: SplitMode.equal,
    );
    expect(out.shares.map((s) => s.rentInr), [10000, 10000, 10000]);
  });

  test('two people in one room share that room, and rupees add back', () {
    final rooms = [
      _design()[0].copyWith(occupants: ['You', 'Priya']),
      _design()[1],
      _design()[2],
    ];
    final out = computeSplit(
      home: _home.copyWith(rentInr: 30001),
      rooms: rooms,
      mode: SplitMode.smart,
    );
    expect(out.shares, hasLength(4));
    expect(out.shares[0].rentInr + out.shares[1].rentInr, 13501);
    expect(
      (out.shares[0].rentInr - out.shares[1].rentInr).abs(),
      lessThanOrEqualTo(1),
    );
    expect(out.rentTotal, 30001);
  });

  test('an empty room carries no rent and bills are shared equally', () {
    final rooms = [
      _design()[0],
      _design()[1].copyWith(occupants: const []),
      _design()[2],
    ];
    final out = computeSplit(
      home: _home.copyWith(maintenanceInr: 3000, utilitiesInr: 1500),
      rooms: rooms,
      mode: SplitMode.smart,
    );
    expect(out.shares, hasLength(2));
    expect(out.rentTotal, 30000);
    expect(out.shares.map((s) => s.billsInr), [2250, 2250]);
    expect(out.grandTotal, 34500);
  });

  test('a custom split must add up to the rent', () {
    final short = computeSplit(
      home: _home,
      rooms: _design(),
      mode: SplitMode.custom,
      custom: const {0: 12000, 1: 9000, 2: 8000},
    );
    expect(short.problem, 'Shares are ₹1,000 short of the rent.');
    final over = computeSplit(
      home: _home,
      rooms: _design(),
      mode: SplitMode.custom,
      custom: const {0: 12000, 1: 10000, 2: 9000},
    );
    expect(over.problem, 'Shares are ₹1,000 over the rent.');
    final ok = computeSplit(
      home: _home,
      rooms: _design(),
      mode: SplitMode.custom,
      custom: const {0: 12000, 1: 9000, 2: 9000},
    );
    expect(ok.problem, isNull);
  });

  test('no people or no rent is refused', () {
    expect(
      computeSplit(
        home: _home,
        rooms: [_design()[0].copyWith(occupants: const [])],
        mode: SplitMode.smart,
      ).problem,
      isNotNull,
    );
    expect(
      computeSplit(
        home: _home.copyWith(rentInr: 0),
        rooms: _design(),
        mode: SplitMode.smart,
      ).problem,
      isNotNull,
    );
  });

  test('default rooms follow the BHK with a master first', () {
    final rooms = defaultRooms('3 BHK', 3, names: ['You', 'Amit']);
    expect(rooms, hasLength(3));
    expect(rooms.first.isMaster, isTrue);
    expect(peopleIn(rooms).map((p) => p.name), ['You', 'Amit', 'Roommate 3']);
    final four = defaultRooms('2 BHK', 4);
    expect(four.map((r) => r.occupants.length), [2, 2]);
    expect(bedroomsFor('1 RK'), 1);
    expect(defaultRooms('1 RK', 2).single.isMaster, isFalse);
  });

  test('a saved split survives encoding', () {
    final out = computeSplit(
      home: _home,
      rooms: _design(),
      mode: SplitMode.smart,
    );
    final split = SavedRentSplit(
      id: 'local-1',
      home: _home,
      rooms: _design(),
      mode: SplitMode.smart,
      shares: out.shares,
      agreed: const ['You', 'Amit', 'Rahul'],
      finalizedAt: DateTime.utc(2026, 11, 14, 13),
    );
    final back = decodeSplits(encodeSplits([split]));
    expect(back, hasLength(1));
    expect(back.single.shares.map((s) => s.rentInr), [13500, 8250, 8250]);
    expect(back.single.rooms.first.isMaster, isTrue);
    expect(back.single.home.locality, 'Andheri East, Mumbai');
    expect(decodeSplits('not json'), isEmpty);
  });

  test('summary text and query names', () {
    final out = computeSplit(
      home: _home,
      rooms: _design(),
      mode: SplitMode.smart,
    );
    final text = splitSummaryText(
      home: _home,
      rooms: _design(),
      mode: SplitMode.smart,
      shares: out.shares,
    );
    expect(text, contains('₹30,000'));
    expect(text, contains('You (Room 1 (Master)): ₹13,500'));
    expect(splitRoommatesFromQuery('Amit Shah, Rahul ,'), ['Amit', 'Rahul']);
    expect(splitRoommatesFromQuery(null), isEmpty);
  });
}
