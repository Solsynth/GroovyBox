package dev.solsynth.rhythmBox

import com.ryanheise.audioservice.AudioServiceActivity

/**
 * The app's activity, on audio_service's engine.
 *
 * AudioServiceActivity shares the Flutter engine with the media service, so a
 * media button that arrives while the UI is gone still reaches the handler.
 */
class MainActivity : AudioServiceActivity()
