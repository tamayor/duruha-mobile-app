import 'dart:io';

void main() async {
  final content = await File('lib/supabase_config.dart').readAsString();
  final url = RegExp(r"const supabaseUrl = '([^']+)'").firstMatch(content)?.group(1);
  final key = RegExp(r"const supabaseAnonKey = '([^']+)'").firstMatch(content)?.group(1);
  
  if (url != null && key != null) {
    print("URL: \$url");
    // Just run a simple curl to see what the API returns!
    final result = await Process.run('curl', [
      '-s',
      '\$url/rest/v1/users_addresses?select=location&limit=1',
      '-H', 'apikey: \$key',
      '-H', 'Authorization: Bearer \$key'
    ]);
    print("CURL OUTPUT:");
    print(result.stdout);
  } else {
    print("Failed to parse");
  }
}
