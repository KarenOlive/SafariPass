import 'package:envied/envied.dart';

part 'env.g.dart';

@Envied(path: '.env', obfuscate: true)  // obfuscate makes it harder to reverse-engineer
abstract class Env {
  @EnviedField(varName: 'GEMINI_API_KEY')
  static final String geminiApiKey = _Env.geminiApiKey;

  // Future environment variables can be added here, e.g.:
  @EnviedField(varName: 'AVIATION_STACK_API_KEY')
  static final String aviationStackApiKey = _Env.aviationStackApiKey;
}