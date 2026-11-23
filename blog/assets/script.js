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

// One header row: put the section tabs inside the header, after the title.
// style.css hides the tabs until they are there. With navigation.instant,
// each page brings new tabs (with the new active tab), so the old ones go.
function doxTabsInHeader() {
  var inner = document.querySelector(".md-header__inner");
  var title = document.querySelector(".md-header__title");
  var fresh = document.querySelector(".md-container > .md-tabs");
  if (!inner || !title || !fresh) return;
  var old = inner.querySelector(".md-tabs");
  if (old) old.remove();
  title.insertAdjacentElement("afterend", fresh);
}
document$.subscribe(doxTabsInHeader);
