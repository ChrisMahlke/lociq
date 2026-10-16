/*
  Appearance for the LOC IQ website: dark or light, from a saved choice or
  the device's setting. Loaded in the head so the theme applies before the
  page paints. The switch in the header flips it and remembers the choice.
*/

(function () {
  var key = "lociq.appearance";
  var root = document.documentElement;
  var media = window.matchMedia ? window.matchMedia("(prefers-color-scheme: light)") : null;
  var icons = {
    // Shown in dark, to switch to light
    light: '<circle cx="12" cy="12" r="4"/><path d="M12 2.5V5M12 19v2.5M2.5 12H5M19 12h2.5M5.3 5.3l1.8 1.8M16.9 16.9l1.8 1.8M5.3 18.7l1.8-1.8M16.9 7.1l1.8-1.8"/>',
    // Shown in light, to switch to dark
    dark: '<path d="M20 14.5A8 8 0 1 1 9.5 4a6.5 6.5 0 0 0 10.5 10.5z"/>'
  };

  function saved() {
    try {
      var value = localStorage.getItem(key);
      return value === "dark" || value === "light" ? value : null;
    } catch (e) {
      return null;
    }
  }

  var choice = saved();

  function current() {
    return choice || (media && media.matches ? "light" : "dark");
  }

  root.setAttribute("data-theme", current());

  document.addEventListener("DOMContentLoaded", function () {
    var button = document.querySelector(".theme-toggle");
    if (!button) return;

    function update() {
      var theme = current();
      var next = theme === "dark" ? "light" : "dark";
      root.setAttribute("data-theme", theme);
      button.innerHTML = '<svg class="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.3" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' + icons[next] + "</svg>";
      button.setAttribute("aria-label", "Switch to " + next + " theme");
    }

    button.addEventListener("click", function () {
      choice = current() === "dark" ? "light" : "dark";
      try {
        localStorage.setItem(key, choice);
      } catch (e) {}
      update();
    });

    if (media && media.addEventListener) media.addEventListener("change", update);

    update();
    button.hidden = false;
  });
})();
