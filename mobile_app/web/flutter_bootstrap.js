{{flutter_js}}
{{flutter_build_config}}

(function () {
  const loadingElement = document.querySelector('.app-loading');

  function removeLoadingElement() {
    loadingElement?.remove();
  }

  _flutter.loader.load({
    onEntrypointLoaded: async function (engineInitializer) {
      const appRunner = await engineInitializer.initializeEngine();
      removeLoadingElement();
      await appRunner.runApp();
      requestAnimationFrame(removeLoadingElement);
      window.setTimeout(removeLoadingElement, 250);
    },
  });
})();
