" vim: set noet nosta sw=4 ts=4 fdm=marker : 
"
" Specky!
" Mahlon E. Smith <mahlon@martini.nu>
" $Id: specky.vim 89 2008-07-29 23:12:11Z mahlon $
"
" Some documentation {{{
"
" ------------------------------------------------------
" What's this?
" ------------------------------------------------------
"
" Specky is a small collection of functions to help make behaviorial testing
" streamlined and easy when working with ruby and rspec.
"
" It also includes a couple of convenience functions for day to day
" programming tasks.
"
" ------------------------------------------------------
" Okay then, what does it do?
" ------------------------------------------------------
"
" By default?  Nothing, unless you are comfortable using the menus.  I decided
" the easiest way to cherry pick the functions that you'd like was to enable
" them via key bindings.  By doing this Specky won't make assumptions about
" your current bindings, and won't stomp on anything you don't want it to.
"
" After you've configured your bindings, here are some of the things you can
" now do with a single key stroke:
"
" 	- Switch back and forth from code to testing spec
"
" 	- Run the spec, with results going to a new, syntax highlighted buffer
"
" 	- Jump quickly to spec failures and failure detail
" 		- 'e' to move to each failed assertion, and 'E' to jump
" 		  to the details for it.  'q' to close the spec output buffer.
"
" 	- View rdoc of the word under the cursor
"
" 	- Dynamically switch string types for the word under the cursor
" 	  (double quoted, quoted, symbol)
"
" 	- Automatically align hash blocks and assignment lines
"
"
" ------------------------------------------------------
" Configuration
" ------------------------------------------------------
"
" Here are all of the available configuration options.
" Note that you must at least set the *Key binding variables to enable the
" functions.  Everything else is optional.  Put these into your ~/.vimrc, or
" wherever else you store this kind of stuff.
"
"
"    g:speckySpecSwitcherKey
"    -----------------------
"    Setting this enables spec to code switching, and visa versa.
"    
"    Switching uses path searching instead of reliance on directory structure
"    in your project.  The idea here is that you'd :chdir into your project
"    directory.  Spec files just need to end in '_spec.rb'.
"
"        aRubyClass.rb ---> aRubyClass_spec.rb
"
"
"    g:speckyQuoteSwitcherKey
"    ------------------------
"    Setting this enables quote style switching.
"
"    If you aren't in ruby mode, this just changes the word under the cursor
"    back and forth from double quoting to single quoting.
"
"    In ruby mode, symbols are also put into the rotation.
"
"        "string" -> 'string' -> :string
"
"
"    g:speckyRunRdocKey
"    ------------------
"    Setting this enables the display of rdoc documentation for the current
"    word under the cursor.
"
"
"    g:speckyRunRdocCmd
"    ------------------
"    If you prefer an rdoc display program other than 'ri', you can set it
"    with this variable.
"
"
"    g:speckyRunRdocFlags
"    --------------------
"    Any additional flags for the g:speckyRunRdocCmd program.
"
"
"    g:speckyRunSpecKey
"    ------------------
"    Settings this variable allows you to run 'spec' on the current buffer.
"
"
"    g:speckySpecFlags
"    -----------------
"    Any additional flags for the 'spec' program.  Defaults to '-fs'.
"
"
"    g:speckyVertSplit
"    -----------------
"    For both spec and rdoc commands, split the window vertically instead of
"    horizontally.
"
"
"    g:speckyAlignKey
"    -----------------
"    Automatically line up consecutive assignments, or hash definitions.
"    Here's a useful macro, assuming you use the 'cntl-s a' binding:
"
"    	:map <C-S>} vi}=vi}<C-S>a 
"
"	 This auto aligns anything inside braces.
"
"    hash = {                  |   hash = {   
"        :blah => 1,           |       :blah     => 1,
"                :woo => 2,    |       :woo      => 2,
"            :whatever => 3    |       :whatever => 3 
"    }                         |   }
"
"
" Here's what my config looks like:
"
" let g:speckySpecSwitcherKey = '<C-S>x'
" let g:speckyQuoteSwitcherKey = "<C-S>'"
" let g:speckyRunRdocKey = '<C-S>r'
" let g:speckyRunRdocCmd = 'fri'
" let g:speckyRunRdocFlags = '-L -f plain'
" let g:speckyRunSpecKey = '<C-S>s'
" let g:speckySpecFlags = '-fs -r extra_libs.rb'
" let g:speckyVertSplit = 1
" let g:speckyAlignKey = "<C-S>a"
" map <C-S>} vi}=vi}<C-S>a 


" }}}
" Hook up the functions to the user supplied key bindings. {{{
"
if exists( 'g:speckySpecSwitcherKey' )
	exec 'map ' . g:speckySpecSwitcherKey . ' :call <SID>SpecSwitcher()<CR>'
endif

if exists( 'g:speckyQuoteSwitcherKey' )
	exec 'map ' . g:speckyQuoteSwitcherKey . ' :call <SID>QuoteSwitcher()<CR>'
endif

if exists( 'g:speckyRunSpecKey' )
	exec 'map ' . g:speckyRunSpecKey . ' :call <SID>RunSpec()<CR>'
endif

if exists( 'g:speckyRunRdocKey' )
	exec 'map ' . g:speckyRunRdocKey . ' :call <SID>RunRdoc()<CR>'
endif

if exists( 'g:speckyAlignKey' )
	exec 'map ' . g:speckyAlignKey . ' :call <SID>AlignAssignment()<CR>'
endif


if exists( 'specky_loaded' )
	finish
endif
let specky_loaded = '$Rev: 89 $'


"}}}
" Menu configuration {{{
"
let s:menuloc = '&Plugin.&specky'
execute 'menu ' . s:menuloc . '.&Jump\ to\ code/spec :call <SID>SpecSwitcher()<CR>'
execute 'menu ' . s:menuloc . '.Run\ &spec :call <SID>RunSpec()<CR>'
execute 'menu ' . s:menuloc . '.&RDoc\ lookup :call <SID>RunRdoc()<CR>'
execute 'menu ' . s:menuloc . '.Rotate\ &quote\ style :call <SID>QuoteSwitcher()<CR>'
execute 'menu ' . s:menuloc . '.&Align\ assignments :call <SID>AlignAssignment()<CR>'


" }}}
" SpecSwitcher() {{{
"
" When in ruby code or an rspec BDD file, try and search recursively through
" the filesystem (within the current working directory) to find the
" respectively matching file.  (code to spec, spec to code.)
"
" This operates under the assumption that you've used chdir() to put vim into
" the top level directory of your project.
"
function! <SID>:SpecSwitcher()

	" If we aren't in a ruby file (specs are ruby-mode too) then we probably
	" don't care too much about this function.
	"
	if &ft != 'ruby'
		call s:err( "Not currently in ruby-mode." )
		return
	endif

	" Ensure that we can always search recursively for files to open.
	"
	let l:orig_path = &path
	set path=**

	" Get the current buffer name, and determine if it is a spec file.
	"
	" /tmp/something/whatever/rubycode.rb ---> rubycode.rb
	" A requisite of the specfiles is that they match to the class/code file,
	" this emulates the eigenclass stuff, but doesn't require the same
	" directory structures.
	"
	" rubycode.rb ---> rubycode_spec.rb
	" 
	let l:filename     = matchstr( bufname('%'), '[0-9A-Za-z_.-]*$' )
	let l:is_spec_file = match( l:filename, '_spec.rb$' ) == -1 ? 0 : 1

	if l:is_spec_file
		let l:other_file = substitute( l:filename, '_spec\.rb$', '\.rb', '' )
	else
		let l:other_file = substitute( l:filename, '\.rb$', '_spec\.rb', '' )
	endif

	let l:bufnum = bufnr( l:other_file )
	if l:bufnum == -1
		" The file isn't currently open, so let's search for it.
		execute 'find ' . l:other_file
	else
		" We've already got an open buffer with this file, just go to it.
		execute 'buffer' . l:bufnum
	endif

	" Restore the original path.
	"
	execute 'set path=' . l:orig_path
endfunction


" }}}
" QuoteSwitcher() {{{
"
" Wrap the word under the cursor in quotes.  If in ruby mode,
" cycle between quoting styles and symbols.
"
" variable -> "variable" -> 'variable' -> :variable
"
function! <SID>QuoteSwitcher()
	let l:type = strpart( expand("<cWORD>"), 0, 1 )
	let l:word = expand("<cword>")

	if l:type == '"'
		" Double quote to single
		"
		execute ":normal viWs'" . l:word . "'"

	elseif l:type == "'"
		if &ft == "ruby"
			" Single quote to symbol
			"
			execute ':normal viWs:' . l:word
		else
			" Single quote to double
			"
			execute ':normal viWs"' . l:word . '"'
		end

	else
		" Whatever to double quote
		"
		execute ':normal viWs"' . l:word . '"'
	endif

	" Move the cursor back into the cl:word
	"
	call cursor( 0, getpos('.')[2] - 1 )
endfunction


" }}}
" RunSpec() {{{
"
" Run this function while in a spec file to run the specs within vim.
"
function! <SID>RunSpec()

	if !executable( 'spec' )
		call s:err( '"spec" was not found in your $PATH.' )
		return
	endif

	let l:spec   = bufname('%')
	let l:buf    = 'specky:specrun'
	let l:bufnum = bufnr( l:buf )

	" Squash the old buffer, if it exists.
	"
	if buflisted( l:buf )
		execute 'bd! ' . l:buf
	endif

	execute ( exists('g:speckyVertSplit') ? 'vert new ' : 'new ') . l:buf
	execute 'setlocal buftype=nofile bufhidden=delete noswapfile filetype=specrun'
	set foldtext='--'.getline(v:foldstart).v:folddashes

	" Set up some convenient keybindings.
	"
	execute 'nnoremap <silent> <buffer> q :close<CR>'
	execute 'nnoremap <silent> <buffer> e :call <SID>FindSpecError(0)<CR>'
	execute 'nnoremap <silent> <buffer> E :call <SID>FindSpecError(1)<CR>'

	" Default flags for spec
	"
	if !exists( 'g:speckySpecFlags' )
		let g:speckySpecFlags = '-fs'
	endif

	" Call spec and gather up the output
	"
	let l:cmd    = 'spec ' . g:speckySpecFlags . ' ' . l:spec
	let l:output = system( l:cmd )
	call append( 0, split( l:output, "\n" ) )
	call append( 0, '' )
	call append( 0, 'Output of: ' . l:cmd  )
	execute 'normal gg'

	" Lockdown the buffer
	"
	execute 'setlocal nomodifiable'
endfunction


" }}}
" RunRdoc() {{{
"
" Get documentation for the word under the cursor.
"
function! <SID>RunRdoc()

	" If we aren't in a ruby file (specs are ruby-mode too) then we probably
	" don't care too much about this function.
	"
	if ( &ft != 'ruby' && &ft != 'rdoc' )
		call s:err( "Not currently in ruby-mode." )
		return
	endif

	" Set defaults
	"
	if !exists( 'g:speckyRunRdocCmd' )
		let g:speckyRunRdocCmd = 'ri'
	endif

	if !exists( 'g:speckyRunRdocFlags' )
		let g:speckyRunRdocFlags = ''
	endif

	if !executable( g:speckyRunRdocCmd )
		call s:err( '"' . g:speckyRunRdocCmd . '" was not found in your $PATH.' )
		return
	endif

	let l:buf     = 'specky:rdoc'
	let l:bufname = bufname('%')

	if ( match( l:bufname, l:buf ) != -1 )
		" Already in the rdoc buffer.  This allows us to lookup
		" something like Kernel#require.
		"
		let l:word = expand('<cWORD>')
	else
		" Not in the rdoc buffer.  This allows us to lookup
		" something like 'each' in some_hash.each { ... }
		"
		let l:word = expand('<cword>')
	endif

	" Squash the old buffer, if it exists.
	"
	if buflisted( l:buf )
		execute 'bd! ' . l:buf
	endif

	" With multiple matches, strip the comams from the cWORD.
	let l:word = substitute( l:word, ',', '', 'eg' )

	execute ( exists('g:speckyVertSplit') ? 'vert new ' : 'new ') . l:buf
	execute 'setlocal buftype=nofile bufhidden=delete noswapfile filetype=rdoc'
	execute 'nnoremap <silent> <buffer> q :close<CR>'

	" Call the documentation and gather up the output
	"
	let l:cmd    = g:speckyRunRdocCmd . ' ' . g:speckyRunRdocFlags . ' ' . l:word
	let l:output = system( l:cmd )
	call append( 0, split( l:output, "\n" ) )
	execute 'normal gg'

	" Lockdown the buffer
	"
	execute 'setlocal nomodifiable'
endfunction


" }}}
" FindSpecError( detail ) {{{
"
" Convenience searches for jumping to spec failures.
"
function! <SID>FindSpecError( detail )

	if ( a:detail )
		" Find the detailed failure text for the current failure line,
		" and unfold it.
		"
		call search('^' . matchstr(getline('.'),'\d\+)$') )
		if has('folding')
			execute 'normal za'
		endif

	else
		" Find the 'regular' failure line
		"
		call search('(ERROR - \d\+)$')
		execute 'nohl'

	endif
endfunction


" }}}
" AlignAssignment( range ) {{{
"
" Prettify =, =>, and --> lines as such:
"
"	:blah => 1,
"	:woo => 2,
"	:whatever => 3
"
"	:blah     => 1,
"	:woo      => 2,
"	:whatever => 3
"
function! <SID>AlignAssignment() range

	let l:pat     = '[-=]\+>\?'
	let l:longest = 0

	" First pass, find the longest lvalue in the selection
	"
	let l:curline = a:firstline
	while l:curline <= a:lastline
		let l:curlength = match( getline( l:curline ), l:pat )
		let l:longest   = l:curlength > l:longest ? l:curlength : l:longest
		
		let l:curline = l:curline + 1
	endwhile

	" Second pass, expand with spaces to align assignments
	"
	let l:curline = a:firstline
	while l:curline <= a:lastline
		let l:spaces_needed = l:longest - match( getline( l:curline ), l:pat )
		let l:char = ' ' . matchstr( getline( l:curline ), l:pat ) . ' '
		call setline( l:curline, substitute( getline(l:curline), l:char, repeat( ' ', l:spaces_needed ) . l:char, ''))
		let l:curline = l:curline + 1
	endwhile
endfunction


"}}}
" s:err( msg ) "{{{
" Notify of problems in a consistent fashion.
"
function! s:err( msg )
	echohl WarningMsg|echomsg 'specky: ' . a:msg|echohl None
endfunction " }}}

