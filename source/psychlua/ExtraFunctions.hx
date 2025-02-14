package psychlua;

#if LUA_ALLOWED
import llua.Lua;
import llua.LuaL;
import llua.State;
import llua.Convert;
#end

#if MODS_ALLOWED
import haxe.Json;
#end

#if sys
import sys.FileSystem;
import sys.io.File;
#end

import flixel.util.FlxSave;
import openfl.utils.Assets;

//
// Things to trivialize some dumb stuff like splitting strings on older Lua
//

class ExtraFunctions
{
	public static function implement(funk:FunkinLua)
	{
		var lua:State = funk.lua;
		
		// Keyboard & Gamepads
		Lua_helper.add_callback(lua, "keyboardJustPressed", function(name:String)
		{
			return Reflect.getProperty(FlxG.keys.justPressed, name);
		});
		Lua_helper.add_callback(lua, "keyboardPressed", function(name:String)
		{
			return Reflect.getProperty(FlxG.keys.pressed, name);
		});
		Lua_helper.add_callback(lua, "keyboardReleased", function(name:String)
		{
			return Reflect.getProperty(FlxG.keys.justReleased, name);
		});

		Lua_helper.add_callback(lua, "anyGamepadJustPressed", function(name:String)
		{
			return FlxG.gamepads.anyJustPressed(name);
		});
		Lua_helper.add_callback(lua, "anyGamepadPressed", function(name:String)
		{
			return FlxG.gamepads.anyPressed(name);
		});
		Lua_helper.add_callback(lua, "anyGamepadReleased", function(name:String)
		{
			return FlxG.gamepads.anyJustReleased(name);
		});

		Lua_helper.add_callback(lua, "gamepadAnalogX", function(id:Int, ?leftStick:Bool = true)
		{
			var controller = FlxG.gamepads.getByID(id);
			if (controller == null)
			{
				return 0.0;
			}
			return controller.getXAxis(leftStick ? LEFT_ANALOG_STICK : RIGHT_ANALOG_STICK);
		});
		Lua_helper.add_callback(lua, "gamepadAnalogY", function(id:Int, ?leftStick:Bool = true)
		{
			var controller = FlxG.gamepads.getByID(id);
			if (controller == null)
			{
				return 0.0;
			}
			return controller.getYAxis(leftStick ? LEFT_ANALOG_STICK : RIGHT_ANALOG_STICK);
		});
		Lua_helper.add_callback(lua, "gamepadJustPressed", function(id:Int, name:String)
		{
			var controller = FlxG.gamepads.getByID(id);
			if (controller == null)
			{
				return false;
			}
			return Reflect.getProperty(controller.justPressed, name) == true;
		});
		Lua_helper.add_callback(lua, "gamepadPressed", function(id:Int, name:String)
		{
			var controller = FlxG.gamepads.getByID(id);
			if (controller == null)
			{
				return false;
			}
			return Reflect.getProperty(controller.pressed, name) == true;
		});
		Lua_helper.add_callback(lua, "gamepadReleased", function(id:Int, name:String)
		{
			var controller = FlxG.gamepads.getByID(id);
			if (controller == null)
			{
				return false;
			}
			return Reflect.getProperty(controller.justReleased, name) == true;
		});

		Lua_helper.add_callback(lua, "keyJustPressed", function(name:String = '') {
			name = name.toLowerCase();
			switch(name) {
				case 'left': return PlayState.instance.controls.NOTE_LEFT_P;
				case 'down': return PlayState.instance.controls.NOTE_DOWN_P;
				case 'up': return PlayState.instance.controls.NOTE_UP_P;
				case 'right': return PlayState.instance.controls.NOTE_RIGHT_P;
				default: return PlayState.instance.controls.justPressed(name);
			}
			return false;
		});
		Lua_helper.add_callback(lua, "keyPressed", function(name:String = '') {
			name = name.toLowerCase();
			switch(name) {
				case 'left': return PlayState.instance.controls.NOTE_LEFT;
				case 'down': return PlayState.instance.controls.NOTE_DOWN;
				case 'up': return PlayState.instance.controls.NOTE_UP;
				case 'right': return PlayState.instance.controls.NOTE_RIGHT;
				default: return PlayState.instance.controls.pressed(name);
			}
			return false;
		});
		Lua_helper.add_callback(lua, "keyReleased", function(name:String = '') {
			name = name.toLowerCase();
			switch(name) {
				case 'left': return PlayState.instance.controls.NOTE_LEFT_R;
				case 'down': return PlayState.instance.controls.NOTE_DOWN_R;
				case 'up': return PlayState.instance.controls.NOTE_UP_R;
				case 'right': return PlayState.instance.controls.NOTE_RIGHT_R;
				default: return PlayState.instance.controls.justReleased(name);
			}
			return false;
		});

		// Save data management
		Lua_helper.add_callback(lua, "initSaveData", function(name:String, ?folder:String = 'psychenginemods') {
			if(!PlayState.instance.modchartSaves.exists(name))
			{
				var save:FlxSave = new FlxSave();
				// folder goes unused for flixel 5 users. @BeastlyGhost
				save.bind(name, CoolUtil.getSavePath() + '/' + folder);
				PlayState.instance.modchartSaves.set(name, save);
				return;
			}
			funk.luaTrace('initSaveData: Save file already initialized: ' + name);
		});
		Lua_helper.add_callback(lua, "flushSaveData", function(name:String) {
			if(PlayState.instance.modchartSaves.exists(name))
			{
				PlayState.instance.modchartSaves.get(name).flush();
				return;
			}
			funk.luaTrace('flushSaveData: Save file not initialized: ' + name, false, false, FlxColor.RED);
		});
		Lua_helper.add_callback(lua, "getDataFromSave", function(name:String, field:String, ?defaultValue:Dynamic = null) {
			if(PlayState.instance.modchartSaves.exists(name))
			{
				var retVal:Dynamic = Reflect.field(PlayState.instance.modchartSaves.get(name).data, field);
				return retVal;
			}
			funk.luaTrace('getDataFromSave: Save file not initialized: ' + name, false, false, FlxColor.RED);
			return defaultValue;
		});
		Lua_helper.add_callback(lua, "setDataFromSave", function(name:String, field:String, value:Dynamic) {
			if(PlayState.instance.modchartSaves.exists(name))
			{
				Reflect.setField(PlayState.instance.modchartSaves.get(name).data, field, value);
				return;
			}
			funk.luaTrace('setDataFromSave: Save file not initialized: ' + name, false, false, FlxColor.RED);
		});
		Lua_helper.add_callback(lua, "loadJsonOptions", function(inclMainFol:Bool = true, ?modNames:Array<String> = null) {
			#if MODS_ALLOWED
			if (modNames == null) modNames = [];
			if (modNames.length < 1) modNames.push(Paths.currentModDirectory);
			for(mod in Paths.getModDirectories(inclMainFol)) if(modNames.contains(mod) || (inclMainFol && mod == '')) {
				var path:String = haxe.io.Path.join([Paths.mods(), mod, 'options']);
				if(FileSystem.exists(path)) for(file in FileSystem.readDirectory(path)) {
					var folder:String = path + '/' + file;
					if(FileSystem.isDirectory(folder)) for(rawFile in FileSystem.readDirectory(folder)) if(rawFile.endsWith('.json')) {
						var rawJson = File.getContent(folder + '/' + rawFile);
						if (rawJson != null && rawJson.length > 0) {
							var json = Json.parse(rawJson);
							if (!ClientPrefs.data.modsOptsSaves.exists(mod)) ClientPrefs.data.modsOptsSaves.set(mod, []);
							if (!ClientPrefs.data.modsOptsSaves[mod].exists(json.variable)) {
								if (!Reflect.hasField(json, 'defaultValue')) {
									var type:String = 'bool';
									if (Reflect.hasField(json, 'type')) type = json.type;
									ClientPrefs.data.modsOptsSaves[mod][json.variable] =
										CoolUtil.getOptionDefVal(type, Reflect.field(json, 'options'));
								} else {
									ClientPrefs.data.modsOptsSaves[mod][json.variable] = json.defaultValue;
								}
							}
						}
					}
				}
			}
			return ClientPrefs.data.modsOptsSaves.toString();
			#else
			funk.luaTrace('loadJsonOptions: Platform unsupported for Json Options!', false, false, FlxColor.RED);
			return false;
			#end
		});
		Lua_helper.add_callback(lua, "getOptionSave", function(variable:String, isJson:Bool = false, ?modName:String = null) {
			if (!isJson) {
				return Reflect.getProperty(ClientPrefs.data, variable);
			} else if (isJson) {
				#if MODS_ALLOWED
				if (modName == null) modName = Paths.currentModDirectory;
				if (ClientPrefs.data.modsOptsSaves.exists(modName) && ClientPrefs.data.modsOptsSaves[modName].exists(variable)) {
					return ClientPrefs.data.modsOptsSaves[modName][variable];
				}
				#else
				funk.luaTrace('getOptionSave: Platform unsupported for Json Options!', false, false, FlxColor.RED);
				#end
			}
			return null;
		});
		Lua_helper.add_callback(lua, "setOptionSave", function(variable:String, value:Dynamic, isJson:Bool = false, ?modName:String = null) {
			if (!isJson) {
				Reflect.setProperty(ClientPrefs.data, variable, value);
				return Reflect.getProperty(ClientPrefs.data, variable) != null ? true : false;
			} else if (isJson) {
				#if MODS_ALLOWED
				if (modName == null) modName = Paths.currentModDirectory;
				if (ClientPrefs.data.modsOptsSaves.exists(modName) && ClientPrefs.data.modsOptsSaves[modName].exists(variable)) {
					ClientPrefs.data.modsOptsSaves[modName][variable] = value;
					return true;
				}
				#else
				funk.luaTrace('setOptionSave: Platform unsupported for Json Options!', false, false, FlxColor.RED);
				#end
			}
			return false;
		});
		Lua_helper.add_callback(lua, "saveSettings", function() {
			ClientPrefs.saveSettings();
			return true;
		});

		// File management
		Lua_helper.add_callback(lua, "checkFileExists", function(filename:String, ?absolute:Bool = false) {
			#if MODS_ALLOWED
			if(absolute)
			{
				return FileSystem.exists(filename);
			}

			var path:String = Paths.modFolders(filename);
			if(FileSystem.exists(path))
			{
				return true;
			}
			return FileSystem.exists(Paths.getPath('assets/$filename', TEXT));
			#else
			if(absolute)
			{
				return Assets.exists(filename);
			}
			return Assets.exists(Paths.getPath('assets/$filename', TEXT));
			#end
		});
		Lua_helper.add_callback(lua, "saveFile", function(path:String, content:String, ?absolute:Bool = false)
		{
			try {
				if(!absolute)
					File.saveContent(Paths.mods(path), content);
				else
					File.saveContent(path, content);

				return true;
			} catch (e:Dynamic) {
				funk.luaTrace("saveFile: Error trying to save " + path + ": " + e, false, false, FlxColor.RED);
			}
			return false;
		});
		Lua_helper.add_callback(lua, "deleteFile", function(path:String, ?ignoreModFolders:Bool = false)
		{
			try {
				#if MODS_ALLOWED
				if(!ignoreModFolders)
				{
					var lePath:String = Paths.modFolders(path);
					if(FileSystem.exists(lePath))
					{
						FileSystem.deleteFile(lePath);
						return true;
					}
				}
				#end

				var lePath:String = Paths.getPath(path, TEXT);
				if(Assets.exists(lePath))
				{
					FileSystem.deleteFile(lePath);
					return true;
				}
			} catch (e:Dynamic) {
				funk.luaTrace("deleteFile: Error trying to delete " + path + ": " + e, false, false, FlxColor.RED);
			}
			return false;
		});
		Lua_helper.add_callback(lua, "getTextFromFile", function(path:String, ?ignoreModFolders:Bool = false) {
			return Paths.getTextFromFile(path, ignoreModFolders);
		});
		Lua_helper.add_callback(lua, "directoryFileList", function(folder:String) {
			var list:Array<String> = [];
			#if sys
			if(FileSystem.exists(folder)) {
				for (folder in FileSystem.readDirectory(folder)) {
					if (!list.contains(folder)) {
						list.push(folder);
					}
				}
			}
			#end
			return list;
		});
		
		Lua_helper.add_callback(lua, "parseJson", function(jsonStr:String, varName:String) {
			var json = Paths.modFolders('data/' + jsonStr + '.json');
			var foundJson:Bool;
			
			#if sys
				if (FileSystem.exists(json)) {
					foundJson = true;
				} else {
					luaTrace('parseJson: Invalid json file path!', false, false, FlxColor.RED);
					foundJson = false;
					return;	
				}
			#else
				if (Assets.exists(json)) {
					foundJson = true;
				} else {
					luaTrace('parseJson: Invalid json file path!', false, false, FlxColor.RED);
					foundJson = false;
					return;	
				}
			#end
			
			if (foundJson) {
				var parsedJson = haxe.Json.parse(File.getContent(json));				
				PlayState.instance.variables.set(varName, parsedJson);
			}
		});

		// String tools
		Lua_helper.add_callback(lua, "stringStartsWith", function(str:String, start:String) {
			return str.startsWith(start);
		});
		Lua_helper.add_callback(lua, "stringEndsWith", function(str:String, end:String) {
			return str.endsWith(end);
		});
		Lua_helper.add_callback(lua, "stringSplit", function(str:String, split:String) {
			return str.split(split);
		});
		Lua_helper.add_callback(lua, "stringTrim", function(str:String) {
			return str.trim();
		});

		// Randomization
		Lua_helper.add_callback(lua, "getRandomInt", function(min:Int, max:Int = FlxMath.MAX_VALUE_INT, exclude:String = '') {
			var excludeArray:Array<String> = exclude.split(',');
			var toExclude:Array<Int> = [];
			for (i in 0...excludeArray.length)
			{
				toExclude.push(Std.parseInt(excludeArray[i].trim()));
			}
			return FlxG.random.int(min, max, toExclude);
		});
		Lua_helper.add_callback(lua, "getRandomFloat", function(min:Float, max:Float = 1, exclude:String = '') {
			var excludeArray:Array<String> = exclude.split(',');
			var toExclude:Array<Float> = [];
			for (i in 0...excludeArray.length)
			{
				toExclude.push(Std.parseFloat(excludeArray[i].trim()));
			}
			return FlxG.random.float(min, max, toExclude);
		});
		Lua_helper.add_callback(lua, "getRandomBool", function(chance:Float = 50) {
			return FlxG.random.bool(chance);
		});
	}

	 public function luaTrace(text:String, ignoreCheck:Bool = false, deprecated:Bool = false, color:FlxColor = FlxColor.WHITE) {
	 #if LUA_ALLOWED
	 if(ignoreCheck || getBool('luaDebugMode')) {
	 	if(deprecated && !getBool('luaDeprecatedWarnings')) {
	 		return;
	 	}
	 	PlayState.instance.addTextToDebug(text, color);
	 	trace(text);
	 }
	 #end
    }
	
	#if LUA_ALLOWED
	public function getBool(variable:String) {
		var result:String = null;
		Lua.getglobal(lua, variable);
		result = Convert.fromLua(lua, -1);
		Lua.pop(lua, 1);

		if(result == null) {
			return false;
		}
		return (result == 'true');
	}
	#end
}
