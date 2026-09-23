// template, the host fills __WEBAPP_ENTRIES__ with [{css, filter}] at launch.
// one script manages every injected style: added at documentStart so tweaks
(function () {
  var entries = __WEBAPP_ENTRIES__;
  var styles = [];
  entries.forEach(function (e) {
    var s = document.createElement('style');
    s.textContent = e.css;
    (document.head || document.documentElement).appendChild(s);
    styles.push({ el: s, filter: e.filter });
  });
  var update = function () {
    styles.forEach(function (s) {
      s.el.disabled = !!s.filter && location.href.indexOf(s.filter) === -1;
    });
  };
  var bump = function () {
    styles.forEach(function (s) { (document.head || document.documentElement).appendChild(s.el); });
  };
  update();
  document.addEventListener('DOMContentLoaded', bump);
  window.addEventListener('popstate', update);
  window.__webappUpdateInjectedCSS = update;
})();
