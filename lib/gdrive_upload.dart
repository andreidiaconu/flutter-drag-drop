//import 'dart:io';
//
//import 'package:firebase_storage/firebase_storage.dart';
//
//void saveJson(String json) {
//  File localFile = new File("tempFile.json");
//  IOSink localFileStream = localFile.openWrite();
//  localFileStream.write(json);
//  localFileStream.close();
//  StorageReference ref = FirebaseStorage.instance.ref().child("image_$random.jpg");
//  StorageUploadTask uploadTask = ref.put(imageFile);
//}