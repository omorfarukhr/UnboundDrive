import 'dart:io' as io;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import '../../../../../app/theme/app_colors.dart';

Widget buildPlatformVideoPlayer({
  required String videoId,
  Uint8List? videoBytes,
  String? videoUrl,
  required String fileName,
  required String extension,
}) {
  return NativeVideoPlayerWidget(
    videoId: videoId,
    videoBytes: videoBytes,
    videoUrl: videoUrl,
    fileName: fileName,
    extension: extension,
  );
}

class NativeVideoPlayerWidget extends StatefulWidget {
  final String videoId;
  final Uint8List? videoBytes;
  final String? videoUrl;
  final String fileName;
  final String extension;

  const NativeVideoPlayerWidget({
    super.key,
    required this.videoId,
    this.videoBytes,
    this.videoUrl,
    required this.fileName,
    required this.extension,
  });

  @override
  State<NativeVideoPlayerWidget> createState() => _NativeVideoPlayerWidgetState();
}

class _NativeVideoPlayerWidgetState extends State<NativeVideoPlayerWidget> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  String? _errorMessage;
  String? _localTempPath;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      if (widget.videoBytes != null && widget.videoBytes!.isNotEmpty) {
        final tempDir = await getTemporaryDirectory();
        final ext = widget.extension.isNotEmpty ? widget.extension : 'mp4';
        final tempFile = io.File('${tempDir.path}/unbound_preview_${widget.videoId}.$ext');
        await tempFile.writeAsBytes(widget.videoBytes!, flush: true);
        _localTempPath = tempFile.path;

        _controller = VideoPlayerController.file(tempFile);
      } else if (widget.videoUrl != null && widget.videoUrl!.isNotEmpty) {
        if (widget.videoUrl!.startsWith('http://') || widget.videoUrl!.startsWith('https://')) {
          _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl!));
        } else {
          throw Exception("No video source provided.");
        }
      } else {
        throw Exception("No video source provided.");
      }

      await _controller!.initialize();
      _controller!.setLooping(true);
      _controller!.play();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _openInExternalPlayer() {
    if (_localTempPath != null && io.File(_localTempPath!).existsSync()) {
      OpenFilex.open(_localTempPath!);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Preparing video file...")),
      );
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        height: 240,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.darkBorder),
        ),
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.amberAccent, size: 40),
              const SizedBox(height: 8),
              const Text(
                "Native Codec Decoding Fallback",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                widget.fileName,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              if (_localTempPath != null)
                ElevatedButton.icon(
                  onPressed: _openInExternalPlayer,
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text("Open in Device Video Player"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    if (!_isInitialized || _controller == null) {
      return Container(
        height: 240,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.darkBorder),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppColors.primaryLight, strokeWidth: 2.5),
              SizedBox(height: 14),
              Text(
                "Decrypting & Initializing Native Player...",
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    final isPlaying = _controller!.value.isPlaying;
    final duration = _controller!.value.duration;
    final position = _controller!.value.position;

    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.darkBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: _controller!.value.aspectRatio > 0 ? _controller!.value.aspectRatio : (16 / 9),
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            GestureDetector(
              onTap: () {
                setState(() {
                  _showControls = !_showControls;
                });
              },
              child: Center(
                child: VideoPlayer(_controller!),
              ),
            ),
            if (_showControls) ...[
              // Center Play/Pause button
              Center(
                child: IconButton(
                  iconSize: 56,
                  icon: Icon(
                    isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                  onPressed: () {
                    setState(() {
                      isPlaying ? _controller!.pause() : _controller!.play();
                    });
                  },
                ),
              ),
              // Top Overlay with external player option
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.open_in_new_rounded, color: Colors.white, size: 20),
                    tooltip: "Open in External Video Player",
                    onPressed: _openInExternalPlayer,
                  ),
                ),
              ),
              // Bottom Progress Bar & Timers
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black87],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    VideoProgressIndicator(
                      _controller!,
                      allowScrubbing: true,
                      colors: const VideoProgressColors(
                        playedColor: AppColors.primaryLight,
                        bufferedColor: Colors.white24,
                        backgroundColor: Colors.white10,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 4),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "${_formatDuration(position)} / ${_formatDuration(duration)}",
                          style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                _controller!.value.volume == 0 ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                                color: Colors.white70,
                                size: 18,
                              ),
                              onPressed: () {
                                setState(() {
                                  _controller!.setVolume(_controller!.value.volume == 0 ? 1.0 : 0.0);
                                });
                              },
                            ),
                            InkWell(
                              onTap: _openInExternalPlayer,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.fullscreen_rounded, size: 14, color: AppColors.primaryLight),
                                    SizedBox(width: 4),
                                    Text("Full Player", style: TextStyle(color: AppColors.primaryLight, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
