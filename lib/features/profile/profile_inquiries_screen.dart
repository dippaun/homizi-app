import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/core/widgets/state_views.dart';
import 'package:homizi/features/profile/domain/profile_activity.dart';
import 'package:homizi/features/profile/profile_hub_gateway.dart';
import 'package:homizi/features/profile/profile_hub_providers.dart';

/// Inquiries counted on the profile stats row.
///
/// The list is the same request rows [ProfileActivity] already loads. There
/// is no separate inquiries screen elsewhere.
class ProfileInquiriesScreen extends ConsumerStatefulWidget {
  const ProfileInquiriesScreen({super.key});

  @override
  ConsumerState<ProfileInquiriesScreen> createState() =>
      _ProfileInquiriesScreenState();
}

class _ProfileInquiriesScreenState
    extends ConsumerState<ProfileInquiriesScreen> {
  ProfileActivity? _activity;
  String? _error;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final activity = await ref.read(profileHubGatewayProvider).loadActivity();
      if (!mounted) {
        return;
      }
      setState(() {
        _activity = activity;
        _loading = false;
      });
    } on ProfileHubFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Inquiries did not load.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final activity = _activity;
    return Scaffold(
      key: const Key('profile-inquiries-screen'),
      backgroundColor: HomiziColors.soft,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: HomiziColors.white,
        surfaceTintColor: HomiziColors.white,
        leading: const HomiziBackButton(),
        title: Text(
          homiziText(context, 'Inquiries'),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: HomiziColors.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: _loading
          ? const LoadingState(message: 'Opening inquiries…')
          : _error != null
          ? ErrorState(
              title: 'Inquiries did not load',
              message: _error!,
              onRetry: () => unawaited(_load()),
            )
          : activity == null || activity.requests.isEmpty
          ? const EmptyState(
              title: 'No inquiries yet',
              message:
                  'When someone asks about a home, or you send a request, it shows up here.',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: activity.requests.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final request = activity.requests[index];
                final budget =
                    '${formatInr(request.budgetMinInr)} – ${formatInr(request.budgetMaxInr)}';
                return Material(
                  color: HomiziColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: HomiziColors.line),
                  ),
                  child: ListTile(
                    key: Key('profile-inquiry-$index'),
                    leading: const Icon(
                      Icons.mail_outline,
                      color: HomiziColors.logoOrange,
                    ),
                    title: Text(
                      homiziText(context, request.city),
                      style: const TextStyle(
                        color: HomiziColors.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    subtitle: Text(
                      homiziText(context, budget),
                      style: const TextStyle(color: HomiziColors.inkSoft),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
