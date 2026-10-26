import 'package:flutter/material.dart';

/// High-performance, hardware-accelerated shimmer effect widget.
class ShimmerLoading extends StatefulWidget {
  final Widget child;
  final bool isLoading;
  final Color baseColor;
  final Color highlightColor;
  final Duration duration;

  const ShimmerLoading({
    super.key,
    required this.child,
    this.isLoading = true,
    this.baseColor = const Color(0xFFE2EAF1),
    this.highlightColor = const Color(0xFFFFFFFF),
    this.duration = const Duration(milliseconds: 1300),
  });

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isLoading) return widget.child;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final gradient = LinearGradient(
              begin: const Alignment(-1.0, -0.3),
              end: const Alignment(1.0, 0.3),
              colors: [
                widget.baseColor,
                widget.highlightColor,
                widget.baseColor,
              ],
              stops: const [0.15, 0.5, 0.85],
              transform: _SlidingGradientTransform(
                slidePercent: _controller.value,
              ),
            );
            return gradient.createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;
  const _SlidingGradientTransform({required this.slidePercent});

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(
      bounds.width * (slidePercent * 2.2 - 1.1),
      0.0,
      0.0,
    );
  }
}

/// A generic shimmer placeholder box.
class ShimmerBox extends StatelessWidget {
  final double? width;
  final double? height;
  final double borderRadius;
  final BoxShape shape;
  final Color? color;

  const ShimmerBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 8,
    this.shape = BoxShape.rectangle,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color ?? const Color(0xFFE2E8F0),
        shape: shape,
        borderRadius: shape == BoxShape.circle
            ? null
            : BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Shimmer skeleton for chat conversations list.
class ChatConversationShimmerList extends StatelessWidget {
  final int count;
  const ChatConversationShimmerList({super.key, this.count = 5});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      baseColor: const Color(0xFFE8EEF5),
      highlightColor: const Color(0xFFFFFFFF),
      child: Column(
        children: List.generate(
          count,
          (index) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: const Color(0xFFE1ECF3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE2E8F0),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            height: 14,
                            width: 120,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            height: 10,
                            width: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 11,
                        width: index.isEven ? 190 : 140,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
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

/// Shimmer skeleton for active chat messages while loading or entering.
class ChatMessageShimmerList extends StatelessWidget {
  final int count;
  const ChatMessageShimmerList({super.key, this.count = 6});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      baseColor: const Color(0xFFE2EAF1),
      highlightColor: const Color(0xFFFFFFFF),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // Today date badge placeholder
          Center(
            child: Container(
              width: 80,
              height: 22,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFE2EAF1),
                borderRadius: BorderRadius.circular(11),
              ),
            ),
          ),
          _buildBubble(
            isMine: false,
            width: 220,
            height: 52,
          ),
          const SizedBox(height: 12),
          _buildBubble(
            isMine: true,
            width: 180,
            height: 44,
          ),
          const SizedBox(height: 12),
          _buildBubble(
            isMine: false,
            width: 260,
            height: 68,
          ),
          const SizedBox(height: 12),
          _buildBubble(
            isMine: true,
            width: 210,
            height: 54,
          ),
          const SizedBox(height: 12),
          _buildBubble(
            isMine: false,
            width: 240,
            height: 80,
          ),
          const SizedBox(height: 12),
          _buildBubble(
            isMine: true,
            width: 140,
            height: 40,
          ),
        ],
      ),
    );
  }

  Widget _buildBubble({
    required bool isMine,
    required double width,
    required double height,
  }) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: width,
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isMine ? const Color(0xFFCCE4DD) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMine ? 18 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 18),
          ),
          border: Border.all(
            color: isMine
                ? const Color(0xFFB0D5CB)
                : const Color(0xFFE2ECF2),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x080F172A),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              height: 11,
              width: width * 0.68,
              decoration: BoxDecoration(
                color: isMine
                    ? const Color(0xFFB8DDD2)
                    : const Color(0xFFE2EAF1),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            if (height > 46)
              Container(
                height: 10,
                width: width * 0.44,
                decoration: BoxDecoration(
                  color: isMine
                      ? const Color(0xFFB8DDD2)
                      : const Color(0xFFE2EAF1),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 8,
                  width: 32,
                  decoration: BoxDecoration(
                    color: isMine
                        ? const Color(0xFFA6D4C6)
                        : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                if (isMine) ...[
                  const SizedBox(width: 4),
                  Container(
                    height: 8,
                    width: 12,
                    decoration: BoxDecoration(
                      color: const Color(0xFFA6D4C6),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Shimmer skeleton for profile page during initial load.
class ProfileShimmerSkeleton extends StatelessWidget {
  const ProfileShimmerSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      baseColor: const Color(0xFFE8EEF5),
      highlightColor: const Color(0xFFFFFFFF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE1ECF3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE2E8F0),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 18,
                        width: 140,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 12,
                        width: 90,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 12,
                        width: 160,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE1ECF3)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE1ECF3)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 130,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE1ECF3)),
            ),
          ),
        ],
      ),
    );
  }
}
