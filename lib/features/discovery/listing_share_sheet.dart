import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/discovery/listing_share_web.dart'
    if (dart.library.io) 'package:homizi/features/discovery/listing_share_stub.dart';
import 'package:url_launcher/url_launcher.dart';

/// Public listing link. Hash routing matches the GitHub Pages app.
String listingShareLink(String listingId) {
  final base = Uri.base;
  final origin = base.hasScheme && base.host.isNotEmpty
      ? base.origin
      : 'https://dippaun.github.io';
  var path = base.path;
  if (path.isEmpty) {
    path = '/homizi-app/';
  }
  if (!path.endsWith('/')) {
    path = '$path/';
  }
  return '$origin$path#/listing/$listingId';
}

Future<void> showListingShareSheet({
  required BuildContext context,
  required String listingId,
  required String title,
  required String place,
}) async {
  final link = listingShareLink(listingId);
  final text = '$title\n$place\n$link';
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: HomiziColors.clear,
    builder: (context) {
      return _ShareSheet(title: title, text: text, link: link);
    },
  );
}

class _ShareSheet extends StatelessWidget {
  const _ShareSheet({
    required this.title,
    required this.text,
    required this.link,
  });

  final String title;
  final String text;
  final String link;

  Future<void> _open(BuildContext context, Uri uri) async {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      await _copy(context);
    }
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: link));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(homiziText(context, 'Link copied'))));
  }

  @override
  Widget build(BuildContext context) {
    final actions = <_ShareAction>[
      _ShareAction(
        label: 'Copy link',
        icon: Icons.link,
        onTap: () => _copy(context),
      ),
      _ShareAction(
        label: 'WhatsApp',
        icon: Icons.chat,
        onTap: () => _open(
          context,
          Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}'),
        ),
      ),
      _ShareAction(
        label: 'Instagram',
        icon: Icons.photo_camera_outlined,
        onTap: () async {
          await _copy(context);
          if (!context.mounted) {
            return;
          }
          await _open(context, Uri.parse('https://www.instagram.com/'));
        },
      ),
      _ShareAction(
        label: 'Telegram',
        icon: Icons.send_outlined,
        onTap: () => _open(
          context,
          Uri.parse(
            'https://t.me/share/url?url=${Uri.encodeComponent(link)}&text=${Uri.encodeComponent(title)}',
          ),
        ),
      ),
      _ShareAction(
        label: 'Email',
        icon: Icons.mail_outline,
        onTap: () => _open(
          context,
          Uri(
            scheme: 'mailto',
            queryParameters: {'subject': title, 'body': text},
          ),
        ),
      ),
      _ShareAction(
        label: 'SMS',
        icon: Icons.sms_outlined,
        onTap: () =>
            _open(context, Uri(scheme: 'sms', queryParameters: {'body': text})),
      ),
      _ShareAction(
        label: 'X',
        icon: Icons.tag,
        onTap: () => _open(
          context,
          Uri.parse(
            'https://twitter.com/intent/tweet?text=${Uri.encodeComponent(text)}',
          ),
        ),
      ),
      _ShareAction(
        label: 'More',
        icon: Icons.ios_share,
        onTap: () async {
          final shared = await shareWithDevice(
            title: title,
            text: text,
            url: link,
          );
          if (!shared && context.mounted) {
            await _copy(context);
          }
        },
      ),
    ];
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: HomiziColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: HomiziColors.line,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                homiziText(context, 'Share this home'),
                key: const Key('listing-share-dialog'),
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  color: HomiziColors.ink,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: HomiziColors.inkSoft),
              ),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                children: [
                  for (final action in actions) _ShareTile(action: action),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShareAction {
  const _ShareAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

class _ShareTile extends StatelessWidget {
  const _ShareTile({required this.action});

  final _ShareAction action;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        final navigator = Navigator.of(context);
        action.onTap();
        if (navigator.canPop()) {
          navigator.pop();
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          DecoratedBox(
            decoration: const BoxDecoration(
              color: HomiziColors.soft,
              shape: BoxShape.circle,
            ),
            child: SizedBox(
              width: 52,
              height: 52,
              child: Icon(action.icon, color: HomiziColors.logoOrange),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            homiziText(context, action.label),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: HomiziColors.ink,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
