import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/core/widgets/state_views.dart';
import 'package:homizi/features/roommates/finder/finder_catalog.dart';
import 'package:homizi/features/shell/min_touch.dart';

class RoommateMatchScreen extends StatelessWidget {
  const RoommateMatchScreen({
    required this.personId,
    this.mutual = true,
    super.key,
  });

  final String personId;
  final bool mutual;

  @override
  Widget build(BuildContext context) {
    final person = finderPersonById(personId);
    final theme = Theme.of(context);
    final name = person?.name ?? 'your roommate';
    final photo = person?.seeker.photoRef;
    return MinTouchScope(
      child: Scaffold(
        key: Key(mutual ? 'roommate-match' : 'roommate-sent'),
        backgroundColor: HomiziColors.white,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: const HomiziBackButton(),
          backgroundColor: HomiziColors.white,
          surfaceTintColor: HomiziColors.white,
        ),
        body: RepaintBoundary(
          key: const Key('roommate-match-shot'),
          child: Material(
            color: HomiziColors.white,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 12),
                Center(
                  child: CircleAvatar(
                    radius: 56,
                    backgroundColor: HomiziColors.soft,
                    backgroundImage: photo == null ? null : AssetImage(photo),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  homiziText(
                    context,
                    mutual ? "It's a match" : 'Interest sent',
                  ),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: HomiziColors.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  homiziText(
                    context,
                    mutual
                        ? 'You and $name both want to find a home together. Contact stays hidden until you each choose to share it.'
                        : 'Your interest is with $name. A match appears when they are interested too. Contact stays hidden.',
                  ),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: HomiziColors.ink,
                  ),
                ),
                const SizedBox(height: 24),
                if (mutual && person != null)
                  FilledButton(
                    key: const Key('roommate-open-chat'),
                    style: FilledButton.styleFrom(
                      backgroundColor: HomiziColors.logoOrange,
                      foregroundColor: HomiziColors.ink,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: () => context.push(
                      RoutePaths.chat(
                        'roommate-${person.id}',
                        name: person.name,
                        title: 'Roommate',
                        otherUserId: person.id,
                        avatar: person.seeker.photoRef,
                      ),
                    ),
                    child: Text(homiziText(context, 'Say hello')),
                  )
                else
                  FilledButton(
                    key: const Key('roommate-sent-done'),
                    style: FilledButton.styleFrom(
                      backgroundColor: HomiziColors.logoOrange,
                      foregroundColor: HomiziColors.ink,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: () => context.go(RoutePaths.roommate),
                    child: Text(homiziText(context, 'Back to roommates')),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RoommateMaybeScreen extends StatelessWidget {
  const RoommateMaybeScreen({required this.personId, super.key});

  final String personId;

  @override
  Widget build(BuildContext context) {
    final person = finderPersonById(personId);
    final name = person?.name ?? 'This roommate';
    final photo = person?.seeker.photoRef;
    final theme = Theme.of(context);
    return RepaintBoundary(
      key: const Key('roommate-maybe-shot'),
      child: MinTouchScope(
        child: Scaffold(
          key: const Key('roommate-maybe'),
          backgroundColor: HomiziColors.white,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            leading: const HomiziBackButton(),
            backgroundColor: HomiziColors.white,
            surfaceTintColor: HomiziColors.white,
          ),
          body: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 12),
              Center(
                child: CircleAvatar(
                  radius: 56,
                  backgroundColor: HomiziColors.soft,
                  backgroundImage: photo == null ? null : AssetImage(photo),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                homiziText(context, 'Saved as Maybe'),
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: HomiziColors.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                homiziText(
                  context,
                  '$name is saved as Maybe. This is not a match, and contact stays hidden.',
                ),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: HomiziColors.ink,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                key: const Key('roommate-maybe-done'),
                style: FilledButton.styleFrom(
                  backgroundColor: HomiziColors.logoOrange,
                  foregroundColor: HomiziColors.ink,
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: () => context.go(RoutePaths.roommate),
                child: Text(homiziText(context, 'Back to roommates')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RoommateRequirementsSavedScreen extends StatelessWidget {
  const RoommateRequirementsSavedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MinTouchScope(
      child: Scaffold(
        key: const Key('roommate-requirements-saved'),
        backgroundColor: HomiziColors.white,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: const HomiziBackButton(),
          backgroundColor: HomiziColors.white,
        ),
        body: EmptyState(
          title: 'Requirements saved',
          message:
              'Your roommate preferences are saved on this device and used for compatibility. Contact is not shared.',
          actionLabel: 'Back to Roommate Finder',
          onAction: () => context.go(RoutePaths.roommate),
        ),
      ),
    );
  }
}
