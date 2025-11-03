import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class MobileFrame extends StatelessWidget {
  final Widget child;
  final String? deviceName;

  const MobileFrame({
    super.key,
    required this.child,
    this.deviceName,
  });

  @override
  Widget build(BuildContext context) {
    // Only show mobile frame on web platform
    if (!kIsWeb) {
      return child;
    }

    final screenSize = MediaQuery.of(context).size;
    final frameWidth = screenSize.width > 500 ? 390.0 : screenSize.width * 0.9;
    final frameHeight = screenSize.height > 900 ? 844.0 : screenSize.height * 0.9;

    return Scaffold(
      backgroundColor: Colors.grey[900],
      body: Center(
        child: Container(
          width: frameWidth,
          height: frameHeight,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(45),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(45),
            child: Stack(
              children: [
                // Mobile screen content
                Positioned.fill(
                  child: child,
                ),
                // Mobile frame UI elements
                _buildMobileFrameUI(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileFrameUI() {
    return Stack(
      children: [
        // Top notch
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(45),
              ),
            ),
            child: Stack(
              children: [
                // Status bar
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 50,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Time
                        const Text(
                          '9:41',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        // Status icons
                        Row(
                          children: [
                            Container(
                              width: 17,
                              height: 10,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              width: 15,
                              height: 10,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.wifi,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.signal_cellular_4_bar,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Container(
                              width: 24,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.grey[300]!, width: 1),
                              ),
                              child: Container(
                                margin: const EdgeInsets.all(1),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // Dynamic Island (for newer iPhone style)
                Positioned(
                  top: 15,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      width: 140,
                      height: 35,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(17),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Bottom home indicator
        Positioned(
          bottom: 10,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              width: 150,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
        // Side buttons
        Positioned(
          left: -2,
          top: 200,
          child: Container(
            width: 4,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Positioned(
          left: -2,
          top: 280,
          child: Container(
            width: 4,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Positioned(
          right: -2,
          top: 200,
          child: Container(
            width: 4,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ],
    );
  }
}
