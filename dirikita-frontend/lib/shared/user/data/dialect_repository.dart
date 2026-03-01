import 'package:duruha/supabase_config.dart';

Future<List<String>> fetchAllDialectNames() async {
  try {
    // 1. Query only the dialect_name column from the dialects table
    final response = await supabase
        .from('dialects')
        .select('dialect_name')
        .order('dialect_name', ascending: true);

    // 2. Map the List of Maps to a List of Strings
    // Response looks like: [{"dialect_name": "Bisaya"}, {"dialect_name": "Tagalog"}]
    return (response as List)
        .map((item) => item['dialect_name'].toString())
        .toList();
  } catch (e) {
    return [];
  }
}
