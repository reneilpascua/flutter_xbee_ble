
import 'package:convert/convert.dart';
main() {
  final hi = hex.decode('7e0f0f0f');
  print(hi);
}

void pad(List<int> arr) {
  arr = [0,0,...arr, 0, 0];
}

List<int> stringToIntList(String input) {
  // check that the input string is of even length (we want pairs)
  if (input.length % 2 != 0) {
    print('incorrect usage: given string is not of even length');
    return null;
  }

  List<int> output = [];
  for (int i=0; i <= input.length - 2; i+=2) {
    final s = input.substring(i,i+2);
    output.add(int.parse(s, radix: 16));
  }

  return output;
}

String intListToHexString(List<int> input) {
  var output = '';
  input.forEach((hex) {output += hex.toRadixString(16).padLeft(2,'0');});
  return output;
}