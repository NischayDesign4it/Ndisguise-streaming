import 'dart:async';
import 'dart:convert';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:haishin_kit/audio_settings.dart';
import 'package:haishin_kit/audio_source.dart';
import 'package:haishin_kit/rtmp_connection.dart';
import 'package:haishin_kit/rtmp_stream.dart';
import 'package:haishin_kit/stream_view_texture.dart';
import 'package:haishin_kit/video_settings.dart';
import 'package:haishin_kit/video_source.dart';
import 'package:haishin_kit_example/camera_live_controller.dart';
import 'package:haishin_kit_example/models/live_stream_state.dart';
import 'package:permission_handler/permission_handler.dart';
import 'background_service.dart';
import 'package:http/http.dart' as http;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeService();

  const String server = "rtmp://live.twitch.tv/app/";
  const streamKey = "live_681536046_qbeaUskvqTi3ISMiGMNsmZm2RCh1HE";

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Example2(
          server: server,
          streamKey: streamKey,
        ),
      ),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  RtmpConnection? _connection;
  RtmpStream? _stream;
  bool _recording = false;
  String _mode = "publish";

  CameraPosition currentPosition = CameraPosition.back;

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  @override
  void dispose() {
    _stream?.dispose();
    _connection?.dispose();
    super.dispose();
  }

  Future<void> initPlatformState() async {
    await Permission.camera.request();
    await Permission.microphone.request();

    // Set up AVAudioSession for iOS.
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
      avAudioSessionCategoryOptions:
      AVAudioSessionCategoryOptions.allowBluetooth,
    ));

    RtmpConnection connection = await RtmpConnection.create();
    connection.eventChannel.receiveBroadcastStream().listen((event) {
      print("event: $event");
      switch (event["data"]["code"]) {
        case 'NetConnection.Connect.Success':
          if (_mode == "publish") {
            _stream?.publish("live");
          } else {
            _stream?.play("live");
          }
          setState(() {
            _recording = true;
          });
          break;
      }
    });

    RtmpStream stream = await RtmpStream.create(connection);
    stream.audioSettings = AudioSettings(bitrate: 64 * 1000);
    stream.videoSettings = VideoSettings(
      width: 480,
      height: 272,
      bitrate: 512 * 1000,
    );
    stream.attachAudio(AudioSource());
    stream.attachVideo(VideoSource(position: currentPosition));

    if (!mounted) return;

    setState(() {
      _connection = connection;
      _stream = stream;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: _stream == null ? const Text("") : StreamViewTexture(_stream),
        ),
      ),
    );
  }
}

class Example2 extends StatefulWidget {
  final String server;
  final String streamKey;

  const Example2({
    super.key,
    required this.server,
    required this.streamKey,
  });

  @override
  State<Example2> createState() => Example2State();
}

// class Example2State extends State<Example2> {
//   late final CameraLiveStreamController _controller;
//   late StreamSubscription<LiveStreamState> _subscription;
//   late LiveStreamState _currentState;
//   bool _audioSessionConfigured = false;
//   Timer? _timer;
//
//   @override
//   void initState() {
//     super.initState();
//     _controller = CameraLiveStreamController(
//       widget.server,
//       widget.streamKey,
//     )..initialize();
//
//     _init();
//
//     _subscription = _controller.stateStream.listen((event) {
//       print("Live stream state changed: ${event.status}");
//       if (_currentState != event) {
//         setState(() {
//           _currentState = event;
//         });
//       }
//     });
//
//     _currentState = _controller.state;
//
//     // Start polling the API for status
//     _startPolling();
//   }
//
//   void _init() async {
//     await Permission.camera.request();
//     await Permission.microphone.request();
//
//     _audioSessionConfigured = await configureAudioSession();
//
//     setState(() {});
//   }
//
//   void _startPolling() {
//     _timer = Timer.periodic(Duration(milliseconds: 500), (timer) async {
//       final status = await _fetchStreamingStatus();
//       print("Fetched streaming status: $status");
//
//       if (status == true && _currentState.status != LiveStreamStatus.living) {
//         print("Starting stream...");
//         _controller.startStreaming();
//       } else if (status == false && _currentState.status == LiveStreamStatus.living) {
//         print("Stopping stream...");
//         _controller.stopStreaming();
//       }
//     });
//   }
//
//   Future<bool> _fetchStreamingStatus() async {
//     try {
//       final response = await http.get(Uri.parse('http://54.205.106.103:8000/api/status/'));
//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);
//         print("API Response: $data");
//
//         // Ensure case insensitivity and handle boolean conversion
//         final status = data['Status']?.toString().toLowerCase();
//         if (status == 'true' || status == '1') {
//           return true;
//         } else {
//           return false;
//         }
//       } else {
//         print("Failed to load streaming status, status code: ${response.statusCode}");
//         return false;
//       }
//     } catch (e) {
//       print("Error fetching streaming status: $e");
//       return false;
//     }
//   }
//
//   @override
//   void dispose() {
//     _subscription.cancel();
//     _controller.dispose();
//     _timer?.cancel();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("Live Stream Example"),
//       ),
//       body: _buildBodyView(),
//     );
//   }
//
//   Widget _buildBodyView() {
//     if (_currentState.status == LiveStreamStatus.idle) {
//       return const Center(
//         child: Text("Configuring Camera..."),
//       );
//     } else if (_currentState.status == LiveStreamStatus.connected ||
//         _currentState.status == LiveStreamStatus.initialized ||
//         _currentState.status == LiveStreamStatus.living) {
//       return LiveStreamPreview(
//         textureManager: _controller,
//         state: _currentState,
//       );
//     } else {
//       return const Center(
//         child: Text("Live stream stopped or disconnected."),
//       );
//     }
//   }
// }


class Example2State extends State<Example2> {
  late final CameraLiveStreamController _controller;
  late StreamSubscription<LiveStreamState> _subscription;
  late LiveStreamState _currentState;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = CameraLiveStreamController(
      widget.server,
      widget.streamKey,
    )..initialize();

    _init();

    _subscription = _controller.stateStream.listen((event) {
      print("Live stream state changed: ${event.status}");
      if (_currentState != event) {
        setState(() {
          _currentState = event;
        });
      }
    });

    _currentState = _controller.state;

    // Start polling the API for status
    _startPolling();
  }

  void _init() async {
    await Permission.camera.request();
    await Permission.microphone.request();
    // Initialize the camera, audio session setup if needed
    setState(() {});
  }

  void _startPolling() {
    _timer = Timer.periodic(Duration(milliseconds: 500), (timer) async {
      final status = await _fetchStreamingStatus();
      print("Fetched streaming status: $status");

      if (status == true && _currentState.status != LiveStreamStatus.living) {
        print("Starting stream...");
        _controller.startStreaming();
      } else if (status == false && _currentState.status == LiveStreamStatus.living) {
        print("Stopping stream...");
        _controller.stopStreaming();
      }
    });
  }

  Future<bool> _fetchStreamingStatus() async {
    try {
      final response = await http.get(Uri.parse('http://54.205.106.103:8000/api/status/'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("API Response: $data");

        final status = data['Status']?.toString().toLowerCase();
        return status == 'true' || status == '1';
      } else {
        print("Failed to load streaming status, status code: ${response.statusCode}");
        return false;
      }
    } catch (e) {
      print("Error fetching streaming status: $e");
      return false;
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    _controller.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Live Stream Example"),
      ),
      body: _buildBodyView(),
    );
  }

  Widget _buildBodyView() {
    if (_currentState.status == LiveStreamStatus.idle) {
      return const Center(
        child: Text("Configuring Camera..."),
      );
    } else if (_currentState.status == LiveStreamStatus.connected ||
        _currentState.status == LiveStreamStatus.initialized ||
        _currentState.status == LiveStreamStatus.living) {
      return LiveStreamPreview(
        textureManager: _controller,
        state: _currentState,
      );
    } else {
      return
        Center(
        child: Text("Live stream stopped or disconnected."),
      );
    }
  }
}



class LiveStreamPreview extends StatefulWidget {
  final LiveStreamTextureMixin textureManager;
  final LiveStreamState state;

  const LiveStreamPreview({
    super.key,
    required this.textureManager,
    required this.state,
  });

  @override
  State<LiveStreamPreview> createState() => _LiveStreamPreviewState();
}

class _LiveStreamPreviewState extends State<LiveStreamPreview> {
  int? _textureId;

  @override
  void initState() {
    super.initState();

    if (widget.textureManager.textureId == null) {
      _registerTexture();
    } else {
      _textureId = widget.textureManager.textureId;
    }
  }

  void _updateTextureSize() {
    final mediaSize = MediaQuery.of(context).size;

    widget.textureManager.updateTextureSize(mediaSize);
  }

  void _registerTexture() async {
    final textureId = await widget.textureManager.registerTexture();
    setState(() {
      _textureId = textureId;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_textureId == null) {
      return const Center(
        child: Text("No available video preview.\nProbably this device "
            "does not support video preview."),
      );
    }
    _updateTextureSize();

    final orientation = MediaQuery.of(context).orientation;

    final resolution = widget.state.videoResolution;

    final aspectRatio = orientation == Orientation.portrait
        ? 1 / resolution.aspectRatio
        : resolution.aspectRatio;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.red, width: 2),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Colors.black),
          Align(
            child: AspectRatio(
              aspectRatio: aspectRatio,
              child: Texture(
                textureId: _textureId!,
              ),
            ),
          )
        ],
      ),
    );
  }
}




