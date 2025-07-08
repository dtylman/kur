import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class TempFilesCache{
  final Duration maxAge;
  final String name;
  
  TempFilesCache({required this.maxAge, required this.name});

  Future<String> getCacheDirectory() async {
    final Directory directory = await getApplicationSupportDirectory();
    final Directory cacheDir = Directory('${directory.path}/cache/$name');
    if (!await cacheDir.exists()) {      
      await cacheDir.create(recursive: true);
      debugPrint('Cache directory created at: ${cacheDir.path}');
    }    
    return cacheDir.path;
  }

  Future<Map<String, Object?>?> get(String key) async {
    final File file = await getFilePath(key);
    var fileExists = await file.exists();
    if (!fileExists) {
      debugPrint('File not found in cache: $key');
      return null;
    } 
    
    var lastModified = await file.lastModified();
    if (DateTime.now().difference(lastModified) > maxAge) {
      debugPrint('File expired in cache: $key');
      return null;
    }

    final String jsonValue = await file.readAsString();
    debugPrint('Read file from cache: $key');
    try {
      final Map<String, Object?> value = jsonDecode(jsonValue);
      return value;
    } catch (e) {
      debugPrint('Error decoding JSON from cache for $key: $e');
      return null;
    }
  }

  Future<void> put(String key, Map<String, Object?> value) async {    
    final File file = await getFilePath(key);
    if (!await file.exists()) {
      await file.create(recursive: true);
    }
    final String jsonValue = jsonEncode(value);
    await file.writeAsString(jsonValue);
    debugPrint('wrote file to cache: $key');        
  }

  void clear() async{
    debugPrint('Clearing cache for $name');
    final String cachePath = await getCacheDirectory();
    final Directory cacheDir = Directory(cachePath);
    if (await cacheDir.exists()) {
      await cacheDir.delete(recursive: true);
      debugPrint('Cache cleared for $name');
    } 
  }

  void test() async{
    var folder=  await getCacheDirectory();
    print('Cache directory: $folder');
  }
  
  Future<File> getFilePath(String key) async {
    final String cachePath = await getCacheDirectory();
    final String encodedKey = Uri.encodeComponent(key.toString());
    final File file = File('$cachePath/$encodedKey');
    if (!await file.exists()) {
      await file.create(recursive: true);
    }
    return file;
  }
}