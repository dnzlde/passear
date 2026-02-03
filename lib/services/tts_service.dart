abstract class TtsService {
  Future<void> speak(String text);
  Future<void> stop();
  Future<void> pause();
  Future<void> dispose();
  bool get isPlaying;
  bool get isPaused;
  bool get isSynthesizing; // Add this to track synthesis progress
  void setCompletionCallback(void Function() callback);
  void setProgressCallback(
    void Function(int current, int total) callback,
  ); // Add progress tracking
}
