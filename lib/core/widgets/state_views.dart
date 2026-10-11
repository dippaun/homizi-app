import 'package:flutter/material.dart';
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
          'Preview state',
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(color: HomiziColors.warning),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final value in ViewStatus.values)
              ChoiceChip(
                key: Key('preview-${value.name}'),
                label: Text(value.label),
                selected: value == status,
                onSelected: (_) => onChanged(value),
              ),
          ],
        ),
      ],
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
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
          ],
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
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inbox_outlined, size: 40, color: HomiziColors.ink),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
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
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 40,
              color: HomiziColors.clay,
            ),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('retry-button'),
              onPressed: onRetry,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
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
