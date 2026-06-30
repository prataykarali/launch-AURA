class Topic {
  final String title;
  final bool done;
  const Topic({required this.title, this.done = false});
  Topic toggle() => Topic(title: title, done: !done);
}
