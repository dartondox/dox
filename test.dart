void abc() {
  print('work abc');
}

void def(a, b) {
  print('def: $a, $b');
}

void callFunction(
  Function f,
) {
  var functionParameters = f.toString().split('(')[1].split(')')[0].split(', ');
  print(functionParameters);
}

register(Function() f) {
  print(f);
}

void main() {
  register(() => abc());
}
