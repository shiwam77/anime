import 'package:shared_preferences/shared_preferences.dart';

final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();

setPrefsString(String key,String value) async {
  final SharedPreferences prefs = await _prefs;
  prefs.setString(key, value);
}

 Future<String?> readPrefsString(String key) async{
  final SharedPreferences prefs = await _prefs;
  return prefs.getString(key);
}