import 'package:homizi/core/network/offline_failure.dart';
import 'package:homizi/features/support/domain/faq_catalog.dart';
import 'package:homizi/features/support/support_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseSupportGateway implements SupportGateway {
  SupabaseSupportGateway(this._client);

  final SupabaseClient _client;

  @override
  Future<List<SupportTicket>> loadMine() async {
    final user = _user();
    final rows = await _guard(
      () => _client
          .from('support_tickets')
          .select('id, topic, message, created_at')
          .eq('user_id', user.id)
          .order('created_at', ascending: false),
    );
    return [for (final row in rows) _ticket(_asMap(row))];
  }

  @override
  Future<SupportTicket> submit({
    required String topic,
    required String message,
  }) async {
    final user = _user();
    if (!supportTopics.contains(topic)) {
      throw const SupportFailure('Choose a topic.');
    }
    final error = supportMessageError(message);
    if (error != null) {
      throw SupportFailure(error);
    }
    final inserted = await _guard(
      () => _client
          .from('support_tickets')
          .insert({
            'user_id': user.id,
            'topic': topic,
            'message': message.trim(),
          })
          .select('id, topic, message, created_at')
          .single(),
    );
    return _ticket(_asMap(inserted));
  }

  User _user() {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const SupportFailure('Sign in before contacting support.');
    }
    return user;
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on SupportFailure {
      rethrow;
    } on PostgrestException catch (error) {
      throw SupportFailure(_safe(error.message));
    } catch (error) {
      throw SupportFailure(describedFailure(error));
    }
  }
}

Map<String, dynamic> _asMap(Object? raw) {
  if (raw is Map<String, dynamic>) {
    return raw;
  }
  if (raw is Map) {
    return raw.map((key, value) => MapEntry(key.toString(), value));
  }
  throw const SupportFailure('The support reply was not readable.');
}

SupportTicket _ticket(Map<String, dynamic> row) {
  final id = row['id'];
  final topic = row['topic'];
  final message = row['message'];
  if (id is! String || topic is! String || message is! String) {
    throw const SupportFailure('The support reply was not readable.');
  }
  return SupportTicket(
    id: id,
    topic: topic,
    message: message,
    createdAt:
        DateTime.tryParse('${row['created_at']}') ?? DateTime.now().toUtc(),
  );
}

String _safe(String message) {
  final trimmed = message.trim();
  if (trimmed.isEmpty ||
      trimmed.length > 180 ||
      trimmed.contains('@') ||
      trimmed.contains('+91')) {
    return 'The support note could not be saved.';
  }
  return trimmed;
}
