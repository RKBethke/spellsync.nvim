# spellsync.nvim

A simple replacement for `spellfile.vim` which has no dependencies on netrw.

## Features

* Install spellfiles on-demand with the `:SpellSync <lang>` command.
* Automatically install spell files in response to the `SpellFileMissing` autocommand.
* No external dependencies other than `cURL` and `mkdir`.

## Installation

- With [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
    'RKBethke/spellsync.nvim',
    config = function()
        require('spellsycn').setup()
    end
}
```

- With [lazy.nvim](https://github.com/folke/lazy.nvim)
```lua
return {
    "RKBethke/spellsync.nvim",
    init = function()
        require("spellsync").setup()
    end,
}
```

## License

This project is licensed under the MIT No Attribution License - see the [LICENSE.md](LICENSE.md) file for details.
