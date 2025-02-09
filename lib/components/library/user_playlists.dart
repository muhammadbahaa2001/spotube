import 'package:flutter/material.dart' hide Image;
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fuzzywuzzy/fuzzywuzzy.dart';
import 'package:collection/collection.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:spotify/spotify.dart';
import 'package:spotube/collections/spotube_icons.dart';
import 'package:spotube/components/playlist/playlist_create_dialog.dart';
import 'package:spotube/components/shared/shimmers/shimmer_playbutton_card.dart';
import 'package:spotube/components/shared/fallbacks/anonymous_fallback.dart';
import 'package:spotube/components/playlist/playlist_card.dart';
import 'package:spotube/components/shared/waypoint.dart';
import 'package:spotube/extensions/context.dart';
import 'package:spotube/provider/authentication_provider.dart';
import 'package:spotube/services/queries/queries.dart';

class UserPlaylists extends HookConsumerWidget {
  const UserPlaylists({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, ref) {
    final searchText = useState('');

    final auth = ref.watch(AuthenticationNotifier.provider);

    final playlistsQuery = useQueries.playlist.ofMine(ref);

    final pagePlaylists = useMemoized(
      () => playlistsQuery.pages
          .expand((page) => page.items?.toList() ?? <PlaylistSimple>[]),
      [playlistsQuery.pages],
    );

    final likedTracksPlaylist = useMemoized(
        () => PlaylistSimple()
          ..name = context.l10n.liked_tracks
          ..description = context.l10n.liked_tracks_description
          ..type = "playlist"
          ..collaborative = false
          ..public = false
          ..id = "user-liked-tracks"
          ..images = [
            Image()
              ..height = 300
              ..width = 300
              ..url =
                  "https://t.scdn.co/images/3099b3803ad9496896c43f22fe9be8c4.png"
          ],
        [context.l10n]);

    final playlists = useMemoized(
      () {
        if (searchText.value.isEmpty) {
          return [
            likedTracksPlaylist,
            ...pagePlaylists,
          ];
        }
        return [
          likedTracksPlaylist,
          ...pagePlaylists,
        ]
            .map((e) => (weightedRatio(e.name!, searchText.value), e))
            .sorted((a, b) => b.$1.compareTo(a.$1))
            .where((e) => e.$1 > 50)
            .map((e) => e.$2)
            .toList();
      },
      [pagePlaylists, searchText.value],
    );

    final controller = useScrollController();

    if (auth == null) {
      return const AnonymousFallback();
    }

    return RefreshIndicator(
      onRefresh: playlistsQuery.refresh,
      child: SingleChildScrollView(
        controller: controller,
        physics: const AlwaysScrollableScrollPhysics(),
        child: Waypoint(
          controller: controller,
          onTouchEdge: () {
            if (playlistsQuery.hasNextPage) {
              playlistsQuery.fetchNext();
            }
          },
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: SearchBar(
                    onChanged: (value) => searchText.value = value,
                    hintText: context.l10n.filter_playlists,
                    leading: const Icon(SpotubeIcons.filter),
                  ),
                ),
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 300),
                  crossFadeState: playlistsQuery.isLoadingPage ||
                          !playlistsQuery.hasPageData
                      ? CrossFadeState.showFirst
                      : CrossFadeState.showSecond,
                  firstChild:
                      const Center(child: ShimmerPlaybuttonCard(count: 7)),
                  secondChild: Wrap(
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      Row(
                        children: [
                          const SizedBox(width: 10),
                          const PlaylistCreateDialogButton(),
                          const SizedBox(width: 10),
                          ElevatedButton.icon(
                            icon: const Icon(SpotubeIcons.magic),
                            label: Text(context.l10n.generate_playlist),
                            onPressed: () {
                              GoRouter.of(context).push("/library/generate");
                            },
                          ),
                          const SizedBox(width: 10),
                        ],
                      ),
                      ...playlists.map((playlist) => PlaylistCard(playlist))
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
