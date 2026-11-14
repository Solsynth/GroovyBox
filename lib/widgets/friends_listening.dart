import 'package:easy_localization/easy_localization.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/pulsar/models.dart';
import 'package:groovy_box/pulsar/providers.dart';
import 'package:groovy_box/screens/explore.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// What the account's friends are listening to, right now.
///
/// One row per friend with a live presence activity: avatar, name, and the
/// track their player reported. Data comes from Stargate's friends overview,
/// which already merges each friend's live Pulsar session, so this widget
/// only renders and refreshes.
class FriendsListeningShelf extends ConsumerWidget {
  const FriendsListeningShelf({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friends = ref.watch(friendListeningFeedProvider);
    return friends.when(
      data: (list) => list.isEmpty
          ? const SizedBox.shrink()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LibrarySectionHeader(title: 'friendsListeningTitle'.tr()),
                for (final friend in list) _FriendRow(friend: friend),
              ],
            ),
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

/// One friend, one row: who and what.
class _FriendRow extends StatelessWidget {
  final FriendListening friend;

  const _FriendRow({required this.friend});

  @override
  Widget build(BuildContext context) {
    final activity = friend.nowPlaying!;
    final avatar = friend.account.avatarUrl;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SolSpace.xs),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: avatar != null && avatar.isNotEmpty
                ? CircleAvatar(
                    backgroundImage: NetworkImage(avatar),
                    onBackgroundImageError: (_, _) {},
                  )
                : CircleAvatar(
                    child: Text(
                      friend.account.displayName.isEmpty
                          ? '?'
                          : friend.account.displayName[0].toUpperCase(),
                    ),
                  ),
          ),
          const SizedBox(width: SolSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  friend.account.displayName,
                  style: Theme.of(context).textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  [
                    if (activity.title != null && activity.title!.isNotEmpty)
                      activity.title!,
                    if (activity.subtitle != null &&
                        activity.subtitle!.isNotEmpty)
                      activity.subtitle!,
                  ].join(' · '),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(
            Symbols.graphic_eq_rounded,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }
}
