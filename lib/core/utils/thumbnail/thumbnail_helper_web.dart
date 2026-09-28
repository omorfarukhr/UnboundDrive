import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

Future<Uint8List?> generateVideoThumbnailPlatform(Uint8List videoBytes, String extension) async {
  try {
    final ext = extension.toLowerCase();
    String mime = 'video/mp4';
    if (ext == 'webm') {
      mime = 'video/webm';
    } else if (ext == 'ogg' || ext == 'ogv') {
      mime = 'video/ogg';
    }

    final blob = html.Blob([videoBytes], mime);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final video = html.VideoElement()
      ..src = url
      ..muted = true
      ..autoplay = false
      ..preload = 'auto';

    final completer = Completer<Uint8List?>();

    void cleanup() {
      try {
        html.Url.revokeObjectUrl(url);
      } catch (_) {}
    }

    void handleFrameCapture() {
      try {
        final rawW = video.videoWidth > 0 ? video.videoWidth : 320;
        final rawH = video.videoHeight > 0 ? video.videoHeight : 180;
        final w = rawW > 320 ? 320 : rawW;
        final h = (w * (rawH / rawW)).toInt();

        final canvas = html.CanvasElement(width: w, height: h);
        final ctx = canvas.context2D;
        ctx.drawImageScaled(video, 0, 0, w, h);
        final dataUrl = canvas.toDataUrl('image/jpeg', 0.82);
        final base64Str = dataUrl.split(',').last;
        final bytes = base64Decode(base64Str);
        cleanup();
        if (!completer.isCompleted) completer.complete(bytes);
      } catch (_) {
        cleanup();
        if (!completer.isCompleted) completer.complete(null);
      }
    }

    video.onLoadedMetadata.listen((_) {
      final duration = video.duration ?? 0;
      final target = duration > 1.0 ? 0.8 : (duration > 0.1 ? duration / 2 : 0.05);
      video.currentTime = target;
    });

    video.onSeeked.listen((_) {
      handleFrameCapture();
    });

    video.onCanPlay.listen((_) {
      if (video.currentTime == 0) {
        final duration = video.duration ?? 0;
        video.currentTime = duration > 1.0 ? 0.8 : 0.05;
      }
    });

    video.onError.listen((_) {
      cleanup();
      if (!completer.isCompleted) completer.complete(null);
    });

    // Start loading video stream
    video.load();

    // Timeout safety (extended to 6s for larger 4K / 1080p clips)
    Future.delayed(const Duration(seconds: 6), () {
      cleanup();
      if (!completer.isCompleted) completer.complete(null);
    });

    return await completer.future;
  } catch (_) {
    return null;
  }
}
