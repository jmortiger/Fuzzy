{{flutter_js}}
{{flutter_build_config}}

// const searchParams = new URLSearchParams(window.location.search);
// const forceCanvaskit = true;//searchParams.get('force_canvaskit') === 'true';
// const userConfig = forceCanvaskit ? {'renderer': 'canvaskit'} : {};
_flutter.buildConfig.builds.push({
	"compileTarget": "dartdevc",
	"renderer": "html",
	"mainJsPath": "main.dart.js"
});
_flutter.buildConfig.builds.push({
	"compileTarget": "dartdevc",
	"renderer": "canvaskit",
	"mainJsPath": "main.dart.js"
});
_flutter.loader.load({
  config: {"renderer": "html"},
});