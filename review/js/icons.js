/* Procedural glyph set. Everything is inline SVG so themes can recolor it
 * with currentColor; there are no image assets anywhere in the review.
 */
(function () {
  "use strict";

  var paths = {
    ember:
      '<path d="M12 2c.4 4.1-4.2 5.5-4.2 10.1a4.2 4.2 0 0 0 8.4 0c0-2.1-1.1-3.4-2-4.5.1 2.1-.7 3.4-2.1 4.1.7-3.2-.1-6.5-.1-9.7Z" fill="currentColor"/><path d="M12 14.4c-.2 1.3-1.4 1.9-1.4 3.1a1.4 1.4 0 0 0 2.8 0c0-1.1-1-1.8-1.4-3.1Z" fill="currentColor" opacity=".55"/>',
    tide:
      '<path d="M2 8.5c2.2 0 2.2 1.7 4.4 1.7s2.2-1.7 4.4-1.7 2.2 1.7 4.4 1.7 2.2-1.7 4.4-1.7M2 13c2.2 0 2.2 1.7 4.4 1.7s2.2-1.7 4.4-1.7 2.2 1.7 4.4 1.7 2.2-1.7 4.4-1.7M2 17.5c2.2 0 2.2 1.7 4.4 1.7s2.2-1.7 4.4-1.7 2.2 1.7 4.4 1.7 2.2-1.7 4.4-1.7" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>',
    verdant:
      '<path d="M20.5 3.5C10 3.5 4 9 4 20c11 0 16.5-5.8 16.5-16.5Z" fill="currentColor"/><path d="M4.8 19.2C8.5 14 12.8 9.7 18.6 6" fill="none" stroke="rgba(0,0,0,.35)" stroke-width="1.3" stroke-linecap="round"/>',
    umbra:
      '<path d="M16.6 2.8a9.4 9.4 0 1 0 4.1 12.6 7.7 7.7 0 0 1-4.1-12.6Z" fill="currentColor"/>',
    neutral:
      '<path d="M12 2.5 21.5 12 12 21.5 2.5 12 12 2.5Z" fill="none" stroke="currentColor" stroke-width="1.6"/><path d="M12 7 17 12l-5 5-5-5 5-5Z" fill="currentColor"/>',
    warden:
      '<path d="M9 4.5h6M10 3h4" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linecap="round"/><path d="M8.4 6.5h7.2l1.5 5.2v6.8H6.9v-6.8L8.4 6.5Z" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linejoin="round"/><path d="M12 8.4c.2 2-1.6 2.6-1.6 4.6a1.6 1.6 0 0 0 3.2 0c0-1-.5-1.6-1-2.2 0 1-.4 1.6-1 1.9.4-1.6.4-3.2.4-4.3Z" fill="currentColor"/><path d="M6.9 16.2h10.2M6.9 18.5h10.2" fill="none" stroke="currentColor" stroke-width="1.3" opacity=".6"/>',
    shield:
      '<path d="M12 2.8 20 6v5.5c0 4.6-3.2 8.2-8 9.7-4.8-1.5-8-5.1-8-9.7V6l8-3.2Z" fill="none" stroke="currentColor" stroke-width="1.5"/><path d="M12 7v6.5M9.4 9.4h5.2" stroke="currentColor" stroke-width="1.3" stroke-linecap="round"/>',
    star:
      '<path d="m12 2.8 2.8 5.7 6.3.9-4.6 4.4 1.1 6.3-5.6-3-5.6 3 1.1-6.3L2.9 9.4l6.3-.9L12 2.8Z" fill="currentColor"/>',
    spark:
      '<path d="M12 1.8c.5 5.2 4.9 9.6 10.2 10.2-5.3.5-9.7 4.9-10.2 10.2C11.5 16.9 7.1 12.5 1.8 12 7.1 11.5 11.5 7.1 12 1.8Z" fill="currentColor"/>',
    play:
      '<path d="M7 4.5v15L20 12 7 4.5Z" fill="currentColor"/>',
    pause:
      '<path d="M6.5 4.5h4v15h-4zM13.5 4.5h4v15h-4z" fill="currentColor"/>',
    soundOn:
      '<path d="M4 9v6h3.5L13 19V5L7.5 9H4Z" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linejoin="round"/><path d="M16 8.5a5 5 0 0 1 0 7M18.5 6a8.5 8.5 0 0 1 0 12" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>',
    soundOff:
      '<path d="M4 9v6h3.5L13 19V5L7.5 9H4Z" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linejoin="round"/><path d="m16.5 9 5 6M21.5 9l-5 6" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>',
    expand:
      '<path d="M9 4H4v5M15 4h5v5M9 20H4v-5M20 15v5h-5" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/>',
    reset:
      '<path d="M4.5 9.5A8 8 0 1 1 4 14" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"/><path d="M4 4v6h6" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"/>',
    gear:
      '<path d="M12 8.4a3.6 3.6 0 1 0 0 7.2 3.6 3.6 0 0 0 0-7.2Z" fill="none" stroke="currentColor" stroke-width="1.5"/><path d="M12 2.8v2.1M12 19.1v2.1M21.2 12h-2.1M4.9 12H2.8M18.5 5.5l-1.5 1.5M7 17l-1.5 1.5M18.5 18.5 17 17M7 7 5.5 5.5" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>',
    coin:
      '<circle cx="12" cy="12" r="8" fill="none" stroke="currentColor" stroke-width="1.5"/><path d="M12 7v10M9.5 9.2c.7-.8 4.8-1 4.8 1.2 0 2.4-4.9 1.2-4.9 3.6 0 2 3.7 2.1 5 1" fill="none" stroke="currentColor" stroke-width="1.3" stroke-linecap="round"/>',
    cards:
      '<rect x="7" y="3.5" width="10" height="14" rx="1.4" fill="none" stroke="currentColor" stroke-width="1.4"/><path d="M4.5 6.5h1M4.5 6.5v12.2c0 1 .7 1.6 1.6 1.6h8.4M10 8h4M10 11h4M12 14h2" fill="none" stroke="currentColor" stroke-width="1.3" stroke-linecap="round"/>',
    eye:
      '<path d="M2.5 12S6 5.8 12 5.8 21.5 12 21.5 12 18 18.2 12 18.2 2.5 12 2.5 12Z" fill="none" stroke="currentColor" stroke-width="1.4"/><circle cx="12" cy="12" r="2.8" fill="currentColor"/>',
    arrow:
      '<path d="M4 12h15M14 7l5 5-5 5" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"/>',
    close:
      '<path d="m5 5 14 14M19 5 5 19" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>'
  };

  function svg(name, cls) {
    var body = paths[name] || paths.spark;
    return (
      '<svg class="rz-icon' +
      (cls ? " " + cls : "") +
      '" viewBox="0 0 24 24" aria-hidden="true" focusable="false">' +
      body +
      "</svg>"
    );
  }

  window.RazeahIcons = {
    svg: svg,
    attr: function (attribute) {
      return svg(attribute || "neutral", "rz-icon--attr");
    }
  };
})();
