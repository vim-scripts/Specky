"
" specky: syntax highlighting for rspec test output, using the
" custom specky formatter. (rspec 2.x)
" $Id: specrun.vim,v 763cef799c74 2010/12/18 08:56:09 mahlon $
"

if has("folding")
  setlocal foldmethod=syntax
endif

" Command line as it was called, inserted by Specky
syntax match specSpeckyCmd /^Output of: .*/

" Pending specs that somehow pass
syntax keyword specCallout FIXED

" Passed specs
syntax match specPassed /.*(\d\+.\d\+s)/ contains=specDuration,specBoxLine
syntax keyword specPassedKeyword Succeeded

" Pending specs
syntax match specPending /.*PENDING: .*)$/ contains=specDuration,specBoxLine
syntax keyword specPendingKeyword Pending

" Failed specs
syntax match specFailed /.*FAILED - #\d\+)/ contains=specDuration,specBoxLine
syntax keyword specFailedKeyword Failed

" Failure details
syntax region specFailedDetails start="^FAILURE - #\d\+)" end="^$" fold contains=specCallout

" Boxes
syntax match specBox /^\(\s\+\)\?\(+[+-]\+\||.*|\)$/ contains=specFailedKeyword,specDurationKeyword,specPendingKeyword,specPassedKeyword,specBoxContent
syntax match specBoxContent /[a-zA-Z0-9]\+/ contained
syntax match specBoxLine /^\(\s\+\)\?|/ contained

" Spec timing
" syntax match specDuration /\d\+\.\d\+s/ contained
" syntax keyword specDurationKeyword Duration

highlight def link specSpeckyCmd Question
highlight def link specCallout Todo
highlight def link specPassed MoreMsg
highlight def link specPassedKeyword specPassed
highlight def link specPending Function
highlight def link specPendingKeyword specPending
highlight def link specFailed WarningMsg
highlight def link specFailedKeyword specFailed
highlight def link specFailedDetails specFailed
highlight def link specDuration Normal
highlight def link specBox LineNr
highlight def link specBoxContent Constant
highlight def link specBoxLine LineNr

let b:current_syntax = "specrun"

