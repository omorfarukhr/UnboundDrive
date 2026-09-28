import 'dart:typed_data';
import 'package:flutter/material.dart';

import 'real_video_player_stub.dart'
    if (dart.library.html) 'real_video_player_web.dart' as impl;

class RealVideoPlayerWidget extends StatelessWidget {
  final String videoId;
  final Uint8List videoBytes;
  final String fileName;
  final String extension;

  const RealVideoPlayerWidget({
    super.key,
    required this.videoId,
    required this.videoBytes,
    required this.fileName,
    required this.extension,
  });

  @override
  Widget build(BuildContext context) {
    return impl.buildPlatformVideoPlayer(
      videoId: videoId,
      videoBytes: videoBytes,
      fileName: fileName,
      extension: extension,
    );
  }
}
