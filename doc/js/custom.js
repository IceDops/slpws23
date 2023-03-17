function routeKeyboardShortcuts() {
  if (window.top.frames.main) return;
  $(document).keypress(function(evt) {
    if (evt.altKey || evt.ctrlKey || evt.metaKey || evt.shiftKey) return;
    if (typeof evt.orignalTarget !== "undefined" &&
        (evt.originalTarget.nodeName == "INPUT" ||
        evt.originalTarget.nodeName == "TEXTAREA")) return;
    switch (evt.charCode) {
      case 82: case 114: $('#route_list_link').click(); break; // 'r'
    }
  });
}

$(routeKeyboardShortcuts);
