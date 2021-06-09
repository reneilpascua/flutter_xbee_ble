main() {
  final codeunits = [126, 0, 19, 65533, 2, 104, 101, 108, 108, 108, 111, 32, 119, 111, 114, 108, 100, 33, 33, 33, 33, 33, 33, 46];
  codeunits.forEach((element) {});
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