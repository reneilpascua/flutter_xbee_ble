import 'package:convert/convert.dart';

List<int> lengthInts(List<int> data) {
  // return 2 bytes representing length of the data
  return hex.decode(hex.encode([data.length]).padLeft(4, '0'));
}

int listSum(List<int> ints) {
  int sum = 0;
  ints.forEach((element) {
    sum += element;
  });
  return sum;
}

int getChecksumInt(List<int> data) {
  final intsum = listSum(data);
  final hexsum = intsum.toRadixString(16);

  // truncate and subtract from 0xFF (255 in decimal)
  final last2Digits = hexsum.substring(hexsum.length - 2, hexsum.length);
  return 255 - int.parse(last2Digits, radix: 16);
}

String getNowTime() {
  return '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}:${DateTime.now().second.toString().padLeft(2, '0')}';
}
