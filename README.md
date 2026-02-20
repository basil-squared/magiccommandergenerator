<p align="center">
  <img src="assets/logo.png" alt="magic commander generator logo" width="600">
</p>

# magic's best commander generator. trust me.

this project downloads json data and then finds a random legendary creature and shows it to the user. im also utilizing my own json parser. yay.

## how to install

you're gonna need lua and a couple libraries. here's how:

### 1. get lua

**mac (homebrew):**

```bash
brew install lua
```

**linux (apt):**

```bash
sudo apt install lua5.4
```

**windows:**

grab it from [the lua website](https://www.lua.org/download.html) or use [luabinaries](https://luabinaries.sourceforge.net/). good luck.

### 2. get luarocks

you need luarocks to install the dependencies. if you used homebrew it probably came with lua, but if not:

```bash
brew install luarocks
```

or check [the luarocks site](https://luarocks.org/wiki/Installation).

### 3. install dependencies

```bash
luarocks install luasocket
luarocks install luasec
```

thats it. thats all you need.

## how to run

```bash
lua main.lua
```

the first time you run it, it'll download ~127MB of card data from mtgjson. this takes a minute. after that it parses everything and caches the legendary creatures so future runs are basically instant.

## what it does

1. downloads the full card database from [mtgjson](https://mtgjson.com/)
2. parses it with a custom json parser (yes i wrote my own. yes it works.)
3. finds all legendary creatures
4. caches them so you dont have to wait ever again
5. picks a random one and shows you your new commander

## credits

- [mtgjson](https://mtgjson.com/) for the data
