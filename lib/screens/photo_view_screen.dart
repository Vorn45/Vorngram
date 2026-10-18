import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

class PhotoViewScreen extends StatelessWidget {
  final String? imageSource; // base64, data:image, or http URL
  final Uint8List? imageBytes;
  final String title;
  final String? subtitle;
  final String heroTag;

  const PhotoViewScreen({
    super.key,
    this.imageSource,
    this.imageBytes,
    required this.title,
    this.subtitle,
    required this.heroTag,
  });

  Uint8List? _getBytes() {
    if (imageBytes != null) return imageBytes;
    if (imageSource == null || imageSource!.isEmpty) return null;
    try {
      String clean = imageSource!;
      if (clean.contains(',')) {
        clean = clean.split(',')[1];
      }
      return base64Decode(clean);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _getBytes();
    final isNetwork = imageSource != null && imageSource!.startsWith('http');

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.7),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (subtitle != null && subtitle!.isNotEmpty)
              Text(
                subtitle!,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sharing photo...'), duration: Duration(seconds: 1)),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.download, color: Colors.white),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Photo saved to gallery!'), duration: Duration(seconds: 1)),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Hero(
          tag: heroTag,
          child: InteractiveViewer(
            panEnabled: true,
            minScale: 0.5,
            maxScale: 4.0,
            child: bytes != null
                ? Image.memory(
                    bytes,
                    fit: BoxFit.contain,
                  )
                : (isNetwork
                    ? Image.network(
                        imageSource!,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(Icons.broken_image, color: Colors.white54, size: 64),
                        ),
                      )
                    : const Center(
                        child: Icon(Icons.image_not_supported, color: Colors.white54, size: 64),
                      )),
          ),
        ),
      ),
    );
  }
}
