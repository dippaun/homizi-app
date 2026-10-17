import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/chat/demo_thread_gateway.dart';
import 'package:homizi/features/chat/domain/thread_state.dart';
import 'package:homizi/features/chat/thread_gateway.dart';

void main() {
  test('demo chat refuses contact and does not claim a server write', () async {
    final gateway = DemoThreadGateway();
    final sent = await gateway.send('match-1', 'See you at 11');
    expect(sent.note, ThreadCopy.demoSaved);
    expect(sent.messages.single.body, 'See you at 11');

    expect(
      () => gateway.send('match-1', 'call 9876543210'),
      throwsA(isA<ThreadFailure>()),
    );
    expect(
      () => gateway.send('match-1', 'ada@example.test'),
      throwsA(isA<ThreadFailure>()),
    );
    final after = await gateway.load('match-1');
    expect(after.messages, hasLength(1));
    expect(after.messages.single.body, isNot(contains('9876543210')));
    expect(after.messages.single.body, isNot(contains('@')));
  });

  test('demo visits stay on the device and hide no address', () async {
    final gateway = DemoThreadGateway();
    gateway.seedVisit(
      VisitRequest(
        id: 'visit-incoming',
        matchId: 'match-1',
        requesterId: 'demo-host',
        slots: [DateTime.utc(2026, 11, 2, 5, 30)],
        status: 'requested',
        mine: false,
      ),
    );

    final accepted = await gateway.respondVisit('visit-incoming', 'accepted');
    expect(accepted.note, ThreadCopy.demoSaved);
    expect(accepted.visits.single.status, 'accepted');

    final requested = await gateway.requestVisit('match-1', [
      DateTime.utc(2026, 11, 3, 11),
    ]);
    expect(requested.visits, hasLength(2));
    final mine = requested.visits.last;
    expect(mine.status, 'requested');
    expect(
      () => gateway.respondVisit(mine.id, 'accepted'),
      throwsA(isA<ThreadFailure>()),
    );
    final cancelled = await gateway.respondVisit(mine.id, 'cancelled');
    expect(cancelled.visits.last.status, 'cancelled');
  });

  test('a street address appears only after the visit is accepted', () async {
    final gateway = DemoThreadGateway();
    gateway.seedVisit(
      VisitRequest(
        id: 'visit-incoming',
        matchId: 'match-1',
        requesterId: 'demo-host',
        slots: [DateTime.utc(2026, 11, 2, 5, 30)],
        status: 'requested',
        mine: false,
        addressLine: '99 Fictional Cross',
      ),
    );
    final hidden = await gateway.load('match-1');
    expect(hidden.visits.single.addressLine, isNull);

    final proposed = await gateway.proposeVisitTime('visit-incoming', [
      DateTime.utc(2026, 11, 3, 11),
    ]);
    expect(proposed.visits.single.status, 'rescheduled');
    expect(proposed.visits.single.addressLine, isNull);

    gateway.seedVisit(
      VisitRequest(
        id: 'visit-direct',
        matchId: 'match-1',
        requesterId: 'demo-host',
        slots: [DateTime.utc(2026, 11, 4, 5, 30)],
        status: 'requested',
        mine: false,
        addressLine: '99 Fictional Cross',
      ),
    );
    final accepted = await gateway.respondVisit('visit-direct', 'accepted');
    final shown = accepted.visits.singleWhere(
      (visit) => visit.id == 'visit-direct',
    );
    expect(shown.addressLine, '99 Fictional Cross');
    expect(
      accepted.visits
          .singleWhere((visit) => visit.id == 'visit-incoming')
          .addressLine,
      isNull,
    );

    final completed = await gateway.respondVisit('visit-direct', 'completed');
    expect(
      completed.visits
          .singleWhere((visit) => visit.id == 'visit-direct')
          .status,
      'completed',
    );
    expect(
      completed.visits
          .singleWhere((visit) => visit.id == 'visit-direct')
          .addressLine,
      '99 Fictional Cross',
    );
  });
}
