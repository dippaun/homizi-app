import 'package:flutter/material.dart';
import 'package:homizi/core/brand/homizi_mark.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/network/offline_failure.dart';
import 'package:homizi/core/theme/homizi_colors.dart';

enum ViewStatus { ready, loading, empty, error }

extension ViewStatusLabel on ViewStatus {
  String get label => switch (this) {
    ViewStatus.ready => 'Content',
    ViewStatus.loading => 'Loading',
    ViewStatus.empty => 'Empty',
    ViewStatus.error => 'Error',
  };
}

class StatePreviewBar extends StatelessWidget {
  const StatePreviewBar({
    required this.status,
    required this.onChanged,
    super.key,
  });

  final ViewStatus status;
  final ValueChanged<ViewStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          homiziText(context, 'Preview state'),
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: 8),
        SegmentedButton<ViewStatus>(
          showSelectedIcon: false,
          segments: [
            for (final value in ViewStatus.values)
              ButtonSegment<ViewStatus>(
                value: value,
                label: Text(
                  homiziText(context, value.label),
                  key: Key('preview-${value.name}'),
                ),
              ),
          ],
          selected: {status},
          onSelectionChanged: (next) => onChanged(next.first),
        ),
      ],
    );
  }
}

class OfflineNote extends StatelessWidget {
  const OfflineNote({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Card.filled(
        child: ListTile(
          leading: const Icon(Icons.cloud_off_outlined),
          title: Text(homiziText(context, offlineMessage)),
        ),
      ),
    );
  }
}

class LoadingState extends StatelessWidget {
  const LoadingState({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('loading-state'),
      child: _SettleIn(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const HomiziMark(size: 56),
              const SizedBox(height: 20),
              const SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(strokeWidth: 4),
              ),
              const SizedBox(height: 16),
              Text(homiziText(context, message), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('empty-state'),
      child: _SettleIn(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const HomiziMark(size: 64),
              const SizedBox(height: 16),
              Text(
                homiziText(context, title),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(homiziText(context, message), textAlign: TextAlign.center),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: onAction,
                  child: Text(homiziText(context, actionLabel!)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({
    required this.title,
    required this.message,
    required this.onRetry,
    super.key,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('error-state'),
      child: _SettleIn(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                size: 40,
                color: HomiziColors.accent,
              ),
              const SizedBox(height: 12),
              Text(
                homiziText(context, title),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(homiziText(context, message), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('retry-button'),
                onPressed: onRetry,
                child: Text(homiziText(context, 'Try again')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Short scale-in that finishes, so it does not block a settled frame.
class _SettleIn extends StatelessWidget {
  const _SettleIn({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.96, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: child,
    );
  }
}

class AsyncStateBody extends StatelessWidget {
  const AsyncStateBody({
    required this.status,
    required this.loadingMessage,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.errorTitle,
    required this.errorMessage,
    required this.onRetry,
    required this.child,
    this.emptyActionLabel,
    this.onEmptyAction,
    super.key,
  });

  final ViewStatus status;
  final String loadingMessage;
  final String emptyTitle;
  final String emptyMessage;
  final String errorTitle;
  final String errorMessage;
  final VoidCallback onRetry;
  final Widget child;
  final String? emptyActionLabel;
  final VoidCallback? onEmptyAction;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      ViewStatus.loading => LoadingState(message: loadingMessage),
      ViewStatus.empty => EmptyState(
        title: emptyTitle,
        message: emptyMessage,
        actionLabel: emptyActionLabel,
        onAction: onEmptyAction,
      ),
      ViewStatus.error => ErrorState(
        title: errorTitle,
        message: errorMessage,
        onRetry: onRetry,
      ),
      ViewStatus.ready => child,
    };
  }
}
