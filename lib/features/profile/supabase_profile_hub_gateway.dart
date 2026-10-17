import 'package:homizi/core/network/offline_failure.dart';
import 'package:homizi/features/profile/domain/profile_activity.dart';
import 'package:homizi/features/profile/profile_hub_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseProfileHubGateway implements ProfileHubGateway {
  SupabaseProfileHubGateway(this._client);

  final SupabaseClient _client;

  @override
  Future<ProfileActivity> loadActivity() async {
    if (_client.auth.currentUser == null) {
      throw const ProfileHubFailure('Sign in before opening your profile.');
    }
    try {
      final raw = await _client.rpc<dynamic>('profile_activity');
      return profileActivityFromJson(raw);
    } on ProfileHubFailure {
      rethrow;
    } on PostgrestException catch (error) {
      throw ProfileHubFailure(_safe(error.message));
    } catch (error) {
      throw ProfileHubFailure(describedFailure(error));
    }
  }
}

String _safe(String message) {
  final trimmed = message.trim();
  if (trimmed.isEmpty ||
      trimmed.length > 180 ||
      trimmed.contains('@') ||
      trimmed.contains('+91')) {
    return 'Profile activity could not be loaded.';
  }
  return trimmed;
}
