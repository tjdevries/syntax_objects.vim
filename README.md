# syntax_objects.vim
Map keys to interact with syntax objects

## Installation

```vim
Plug 'tjdevries/standard.vim'
Plug 'tjdevries/syntax_objects.vim'
```

## How to use

```vim

" <leader> Next Function
" In after/ftplugin/vim.vim
nnoremap <buffer> <leader>nf :call syntax_objects#move_to_group('vimfuncbody',
    \ {'ignore_current': v:true, 'direction': 1})<CR>

" <leader> Previous Function
nnoremap <buffer> <leader>pf :call syntax_objects#move_to_group('vimfuncbody',
    \ {'ignore_current': v:true, 'direction': -1})<CR>
```

## Improvements

- [ ] Need to improve the speed. Some "far" searches take quite a long time to get to.
  - Maybe we could do a fun binary search or something to narrow down the search if we don't find it "n" characters
  - Should refactor to start searching at start of line _always_. This is do to vim syntax semantics
  - Early quit from the search depending on what we need (`start` vs. `finish`)
- [ ] Work with motions:
  - `call syntax_objects#register('s', 'string')`
  - Then you can do:
    - `ysis`: like surround, Yank Surroudning Inner String
    - You can set lots of around, inner, etc. to go with these motions
- [ ] Documentation
- [ ] `conf.vim` set up and options to use.
  - Setting default values for "expected" behavior
