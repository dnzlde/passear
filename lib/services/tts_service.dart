abstract class TtsService {
  Future<void> speak(String text);
  Future<void> stop();
  Future<void> pause();
  Future<void> dispose();
  bool get isPlaying;
  void setCompletionCallback(void Function() callback);
}
