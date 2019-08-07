---
title: "Evaluate your ruby code directly from VIM"
layout: post
date: 2017-08-07 12:00:00 -0300
image: /assets/images/evaluate_vim.png
headerImage: true
tag:
- ruby
- vim
category: blog
author: dudribeiro
description: "How evaluate your ruby snippet directly from vim"
hidden: false
---
When I am writing code, usually I want to evaluate some piece of code. I used to do the following actions:
- Copy and paste my code to IRB (or run my ruby script file directly from the terminal).
- When using `tmux`, send my code directly from vim to tmux with the vim-tmux-runner plugin.

The first option needs an extra work of copying and pasting content. I prefer the second option, but sometimes I forgot to attach the VTR pane and get errors.

Now I’m using <https://github.com/JoshCheek/seeing_is_believing> along with <https://github.com/t9md/vim-ruby-xmpfilter> plugin

I set my `.vimrc` with the following content (I use Plug to manage my dependencies):

{% highlight viml %}
Plug 't9md/vim-ruby-xmpfilter'
" Enable seeing-is-believing mappings only for Ruby
let g:xmpfilter_cmd = "seeing_is_believing"
autocmd FileType ruby nmap <buffer> <F4> <Plug>(seeing_is_believing-mark)
autocmd FileType ruby xmap <buffer> <F4> <Plug>(seeing_is_believing-mark)
autocmd FileType ruby imap <buffer> <F4> <Plug>(seeing_is_believing-mark)
autocmd FileType ruby nmap <buffer> <F6> <Plug>(seeing_is_believing-clean)
autocmd FileType ruby xmap <buffer> <F6> <Plug>(seeing_is_believing-clean)
autocmd FileType ruby imap <buffer> <F6> <Plug>(seeing_is_believing-clean)
autocmd FileType ruby nmap <buffer> <F5> <Plug>(seeing_is_believing-run)
autocmd FileType ruby xmap <buffer> <F5> <Plug>(seeing_is_believing-run)
autocmd FileType ruby imap <buffer> <F5> <Plug>(seeing_is_believing-run)
{% endhighlight %}

Now I can visual select my code, use `F4` to `mark` and that line will be evaluated, press `F5` and get the result of that code. After, I can clean all marks with `F6`.

![running](https://miro.medium.com/max/1400/1*7gjSHyVfzMhsoa038YicQg.gif)

Cheers,
🍻
