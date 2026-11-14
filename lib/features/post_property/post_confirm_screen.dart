import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/listings/domain/listing_draft.dart';
import 'package:homizi/features/post_property/partner_application.dart';
import 'package:homizi/features/post_property/post_property_chrome.dart';

class OwnerPostOutcome {
  const OwnerPostOutcome({
    required this.draft,
    required this.verifyLater,
    required this.serverPublished,
  });

  final ListingDraft draft;
  final bool verifyLater;
  final bool serverPublished;
}

class OwnerPostOutcomeController extends Notifier<OwnerPostOutcome?> {
  @override
  OwnerPostOutcome? build() => null;

  void set(OwnerPostOutcome? next) => state = next;
}

final ownerPostOutcomeProvider =
    NotifierProvider<OwnerPostOutcomeController, OwnerPostOutcome?>(
      OwnerPostOutcomeController.new,
    );

class OwnerPostedScreen extends ConsumerWidget {
  const OwnerPostedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outcome = ref.watch(ownerPostOutcomeProvider);
    final draft = outcome?.draft;
    final title = draft == null || draft.title.trim().isEmpty
        ? 'Your property'
        : draft.title.trim();
    final place = [
      if (draft != null && draft.locality.trim().isNotEmpty)
        draft.locality.trim(),
      if (draft != null && draft.city.trim().isNotEmpty) draft.city.trim(),
    ].join(', ');
    return PostPropertyPage(
      pageKey: const Key('post-owner-done'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        children: [
          const Icon(Icons.check_circle, size: 64, color: HomiziColors.success),
          const SizedBox(height: 12),
          Text(
            homiziText(context, 'Listing published'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              color: HomiziColors.ink,
              fontWeight: FontWeight.w800,
              fontSize: 26,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            homiziText(context, title),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: HomiziColors.ink,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          if (place.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              place,
              textAlign: TextAlign.center,
              style: const TextStyle(color: HomiziColors.inkSoft),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            homiziText(
              context,
              outcome?.serverPublished == true
                  ? 'Your listing is live and appears in search.'
                  : 'This home is on this device and shows in search here. The server did not publish this listing.',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(color: HomiziColors.inkSoft, height: 1.35),
          ),
          if (outcome?.verifyLater != false) ...[
            const SizedBox(height: 12),
            const PostTrustPill(
              text:
                  'Verify later. Your listing can go live before the document check finishes.',
            ),
          ],
          const SizedBox(height: 20),
          PostGradientButton(
            buttonKey: const Key('post-go-dashboard'),
            label: 'Go to Dashboard',
            showArrow: false,
            onPressed: () => context.go(RoutePaths.ownerDashboard),
          ),
          const SizedBox(height: 8),
          TextButton(
            key: const Key('post-back-home'),
            onPressed: () => context.go(RoutePaths.home),
            child: Text(
              homiziText(context, 'Back to Home'),
              style: const TextStyle(
                color: HomiziColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PartnerSuccessScreen extends ConsumerWidget {
  const PartnerSuccessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final application = ref.watch(partnerApplicationProvider);
    final id = application.applicationId.trim().isEmpty
        ? 'PP----------'
        : application.applicationId;
    return PostPropertyPage(
      pageKey: const Key('post-partner-success'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
        children: [
          const Icon(
            Icons.check_circle,
            key: Key('post-success-check'),
            size: 72,
            color: HomiziColors.success,
          ),
          const SizedBox(height: 12),
          Text(
            homiziText(context, 'Registration Successful!'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              color: HomiziColors.ink,
              fontWeight: FontWeight.w800,
              fontSize: 26,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            homiziText(
              context,
              application.savedOnServer
                  ? 'Your partner application is saved on your account.'
                  : 'Your partner application is saved on this device. It will sync when the partner table is live.',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(color: HomiziColors.inkSoft, height: 1.35),
          ),
          const SizedBox(height: 16),
          DecoratedBox(
            decoration: BoxDecoration(
              color: HomiziColors.homiziLavender,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          homiziText(context, 'Application ID'),
                          style: const TextStyle(
                            color: HomiziColors.inkSoft,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          id,
                          key: const Key('post-application-id'),
                          style: const TextStyle(
                            color: HomiziColors.ink,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const Key('post-copy-id'),
                    tooltip: homiziText(context, 'Copy'),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: id));
                      if (!context.mounted) {
                        return;
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            homiziText(context, 'Application ID copied'),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.copy,
                      color: HomiziColors.logoOrange,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          PostGradientButton(
            buttonKey: const Key('post-go-dashboard'),
            label: 'Go to Dashboard',
            showArrow: false,
            onPressed: () => context.go(RoutePaths.postPartnerHome),
          ),
          const SizedBox(height: 8),
          TextButton(
            key: const Key('post-back-home'),
            onPressed: () => context.go(RoutePaths.home),
            child: Text(
              homiziText(context, 'Back to Home'),
              style: const TextStyle(
                color: HomiziColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
