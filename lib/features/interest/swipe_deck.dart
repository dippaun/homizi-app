import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:homizi/core/l10n/translate.dart';

/// Horizontal swipe surface shared by home cards and roommate cards.
///
/// Drag right to like and left to pass. Like and pass stay off the screen.
/// [showUndo] keeps the existing undo control on the home deck.
class SwipeDeck extends StatelessWidget {
  const SwipeDeck({
    required this.card,
    required this.dx,
    required this.busy,
    required this.note,
    required this.canUndo,
    required this.likeLabel,
    required this.passLabel,
    required this.onDrag,
    required this.onRelease,
    required this.onLike,
    required this.onPass,
    required this.onUndo,
    this.showUndo = true,
    this.cardKey = const Key('swipe-card'),
    this.undoKey = const Key('swipe-undo'),
    super.key,
  });

  final Widget card;
  final double dx;
  final bool busy;
  final String? note;
  final bool canUndo;
  final String likeLabel;
  final String passLabel;
  final ValueChanged<double> onDrag;
  final VoidCallback onRelease;
  final VoidCallback onLike;
  final VoidCallback onPass;
  final VoidCallback onUndo;
  final bool showUndo;
  final Key cardKey;
  final Key undoKey;

  @override
  Widget build(BuildContext context) {
    final undo = showUndo && canUndo;
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (busy || event is! KeyDownEvent) {
          return KeyEventResult.ignored;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          onLike();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          onPass();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.keyZ && undo) {
          onUndo();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Semantics(
        customSemanticsActions: {
          CustomSemanticsAction(label: likeLabel): onLike,
          CustomSemanticsAction(label: passLabel): onPass,
          if (undo)
            const CustomSemanticsAction(label: 'Undo last swipe'): onUndo,
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            children: [
              Expanded(
                child: GestureDetector(
                  key: cardKey,
                  onHorizontalDragUpdate: busy
                      ? null
                      : (details) => onDrag(details.delta.dx),
                  onHorizontalDragEnd: busy ? null : (_) => onRelease(),
                  child: Transform.translate(
                    offset: Offset(dx, 0),
                    child: Transform.rotate(angle: dx / 1400, child: card),
                  ),
                ),
              ),
              if (showUndo) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton.icon(
                      key: undoKey,
                      onPressed: undo ? onUndo : null,
                      icon: const Icon(Icons.undo),
                      label: Text(homiziText(context, 'Undo')),
                    ),
                    const Spacer(),
                    if (note != null)
                      Flexible(
                        child: Text(
                          homiziText(context, note!),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
