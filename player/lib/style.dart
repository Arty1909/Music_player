// style.dart
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import 'package:dart_tags/dart_tags.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform, ValueListenable;
import 'package:flutter_media_metadata/flutter_media_metadata.dart';
import 'dart:io' as io if (dart.library.html) 'package:universal_io/io.dart';
import 'dart:io' show Directory, File, FileSystemEntity, FileSystemEntityType;
import 'package:flip_card/flip_card.dart';
//import 'dart:io' as io;
import 'package:audio_service/audio_service.dart';

late BaseAudioHandler audioHandler;

final String defaultArtPath = 'assets/images/default_cover.png';
final List<String> audioExt = ['mp3', 'm4a', 'aac', 'wav', 'flac', 'ogg'];
Box? tracksBox, playlistsBox, prefsBox;
final tracksList = ValueNotifier<List<Map<String, dynamic>>>([]);
String currentSort = 'byDate'; // по умолчанию
final currentPage = ValueNotifier<String>('home');
void setPage(String id) => currentPage.value = id;
final currentPlaylistId = ValueNotifier<String?>(null);
void openPlaylist(String id) {
  currentPlaylistId.value = id;
  setPage('playlist');
}

final isSearchMode = ValueNotifier<bool>(false);

final isSelectionMode = ValueNotifier<bool>(false);
final selectedTrackIds = ValueNotifier<Set<String>>({});

final playbackMode = ValueNotifier<String>('order');
void setPlayMode(String m) {
  playbackMode.value = m;
  prefsBox?.put('playbackMode', m);
}

final pm = prefsBox!.get('playbackMode', defaultValue: 'order');

final audio = AudioPlayer();
bool audioInited = false;

final isPlaying = ValueNotifier<bool>(false);
final currentId = ValueNotifier<String?>(null);
final positionMs = ValueNotifier<int>(0);
final durationMs = ValueNotifier<int>(0);
final playlistsList = ValueNotifier<List<Map<String, dynamic>>>([]);
final backgroundId = ValueNotifier<String>('sky');

final Map<String, Uint8List> webBytes = {};

int queueIndex = -1;

final searchQuery = ValueNotifier<String>('');
final searchController = TextEditingController();
void clearSearch() {
  searchController.clear();
  searchQuery.value = '';
}

/* ========= data ========= */

final Map<String, String> texts = {
  'app': 'Glass Player',
  'home': 'Listen now',
  'library': 'Library',
  'playlists': 'Playlists',
  'queue': 'Queue',
  'queueTitle': 'Queue',
  'settings': 'Settings',
  'addMusic': 'Add music',
  'createPlaylist': 'Create playlist',
  'importFiles': 'Import files',
  'importFolder': 'Import folder',
  'sort': 'Sort',
  'search': 'Search',
  'byName': 'By name',
  'byArtist': 'By artist',
  'byDate': 'Recently added',
  'byDuration': 'By duration',
  'noTracks': 'No tracks yet',
  'importCta': 'Tap + to add',
  'trackSample': 'Psychedelic',
  'artistSample': 'D3m0n X Diablo',
  'unknown': 'Unknown',
  'addToPlaylist': 'Add to playlist',
  'newPlaylist': 'New playlist',
  'playlistName': 'Playlist name',
  'create': 'Create',
  'cancel': 'Cancel',
  'emptyPlaylists': 'No playlists yet',
  'playNext': 'Play next',
  'addToQueue': 'Add to queue',
  'removeFromQueue': 'Remove from queue',
  'clearQueue': 'Clear queue',
  'emptyQueue': 'Queue is empty',
  'playAll': 'Play all',
  'addAllToQueue': 'Add all to queue',
  'rename': 'Rename',
  'delete': 'Delete',
  'confirmDelete': 'Delete this playlist?',
  'deleteFromLibrary': 'Delete from library',
  'confirmDeleteTrack':
      'Delete this track from library? It will be removed from all playlists and the queue.',
  'noResults': 'No results',
  'save': 'Save',
  'themes': 'Themes',
  'sizes': 'Sizes',
  'uiScale': 'Overall UI size',
  'small': 'Small',
  'normal': 'Normal',
  'large': 'Large',
  'xl': 'XL',
  'back': 'Back',
  'backgrounds': 'Backgrounds',
};

final Map<String, Color> colors = {
  'bg1': const Color(0xFFBFD9FF),
  'bg2': const Color(0xFF9FC3FF),
  'glass': const Color(0x44FFFFFF),
  'glassBorder': const Color(0x22FFFFFF),
  'text': Colors.white,
  'textDim': Colors.white70,
  'accent': const Color(0xFF7A4DFF),
  'accentDim': const Color(0x337A4DFF),
  'shadow': const Color(0x33000000),
};

final Map<String, double> sizes = {
  'minEl': 8,
  'maxEl': 24,
  'blur': 20,
  'radiusK': 2.4,
};

final Map<String, IconData> iconsMap = {
  'menu': Icons.menu_rounded,
  'more': Icons.more_horiz_rounded,
  'search': Icons.search_rounded,
  'add': Icons.add_rounded,
  'playlist': Icons.queue_music_rounded,
  'queue': Icons.queue_play_next_rounded,
  'settings': Icons.settings_rounded,
  'sort': Icons.sort_rounded,
  'play': Icons.play_arrow_rounded,
  'pause': Icons.pause_rounded,
  'prev': Icons.skip_previous_rounded,
  'next': Icons.skip_next_rounded,
  'drag': Icons.drag_indicator_rounded,
  'shuffle': Icons.shuffle_rounded,
  'repeat': Icons.repeat_rounded,
  'repeatOne': Icons.repeat_one_rounded,
  'order': Icons.format_list_bulleted_rounded,
  'back': Icons.arrow_back_rounded,
  'info': Icons.info_outline_rounded,
  'theme': Icons.color_lens_rounded,
  'size': Icons.straighten_rounded,
};

Widget scrollY(Widget child) {
  return LayoutBuilder(
    builder: (ctx, c) => SingleChildScrollView(
      padding: EdgeInsets.zero,
      physics: const ClampingScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: c.maxHeight),
        child: child,
      ),
    ),
  );
}

/* ========= registries ========= */

typedef IconButtonBuilder =
    Widget Function(IconData icon, VoidCallback onTap, double el);

final Map<String, IconButtonBuilder> iconButtons = {
  'circle': (icon, onTap, el) => Material(
    type: MaterialType.transparency,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(el * (sizes['radiusK'] ?? 2.4)),
      child: Container(
        width: el * 2.6,
        height: el * 2.6,
        decoration: BoxDecoration(
          color: colors['glass'],
          borderRadius: BorderRadius.circular(el * (sizes['radiusK'] ?? 2.4)),
          border: Border.all(color: colors['glassBorder']!, width: 1),
          boxShadow: [
            BoxShadow(
              color: colors['shadow']!,
              blurRadius: el,
              offset: Offset(0, el * .3),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: el * 1.6, color: colors['text']),
      ),
    ),
  ),
};

final Map<String, dynamic> buttons = {
  'icon': (IconData icon, VoidCallback onTap, double el) =>
      iconButtons['circle']!(icon, onTap, el),

  'pill': (String text, IconData icon, VoidCallback onTap, double el) =>
      Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(el * (sizes['radiusK'] ?? 2.4)),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: el * 1.2,
              vertical: el * 1.0,
            ),
            decoration: BoxDecoration(
              color: colors['glass'],
              borderRadius: BorderRadius.circular(
                el * (sizes['radiusK'] ?? 2.4),
              ),
              border: Border.all(color: colors['glassBorder']!, width: 1),
              boxShadow: [
                BoxShadow(
                  color: colors['shadow']!,
                  blurRadius: el,
                  offset: Offset(0, el * .3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: el * 1.4, color: colors['text']),
                SizedBox(width: el * .6),
                Text(
                  text,
                  style: TextStyle(color: colors['text'], fontSize: el * 1.05),
                ),
              ],
            ),
          ),
        ),
      ),
};

/* ========= helpers ========= */

double elOf(BuildContext ctx) {
  final s = MediaQuery.of(ctx).size;
  final base = min(s.width, s.height) / 24;
  final mn = sizes['minEl'] ?? 8.0, mx = sizes['maxEl'] ?? 28.0;
  final scaled = base * (uiScale.value);
  return scaled.clamp(mn, mx);
}

String formatMs(int ms) {
  final s = ms ~/ 1000;
  final m = s ~/ 60;
  final r = s % 60;
  return '$m:${r.toString().padLeft(2, '0')}';
}

BoxDecoration appBackground() => BoxDecoration(
  gradient: LinearGradient(
    colors: [colors['bg1']!, colors['bg2']!],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
);

Widget glass(Widget child, double el) {
  final r = el * (sizes['radiusK'] ?? 2.4);
  return ClipRRect(
    borderRadius: BorderRadius.circular(r),
    child: BackdropFilter(
      filter: ImageFilter.blur(
        sigmaX: sizes['blur'] ?? 20,
        sigmaY: sizes['blur'] ?? 20,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          padding: EdgeInsets.all(el * 1.2),
          decoration: BoxDecoration(
            color: colors['glass'],
            borderRadius: BorderRadius.circular(r),
            border: Border.all(color: colors['glassBorder']!, width: 1),
            boxShadow: [
              BoxShadow(
                color: colors['shadow']!,
                blurRadius: el * 1.4,
                offset: Offset(0, el * .4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    ),
  );
}

/* ========= reusable UI ========= */

Drawer appDrawer(double el) {
  final items = [
    {'icon': iconsMap['playlist']!, 'title': texts['library']!},
    {'icon': iconsMap['playlist']!, 'title': texts['playlists']!},
    {'icon': iconsMap['queue']!, 'title': texts['queue']!},
    {'icon': iconsMap['settings']!, 'title': texts['settings']!},
  ];

  return Drawer(
    backgroundColor: Colors.transparent,
    child: SafeArea(
      child: Padding(
        padding: EdgeInsets.all(el * 1.2),
        child: glass(
          ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => SizedBox(height: el * .6),
            itemBuilder: (ctx, i) => ListTile(
              leading: Icon(
                items[i]['icon'] as IconData,
                color: colors['text'],
              ),
              title: Text(
                items[i]['title'] as String,
                style: TextStyle(color: colors['text']),
              ),
              onTap: () {
                final title = items[i]['title'] as String;

                if (title == texts['library']) setPage('home');
                if (title == texts['playlists']) setPage('playlists');
                if (title == texts['queue']) setPage('queue');
                if (title == texts['settings']) setPage('settings');

                Navigator.pop(ctx);
              },
            ),
          ),
          el,
        ),
      ),
    ),
  );
}

Widget topBar(BuildContext ctx, double el) {
  ensureBoxes();
  ensureAudio();

  return ValueListenableBuilder<bool>(
    valueListenable: isSelectionMode,
    builder: (context, isSelecting, _) {
      if (isSelecting) {
        return _buildSelectionTopBar(context, el);
      }
      return ValueListenableBuilder<bool>(
        valueListenable: isSearchMode,
        builder: (context, isSearching, _) {
          if (isSearching) {
            return _buildSearchTopBar(context, el);
          }
          return ValueListenableBuilder<String>(
            valueListenable: currentPage,
            builder: (context, page, _) {
              if (page == 'settings') {
                return _buildSettingsTopBar(ctx, el);
              }
              return _buildNormalTopBar(context, el);
            },
          );
        },
      );
    },
  );
}

Widget _buildSearchTopBar(BuildContext ctx, double el) {
  final iconBtn =
      buttons['icon'] as Widget Function(IconData, VoidCallback, double);

  return Row(
    children: [
      iconBtn(Icons.arrow_back_rounded, () {
        isSearchMode.value = false;
        clearSearch();
      }, el),
      SizedBox(width: el),
      Expanded(
        child: glass(
          SizedBox(
            height: el * 3.4,
            child: ValueListenableBuilder<String>(
              valueListenable: searchQuery,
              builder: (_, q, __) => Row(
                children: [
                  Icon(
                    iconsMap['search']!,
                    color: colors['textDim'],
                    size: el * 1.6,
                  ),
                  SizedBox(width: el * .8),
                  Expanded(
                    child: TextField(
                      controller: searchController,
                      autofocus: true,
                      onChanged: (s) =>
                          searchQuery.value = s.trim().toLowerCase(),
                      style: TextStyle(
                        color: colors['text'],
                        fontSize: el * 1.05,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: texts['search']!,
                        hintStyle: TextStyle(
                          color: colors['textDim'],
                          fontSize: el * 1.05,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  if (q.isNotEmpty) ...[
                    SizedBox(width: el * .4),
                    InkWell(
                      onTap: clearSearch,
                      borderRadius: BorderRadius.circular(el),
                      child: Padding(
                        padding: EdgeInsets.all(el * .4),
                        child: Icon(
                          Icons.close_rounded,
                          size: el * 1.4,
                          color: colors['textDim'],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          el,
        ),
      ),
    ],
  );
}

Widget _buildNormalTopBar(BuildContext ctx, double el) {
  final iconBtn =
      buttons['icon'] as Widget Function(IconData, VoidCallback, double);
  final pillBtn =
      buttons['pill']
          as Widget Function(String, IconData, VoidCallback, double);

  // Определяем, что это мобильный
  final screenWidth = MediaQuery.of(ctx).size.width;
  final isMobile = screenWidth < 600;

  return Builder(
    builder: (inner) => Row(
      children: [
        iconBtn(
          iconsMap['menu']!,
          () => Scaffold.of(inner).openDrawer(),
          el,
        ), // <-- inner
        SizedBox(width: el),
        Expanded(
          child: Text(
            texts['home']!,
            style: TextStyle(
              fontSize: el * 1.6,
              color: colors['text'],
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        /* SizedBox(width: el),
        iconBtn(iconsMap['sort']!, () => openSortSheet(inner, el), el),
        SizedBox(width: el),
        if (isMobile)
          iconBtn(iconsMap['add']!, () => openAddMenu(inner, el), el)
        else
          pillBtn(
            texts['addMusic']!,
            iconsMap['add']!,
            () => openAddMenu(inner, el),
            el,
          ),*/
        SizedBox(width: el),
        iconBtn(iconsMap['search']!, () {
          isSearchMode.value = true;
        }, el),

        SizedBox(width: el),

        iconBtn(iconsMap['more']!, () => openTopMoreMenu(inner, el), el),
      ],
    ),
  );
}

Widget _buildSelectionTopBar(BuildContext ctx, double el) {
  final iconBtn =
      buttons['icon'] as Widget Function(IconData, VoidCallback, double);

  return ValueListenableBuilder<Set<String>>(
    valueListenable: selectedTrackIds,
    builder: (context, selected, _) {
      final count = selected.length;
      return Row(
        children: [
          iconBtn(Icons.close_rounded, _cancelSelectionMode, el),
          SizedBox(width: el),
          Expanded(
            child: Text(
              '$count selected',
              style: TextStyle(
                fontSize: el * 1.6,
                color: colors['text'],
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: _selectAllTracks,
            child: Text(
              'Select All',
              style: TextStyle(color: colors['text'], fontSize: el * 1.05),
            ),
          ),
          SizedBox(width: el),
          iconBtn(
            Icons.delete_outline_rounded,
            () => _deleteSelectedTracks(ctx),
            el,
          ),
        ],
      );
    },
  );
}

Widget libraryView(double el) {
  final iconBtn =
      buttons['icon'] as Widget Function(IconData, VoidCallback, double);

  return ValueListenableBuilder<List<Map<String, dynamic>>>(
    valueListenable: tracksList,
    builder: (_, list, __) {
      if (list.isEmpty) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              texts['library']!,
              style: TextStyle(
                color: colors['text'],
                fontSize: el * 1.2,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: el * .8),
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: el * 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      iconsMap['playlist']!,
                      size: el * 4,
                      color: colors['textDim'],
                    ),
                    SizedBox(height: el),
                    Text(
                      texts['noTracks']!,
                      style: TextStyle(
                        color: colors['textDim'],
                        fontSize: el * 1.05,
                      ),
                    ),
                    SizedBox(height: el * .6),
                    Text(
                      texts['importCta']!,
                      style: TextStyle(color: colors['textDim'], fontSize: el),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }
      return ValueListenableBuilder<String>(
        valueListenable: searchQuery,
        builder: (_, q, __) {
          final view = (q.isEmpty)
              ? list
              : list.where((t) {
                  final title = (t['title'] ?? '').toString().toLowerCase();
                  final artist = (t['artist'] ?? '').toString().toLowerCase();
                  return title.contains(q) || artist.contains(q);
                }).toList();
          if (view.isEmpty) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      texts['library']!,
                      style: TextStyle(
                        color: colors['text'],
                        fontSize: el * 1.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      texts[currentSort] ?? '',
                      style: TextStyle(color: colors['textDim'], fontSize: el),
                    ),
                  ],
                ),
                SizedBox(height: el * .8),
                Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: el * 4),
                    child: Text(
                      texts['noResults']!,
                      style: TextStyle(
                        color: colors['textDim'],
                        fontSize: el * 1.05,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    texts['library']!,
                    style: TextStyle(
                      color: colors['text'],
                      fontSize: el * 1.2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    texts[currentSort] ?? '',
                    style: TextStyle(color: colors['textDim'], fontSize: el),
                  ),
                ],
              ),
              SizedBox(height: el * .8),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: view.length,
                separatorBuilder: (_, __) => SizedBox(height: el * .6),
                itemBuilder: (ctx, i) {
                  final t = view[i];
                  final artist = (t['artist'] ?? '').toString().trim();
                  final int dur = (t['duration'] ?? 0) as int;
                  final String meta =
                      '${artist.isEmpty ? texts['unknown']! : artist}'
                      '${dur > 0 ? ' • ${formatMs(dur)}' : ''}';
                  return ValueListenableBuilder<bool>(
                    valueListenable: isSelectionMode,
                    builder: (_, isSelecting, __) {
                      return ValueListenableBuilder<Set<String>>(
                        valueListenable: selectedTrackIds,
                        builder: (_, selectedIds, __) {
                          final isSelected = selectedIds.contains(t['id']);

                          return Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? colors['accentDim']!.withOpacity(0.5)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(el),
                            ),
                            child: InkWell(
                              onTap: () {
                                if (isSelecting) {
                                  _toggleTrackSelection(t['id'] as String);
                                } else {
                                  playById(t['id'] as String);
                                  setPage('now');
                                }
                              },
                              onLongPress: () {
                                if (isSelecting) {
                                } else {
                                  openTrackActions(ctx, el, t['id'] as String);
                                }
                              },
                              borderRadius: BorderRadius.circular(el),
                              child: Padding(
                                padding: EdgeInsets.all(el * .6),
                                child: Row(
                                  children: [
                                    if (isSelecting) ...[
                                      Icon(
                                        isSelected
                                            ? Icons.check_circle_rounded
                                            : Icons
                                                  .radio_button_unchecked_rounded,
                                        color: colors['text'],
                                        size: el * 2.6, // == artThumb size
                                      ),
                                    ] else ...[
                                      artThumb(t, el),
                                    ],
                                    SizedBox(width: el),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            t['title'] ?? '',
                                            style: TextStyle(
                                              color: colors['text'],
                                              fontSize: el * 1.05,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          SizedBox(height: el * .2),
                                          Text(
                                            meta,
                                            style: TextStyle(
                                              color: colors['textDim'],
                                              fontSize: el,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(width: el),
                                    if (!isSelecting)
                                      iconBtn(
                                        iconsMap['more']!,
                                        () => openTrackActions(
                                          ctx,
                                          el,
                                          t['id'] as String,
                                        ),
                                        el,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ],
          );
        },
      );
    },
  );
}

Widget miniPlayer(double el) {
  final iconBtn =
      buttons['icon'] as Widget Function(IconData, VoidCallback, double);

  return ValueListenableBuilder<String?>(
    valueListenable: currentId,
    builder: (_, id, __) {
      Map<String, dynamic>? t;
      if (id != null) {
        t = tracksList.value.cast<Map<String, dynamic>?>().firstWhere(
          (e) => e?['id'] == id,
          orElse: () => null,
        );
      }

      final title = ((t?['title'] ?? texts['trackSample']!) as String);
      final artistRaw = ((t?['artist'] ?? '') as String).trim();
      final artist = artistRaw.isEmpty ? texts['unknown']! : artistRaw;
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              artThumb(t ?? <String, dynamic>{}, el),
              SizedBox(width: el),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors['text'], fontSize: el),
                    ),
                    Text(
                      artist,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors['textDim'],
                        fontSize: el * .95,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: el * .6),
              iconBtn(iconsMap['prev']!, () => playPrev(), el),
              SizedBox(width: el * .6),
              ValueListenableBuilder<bool>(
                valueListenable: isPlaying,
                builder: (_, playing, __) => iconBtn(
                  playing ? iconsMap['pause']! : iconsMap['play']!,
                  () => togglePlay(),
                  el,
                ),
              ),
              SizedBox(width: el * .6),
              iconBtn(iconsMap['next']!, () => playNext(), el),
            ],
          ),
        ],
      );
    },
  );
}

/* ========= actions ========= */

void openAddMenu(BuildContext ctx, double el) {
  showModalBottomSheet(
    context: ctx,
    backgroundColor: Colors.transparent,
    builder: (_) => Padding(
      padding: EdgeInsets.all(el * 1.2),
      child: glass(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.file_upload_rounded,
                color: Colors.white,
              ),
              title: Text(
                texts['importFiles']!,
                style: TextStyle(color: colors['text']),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                await pickAndImportFiles(ctx);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.folder_open_rounded,
                color: Colors.white,
              ),
              title: Text(
                texts['importFolder']!,
                style: TextStyle(color: colors['text']),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                await pickAndImportFolder(ctx);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.playlist_add_rounded,
                color: Colors.white,
              ),
              title: Text(
                texts['createPlaylist']!,
                style: TextStyle(color: colors['text']),
              ),
              onTap: () {
                Navigator.pop(ctx);
                openCreatePlaylistDialog(ctx, el, null);
              },
            ),
          ],
        ),
        el,
      ),
    ),
  );
}

void openSortSheet(BuildContext ctx, double el) {
  final opts = [
    texts['byName']!,
    texts['byArtist']!,
    texts['byDate']!,
    texts['byDuration']!,
  ];
  showModalBottomSheet(
    context: ctx,
    backgroundColor: Colors.transparent,
    builder: (_) => Padding(
      padding: EdgeInsets.all(el * 1.2),
      child: glass(
        ListView.builder(
          shrinkWrap: true,
          itemCount: opts.length,
          itemBuilder: (_, i) => ListTile(
            title: Text(opts[i], style: TextStyle(color: colors['text'])),
            onTap: () {
              Navigator.pop(ctx);
              final ids = ['byName', 'byArtist', 'byDate', 'byDuration'];
              setSort(ids[i]);
            },
          ),
        ),
        el,
      ),
    ),
  );
}

Future<void> ensureBoxes() async {
  if (tracksBox != null && playlistsBox != null && prefsBox != null) {
    // UI scale
    final savedScale = prefsBox!.get('uiScale', defaultValue: 1.0);
    uiScale.value = (savedScale is num) ? savedScale.toDouble() : 1.0;

    // Theme
    final savedTheme = prefsBox!.get('theme', defaultValue: 'glass') as String;
    themeId.value = themes.containsKey(savedTheme) ? savedTheme : 'glass';
    _applyTheme(themeId.value);

    final savedBackground =
        prefsBox!.get('background', defaultValue: 'sky') as String;
    backgroundId.value = backgrounds.containsKey(savedBackground)
        ? savedBackground
        : 'sky';

    // Sort / Playback mode
    currentSort = prefsBox!.get('sort', defaultValue: 'byDate');
    playbackMode.value = prefsBox!.get('playbackMode', defaultValue: 'order');

    // Queue
    final savedQ =
        (prefsBox!.get('queueIds', defaultValue: <dynamic>[]) as List)
            .map((e) => e.toString())
            .toList();
    queueIds.value = savedQ;
    _reloadTracks();
    _reloadPlaylists();

    final lastId = prefsBox!.get('lastPlayedId') as String?;
    if (lastId != null && tracksList.value.any((t) => t['id'] == lastId)) {
      currentId.value = lastId;
    }
    return;
  }

  await Hive.initFlutter();
  tracksBox = await Hive.openBox('tracksBox');
  playlistsBox = await Hive.openBox('playlistsBox');
  prefsBox = await Hive.openBox('prefsBox');

  // UI scale
  final savedScale = prefsBox!.get('uiScale', defaultValue: 1.0);
  uiScale.value = (savedScale is num) ? savedScale.toDouble() : 1.0;

  // Theme
  final savedTheme = prefsBox!.get('theme', defaultValue: 'glass') as String;
  themeId.value = themes.containsKey(savedTheme) ? savedTheme : 'glass';
  _applyTheme(themeId.value);

  final savedBackground =
      prefsBox!.get('background', defaultValue: 'sky') as String;
  backgroundId.value = backgrounds.containsKey(savedBackground)
      ? savedBackground
      : 'sky';

  // Sort / Playback mode
  currentSort = prefsBox!.get('sort', defaultValue: 'byDate');
  playbackMode.value = prefsBox!.get('playbackMode', defaultValue: 'order');

  _reloadTracks();

  // Queue
  final savedQ = (prefsBox!.get('queueIds', defaultValue: <dynamic>[]) as List)
      .map((e) => e.toString())
      .toList();
  queueIds.value = savedQ;

  _reloadPlaylists();

  // Last played
  final lastId = prefsBox!.get('lastPlayedId') as String?;
  if (lastId != null && tracksList.value.any((t) => t['id'] == lastId)) {
    currentId.value = lastId;
  }
}

void setSort(String id) {
  currentSort = id;
  prefsBox?.put('sort', id);
  _reloadTracks();
}

void _reloadTracks() {
  final values = tracksBox?.values ?? const [];
  final all = values.map((e) => Map<String, dynamic>.from(e as Map)).toList();

  all.sort((a, b) {
    switch (currentSort) {
      case 'byName':
        return (a['title'] ?? '').toString().toLowerCase().compareTo(
          (b['title'] ?? '').toString().toLowerCase(),
        );
      case 'byArtist':
        return (a['artist'] ?? '').toString().toLowerCase().compareTo(
          (b['artist'] ?? '').toString().toLowerCase(),
        );
      case 'byDuration':
        return (a['duration'] ?? 0).compareTo(b['duration'] ?? 0);
      case 'byDate':
      default:
        return (b['addedAt'] ?? 0).compareTo(a['addedAt'] ?? 0);
    }
  });

  tracksList.value = all;
}

Future<void> pickAndImportFiles(BuildContext ctx) async {
  final res = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: audioExt,
    allowMultiple: true,
    withData: kIsWeb,
  );
  if (res == null || res.files.isEmpty) return;

  await ensureBoxes();

  for (final f in res.files) {
    String? path;
    Uint8List? bytes;
    String name;
    String idSource;

    if (kIsWeb) {
      bytes = f.bytes;
      name = f.name;
      idSource = f.name;
      if (bytes == null || bytes.isEmpty) continue;
    } else {
      path = f.path;
      name = f.name;
      idSource = path ?? f.name;
      if (path == null) continue;
    }

    if (!_isAudio(name)) continue;

    if (_existsFile(f)) continue;

    final now = DateTime.now().millisecondsSinceEpoch;
    final id = _fastId(idSource, now);
    final base = p.basenameWithoutExtension(idSource);

    String title = base;
    String artist = '';
    int duration = 0;
    Uint8List? art;
    String lyrics = '';

    try {
      final tp = TagProcessor();
      Metadata? md;

      if (kIsWeb && bytes != null && bytes.isNotEmpty) {
        md = await MetadataRetriever.fromBytes(bytes);
        webBytes[id] = bytes;
        final tags = await tp.getTagsFromByteArray(Future.value(bytes));
        lyrics = _pickLyrics(tags);
      } else if (!kIsWeb && path != null) {
        md = await MetadataRetriever.fromFile(io.File(path));

        final fileBytes = await io.File(path).readAsBytes();
        final tags = await tp.getTagsFromByteArray(Future.value(fileBytes));
        lyrics = _pickLyrics(tags);
      }

      if (md != null) {
        final t = (md.trackName ?? '').trim();
        if (t.isNotEmpty) title = t;
        final names = (md.trackArtistNames ?? const <String>[])
            .where((e) => e.trim().isNotEmpty)
            .toList();
        if (names.isEmpty && (md.authorName ?? '').trim().isNotEmpty) {
          names.add(md.authorName!.trim());
        }
        artist = names.join(', ').trim();
        duration = md.trackDuration ?? 0;
        art = md.albumArt;
      }

      if (title == base && artist.isEmpty) {
        final g = _guessMetaFromName(base);
        title = g['title']!;
        artist = g['artist']!;
      }
    } catch (e) {
      debugPrint('Metadata read failed for $idSource: $e');
      final g = _guessMetaFromName(base);
      title = g['title']!;
      artist = g['artist']!;
    }

    final track = <String, dynamic>{
      'id': id,
      'source': kIsWeb ? 'web' : 'fs',
      'path': path ?? '',
      'name': name,
      'size': f.size,
      'title': title,
      'artist': artist,
      'album': '',
      'duration': duration,
      'art': art,
      'lyrics': lyrics,
      'addedAt': now,
    };

    await tracksBox!.put(id, track);
  }

  _reloadTracks();
}

Widget artThumb(Map<String, dynamic> t, double el, {double size = 2.6}) {
  final Uint8List? art = t['art'] is Uint8List ? t['art'] as Uint8List : null;
  final w = el * size;
  final r = BorderRadius.circular(el);

  return ClipRRect(
    borderRadius: r,
    child: (art != null && art.isNotEmpty)
        ? Image.memory(
            art,
            width: w,
            height: w,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            filterQuality: FilterQuality.medium,
          )
        : Image.asset(
            defaultArtPath,
            width: w,
            height: w,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            filterQuality: FilterQuality.medium,
          ),
  );
}

bool _isAudio(String path) {
  final ext = p.extension(path).replaceFirst('.', '').toLowerCase();
  return audioExt.contains(ext);
}

bool _existsFile(PlatformFile f) {
  final vals = tracksBox?.values ?? const Iterable.empty();

  if (kIsWeb) {
    return vals.any((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return (m['name'] ?? '') == f.name && (m['size'] ?? -1) == f.size;
    });
  }

  final path = f.path;
  if (path != null) {
    return vals.any((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return (m['path'] ?? '') == path;
    });
  }

  return vals.any((e) {
    final m = Map<String, dynamic>.from(e as Map);
    return (m['name'] ?? '') == f.name && (m['size'] ?? -1) == f.size;
  });
}

String _fastId(String path, int seed) {
  final s = '${path.length}_${path.hashCode}_$seed';
  return s;
}

final audioCfg = {
  'stayAwake': true,
  'respectSilence': false,
  'duckAudio': true,
};

Future<void> ensureAudio() async {
  if (audioInited) return;
  audioInited = true;

  try {
    await audio.setAudioContext(
      AudioContext(
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: <AVAudioSessionOptions>{},
        ),
        android: const AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: true,
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.gain,
        ),
      ),
    );
  } catch (e) {
    debugPrint('AudioContext setup failed: $e');
  }

  await audio.setReleaseMode(ReleaseMode.stop);

  audio.onPlayerStateChanged.listen(
    (s) => isPlaying.value = s == PlayerState.playing,
  );
  audio.onPositionChanged.listen((d) => positionMs.value = d.inMilliseconds);
  audio.onDurationChanged.listen((d) => durationMs.value = d.inMilliseconds);

  audio.onPlayerComplete.listen((_) async {
    if (playbackMode.value == 'repeatOne' && currentId.value != null) {
      await playById(currentId.value!);
      return;
    }
    await playNext(completed: true);
  });
}

final sys = {
  'androidChannelId': 'glass.player.playback',
  'androidChannelName': 'Playback',
  'androidNotifOngoing': true,
};

Future<Source?> _sourceFor(Map<String, dynamic> t) async {
  if (kIsWeb) {
    final b = webBytes[t['id']];
    if (b != null) return BytesSource(b);
    final url = (t['url'] ?? '') as String;
    if (url.isNotEmpty) return UrlSource(url);
    return null;
  }

  final path = (t['path'] ?? '') as String;
  if (path.isNotEmpty) return DeviceFileSource(path);

  final url = (t['url'] ?? '') as String;
  if (url.startsWith('file://')) {
    try {
      final p = Uri.parse(url).toFilePath(windows: true);
      if (p.isNotEmpty) return DeviceFileSource(p);
    } catch (_) {}
  }
  if (url.isNotEmpty) return UrlSource(url); // http/https кейс

  return null;
}

void _updateQueueIndex(String id) {
  final list = tracksList.value;
  queueIndex = list.indexWhere((e) => e['id'] == id);
}

Future<void> playById(String id) async {
  await ensureBoxes();
  await ensureAudio();

  final raw = tracksBox!.get(id);
  final Map<String, dynamic>? t = raw is Map
      ? Map<String, dynamic>.from(raw)
      : null;
  if (t == null) return;

  final src = await _sourceFor(t);
  if (src == null) return;
  audioHandler!.mediaItem.add(
    MediaItem(
      id: id,
      title: (t['title'] ?? '') as String,
      artist: ((t['artist'] ?? '') as String).trim().isEmpty
          ? texts['unknown']!
          : (t['artist'] as String),
      duration: ((t['duration'] ?? 0) as int) > 0
          ? Duration(milliseconds: (t['duration'] as int))
          : null,
    ),
  );
  audioHandler!.playbackState.add(
    audioHandler!.playbackState.value.copyWith(
      playing: true,
      processingState: AudioProcessingState.loading,
      controls: const [
        MediaControl.skipToPrevious,
        MediaControl.pause,
        //MediaControl.stop,
        MediaControl.skipToNext,
      ],
      updatePosition: Duration.zero,
    ),
  );

  try {
    await audio.stop();
    await audio.play(src);
    currentId.value = id;
    _updateQueueIndex(id);
    prefsBox?.put('lastPlayedId', id);
  } catch (e) {
    debugPrint('playById error: $e');
  }
}

/*Future<void> togglePlay() async {
  await ensureAudio();
  if (isPlaying.value) {
    await audio.pause();
  } else {
    await audio.resume();
  }
}*/

Future<void> togglePlay() async {
  await ensureAudio();

  final playerState = audio.state;

  if (playerState == PlayerState.playing) {
    await audio.pause();
  } else if (playerState == PlayerState.paused) {
    await audio.resume();
  } else {
    final id = currentId.value;
    if (id != null) {
      await playById(id);
    }
  }
}

Future<void> seekToFraction(double f) async {
  final d = durationMs.value;
  if (d <= 0) return;
  final pos = (d * f).round();
  await audio.seek(Duration(milliseconds: pos));
}

Future<void> playNext({bool completed = false}) async {
  final q = queueIds.value;
  final pool = q.isNotEmpty
      ? q
      : tracksList.value.map((e) => e['id'] as String).toList();
  if (pool.isEmpty) return;

  final cur = currentId.value;
  final mode = playbackMode.value;

  if (mode == 'shuffle') {
    if (pool.length == 1 && cur != null && pool.first == cur) {
      if (completed) {
        await audio.stop();
        return;
      }
      await playById(pool.first);
      return;
    }
    var nextId = cur;
    final rng = Random();
    for (var k = 0; k < 7 && nextId == cur; k++) {
      nextId = pool[rng.nextInt(pool.length)];
    }
    await playById(nextId ?? pool.first);
    return;
  }

  int i = cur == null ? -1 : pool.indexOf(cur);
  final isLast = i >= 0 && i == pool.length - 1;

  if (isLast && completed && mode == 'order') {
    await audio.stop();
    return;
  }

  final nextId = pool[(i + 1) % pool.length];
  await playById(nextId);
}

Future<void> playPrev() async {
  final q = queueIds.value;
  final pool = q.isNotEmpty
      ? q
      : tracksList.value.map((e) => e['id'] as String).toList();
  if (pool.isEmpty) return;

  final cur = currentId.value;
  final mode = playbackMode.value;

  if (mode == 'shuffle') {
    if (pool.length == 1) {
      await playById(pool.first);
      return;
    }
    var prevId = cur;
    final rng = Random();
    for (var k = 0; k < 7 && prevId == cur; k++) {
      prevId = pool[rng.nextInt(pool.length)];
    }
    await playById(prevId ?? pool.first);
    return;
  }

  int i = cur == null ? 0 : pool.indexOf(cur);
  final prevId = pool[(i - 1 + pool.length) % pool.length];
  await playById(prevId);
}

Map<String, String> _guessMetaFromName(String base) {
  var s = base.replaceAll('_', ' ').trim();
  for (final d in [' - ', ' – ', ' — ']) {
    if (s.contains(d)) {
      final parts = s.split(d);
      final artist = parts.first.trim();
      final title = parts.sublist(1).join(d).trim();
      if (artist.isNotEmpty && title.isNotEmpty) {
        return {'artist': artist, 'title': title};
      }
    }
  }
  return {'artist': '', 'title': s};
}

void _reloadPlaylists() {
  final values = playlistsBox?.values ?? const [];
  final all = values.map((e) => Map<String, dynamic>.from(e as Map)).toList()
    ..sort((a, b) => (b['createdAt'] ?? 0).compareTo(a['createdAt'] ?? 0));
  playlistsList.value = all;
}

Future<String?> createPlaylist(String name) async {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return null;
  await ensureBoxes();
  final id = 'pl_${_fastId(trimmed, DateTime.now().millisecondsSinceEpoch)}';
  final pl = <String, dynamic>{
    'id': id,
    'name': trimmed,
    'trackIds': <String>[],
    'createdAt': DateTime.now().millisecondsSinceEpoch,
  };
  await playlistsBox!.put(id, pl);
  _reloadPlaylists();
  return id;
}

Future<void> addTrackToPlaylist(String playlistId, String trackId) async {
  await ensureBoxes();
  final raw = playlistsBox!.get(playlistId);
  final Map<String, dynamic>? pl = raw is Map
      ? Map<String, dynamic>.from(raw)
      : null;
  if (pl == null) return;

  final List<dynamic> idsDyn = (pl['trackIds'] ?? <dynamic>[]) as List<dynamic>;
  final ids = idsDyn.map((e) => e.toString()).toList();
  if (!ids.contains(trackId)) ids.add(trackId);

  pl['trackIds'] = ids;
  await playlistsBox!.put(playlistId, pl);
  _reloadPlaylists();
}

Future<void> removeTrackFromPlaylist(String playlistId, String trackId) async {
  await ensureBoxes();
  final raw = playlistsBox!.get(playlistId);
  final Map<String, dynamic>? pl = raw is Map
      ? Map<String, dynamic>.from(raw)
      : null;
  if (pl == null) return;

  final List<dynamic> idsDyn = (pl['trackIds'] ?? <dynamic>[]) as List<dynamic>;
  final ids = idsDyn.map((e) => e.toString()).toList()..remove(trackId);

  pl['trackIds'] = ids;
  await playlistsBox!.put(playlistId, pl);
  _reloadPlaylists();
}

void openAddToPlaylistSheet(BuildContext ctx, double el, String trackId) {
  showModalBottomSheet(
    context: ctx,
    backgroundColor: Colors.transparent,
    builder: (_) => Padding(
      padding: EdgeInsets.all(el * 1.2),
      child: glass(
        ValueListenableBuilder<List<Map<String, dynamic>>>(
          valueListenable: playlistsList,
          builder: (_, pls, __) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.playlist_add_rounded,
                    color: Colors.white,
                  ),
                  title: Text(
                    texts['newPlaylist']!,
                    style: TextStyle(color: colors['text']),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await openCreatePlaylistDialog(ctx, el, trackId);
                  },
                ),
                if (pls.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: el),
                    child: Text(
                      texts['emptyPlaylists']!,
                      style: TextStyle(
                        color: colors['textDim'],
                        fontSize: el * 1.05,
                      ),
                    ),
                  ),
                if (pls.isNotEmpty)
                  ...pls.map(
                    (pl) => ListTile(
                      leading: const Icon(
                        Icons.queue_music_rounded,
                        color: Colors.white,
                      ),
                      title: Text(
                        pl['name'] ?? '',
                        style: TextStyle(color: colors['text']),
                      ),
                      trailing: Text(
                        ((pl['trackIds'] ?? const <dynamic>[]).length)
                            .toString(),
                        style: TextStyle(color: colors['textDim']),
                      ),
                      onTap: () async {
                        await addTrackToPlaylist(pl['id'] as String, trackId);
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                    ),
                  ),
              ],
            );
          },
        ),
        el,
      ),
    ),
  );
}

Future<void> openCreatePlaylistDialog(
  BuildContext ctx,
  double el,
  String? addTrackIdAfter,
) async {
  final c = TextEditingController();
  final ok = await showDialog<bool>(
    context: ctx,
    builder: (_) => AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            texts['playlistName']!,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          TextField(controller: c, autofocus: true),
          const SizedBox(height: 8),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(texts['cancel']!),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(texts['create']!),
        ),
      ],
    ),
  );

  if (ok != true) return;
  final id = await createPlaylist(c.text);
  if (id == null) return;
  if (addTrackIdAfter != null) {
    await addTrackToPlaylist(id, addTrackIdAfter);
  }
}

Widget playlistsView(double el) {
  return ValueListenableBuilder<List<Map<String, dynamic>>>(
    valueListenable: playlistsList,
    builder: (_, pls, __) {
      if (pls.isEmpty) {
        return Center(
          child: Text(
            texts['emptyPlaylists']!,
            style: TextStyle(color: colors['textDim'], fontSize: el * 1.05),
          ),
        );
      }
      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: pls.length,
        separatorBuilder: (_, __) => SizedBox(height: el * .6),
        itemBuilder: (ctx, i) {
          final p = pls[i];
          final count = (p['trackIds'] ?? const <dynamic>[]).length;
          return InkWell(
            onTap: () => openPlaylist(p['id'] as String),
            borderRadius: BorderRadius.circular(el),
            child: Padding(
              padding: EdgeInsets.all(el * .6),
              child: Row(
                children: [
                  Icon(iconsMap['playlist'], color: colors['text']),
                  SizedBox(width: el),
                  Expanded(
                    child: Text(
                      p['name'] ?? '',
                      style: TextStyle(
                        color: colors['text'],
                        fontSize: el * 1.05,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '$count',
                    style: TextStyle(color: colors['textDim'], fontSize: el),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

Widget playlistView(double el) {
  return ValueListenableBuilder<String?>(
    valueListenable: currentPlaylistId,
    builder: (ctx, id, __) {
      return ValueListenableBuilder<List<Map<String, dynamic>>>(
        valueListenable: playlistsList,
        builder: (_, __pls, ___) {
          if (id == null) {
            return Center(
              child: Text(
                texts['emptyPlaylists']!,
                style: TextStyle(color: colors['textDim']),
              ),
            );
          }

          final raw = playlistsBox?.get(id);
          final Map<String, dynamic>? pl = raw is Map
              ? Map<String, dynamic>.from(raw)
              : null;
          if (pl == null) {
            return Center(
              child: Text(
                texts['emptyPlaylists']!,
                style: TextStyle(color: colors['textDim']),
              ),
            );
          }

          final ids = ((pl['trackIds'] ?? const <dynamic>[]) as List)
              .map((e) => e.toString())
              .toList();
          final allTracks = tracksList.value;
          final list = ids
              .map(
                (tid) => allTracks.firstWhere(
                  (t) => t['id'] == tid,
                  orElse: () => <String, dynamic>{},
                ),
              )
              .where((t) => t.isNotEmpty)
              .toList();

          if (list.isEmpty) {
            return Center(
              child: Text(
                texts['noTracks']!,
                style: TextStyle(color: colors['textDim']),
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  (buttons['icon']
                      as Widget Function(IconData, VoidCallback, double))(
                    iconsMap['back']!,
                    () => setPage('playlists'),
                    el,
                  ),
                  SizedBox(width: el),
                  Expanded(
                    child: Text(
                      pl['name'] ?? '',
                      style: TextStyle(
                        color: colors['text'],
                        fontSize: el * 1.2,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  (buttons['icon']
                      as Widget Function(IconData, VoidCallback, double))(
                    iconsMap['more']!,
                    () => openPlaylistActions(ctx, el, id!),
                    el,
                  ),
                ],
              ),
              SizedBox(height: el * .8),
              Expanded(
                child: ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  itemCount: list.length,
                  onReorder: (oldIndex, newIndex) async {
                    if (newIndex > oldIndex) newIndex -= 1;
                    await reorderPlaylist(id, oldIndex, newIndex);
                  },

                  itemBuilder: (ctx2, i) {
                    final t = list[i];
                    final artist = (t['artist'] ?? '').toString().trim();
                    final int dur = (t['duration'] ?? 0) as int;
                    final String meta =
                        '${artist.isEmpty ? texts['unknown']! : artist}'
                        '${dur > 0 ? ' • ${formatMs(dur)}' : ''}';

                    return Container(
                      key: ValueKey(t['id']),
                      padding: EdgeInsets.all(el * .6),
                      child: Row(
                        children: [
                          ReorderableDragStartListener(
                            index: i,
                            child: Icon(
                              iconsMap['drag']!,
                              color: colors['textDim'],
                            ),
                          ),
                          SizedBox(width: el),
                          artThumb(t, el),
                          SizedBox(width: el),
                          Expanded(
                            child: InkWell(
                              onTap: () => playById(t['id'] as String),
                              onLongPress: () => removeTrackFromPlaylist(
                                id!,
                                t['id'] as String,
                              ),
                              borderRadius: BorderRadius.circular(el),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    t['title'] ?? '',
                                    style: TextStyle(
                                      color: colors['text'],
                                      fontSize: el * 1.05,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(height: el * .2),
                                  Text(
                                    meta,
                                    style: TextStyle(
                                      color: colors['textDim'],
                                      fontSize: el,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () =>
                                removeTrackFromPlaylist(id!, t['id'] as String),
                            icon: const Icon(
                              Icons.remove_circle_outline,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<void> reorderPlaylist(
  String playlistId,
  int oldIndex,
  int newIndex,
) async {
  await ensureBoxes();
  final raw = playlistsBox!.get(playlistId);
  final Map<String, dynamic>? pl = raw is Map
      ? Map<String, dynamic>.from(raw)
      : null;
  if (pl == null) return;

  final ids = ((pl['trackIds'] ?? const <dynamic>[]) as List)
      .map((e) => e.toString())
      .toList();

  if (oldIndex < 0 || oldIndex >= ids.length) return;
  if (newIndex < 0 || newIndex >= ids.length) return;

  final moved = ids.removeAt(oldIndex);
  ids.insert(newIndex, moved);

  pl['trackIds'] = ids;
  await playlistsBox!.put(playlistId, pl);
  _reloadPlaylists();
}

final queueIds = ValueNotifier<List<String>>([]);
void _saveQueue() => prefsBox?.put('queueIds', queueIds.value);

void clearQueue() {
  queueIds.value = [];
  _saveQueue();
}

void enqueueEnd(String id) {
  final q = [...queueIds.value];
  q.add(id);
  queueIds.value = q;
  _saveQueue();
}

void enqueueNext(String id) {
  final q = [...queueIds.value];
  final cur = currentId.value;
  final insertAt = cur == null ? 0 : (q.indexOf(cur) + 1).clamp(0, q.length);
  q.insert(insertAt, id);
  queueIds.value = q;
  _saveQueue();
}

Widget queueView(double el) {
  return ValueListenableBuilder<List<String>>(
    valueListenable: queueIds,
    builder: (ctx, q, __) {
      if (q.isEmpty) {
        return Center(
          child: Text(
            texts['emptyQueue']!,
            style: TextStyle(color: colors['textDim'], fontSize: el * 1.05),
          ),
        );
      }

      final all = tracksList.value;
      final items = q
          .map(
            (id) => all.firstWhere(
              (t) => t['id'] == id,
              orElse: () => <String, dynamic>{
                'id': id,
                'title': 'Unknown',
                'artist': texts['unknown'],
              },
            ),
          )
          .toList();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              (buttons['icon']
                  as Widget Function(IconData, VoidCallback, double))(
                iconsMap['back']!,
                () => setPage('home'),
                el,
              ),
              SizedBox(width: el),
              Text(
                texts['queueTitle']!,
                style: TextStyle(
                  color: colors['text'],
                  fontSize: el * 1.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: clearQueue,
                child: Text(
                  texts['clearQueue']!,
                  style: TextStyle(color: colors['text']),
                ),
              ),
            ],
          ),
          SizedBox(height: el * .8),
          Expanded(
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              itemCount: items.length,
              onReorder: (oldIndex, newIndex) {
                if (newIndex > oldIndex) newIndex -= 1;
                reorderQueue(oldIndex, newIndex);
              },
              itemBuilder: (ctx2, i) {
                final t = items[i];
                final artist = (t['artist'] ?? '').toString().trim();
                final int dur = (t['duration'] ?? 0) as int;
                final String meta =
                    '${artist.isEmpty ? texts['unknown']! : artist}'
                    '${dur > 0 ? ' • ${formatMs(dur)}' : ''}';

                return Padding(
                  key: ValueKey(t['id']),
                  padding: EdgeInsets.all(el * .6),
                  child: Row(
                    children: [
                      ReorderableDragStartListener(
                        index: i,
                        child: Icon(
                          iconsMap['drag'] ?? Icons.drag_indicator_rounded,
                          color: colors['textDim'],
                        ),
                      ),
                      SizedBox(width: el),
                      artThumb(t, el),
                      SizedBox(width: el),
                      Expanded(
                        child: InkWell(
                          onTap: () => playById(t['id'] as String),
                          onLongPress: () {
                            final id = t['id'] as String;
                            final q2 = [...queueIds.value]..remove(id);
                            queueIds.value = q2;
                            _saveQueue();
                          },
                          borderRadius: BorderRadius.circular(el),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t['title'] ?? '',
                                style: TextStyle(
                                  color: colors['text'],
                                  fontSize: el * 1.05,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: el * .2),
                              Text(
                                meta,
                                style: TextStyle(
                                  color: colors['textDim'],
                                  fontSize: el,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          final id = t['id'] as String;
                          final q2 = [...queueIds.value]..remove(id);
                          queueIds.value = q2;
                          _saveQueue();
                        },
                        icon: const Icon(
                          Icons.remove_circle_outline,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      );
    },
  );
}

Future<void> deleteTrack(String id) async {
  await ensureBoxes();
  if (currentId.value == id) {
    await audio.stop();
    currentId.value = null;
  }
  await tracksBox?.delete(id);
  if (playlistsBox != null) {
    for (final key in playlistsBox!.keys) {
      final raw = playlistsBox!.get(key);
      final Map<String, dynamic>? pl = raw is Map
          ? Map<String, dynamic>.from(raw)
          : null;
      if (pl == null) continue;

      final ids =
          ((pl['trackIds'] ?? const <dynamic>[]) as List)
              .map((e) => e.toString())
              .toList()
            ..removeWhere((e) => e == id);

      pl['trackIds'] = ids;
      await playlistsBox!.put(key, pl);
    }
  }

  queueIds.value = [...queueIds.value]..removeWhere((e) => e == id);
  _saveQueue();
  webBytes.remove(id);
  _reloadTracks();
  _reloadPlaylists();
}

void reorderQueue(int oldIndex, int newIndex) {
  final q = [...queueIds.value];
  final item = q.removeAt(oldIndex);
  q.insert(newIndex, item);
  queueIds.value = q;
  _saveQueue();
}

void openTrackActions(BuildContext ctx, double el, String trackId) {
  showModalBottomSheet(
    context: ctx,
    backgroundColor: Colors.transparent,
    builder: (_) => Padding(
      padding: EdgeInsets.all(el * 1.2),
      child: glass(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.playlist_play_rounded,
                color: Colors.white,
              ),
              title: Text(
                texts['playNext']!,
                style: TextStyle(color: colors['text']),
              ),
              onTap: () {
                Navigator.pop(ctx);
                enqueueNext(trackId);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.queue_music_rounded,
                color: Colors.white,
              ),
              title: Text(
                texts['addToQueue']!,
                style: TextStyle(color: colors['text']),
              ),
              onTap: () {
                Navigator.pop(ctx);
                enqueueEnd(trackId);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.playlist_add_rounded,
                color: Colors.white,
              ),
              title: Text(
                texts['addToPlaylist']!,
                style: TextStyle(color: colors['text']),
              ),
              onTap: () {
                Navigator.pop(ctx);
                openAddToPlaylistSheet(ctx, el, trackId);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.white,
              ),
              title: Text(
                texts['deleteFromLibrary']!,
                style: TextStyle(color: colors['text']),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                final ok = await showDialog<bool>(
                  context: ctx,
                  builder: (_) => AlertDialog(
                    content: Text(texts['confirmDeleteTrack']!),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(texts['cancel']!),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(texts['delete']!),
                      ),
                    ],
                  ),
                );
                if (ok == true) {
                  await deleteTrack(trackId);
                }
              },
            ),
          ],
        ),
        el,
      ),
    ),
  );
}

Future<void> enqueueListEnd(List<String> ids) async {
  final q = [...queueIds.value]..addAll(ids);
  queueIds.value = q;
  _saveQueue();
}

Future<void> playListFromStart(List<String> ids) async {
  if (ids.isEmpty) return;
  queueIds.value = [...ids];
  _saveQueue();
  await playById(ids.first);
}

Future<void> renamePlaylist(String id, String newName) async {
  await ensureBoxes();
  final raw = playlistsBox!.get(id);
  final Map<String, dynamic>? pl = raw is Map
      ? Map<String, dynamic>.from(raw)
      : null;
  if (pl == null) return;
  pl['name'] = newName.trim();
  await playlistsBox!.put(id, pl);
  _reloadPlaylists();
}

Future<void> deletePlaylist(String id) async {
  await ensureBoxes();
  await playlistsBox!.delete(id);
  _reloadPlaylists();
  setPage('playlists');
}

void openPlaylistActions(BuildContext ctx, double el, String playlistId) {
  final raw = playlistsBox?.get(playlistId);
  final Map<String, dynamic>? pl = raw is Map
      ? Map<String, dynamic>.from(raw)
      : null;
  final ids = ((pl?['trackIds'] ?? const <dynamic>[]) as List)
      .map((e) => e.toString())
      .toList();

  showModalBottomSheet(
    context: ctx,
    backgroundColor: Colors.transparent,
    builder: (_) => Padding(
      padding: EdgeInsets.all(el * 1.2),
      child: glass(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.play_circle_fill_rounded,
                color: Colors.white,
              ),
              title: Text(
                texts['playAll']!,
                style: TextStyle(color: colors['text']),
              ),
              onTap: () {
                Navigator.pop(ctx);
                playListFromStart(ids);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.queue_music_rounded,
                color: Colors.white,
              ),
              title: Text(
                texts['addAllToQueue']!,
                style: TextStyle(color: colors['text']),
              ),
              onTap: () {
                Navigator.pop(ctx);
                enqueueListEnd(ids);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.drive_file_rename_outline_rounded,
                color: Colors.white,
              ),
              title: Text(
                texts['rename']!,
                style: TextStyle(color: colors['text']),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                final c = TextEditingController(
                  text: (pl?['name'] ?? '').toString(),
                );
                final ok = await showDialog<bool>(
                  context: ctx,
                  builder: (_) => AlertDialog(
                    contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          texts['rename']!,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        TextField(controller: c, autofocus: true),
                        const SizedBox(height: 8),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(texts['cancel']!),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(texts['create']!),
                      ),
                    ],
                  ),
                );
                if (ok == true) await renamePlaylist(playlistId, c.text);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.white,
              ),
              title: Text(
                texts['delete']!,
                style: TextStyle(color: colors['text']),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                final ok = await showDialog<bool>(
                  context: ctx,
                  builder: (_) => AlertDialog(
                    content: Text(texts['confirmDelete']!),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(texts['cancel']!),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(texts['delete']!),
                      ),
                    ],
                  ),
                );
                if (ok == true) await deletePlaylist(playlistId);
              },
            ),
          ],
        ),
        el,
      ),
    ),
  );
}

void cyclePlaybackMode() {
  const cycle = ['order', 'repeatAll', 'repeatOne', 'shuffle'];
  final current = playbackMode.value;
  final i = cycle.indexOf(current);
  final nextIndex = (i + 1) % cycle.length;
  final next = cycle[nextIndex];

  playbackMode.value = next;
  prefsBox?.put('playbackMode', next);
}

Future<void> pickAndImportFolder(BuildContext ctx) async {
  if (kIsWeb) {
    ScaffoldMessenger.of(ctx).showSnackBar(
      const SnackBar(
        content: Text(
          'Folder import is not supported on Web. Use file import instead.',
        ),
      ),
    );
    return;
  }

  if (io.Platform.isAndroid || io.Platform.isIOS) {
    await pickAndImportFiles(ctx);
    return;
  }

  final String? dirPath = await FilePicker.platform.getDirectoryPath();
  if (dirPath == null) return;

  await ensureBoxes();
  final dir = io.Directory(dirPath);

  try {
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is! io.File) continue;

      final path = entity.path;
      if (!_isAudio(path)) continue;

      final size = await entity.length();
      final name = p.basename(path);
      final platformFile = PlatformFile(path: path, name: name, size: size);
      if (_existsFile(platformFile)) continue;

      final now = DateTime.now().millisecondsSinceEpoch;
      final id = _fastId(path, now);
      final base = p.basenameWithoutExtension(path);

      String title = base;
      String artist = '';
      int duration = 0;
      Uint8List? art;
      String lyrics = '';

      try {
        final md = await MetadataRetriever.fromFile(io.File(path));
        final tp = TagProcessor();
        final fileBytes = await io.File(path).readAsBytes();
        final tags = await tp.getTagsFromByteArray(Future.value(fileBytes));
        lyrics = _pickLyrics(tags);

        final t = (md.trackName ?? '').trim();
        if (t.isNotEmpty) title = t;

        final names = (md.trackArtistNames ?? const <String>[])
            .where((e) => e.trim().isNotEmpty)
            .toList();
        if (names.isEmpty && (md.authorName ?? '').trim().isNotEmpty) {
          names.add(md.authorName!.trim());
        }
        artist = names.join(', ').trim();
        duration = md.trackDuration ?? 0;
        art = md.albumArt;

        if (title == base && artist.isEmpty) {
          final g = _guessMetaFromName(base);
          title = g['title']!;
          artist = g['artist']!;
        }
      } catch (e) {
        debugPrint('Metadata read failed for $path: $e');
        final g = _guessMetaFromName(base);
        title = g['title']!;
        artist = g['artist']!;
      }

      final track = <String, dynamic>{
        'id': id,
        'source': 'fs',
        'path': path,
        'name': name,
        'size': size,
        'title': title,
        'artist': artist,
        'album': '',
        'duration': duration,
        'art': art,
        'lyrics': lyrics,
        'addedAt': now,
      };

      await tracksBox!.put(id, track);
    }
  } catch (e) {
    debugPrint('Error scanning directory: $e');
  }

  _reloadTracks();
}

Widget nowPlayingView(double el) {
  return ValueListenableBuilder<String?>(
    valueListenable: currentId,
    builder: (ctx, id, __) {
      Map<String, dynamic>? t;
      if (id != null) {
        t = tracksList.value.cast<Map<String, dynamic>?>().firstWhere(
          (e) => e?['id'] == id,
          orElse: () => null,
        );
      }
      final title = ((t?['title'] ?? texts['trackSample']!) as String);
      final artistRaw = ((t?['artist'] ?? '') as String).trim();
      final artist = artistRaw.isEmpty ? texts['unknown']! : artistRaw;
      final durMs = (t?['duration'] ?? durationMs.value) as int;
      final lyrics = (t?['lyrics'] ?? '') as String;

      return scrollY(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                (buttons['icon']
                    as Widget Function(IconData, VoidCallback, double))(
                  iconsMap['back']!,
                  () => setPage('home'),
                  el,
                ),
                SizedBox(width: el),
                Expanded(
                  child: Text(
                    texts['queueTitle']!,
                    style: TextStyle(
                      color: colors['text'],
                      fontSize: el * 1.2,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: el * .6),
                (buttons['icon']
                    as Widget Function(IconData, VoidCallback, double))(
                  iconsMap['info']!,
                  () => openTrackInfoDialog(ctx, el, id),
                  el,
                ),
              ],
            ),
            SizedBox(height: el * 1.2),

            FlipCard(
              fill: Fill.fillBack,
              direction: FlipDirection.HORIZONTAL,
              front: AspectRatio(
                aspectRatio: 1,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(el),
                  child:
                      (t?['art'] is Uint8List &&
                          (t!['art'] as Uint8List).isNotEmpty)
                      ? Image.memory(t!['art'] as Uint8List, fit: BoxFit.cover)
                      : Image.asset(defaultArtPath, fit: BoxFit.cover),
                ),
              ),
              back: AspectRatio(
                aspectRatio: 1,
                child: Container(
                  padding: EdgeInsets.all(el),
                  decoration: BoxDecoration(
                    color: colors['accentDim']!.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(el),
                  ),
                  child: LyricsViewer(
                    trackId: id ?? '',
                    lyrics: lyrics,
                    el: el,
                    position: positionMs,
                    duration: durationMs,
                  ),
                ),
              ),
            ),

            SizedBox(height: el * 1.2),
            Text(
              title,
              style: TextStyle(
                color: colors['text'],
                fontSize: el * 1.6,
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: el * .4),
            Text(
              artist,
              style: TextStyle(color: colors['textDim'], fontSize: el * 1.05),
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: el),

            // time row + seek bar
            ValueListenableBuilder<int>(
              valueListenable: durationMs,
              builder: (_, dMs, __) => ValueListenableBuilder<int>(
                valueListenable: positionMs,
                builder: (_, pMs, __) {
                  final total = (durMs > 0 ? durMs : dMs);
                  final denom = total > 0 ? total : 1;
                  final frac = (pMs / denom).clamp(0.0, 1.0);
                  return Column(
                    children: [
                      Row(
                        children: [
                          Text(
                            formatMs(pMs),
                            style: TextStyle(
                              color: colors['textDim'],
                              fontSize: el * .9,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            formatMs(total),
                            style: TextStyle(
                              color: colors['textDim'],
                              fontSize: el * .9,
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: frac.toDouble(),
                        min: 0.0,
                        max: 1.0,
                        activeColor: colors['accent'],
                        inactiveColor: Colors.white.withOpacity(0.25),
                        onChanged: (v) {
                          seekToFraction(v);
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
            SizedBox(height: el * 1.2),

            // controls: prev / play|pause / next
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                (buttons['icon']
                    as Widget Function(IconData, VoidCallback, double))(
                  iconsMap['prev']!,
                  () => playPrev(),
                  el * 1.1,
                ),
                SizedBox(width: el),
                ValueListenableBuilder<bool>(
                  valueListenable: isPlaying,
                  builder: (_, playing, __) =>
                      (buttons['icon']
                          as Widget Function(IconData, VoidCallback, double))(
                        playing ? iconsMap['pause']! : iconsMap['play']!,
                        () => togglePlay(),
                        el * 1.4,
                      ),
                ),
                SizedBox(width: el),
                (buttons['icon']
                    as Widget Function(IconData, VoidCallback, double))(
                  iconsMap['next']!,
                  () => playNext(),
                  el * 1.1,
                ),
              ],
            ),
            SizedBox(height: el),

            // playback mode toggles
            ValueListenableBuilder<String>(
              valueListenable: playbackMode,
              builder: (_, mode, __) {
                IconData icon;
                switch (mode) {
                  case 'repeatAll':
                    icon = iconsMap['repeat']!;
                    break;
                  case 'repeatOne':
                    icon = iconsMap['repeatOne']!;
                    break;
                  case 'shuffle':
                    icon = iconsMap['shuffle']!;
                    break;
                  case 'order':
                  default:
                    icon = iconsMap['order']!;
                }
                return Center(
                  child:
                      (buttons['icon']
                          as Widget Function(IconData, VoidCallback, double))(
                        icon,
                        () => cyclePlaybackMode(),
                        el,
                      ),
                );
              },
            ),
            SizedBox(height: el),
          ],
        ),
      );
    },
  );
}

Future<void> stopAndHidePlayer() async {
  await ensureAudio();
  await audio.stop();
  currentId.value = null;
  positionMs.value = 0;
  durationMs.value = 0;
  prefsBox?.delete('lastPlayedId');
}

Future<void> updateTrackLyrics(String trackId, String newLyrics) async {
  await ensureBoxes();
  if (trackId.isEmpty) return;
  final raw = tracksBox!.get(trackId);
  final Map<String, dynamic>? t = raw is Map
      ? Map<String, dynamic>.from(raw)
      : null;
  if (t == null) return;

  final newTrack = {...t, 'lyrics': newLyrics};
  await tracksBox!.put(trackId, newTrack);

  final list = [...tracksList.value];
  final index = list.indexWhere((e) => e['id'] == trackId);
  if (index != -1) {
    list[index] = newTrack;
    tracksList.value = list;
  }
}

void openTrackInfoDialog(BuildContext ctx, double el, String? trackId) {
  if (trackId == null) return;
  final raw = tracksBox!.get(trackId);
  final Map<String, dynamic>? t = raw is Map
      ? Map<String, dynamic>.from(raw)
      : null;
  if (t == null) return;

  Widget infoTile(String title, String subtitle) {
    if (subtitle.isEmpty || subtitle == 'N/A') {
      return const SizedBox.shrink(); // Не показывать пустые поля
    }
    return ListTile(
      visualDensity: VisualDensity.compact,
      title: Text(title, style: TextStyle(color: colors['textDim'])),
      subtitle: Text(subtitle, style: TextStyle(color: colors['text'])),
    );
  }

  final art = t['art'] as Uint8List?;
  final sizeMB = ((t['size'] ?? 0) as int) / (1024 * 1024);

  showModalBottomSheet(
    context: ctx,
    backgroundColor: Colors.transparent,
    builder: (_) => Padding(
      padding: EdgeInsets.all(el * 1.2),
      child: glass(
        ListView(
          shrinkWrap: true,
          children: [
            infoTile('Title', (t['title'] ?? texts['unknown']) as String),
            infoTile('Artist', (t['artist'] ?? texts['unknown']) as String),
            infoTile('Duration', formatMs((t['duration'] ?? 0) as int)),
            infoTile('File Path', (t['path'] ?? 'N/A') as String),
            infoTile('File Name', (t['name'] ?? 'N/A') as String),
            infoTile('Size', '${sizeMB.toStringAsFixed(2)} MB'),
            infoTile(
              'Added',
              DateTime.fromMillisecondsSinceEpoch(
                (t['addedAt'] ?? 0) as int,
              ).toIso8601String().substring(0, 16),
            ),
            infoTile(
              'Has Cover Art',
              (art != null && art.isNotEmpty)
                  ? 'Yes (${(art.lengthInBytes / 1024).toStringAsFixed(1)} KB)'
                  : 'No',
            ),
          ],
        ),
        el,
      ),
    ),
  );
}

class LyricsViewer extends StatefulWidget {
  final String trackId;
  final String lyrics;
  final double el;
  final ValueNotifier<int> position;
  final ValueNotifier<int> duration;

  const LyricsViewer({
    super.key,
    required this.trackId,
    required this.lyrics,
    required this.el,
    required this.position,
    required this.duration,
  });

  @override
  State<LyricsViewer> createState() => _LyricsViewerState();
}

class _LyricsViewerState extends State<LyricsViewer> {
  final ScrollController _scrollController = ScrollController();
  late final TextEditingController _textController;
  bool _isScrolling = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    widget.position.addListener(_autoScroll);
    _textController = TextEditingController(text: widget.lyrics);
  }

  @override
  void dispose() {
    widget.position.removeListener(_autoScroll);
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(LyricsViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.lyrics != oldWidget.lyrics) {
      _textController.text = widget.lyrics;
    }
  }

  void _autoScroll() {
    if (_isEditing || _isScrolling || !_scrollController.hasClients) return;
    final dur = widget.duration.value;
    final pos = widget.position.value;
    if (dur <= 0 || pos < 0) return;

    final frac = (pos / dur).clamp(0.0, 1.0);
    final max = _scrollController.position.maxScrollExtent;

    _scrollController.animateTo(
      max * frac,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Widget _buildEditor() {
    return Column(
      children: [
        Expanded(
          child: TextField(
            controller: _textController,
            maxLines: null,
            expands: true,
            autofocus: true,
            style: TextStyle(color: colors['text'], fontSize: widget.el * 1.1),
            decoration: const InputDecoration(border: InputBorder.none),
          ),
        ),
        SizedBox(height: widget.el * .6),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => setState(() => _isEditing = false),
              child: Text(
                texts['cancel']!,
                style: TextStyle(color: colors['textDim']),
              ),
            ),
            SizedBox(width: widget.el * .6),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colors['accent'],
                foregroundColor: colors['text'],
              ),
              onPressed: () async {
                await updateTrackLyrics(widget.trackId, _textController.text);
                setState(() => _isEditing = false);
              },
              child: Text(texts['save']!), // <-- Добавьте 'save' в 'texts'
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildViewer() {
    final hasLyrics = _textController.text.isNotEmpty;
    final canEdit = widget.trackId.isNotEmpty;

    return Column(
      children: [
        Expanded(
          child: hasLyrics
              ? Listener(
                  onPointerDown: (_) => _isScrolling = true,
                  onPointerUp: (_) => _isScrolling = false,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    child: Text(
                      _textController.text,
                      style: TextStyle(
                        color: colors['text'],
                        fontSize: widget.el * 1.3,
                        height: 1.8,
                      ),
                    ),
                  ),
                )
              : Center(
                  child: Text(
                    'No lyrics found for this track.',
                    style: TextStyle(
                      color: colors['textDim'],
                      fontSize: widget.el,
                    ),
                  ),
                ),
        ),
        SizedBox(height: widget.el * .6),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: canEdit
                  ? () => setState(() => _isEditing = true)
                  : null,
              child: Text(
                hasLyrics ? 'Edit Lyrics' : 'Add Lyrics',
                style: TextStyle(
                  color: canEdit ? colors['text']! : colors['textDim']!,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return _isEditing ? _buildEditor() : _buildViewer();
  }
}

String _pickLyrics(List<Tag> tags) {
  for (final t in tags) {
    final v = t.tags['lyrics'] ?? t.tags['USLT'];
    if (v != null) {
      final s = v.toString().trim();
      if (s.isNotEmpty) return s;
    }
  }
  return '';
}

void _toggleTrackSelection(String id) {
  final newSet = {...selectedTrackIds.value};
  if (newSet.contains(id)) {
    newSet.remove(id);
  } else {
    newSet.add(id);
  }
  selectedTrackIds.value = newSet;
}

void _startSelectionMode([String? initialId]) {
  isSelectionMode.value = true;
  final newSet = <String>{};
  if (initialId != null) {
    newSet.add(initialId);
  }
  selectedTrackIds.value = newSet;
}

void _cancelSelectionMode() {
  isSelectionMode.value = false;
  selectedTrackIds.value = {};
}

void _selectAllTracks() {
  final allIds = tracksList.value.map((t) => t['id'] as String).toSet();
  selectedTrackIds.value = allIds;
}

Future<void> _deleteSelectedTracks(BuildContext ctx) async {
  final idsToDelete = {...selectedTrackIds.value};
  if (idsToDelete.isEmpty) {
    _cancelSelectionMode();
    return;
  }

  final ok = await showDialog<bool>(
    context: ctx,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      content: Text('Delete ${idsToDelete.length} tracks from library?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(texts['cancel']!),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(texts['delete']!),
        ),
      ],
    ),
  );

  if (ok != true) return;

  for (final id in idsToDelete) {
    await deleteTrack(id);
  }
  _cancelSelectionMode();
}

void openTopMoreMenu(BuildContext ctx, double el) {
  showModalBottomSheet(
    context: ctx,
    backgroundColor: Colors.transparent,
    builder: (_) => Padding(
      padding: EdgeInsets.all(el * 1.2),
      child: glass(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(iconsMap['add']!, color: colors['text']),
              title: Text(
                texts['addMusic']!,
                style: TextStyle(color: colors['text']),
              ),
              onTap: () {
                Navigator.pop(ctx);
                openAddMenu(ctx, el);
              },
            ),
            ListTile(
              leading: Icon(iconsMap['sort']!, color: colors['text']),
              title: Text(
                texts['sort']!,
                style: TextStyle(color: colors['text']),
              ),
              onTap: () {
                Navigator.pop(ctx);
                openSortSheet(ctx, el);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.check_box_outline_blank_rounded,
                color: colors['text'],
              ),
              title: Text(
                'Select Tracks',
                style: TextStyle(color: colors['text']),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _startSelectionMode();
              },
            ),
            ListTile(
              leading: Icon(iconsMap['settings']!, color: colors['text']),
              title: Text(
                texts['settings']!,
                style: TextStyle(color: colors['text']),
              ),
              onTap: () {
                Navigator.pop(ctx);
                setPage('settings');
              },
            ),
          ],
        ),
        el,
      ),
    ),
  );
}

// =========== SETTINGS STATE ===========
final uiScale = ValueNotifier<double>(1.0);
final themeId = ValueNotifier<String>('glass');

final List<Map<String, dynamic>> sizePresets = [
  {'label': 'Small', 'value': 0.90},
  {'label': 'Normal', 'value': 1.00},
  {'label': 'Large', 'value': 1.15},
  {'label': 'XL', 'value': 1.30},
];

final Map<String, Map<String, Color>> themes = {
  'glass': {
    'bg1': const Color(0xFFBFD9FF),
    'bg2': const Color(0xFF9FC3FF),
    'glass': const Color(0x33FFFFFF),
    'glassBorder': const Color(0x22FFFFFF),
    'text': Colors.white,
    'textDim': Colors.white70,
    'accent': const Color(0xFF7A4DFF),
    'accentDim': const Color(0x337A4DFF),
    'shadow': const Color(0x33000000),
  },
  'dark': {
    'bg1': const Color(0xFF111318),
    'bg2': const Color(0xFF0B0C10),
    'glass': const Color(0x18000000),
    'glassBorder': const Color(0x33000000),
    'text': Colors.white,
    'textDim': Colors.white70,
    'accent': const Color(0xFF7A4DFF),
    'accentDim': const Color(0x337A4DFF),
    'shadow': const Color(0x66000000),
  },
  'light': {
    'bg1': const Color(0xFFF0F3FF),
    'bg2': const Color(0xFFE7EDFF),
    'glass': const Color(0x44FFFFFF),
    'glassBorder': const Color(0x22FFFFFF),
    'text': const Color(0xFF111111),
    'textDim': const Color(0x99111111),
    'accent': const Color(0xFF7A4DFF),
    'accentDim': const Color(0x227A4DFF),
    'shadow': const Color(0x1A000000),
  },
};

void setUiScale(double v) {
  final clamped = v.clamp(0.80, 1.40);
  uiScale.value = clamped;
  prefsBox?.put('uiScale', clamped);
}

void setTheme(String id) {
  if (!themes.containsKey(id)) return;
  themeId.value = id;
  prefsBox?.put('theme', id);
  _applyTheme(id);
}

void _applyTheme(String id) {
  final t = themes[id];
  if (t == null) return;
  for (final entry in t.entries) {
    if (colors.containsKey(entry.key)) {
      colors[entry.key] = entry.value;
    }
  }
}

Widget settingsView(double el) {
  return ValueListenableBuilder3<double, String, String>(
    first: uiScale,
    second: themeId,
    third: backgroundId,
    builder: (_, scale, theme, bgId, __) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ===== THEMES =====
          Text(
            texts['themes']!,
            style: TextStyle(
              color: colors['text'],
              fontSize: el * 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: el * .6),
          Wrap(
            spacing: el * .6,
            runSpacing: el * .6,
            children: [
              for (final opt in ['glass', 'dark', 'light'])
                ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(iconsMap['theme'], size: el * 1.2),
                      SizedBox(width: el * .4),
                      Text(opt[0].toUpperCase() + opt.substring(1)),
                    ],
                  ),
                  selected: theme == opt,
                  onSelected: (_) => setTheme(opt),
                ),
            ],
          ),
          SizedBox(height: el * 1.2),

          Text(
            texts['backgrounds']!,
            style: TextStyle(
              color: colors['text'],
              fontSize: el * 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: el * .6),
          Wrap(
            spacing: el * .6,
            runSpacing: el * .6,
            children: [
              for (final id in backgrounds.keys)
                ChoiceChip(
                  label: Text(id[0].toUpperCase() + id.substring(1)),
                  selected: bgId == id,
                  onSelected: (_) => setBackground(id),
                ),
            ],
          ),
          SizedBox(height: el * 1.2),
          // ===== SIZES =====
          Text(
            texts['sizes']!,
            style: TextStyle(
              color: colors['text'],
              fontSize: el * 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: el * .6),
          Row(
            children: [
              Icon(iconsMap['size'], color: colors['textDim']),
              SizedBox(width: el * .6),
              Expanded(
                child: Slider(
                  value: scale,
                  min: 0.80,
                  max: 1.40,
                  divisions: 12,
                  label: scale.toStringAsFixed(2),
                  activeColor: colors['accent'],
                  inactiveColor: Colors.white.withOpacity(.25),
                  onChanged: (v) => setUiScale(v),
                ),
              ),
            ],
          ),
          SizedBox(height: el * .4),
          Wrap(
            spacing: el * .6,
            runSpacing: el * .6,
            children: [
              for (final p in sizePresets)
                InputChip(
                  label: Text(p['label'] as String),
                  selected: (p['value'] as double) == scale,
                  onPressed: () => setUiScale(p['value'] as double),
                ),
            ],
          ),
        ],
      );
    },
  );
}

class ValueListenableBuilder2<A, B> extends StatelessWidget {
  const ValueListenableBuilder2({
    super.key,
    required this.first,
    required this.second,
    required this.builder,
  });

  final ValueListenable<A> first;
  final ValueListenable<B> second;
  final Widget Function(BuildContext, A, B, Widget?) builder;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<A>(
      valueListenable: first,
      builder: (context, a, _) {
        return ValueListenableBuilder<B>(
          valueListenable: second,
          builder: (context, b, __) => builder(context, a, b, null),
        );
      },
    );
  }
}

Widget _buildSettingsTopBar(BuildContext ctx, double el) {
  final iconBtn =
      buttons['icon'] as Widget Function(IconData, VoidCallback, double);

  return Row(
    children: [
      iconBtn(iconsMap['back']!, () => setPage('home'), el),
      SizedBox(width: el),
      Expanded(
        child: Text(
          texts['settings']!,
          style: TextStyle(
            fontSize: el * 1.6,
            color: colors['text'],
            fontWeight: FontWeight.w700,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );
}

final Map<String, List<Color>> backgrounds = {
  'sky': [const Color(0xFFBFD9FF), const Color(0xFF9FC3FF)],
  'ocean': [
    const Color(0xFF005C97),
    const Color(0xFF363795),
    const Color(0xFF0083B0),
  ],
  'sunset': [
    const Color(0xFFff7e5f), // оранжевый
    const Color(0xFFfeb47b), // персиковый
    const Color(0xFF8a2387), // фиолетовый
  ],
  'forest': [const Color(0xFF136a8a), const Color(0xFF267871)],
};

void setBackground(String id) {
  if (!backgrounds.containsKey(id)) return;
  backgroundId.value = id;
  prefsBox?.put('background', id);
}

class ValueListenableBuilder3<A, B, C> extends StatelessWidget {
  const ValueListenableBuilder3({
    super.key,
    required this.first,
    required this.second,
    required this.third,
    required this.builder,
  });

  final ValueListenable<A> first;
  final ValueListenable<B> second;
  final ValueListenable<C> third;
  final Widget Function(BuildContext, A, B, C, Widget?) builder;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<A>(
      valueListenable: first,
      builder: (context, a, _) {
        return ValueListenableBuilder<B>(
          valueListenable: second,
          builder: (context, b, __) {
            return ValueListenableBuilder<C>(
              valueListenable: third,
              builder: (context, c, ___) => builder(context, a, b, c, null),
            );
          },
        );
      },
    );
  }
}

class AppAudioHandler extends BaseAudioHandler with SeekHandler {
  AppAudioHandler() {
    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        playing: false,
        processingState: AudioProcessingState.ready,
      ),
    );

    audio.onPlayerStateChanged.listen((s) {
      final playing = s == PlayerState.playing;
      _broadcast(playing: playing);
    });
    audio.onDurationChanged.listen((d) {
      final item = mediaItem.value;
      if (item != null) {
        mediaItem.add(item.copyWith(duration: d));
      }
    });
    audio.onPositionChanged.listen((p) {
      _broadcast(position: p);
    });
  }

  void _broadcast({bool? playing, Duration? position}) {
    final curPlaying = playing ?? playbackState.value.playing;
    final pos = position ?? (playbackState.value.position);
    playbackState.add(
      playbackState.value.copyWith(
        controls: curPlaying
            ? const [
                MediaControl.skipToPrevious,
                MediaControl.pause,
                MediaControl.skipToNext,
              ]
            : const [
                MediaControl.skipToPrevious,
                MediaControl.play,
                MediaControl.skipToNext,
              ],
        playing: curPlaying,
        processingState: AudioProcessingState.ready,
        updatePosition: pos,
      ),
    );
  }

  @override
  Future<void> play() => togglePlay();
  @override
  Future<void> pause() => togglePlay();
  @override
  Future<void> stop() => audio.stop();
  @override
  Future<void> seek(Duration pos) => audio.seek(pos);
  @override
  Future<void> skipToNext() => playNext();
  @override
  Future<void> skipToPrevious() => playPrev();
}
