main() {
  final sample = '7E0086AC0254B7EE565EE2E7807617C15F458DF1A5A4C7975A0F85502B18AF5FE8D2442952D5D73B9C2673FB30CCFDC8DF5F543D419EF97948EB44EA56713697184AF82711EB990B5BACF3B8B6CC9D5C468DBF0371F1B97A864DDDBBC71724440CC760B734C08429DBCE2F4F16A14EE3B7E38D166E1A34718FAD3F3B6DA398172E3C2195EE0FC0E5608B';

  // print(stringToIntList(sample));

  final a = [126,0,134,172];
  print(intListToHexString(a));
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