import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/owner/demo_listing_memory.dart';
import 'package:homizi/features/owner/demo_owner_gateway.dart';
import 'package:homizi/features/owner/owner_gateway.dart';
import 'package:homizi/features/owner/owner_models.dart';
import 'package:homizi/features/owner/owner_rules.dart';

void main() {
  test('lead words, response time, and visible copy omit contact', () {
    expect(ownerLeadStatusLabel('new'), 'New');
    expect(ownerLeadStatusLabel('replied'), 'Replied');
    expect(ownerLeadStatusLabel('closed'), 'Closed');
    expect(ownerLeadKindLabel('interest'), 'Interest');
    expect(ownerLeadKindLabel('visit'), 'Visit request');
    expect(isOwnerLeadStatus('closed'), isTrue);
    expect(isOwnerLeadStatus('won'), isFalse);
    expect(ownerActionError('not_found'), contains('lead'));

    final created = DateTime.utc(2026, 10, 20, 8);
    final replied = OwnerLead(
      id: 'l1',
      propertyId: 'p1',
      kind: 'interest',
      status: 'replied',
      personUserId: 'tenant-1',
      displayName: 'Meera K.',
      createdAt: created,
      firstRepliedAt: created.add(const Duration(hours: 2)),
      responseMinutes: 120,
      audit: [
        OwnerLeadAudit(
          actorId: 'host-1',
          fromStatus: 'new',
          toStatus: 'replied',
          changedAt: created.add(const Duration(hours: 2)),
        ),
      ],
    );
    expect(ownerLeadResponseLabel(replied), 'Replied in 2 h');
    expect(
      ownerLeadAuditLabel(replied.audit.single),
      'You set this to Replied',
    );

    final quick = replied.copyWith(responseMinutes: 0);
    expect(ownerLeadResponseLabel(quick), 'Replied in under 1 minute');
    expect(
      ownerLeadResponseLabel(replied.copyWith(responseMinutes: 45)),
      'Replied in 45 min',
    );
    expect(
      ownerLeadResponseLabel(replied.copyWith(keepResponseMinutes: false)),
      'Replied in 2 h',
    );

    final waiting = OwnerLead(
      id: 'l2',
      propertyId: 'p1',
      kind: 'visit',
      status: 'new',
      personUserId: 'tenant-2',
      displayName: 'Arjun P.',
      createdAt: created,
    );
    expect(ownerLeadResponseLabel(waiting), 'Not replied yet');
    expect(waiting.nameLabel, 'Arjun P.');
    expect(
      OwnerLead(
        id: 'l3',
        propertyId: 'p1',
        kind: 'interest',
        status: 'new',
        personUserId: 'tenant-3',
        displayName: '  ',
        createdAt: DateTime.utc(2026, 10, 20),
      ).nameLabel,
      'A tenant',
    );
  });

  test('lead json keeps the inbox fields and drops contact keys', () {
    final lead = ownerLeadsFromPayload({
      'ok': true,
      'leads': [
        {
          'id': 'l1',
          'property_id': 'p1',
          'kind': 'interest',
          'status': 'replied',
          'person_user_id': 'tenant-1',
          'display_name': 'Meera K.',
          'created_at': '2026-10-20T08:00:00Z',
          'first_replied_at': '2026-10-20T10:00:00Z',
          'response_minutes': 120,
          'phone': '+919800011122',
          'email': 'meera@example.test',
          'address_line': '12 CG Road, Navrangpura',
          'landmark': 'Near Law Garden',
          'audit': [
            {
              'actor_id': 'host-1',
              'from_status': 'new',
              'to_status': 'replied',
              'changed_at': '2026-10-20T10:00:00Z',
              'phone': '+919800011122',
              'email': 'meera@example.test',
            },
          ],
        },
      ],
    }).single;
    final copy = ownerLeadVisibleCopy(lead);
    expect(copy, contains('Meera K.'));
    expect(copy, contains('Interest'));
    expect(copy, contains('Replied'));
    expect(copy, contains('Replied in 2 h'));
    expect(copy, contains('You set this to Replied'));
    expect(copy, isNot(contains('+919800011122')));
    expect(copy, isNot(contains('meera@example.test')));
    expect(copy, isNot(contains('12 CG Road')));
    expect(copy, isNot(contains('Law Garden')));
    expect(copy, isNot(contains('NoBroker')));
    expect(lead.audit.single.actorId, 'host-1');
    expect(lead.audit.single.fromStatus, 'new');
  });

  test('demo owner marks a lead and keeps the first response time', () async {
    final gateway = DemoOwnerGateway(DemoListingMemory(seed: demoOwnerSeed()));
    final leads = await gateway.leads('demo-own-koramangala');
    expect(leads, hasLength(2));
    expect(await gateway.leads('demo-own-baner'), isEmpty);

    final interest = leads.firstWhere((lead) => lead.kind == 'interest');
    final visit = leads.firstWhere((lead) => lead.kind == 'visit');
    expect(interest.status, 'new');
    expect(ownerLeadResponseLabel(interest), 'Not replied yet');
    expect(ownerLeadVisibleCopy(interest), isNot(contains('@')));
    expect(ownerLeadVisibleCopy(interest), isNot(contains('+91')));

    final replied = await gateway.setLeadStatus(interest.id, 'replied');
    expect(replied.status, 'replied');
    expect(replied.firstRepliedAt, isNotNull);
    expect(replied.responseMinutes, isNotNull);
    expect(ownerLeadResponseLabel(replied), contains('Replied in'));
    expect(replied.audit.single.actorId, 'demo-owner');
    expect(replied.audit.single.fromStatus, 'new');
    expect(replied.audit.single.toStatus, 'replied');

    final again = await gateway.setLeadStatus(interest.id, 'replied');
    expect(again.firstRepliedAt, replied.firstRepliedAt);
    expect(again.audit, hasLength(1));

    final closed = await gateway.setLeadStatus(interest.id, 'closed');
    expect(closed.status, 'closed');
    expect(closed.firstRepliedAt, replied.firstRepliedAt);
    expect(closed.audit, hasLength(2));

    final reopened = await gateway.setLeadStatus(interest.id, 'replied');
    expect(reopened.firstRepliedAt, replied.firstRepliedAt);
    expect(reopened.audit, hasLength(3));
    expect(ownerLeadResponseLabel(reopened), contains('Replied in'));

    final visitClosed = await gateway.setLeadStatus(visit.id, 'closed');
    expect(visitClosed.firstRepliedAt, isNull);
    expect(ownerLeadResponseLabel(visitClosed), 'Not replied yet');
    expect(visitClosed.audit.single.toStatus, 'closed');

    await expectLater(
      gateway.leads('not-a-home'),
      throwsA(
        isA<OwnerFailure>().having(
          (error) => error.message,
          'message',
          contains('own listing'),
        ),
      ),
    );
    await expectLater(
      gateway.setLeadStatus('missing-lead', 'replied'),
      throwsA(
        isA<OwnerFailure>().having(
          (error) => error.message,
          'message',
          contains('lead'),
        ),
      ),
    );
    await expectLater(
      gateway.setLeadStatus(interest.id, 'won'),
      throwsA(isA<OwnerFailure>()),
    );
  });
}
