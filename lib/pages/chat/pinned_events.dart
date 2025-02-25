import 'dart:async';

import 'package:flutter/material.dart';

import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:matrix/matrix.dart';

import 'package:fluffychat/config/app_config.dart';
import 'package:fluffychat/pages/chat/chat.dart';
import 'package:fluffychat/utils/matrix_sdk_extensions/matrix_locals.dart';
import 'package:fluffychat/utils/url_launcher.dart';

class PinnedEvents extends StatelessWidget {
  final ChatController controller;

  const PinnedEvents(this.controller, {super.key});

  Future<void> _displayPinnedEventsDialog(
    BuildContext context,
    List<Event?> events,
  ) async {
    final eventId = events.length == 1
        ? events.single?.eventId
        : await showConfirmationDialog<String>(
            context: context,
            title: L10n.of(context)!.pinMessage,
            actions: events
                .map(
                  (event) => AlertDialogAction(
                    key: event?.eventId ?? '',
                    label: event?.calcLocalizedBodyFallback(
                          MatrixLocals(L10n.of(context)!),
                          withSenderNamePrefix: true,
                          hideReply: true,
                        ) ??
                        'UNKNOWN',
                  ),
                )
                .toList(),
          );

    if (eventId != null) controller.scrollToEventId(eventId);
  }

  @override
  Widget build(BuildContext context) {
    final pinnedEventIds = controller.room.pinnedEventIds;

    if (pinnedEventIds.isEmpty) {
      return const SizedBox.shrink();
    }
    final completers = pinnedEventIds.map<Completer<Event?>>((e) {
      final completer = Completer<Event?>();
      controller.room
          .getEventById(e)
          .then((value) => completer.complete(value));
      return completer;
    });
    return FutureBuilder<List<Event?>>(
      future: Future.wait(completers.map((e) => e.future).toList()),
      builder: (context, snapshot) {
        final pinnedEvents = snapshot.data;
        final event = (pinnedEvents != null && pinnedEvents.isNotEmpty)
            ? snapshot.data?.last
            : null;

        if (event == null || pinnedEvents == null) {
          return Container();
        }

        final fontSize = AppConfig.messageFontSize * AppConfig.fontSizeFactor;
        return Material(
          color: Theme.of(context).colorScheme.surfaceVariant,
          shape: Border(
            bottom: BorderSide(
              width: 1,
              color: Theme.of(context).dividerColor,
            ),
          ),
          child: InkWell(
            onTap: () => _displayPinnedEventsDialog(
              context,
              pinnedEvents,
            ),
            child: Row(
              children: [
                IconButton(
                  splashRadius: 20,
                  iconSize: 20,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  icon: const Icon(Icons.push_pin),
                  tooltip: L10n.of(context)!.unpin,
                  onPressed:
                      controller.room.canSendEvent(EventTypes.RoomPinnedEvents)
                          ? () => controller.unpinEvent(event.eventId)
                          : null,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: FutureBuilder<String>(
                      future: event.calcLocalizedBody(
                        MatrixLocals(L10n.of(context)!),
                        withSenderNamePrefix: true,
                        hideReply: true,
                      ),
                      builder: (context, snapshot) {
                        return Linkify(
                          text: snapshot.data ??
                              event.calcLocalizedBodyFallback(
                                MatrixLocals(L10n.of(context)!),
                                withSenderNamePrefix: true,
                                hideReply: true,
                              ),
                          options: const LinkifyOptions(humanize: false),
                          maxLines: 2,
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            overflow: TextOverflow.ellipsis,
                            fontSize: fontSize,
                            decoration: event.redacted
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                          linkStyle: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: fontSize,
                            decoration: TextDecoration.underline,
                            decorationColor:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          onOpen: (url) =>
                              UrlLauncher(context, url.url).launchUrl(),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
