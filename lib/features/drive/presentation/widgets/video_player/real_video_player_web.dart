import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'dart:typed_data';
import 'package:flutter/material.dart';

final Set<String> _registeredPlayerViews = {};

Widget buildPlatformVideoPlayer({
  required String videoId,
  Uint8List? videoBytes,
  String? videoUrl,
  required String fileName,
  required String extension,
}) {
  final ext = extension.toLowerCase();
  String mimeType = 'video/mp4';
  if (ext == 'webm') {
    mimeType = 'video/webm';
  } else if (ext == 'ogg' || ext == 'ogv') {
    mimeType = 'video/ogg';
  } else if (ext == 'mov') {
    mimeType = 'video/quicktime';
  }

  String finalSrc = '';
  if (videoBytes != null && videoBytes.isNotEmpty) {
    final blob = html.Blob([videoBytes], mimeType);
    finalSrc = html.Url.createObjectUrlFromBlob(blob);
  } else if (videoUrl != null && videoUrl.isNotEmpty) {
    finalSrc = videoUrl;
  } else {
    finalSrc = '';
  }

  final viewType = 'unbound-video-$videoId-${DateTime.now().millisecondsSinceEpoch}';

  ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
    final videoElement = html.VideoElement()
      ..src = finalSrc
      ..controls = true
      ..setAttribute('playsinline', 'true')
      ..setAttribute('webkit-playsinline', 'true')
      ..setAttribute('controlsList', 'nodownload')
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.backgroundColor = '#000000'
      ..style.borderRadius = '16px'
      ..style.objectFit = 'contain';

    // Muted autoplay ensures compliance with modern browser autoplay security policies
    videoElement.muted = true;
    videoElement.autoplay = true;

    return videoElement;
  });

  return Container(
    height: 280,
    width: double.infinity,
    decoration: BoxDecoration(
      color: Colors.black,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.5),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: HtmlElementView(viewType: viewType),
    ),
  );
}
