# Iris Loadstring

Iris (https://github.com/SirMallard/Iris) v2.5.1 packed into one file that works with `loadstring(game:HttpGet(url))()`.

The original Iris is written in Luau and spread across many module files, so you can't just HttpGet it into an executor script. This repo has the whole library converted to plain Lua and merged into a single `bundle.lua`.

What was changed from upstream: type annotations removed, `if x then a else b` expressions rewritten to `and/or`, interpolated strings (`...`) rewritten to `string.format`, compound operators (`+=` etc.) expanded, implicit table iterators wrapped in `pairs()`, all modules merged behind a small internal require loader. The widget API is unchanged.

## Use

```lua
local Iris = loadstring(game:HttpGet("https://raw.githubusercontent.com/RuHit-Scripts/Iris-Loadstring/main/bundle.lua"))()
Iris.Init()

Iris:Connect(function()
	Iris.Window({"My Menu"})
		local enabled = Iris.Checkbox({"Enable"}).checked
		Iris.SliderNum({"FOV", 10, 500, 120})
		if Iris.Button({"Print"}).clicked() then
			print("hi")
		end
	Iris.End()
end)
```

Works on mobile executors (tested against Delta's Lua environment).

## License

Iris itself is MIT, by Michael_48 (SirMallard). See LICENSE.
