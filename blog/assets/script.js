// Pygments marks most Dart words as plain names (`.n`).
// This tags two kinds so style.css can color them:
// - `dox-type`: a name that starts with a capital letter, like `Future` or `Blog`
// - `dox-call`: a name right after a dot, like `.where` or `.get`
//   (Pygments calls `get` and `set` keywords, so `.kd` is checked too)
function doxTagDartNames() {
  var names = document.querySelectorAll(".language-dart .n, .language-dart .kd");
  for (var i = 0; i < names.length; i++) {
    var name = names[i];
    var before = name.previousElementSibling;
    if (name.classList.contains("n") && /^[A-Z]/.test(name.textContent)) {
      name.classList.add("dox-type");
    } else if (before && /\.$/.test(before.textContent)) {
      name.classList.add("dox-call");
    }
  }
}

// `document$` fires on every page load, also with navigation.instant.
document$.subscribe(doxTagDartNames);
