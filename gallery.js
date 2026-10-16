/*
  Actual-size screenshot viewer for the LOC IQ website. Each thumbnail links
  to its full image, so without JavaScript a click simply opens the image.
  With it, the image opens over the page, with Prev and Next, the arrow
  keys, and a swipe to step through every screenshot, and Escape to close.
*/

(function () {
  document.addEventListener("DOMContentLoaded", function () {
    var dialog = document.querySelector(".lightbox");
    var shots = Array.prototype.slice.call(document.querySelectorAll(".shot"));
    if (!dialog || !dialog.showModal || !shots.length) return;

    var panel = dialog.querySelector(".lb-panel");
    var frame = dialog.querySelector(".lb-frame");
    var image = frame.appendChild(new Image());
    var title = dialog.querySelector(".lb-title");
    var count = dialog.querySelector(".lb-count");
    var sub = dialog.querySelector(".lb-sub");
    var index = 0;

    image.className = "block select-none";

    var items = shots.map(function (shot) {
      var link = shot.querySelector(".shot-frame");
      return {
        link: link,
        src: link.getAttribute("href"),
        width: Number(link.dataset.width),
        height: Number(link.dataset.height),
        alt: link.querySelector("img").getAttribute("alt"),
        caption: shot.querySelector(".cap").textContent.trim(),
        sub: shot.querySelector(".sub").textContent.trim()
      };
    });

    // Fit the image in the panel and the window, never above its actual size.
    function fit() {
      var item = items[index];
      var wide = item.width > item.height;
      var gutter = window.innerWidth >= 640 ? 48 : 32;
      var panelWidth = Math.min(wide ? 960 : 500, window.innerWidth - gutter);
      var maxWidth = panelWidth - 44;
      var maxHeight = Math.min(window.innerHeight * 0.73, window.innerHeight - 190);
      var scale = Math.min(maxWidth / item.width, maxHeight / item.height, 1);
      panel.style.maxWidth = (wide ? 960 : 500) + "px";
      image.style.width = Math.round(item.width * scale) + "px";
      image.style.height = Math.round(item.height * scale) + "px";
    }

    function show(next) {
      index = (next + items.length) % items.length;
      var item = items[index];
      image.src = item.src;
      image.alt = item.alt;
      title.textContent = item.caption;
      count.textContent = "(" + (index + 1) + " of " + items.length + ")";
      sub.textContent = item.sub;
      fit();
      // Fetch the neighbors so stepping through is instant.
      [index - 1, index + 1].forEach(function (i) {
        new Image().src = items[(i + items.length) % items.length].src;
      });
    }

    items.forEach(function (item, i) {
      item.link.addEventListener("click", function (event) {
        event.preventDefault();
        show(i);
        dialog.showModal();
      });
    });

    // A click anywhere on a card opens it, as the thumbnail inside it does.
    shots.forEach(function (shot, i) {
      shot.addEventListener("click", function (event) {
        if (event.target.closest(".shot-frame")) return;
        items[i].link.click();
      });
    });

    dialog.querySelector(".lb-close").addEventListener("click", function () { dialog.close(); });
    dialog.querySelector(".lb-prev").addEventListener("click", function () { show(index - 1); });
    dialog.querySelector(".lb-next").addEventListener("click", function () { show(index + 1); });

    // A click outside the panel closes the viewer.
    dialog.addEventListener("click", function (event) {
      if (event.target === dialog) dialog.close();
    });

    dialog.addEventListener("keydown", function (event) {
      if (event.key === "ArrowLeft") show(index - 1);
      else if (event.key === "ArrowRight") show(index + 1);
    });

    dialog.addEventListener("close", function () {
      items[index].link.focus({ preventScroll: true });
    });

    var startX = null;
    frame.addEventListener("touchstart", function (event) {
      startX = event.touches[0].clientX;
    }, { passive: true });
    frame.addEventListener("touchend", function (event) {
      if (startX === null) return;
      var dx = event.changedTouches[0].clientX - startX;
      startX = null;
      if (Math.abs(dx) > 40) show(dx < 0 ? index + 1 : index - 1);
    });

    window.addEventListener("resize", function () {
      if (dialog.open) fit();
    });
  });
})();
