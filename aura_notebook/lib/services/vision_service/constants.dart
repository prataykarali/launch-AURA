part of 'vision_service.dart';

// Short words that require word-boundary matching to avoid false positives.
// Only words that are unambiguously vision-related in standalone form.
const _kShortTriggerWords = <String>{
  'camera', 'webcam', 'gesture', 'waving', 'screenshot', 'surroundings',
  'yolo', 'detect', 'observe',
};

const List<String> _visionTriggerVocabulary = [
  'what do you see', 'what can you see', 'can you see', 'do you see',
  'did you see', 'are you seeing', 'what are you seeing',
  'look at me', 'look around', 'look here', 'look now',
  'take a look', 'have a look',
  'watch me', 'watch this', 'watch now',
  'use camera', 'open camera', 'check camera', 'scan camera', 'camera feed',
  'live camera', 'webcam', 'use webcam', 'open webcam',
  'my screen', 'on my screen', 'what is on my screen', "what's on my screen",
  'look at my screen', 'see my screen', 'read my screen', 'screen visible',
  'look at my desktop', 'active window', 'current window',
  'surroundings', 'environment',
  'around me', 'near me', 'in front of me', 'behind me',
  'wearing', 'holding', 'carrying',
  'what am i doing', "what i'm doing", 'what i am doing',
  'what am i showing', 'what is this', "what's this",
  'what is that', "what's that", 'what object', 'which object',
  'gesture', 'waving', 'thumbs up', 'open palm',
  'expression', 'smile', 'smiling',
  'movement', 'changed', 'scene change',
  'take a screenshot', 'capture screen', 'capture image',
  'snapshot', 'screenshot', 'analyze image', 'analyse image',
  'visual context', 'camera context', 'screen context',
  'showing you', 'i am showing',
  'can you tell what', 'can you tell if',
  // Standalone short words (matched with word boundaries)
  'camera', 'vision', 'visual', 'visible',
  'observe', 'observing', 'peek', 'inspect', 'recognize', 'detect', 'identify',
  'detect objects', 'detect my hand', 'detect my expression',
  'wave', 'waving at you',
  'person', 'people',
  'what do you see right now',
  'what do you see?',
  // Compound phrases that are safe for substring match
  'i see you can',  // won't false-positive on "I see what you mean"
];
