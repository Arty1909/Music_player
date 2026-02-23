// main.dart
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:player/style.dart';
import 'style.dart' as style;

//late AppAudioHandler audioHandler;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ensureBoxes();
  // await ensureAudio();

  style.audioHandler = await AudioService.init(
    builder: () => style.AppAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'glass.player.playback',
      androidNotificationChannelName: 'Playback',
      androidStopForegroundOnPause: false,
      androidResumeOnClick: true,
    ),
  );

  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: texts['app'] ?? 'Glass Player',
      theme: ThemeData(useMaterial3: true),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // ⬇️ Перенесено из build: теперь флаг живёт между перестройками.
  bool _bgFlip = false;

  @override
  void initState() {
    super.initState();
    ensureBoxes();
    ensureAudio();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: uiScale,
      builder: (context, scale, _) {
        final el = elOf(context);

        return Scaffold(
          drawer: appDrawer(el),
          backgroundColor: Colors.transparent,
          body: ValueListenableBuilder<String>(
            valueListenable: backgroundId,
            builder: (context, bgId, _) {
              final bgColors = backgrounds[bgId] ?? backgrounds['sky']!;
              Widget backgroundBuilder;

              if (bgId == 'sky') {
                backgroundBuilder = Container(decoration: appBackground());
              } else {
                backgroundBuilder = AnimatedContainer(
                  duration: const Duration(seconds: 10),
                  onEnd: () => setState(() => _bgFlip = !_bgFlip),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: _bgFlip ? bgColors.reversed.toList() : bgColors,
                    ),
                  ),
                );
              }

              return Stack(
                children: [
                  Positioned.fill(child: backgroundBuilder),
                  SafeArea(
                    child: ValueListenableBuilder<String>(
                      valueListenable: currentPage,
                      builder: (context, page, _) {
                        if (page == 'now') {
                          return Padding(
                            padding: EdgeInsets.all(el * 1.2),
                            child: nowPlayingView(el),
                          );
                        }
                        return Padding(
                          padding: EdgeInsets.all(el * 1.2),
                          child: Column(
                            children: [
                              topBar(context, el),
                              SizedBox(height: el),
                              Expanded(
                                child: glass(
                                  ValueListenableBuilder<String>(
                                    valueListenable: currentPage,
                                    builder: (_, page, __) {
                                      final Widget content = switch (page) {
                                        'playlists' => playlistsView(el),
                                        'playlist' => playlistView(el),
                                        'queue' => queueView(el),
                                        'settings' => settingsView(el),
                                        _ => libraryView(el),
                                      };

                                      final needsScroll =
                                          !(page == 'queue' ||
                                              page == 'playlist');
                                      return needsScroll
                                          ? scrollY(content)
                                          : content;
                                    },
                                  ),
                                  el,
                                ),
                              ),
                              SizedBox(height: el * .6),
                              ValueListenableBuilder<String?>(
                                valueListenable: currentId,
                                builder: (_, id, __) {
                                  if (id == null || page == 'now') {
                                    return const SizedBox.shrink();
                                  }
                                  return glass(
                                    InkWell(
                                      onTap: () => setPage('now'),
                                      child: miniPlayer(el),
                                    ),
                                    el,
                                  );
                                },
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
          ),
        );
      },
    );
  }
}
