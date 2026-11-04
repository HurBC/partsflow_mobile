import 'package:flutter/widgets.dart';

/// Pixel size to decode an image rendered at [logical] logical pixels.
int decodePx(BuildContext context, double logical) =>
    (logical * MediaQuery.devicePixelRatioOf(context)).round();

/// Max decode width for fullscreen viewers (caps memory on huge images).
const int kMaxFullscreenDecodePx = 2048;
